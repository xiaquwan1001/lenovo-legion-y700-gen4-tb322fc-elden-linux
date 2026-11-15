# GRUB 路径 64 MB initrd 被毁：根因定案（2026-11-15 夜）

> **一句话**：**Mu UEFI 把内核 stub 的 initrd buffer 分配在 Linux DTB 的 `ramoops@c2000000`
> （8 MB，`no-map`）保留区之内**；内核在 **t = 0.027 s** 就把 ramoops 注册成 printk 控制台并往那 8 MB 里写
> ⇒ 64 MB initrd 中间**几 MB 被内核自己覆盖** ⇒ `Initramfs unpacking failed: broken padding`（解包只花 ~120 ms）。
> 删掉 ramoops 节点的 DTB 一发生效，**同一颗内核、同一份 initrd 起进了 SSH**。

- 日期：2026-11-15（21:00–21:35，三发上机，零写盘；ESP 已回滚 Loader-r73，`/boot/Image` 已还原 vk190）
- 取证件：`patches/local/uefi-initrd-probe-20261115/`（内核探针 + 内建 initramfs + 大字菜单）
- 产物：`out/dbg-uefi-initrd-20261115/`、`reports/artifacts/uefi-dbg-initrd-20261115/`
- 上游化候选：**pstore/ram 不该把「与 initrd 重叠」的 zone 注册成控制台**（详见 §5）

---

## 1. 结论的因果链（每一环都有实测）

| # | 事实 | 证据 |
|---|---|---|
| 1 | **同一份 initrd，GRUB 自己读的 sha 与主机逐字相同** | 11-15 ShotA：`grubenv elden_shotA_sha=OK`（63 MB Image + 64 MB initrd） |
| 2 | **GRUB 填完内核 buffer 后，那 64 MB 的抽样校验也与主机逐字相同** | 11-15 LF2 v2：`elden_lf2_addr=0xc23e0000 len=64595425 sum=0x5c53688e tail=8eff7f5e…`（= `scripts/lf2-expected.py` 期望值） |
| 3 | 内核解包在同一地址**只花 123 ms** 就 `broken padding`（真件在 QEMU 要 1.5–2.3 s） | §6.2 屏照；本轮 `ELDEN[unpack-in/out]` 计时另一侧 |
| 4 | **b 槽内核在 t = 0.0269 s 就把 ramoops 注册成控制台** | `dmesg`：`printk: legacy console [ramoops-1] enabled` / `ramoops: using 0x800000@0xc2000000` / `OF: reserved mem: 0xc2000000..0xc27fffff (8192 KiB) nomap non-reusable ramoops@c2000000` |
| 5 | **initrd buffer 的物理区间包含 ramoops 那 8 MB** | 旧 6 发：base `0xc23e0000`（**+0 MB…+4.3 MB** 落在 ramoops 内）；本轮：base `0xc18b0000`，span `0xc18b0000–0xc565b000`（ramoops 落在 **+7.67 MB** 处） |
| 6 | **删掉 ramoops 节点（其余 DTB 逐字不变）⇒ 同一内核起进 SSH** | 本轮第 1 发：`uname -r = 7.3.1-debug-…-00003-gbf0adba8ff9a-dirty`、cmdline 带 `elden_bootmenu=grub-dbg-noramoops`、`ELDEN[unpack-in] phys=0xc18b0000 sum=0x5c53688e` → `unpack-out` **同样值**，解包 2.31 s，32 s 后到用户态 |
| 7 | 换回带 ramoops 的 `elden.dtb`（同内核同菜单同 initrd）⇒ **失败**，设备回落 b 槽 | 本轮第 2 发：回来是 `7.3.1-…-00002-g4da9a8b`、cmdline 无 `elden_bootmenu` |

**为什么一定是 Mu 的分配问题**：DTB 的 `reserved-memory` 是 **Linux 侧**概念，Mu UEFI 读不到；
它按自己的 Conv 区（`0xB90C0000–0xD65C0000` 等）分配，`0xc2000000–0xc2800000` 在它眼里是空闲。
于是 `AllocatePages` 把 64 MB buffer 铺到了 ramoops 上面 —— 这是**同一物理页两个所有者**，
正是 11-15 白天 `alloc magic is broken at 0xbffa227a0`（GRUB 自己堆被清零）那条证据的同类。

**为什么之前「换个地址就好/不好」看着像玄学**：本机 Mu 没有 `EFI_RNG_PROTOCOL` ⇒ KASLR 退化
⇒ 内核落点由 Image 尺寸决定 ⇒ **initrd buffer 地址随内核尺寸确定性平移**（vk190 → `0xc23e0000`；
本轮内建 initramfs 使 Image +1 MB → `0xc18b0000`）。
旧 6 发 base 在 `0xc23e0000`，ramoops 覆盖 buffer 的**前 4.3 MB**；本轮 base 在 `0xc18b0000`，
ramoops 覆盖 buffer 的 **+7.67 MB 处 8 MB**。两种都表现为「解出几 MB 就坏」，与历史现象逐字吻合。

## 2. 本轮三发（时间、件、结局）

| 发 | 件 | 结局 | 判读 |
|---|---|---|---|
| 1 | Image `7dbfc69e…`（含 ELDEN 探针 + 内建 initramfs）+ **`elden-noramoops.dtb`**（删掉 8 MB ramoops 节点）+ 64 MB initrd（LoadFile2） | **起进 SSH 32 s**，`unpack-in/out` 均 `sum=0x5c53688e`、解包 2.31 s | **根因确认**：ramoops 那 8 MB 是唯一变量 |
| 2 | 同上，只把 DTB 换回 **`elden.dtb`**（ramoops 有 `console-size`） | 失败，回落 b 槽（无 `elden_bootmenu`）；`/sys/fs/pstore` **无新记录** | A/B 成立；失败现场仍留不下（ramoops 记录本身也被自己覆盖，见 §4） |
| 3（未做，可选） | 把 ramoops **搬到** initrd span 之外（如 `0x100000000`）再试 | — | 若成功 ⇒ 证明「只要不重叠就行」，可直接当项目侧临时修法 |

产品件：`out/dbg-uefi-initrd-20261115/{Image.v3, grubaa64-dbg3.efi, grubaa64-dbg4.efi, menu.cfg}`；
屏照 `reports/artifacts/uefi-dbg-initrd-20261115/Screenshot_20261115_212312.jpg`；
完整 dmesg `reports/artifacts/uefi-dbg-initrd-20261115/dmesg-boot-1-noramoops.log`。

## 3. 顺手拿到的两个新能力

1. **内核侧探针**（`ELDEN[resv]/[unpack-in]/[unpack-out]/[diag]` + panic_notifier 栈底重打）：
   以后任何「initrd 交接坏掉」都能一次上机分清 **fill 前 / fill 后 / 内核读时 / 解包中** 四个时点。
   `arm64_memblock_init()` 里**不能**采样内容（那时 `__va(initrd)` 还没映射，实测直接挂死），只能打印地址与 `memblock.reserved` 重叠。
2. **大字 GRUB 菜单**（`big.pf2` 96 px + `gfxmode=3040x1904x32`）：旧 v1 菜单字太小（用户反馈），
   已在 `patches/local/uefi-initrd-probe-20261115/arming-menu.cfg` 固化。

## 4. 为什么 pstore 仍然留不下失败现场

- panic 记录写进的就是那 8 MB 环形缓冲，**而它同时在 initrd 中间**：panic 时写记录 = 继续覆盖 initrd；
  失败后设备关机，b 槽启动时 ramoops 校验签名发现无效（被自己写乱）⇒ 不落地。
- 结论沿用 PITFALLS #659：**失败现场只有两条通道**——① 屏拍照（本轮已加「每行停 1.2 s + panic 后重打 + `panic=30`」）；② 让内核**起得来的那一发**自己把 `dmesg` 写盘（本轮第 1 发直接 SSH 取）。

## 5. 修法（三条，按「能不能上游」排序）

1. **Linux 侧（建议先做，可上游）**：`drivers/pstore/ram.c` 在 `ramoops_probe()` 里若发现 zone
   与 `initrd_start/initrd_end` 重叠，**拒绝注册该 zone（尤其不注册 console）**并 `pr_err` 一行。
   理由：这与 `memblock` 的 initrd 保留是同一种冲突，内核自己就该挡住；现状是「静默覆盖别人的 buffer」。
   → 可做成 `[PATCH] pstore/ram: refuse zones overlapping the initrd`。
2. **引导器侧（项目内立即可用）**：GRUB 在执行 `devicetree` 之后，遍历 `/reserved-memory/*`，
   对每个 range 调 `AllocatePages`（EFI_LOADER_DATA，永不释放）——把固件自己的池子先占住，
   这样后续 `LoadFile2` 的 buffer 不可能再落进去。代价 = 永久占几 MB；收益 = **不需要改 Mu**。
3. **设备 DTB 侧（最快但不通用）**：把 `ramoops` 挪到不可能被固件分配的地址，或本轮用过的「删节点」。
   **不要当修法写进 SSOT**：它只是把冲突撞到别处（`tokens`：splash_region / adsp heap / trust-ui-vm 等同样会被 Mu 覆盖）。

## 6. 未决点

- `alloc magic is broken at 0xbffa227a0`（GRUB 堆被清零，≈47.9 GB，接近 DRAM 顶端 `0xc00000000`）：
  该地址**不落在** DTB 任何 `reserved-memory` 段里（已逐段核对 46 段），所以是「Mu 分配的页被第三方写」的**另一例**，
  与本条同源（所有权冲突）但作用对象不同。若后续要钉死，用同一套探针 + 在 GRUB 侧加「分配后立刻回读」即可。
- 内建 initramfs 的持久化通道（`/init` 写 `dmesg` 到 `/var/log`）**在本例中被抢先**：
  外部 initrd 解包失败前已经把 rootfs 里的 `/init` 覆盖成自己的 ⇒ `No working init found`。
  要用它，得让 initrd 的失败发生在写 `/init` **之前**，或把探针脚本放到 initrd 不会碰的路径并 `rdinit=` 指过去。
