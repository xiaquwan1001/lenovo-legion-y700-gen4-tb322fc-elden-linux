# 2026-11-15 UEFI GRUB 路径：Shot A / Shot B 上机实测（读路径清白，Mu 分配页成唯一候选）

- **日期**：2026-11-15（12:47–13:07 三发，零写盘；ESP 只换 BOOTAA64.EFI，已回滚）
- **pi 会话 id**：$PI_SESSION_ID
- **主题**：把「GRUB 路径 64 MB initrd 交接坏掉」从两个候选收敛到一个
- **结论**：**C1（Mu UEFI 大块 BlockIo 读回错字节）否证；C2（Mu AllocatePages 给的页被复用/不独占）成为唯一存活候选**
- **证据指针**：`reports/artifacts/uefi-grub-shotA-20261115/`（menu、EFI sha、三发运行日志）、`reports/uefi-grub-initrd-memmap-20261115.md`（判据设计）
- **★SSOT 待并入**：已并入 `TASKS` §4 N1 行、`INDEX` §0 第 4 条、`PITFALLS` #659 追加与 #664（ESP 满导致 install 半成功）

## 1. 方法（关键改进：判决产物写进 ext4 的 grubenv，宿主机直接读，不靠屏拍照）

GRUB 读 ext4 后：`hashsum --hash sha256 -p ($root) -c ($root)/boot/shotA.sha` →
`if ...; then set elden_shotA_sha=OK; else ...=BAD; fi` → `save_env -f ($root)/boot/grub/grubenv elden_shotA_sha`。
`save_env` 属 `loadenv` 模块（GRUB 2.14 里**没有** saveenv.mod），且 **grubenv 必须先存在**（`grub-editenv create`），否则报 file not found。
机制先在 QEMU 打了正反两例（正例 OK / 篡改一字节 ⇒ BAD），才上设备。

## 2. 三发上机（每发：`reboot bootloader` → `fastboot boot out/r21-sbstop-pc1/uefi-preamblec1-r1.img` → 等 SSH 回来 → 读 grubenv）

| 发 | 菜单臂 | grubenv 判决 | 判读 |
|---|---|---|---|
| 1 | Shot A：只 hash 不启动，写完 reboot | `elden_shotA=1-done`、`elden_shotA_sha=OK` | **GRUB 经 Mu BlockIo 读 64 MB initrd 与 63 MB Image，sha 与主机逐字相同**（3282ae6c… / 0cdb7a45…）⇒ **C1 否证** |
| 2 | Shot B：`linux … initrd=/boot/initrd.img`（不走 LoadFile2，改走 EFI SimpleFileSystem，仍由 Mu 分配页） | `elden_shotA=B-selected`，设备 110 s 后以 ABL 正常启动回来（serialno=HA2EXB0E） | 内核**没起来** ⇒ 换一条读文件路径仍坏 |
| 3 | Shot B2：加了 B-dtb-ok / B-linux-ok-booting 两个中间标记 | `elden_shotA=B-linux-ok-booting` | 排除「GRUB 没 stage 内核」：dtb 与 Image 都装载成功、内核确实被启动，仍没到用户态 ⇒ **坏在 Mu 给的那片内存** |

## 3. 结论与下一步

- 两条完全不同的「读文件 → 填 buffer」路径（GRUB 自己读 vs 内核 SFS 读）**都**拿不到可用 initrd，而 GRUB 自己的读**内容正确**
  ⇒ 剩下唯一能同时解释两者的点：**Mu UEFI 的 AllocatePages 返回的页被别的东西同时写**（或其内存图把可用区描述错，见
  Mu 侧 Conv 只有 0xB90C0000–0xD65C0000 = 469 MiB、0xD65C0000–0xFC800000 共 612 MiB **无条目**）。
- **下一步（主机侧先做）**：给 Mu 件插桩打印 allocation / memory map（SbMark / FrameBufferSerialPortLib），或直接把那 612 MB 标 Reserved / 补齐 Conv 后重打 pc1 —— 都是**另一个固件件、另一发**，不是 GRUB 侧能修的。
- 本轮**未**动 boot_a、未 flash 任何分区；ESP BOOTAA64.EFI 已回滚到 Loader-r73（6e51fc60…）。

## 4. 过程中踩到的两个坑（已入 PITFALLS）

1. **ESP 满 ⇒ esp-install-grub.sh --activate 半成功**：备份那步报「设备上没有空间」，但脚本继续 cp 覆盖 →
   第 3 发实际跑的是**上一版 EFI**（菜单里没有新标记，判决与第 2 发逐字相同，差点误判成「标记没生效」）。
   ⇒ 装件前后都要 df + 核对 sha256sum BOOTAA64.EFI 与预期一致。
2. **他项目遗留的孤儿 fastboot oem dump-emmc（kirin-tool，2 h 36 min 无进展）会抢通道**（PITFALLS #658 同源）：
   本轮清掉两条后才 fastboot boot，三发 getvar product 均 4 ms 返回。

## 5. 2026-11-15 14:0x：pc1m 载荷上机验证 —— **两个假设都否证**

新件 = `out/mu-memmap-20261115/uefi-preamblec1m-r1.img`（sha `300795736c3f…2fb0`，67 194 880 B；相对 pc1 `40d43397…` 只变 Mu 载荷：610 MiB 无主 DDR 标 Conv + `AllocatePages`/`EBS` 插桩）。

| 发 | 变量 | grubenv 标记 | 设备结局 | 判读 |
|---|---|---|---|---|
| 4 | pc1m + **原失败臂**（GRUB `initrd` 交 64 MB，LoadFile2） | `elden_pc1m=3-initrd-ok-booting` | panic=15 自重启回 b 槽（serialno=`HA2EXB0E`，无 `elden_bootmenu`） | **扩 Conv 不解决** |
| 5 | pc1m + 同上 + `mem=4096M`（把分配压到 4 GiB 以下，排除高地址 DDR） | `elden_pc1m=3-initrd-ok-booting` | 同上，仍失败 | **不是 >4 GiB / 高地址区的问题** |

⇒ 两条「位置类」解释都关掉：
- ~~内存图太小（Conv 只有 469 MiB）~~ **作废**：补到 ~1069 MiB 仍失败；
- ~~分配落到 4 GiB 以上的 DDR~~ **作废**：`mem=4096M` 强制压到 4 GiB 以下仍失败。

**下一步必须靠屏上判据**（pc1m 的插桩通道就是帧缓冲：`[M] ebs desc=/convMB=/allMB=` 一行 + 每次 ≥1 MiB 分配的 `[A] t=/b=/p=` 行）：
一次 `fastboot boot pc1m` 后**读/拍屏**上这两类行即可判定：
① `convMB` 是否真的从 469 涨到 ~1069（改动有没有进图）；
② 64 MB 那次 `[A]` 的 `b=`（起始地址）与页数 —— 有了地址就能对照 DTB `/reserved-memory` 与 SMEM/Gunyah 保留区，直接看出是否落在别人手里。

主机侧**无法**替代这一步（屏显是这代唯一通道；`pstore` 会被后续启动覆盖，PITFALLS #659）。


## 6. 2026-11-15 17:10 屏上取证（用户拍摄 4 张，已入档）

**产物**：`reports/artifacts/uefi-pc1m-20261115/Screenshot_20261115_1710{35,43,51}.jpg` + `_171122.jpg`

### 6.1 Mu 侧分配（pc1m 插桩，`[A] t=<type> b=<base> p=<pages>`）

| 行 | 地址 | 页数 = 大小 | 备注 |
|---|---|---|---|
| `[A] t=01 b=0CD965000 p=0006C7` | 0x0CD965000 | 1735 p = 6.94 MiB | 紧跟 `[K] esp ld` ⇒ EFI 应用（GRUB）装载 |
| `[A] t=01 b=0BFE000000 p=002000` | 0x0BFE000000 | 8192 p = 32 MiB | 同上路径的连续分配 |
| `[A] t=02 b=0C9C92000 p=003CD3` | 0x0C9C92000 | 15571 p = 63.8 MiB | **最接近 64 MB initrd 尺寸的那笔**（initrd=64 595 425 B = 15 770 p） |
| `[A] t=01 b=0BFD700000…0BFDF00000 p=000100` ×10 | 0x0BFD700000 起每 1 MiB 递减 | 各 1 MiB | 1 MiB 粒度的连续读/缓冲（与 GRUB `max_agglomerate` 量级一致） |

**RAM 侧对照（同一天、b 槽正常启动时现查）**：`/proc/iomem` 最高段 = `0x8c0000000–0xbffffffff`，`MemTotal = 15 220 752 kB`。
⇒ **上述地址全部落在真 RAM 内**，没有「分配到不存在内存」这种事 ⇒ 「Mu 交了幻影页」这条**不支持**（至少不是靠地址越界体现）。

### 6.2 内核实测（第 4 张照片，内核日志）

```
[0.466329] T1  Unpacking initramfs...
[0.589358] T1  Initramfs unpacking failed: broken padding
[0.591880] T1  Freeing initrd memory: 63080K
```
⇒ 解包只花了 **123 ms**（真件在 QEMU 要 1.6 s / 181 MB）⇒ 解压流在中途就"结束/错位"；
`Freeing … 63080K` 说明 stub **确实报告了完整 64 MB**（只是内容不对）。
屏上还有 `HugeTLB: registered 1.00 GiB / 32.0 MiB / 2.00 MiB / 64 KiB page size, pre-allocated 0 pages` 等常规行，无 arm-smmu fault。

### 6.3 现在的候选（三条，按可测性排序）

1. **缓存属性/一致性**：firmware 写这块 buffer 时的属性（WB/UC）与内核随后映射的属性不一致 ⇒ 内核读到的是"半旧"数据。**这条能同时解释两条路径都坏、而 GRUB 自读（自己 buffer、同属性写读）是好的**。
2. GRUB 的 fill 本身错（指针/长度/跨 4 GiB 搬运），但与 6.1 的各笔大小对不上（63.8 MiB ≠ 64.6 MiB）⇒ 需要直接验 buffer。
3. Mu 在 `ExitBootServices` 时改/收回了该区域的属性。

⇒ **下一步（已派 lane）**：给 GRUB 的 `grub_efi_initrd_load_file2()` 加「**填完 buffer 后回读抽样校验**」，结论写进 ext4 的 `/boot/grub/grubenv`（宿主机直读，不再依赖拍照）：
buffer 内容对 ⇒ 破坏在 EBS 之后/内核读取时（= 候选 1/3，转属性侧）；不对 ⇒ 候选 2。
产物要求：`out/grub-rehash-20261115/` + `reports/grub-rehash-20261115.md`（含上机单与回滚）。


## 7. 2026-11-15 19:32：v1 采样器上机 —— GRUB 报 **堆被破坏**（这是目前最硬的证据）

屏上（用户拍摄，`reports/artifacts/uefi-pc1m-20261115/Screenshot_20261115_1932{12,20}.jpg`）：

```
Booting 'PLAIN: linux + initrd (LoadFile2, 64MB) panic=15'
alloc magic is broken at 0xbffa227a0:0
Aborted. Press any key to exit.
```
底部同时可见 Mu 的分配行：`[A] t=02 b=0ca124000 p=003cd3`（63.8 MiB，type 2）与
`[A] t=01 b=0bfd900000…0bfdf00000 p=000100`（1 MiB × 多笔，自顶向下）。

**判读（重要）**：`alloc magic is broken` 是 **GRUB 自己的 malloc 头**被清零（原本应是 magic，读到 0）。
时点 = `grub_initrd_load()` 把 64 MB 写进**内核 stub 的 buffer** 之后、GRUB 下一次分配时。
⇒ **那片「分配给 kernel stub」的页与 GRUB 自己的堆重叠**（同一物理页被两个所有者同时使用），
这与「读路径清白（GRUB 自己 buffer 的 sha 完全正确）+ 两条交接路径都坏 + 内核只解出几 MB」完全自洽：
写进去的数据被 GRUB/固件后续的堆写入覆盖，反过来 GRUB 的堆头也被 64 MB 数据覆盖。

⇒ **C2 从「唯一存活候选」升级为「有直接证据的结论」**：Mu 的 `AllocatePages` 存在**重复分配/重叠**，
而不是「图太小」或「地址越界」（那两条已在 §5/§6 否证）。

**注意**：v1 采样器在回调里做 grubenv 回写，堆已坏的条件下会 abort 并卡住（本轮即如此，设备需要强制断电）。
v2 改为**只打印不写盘**（`[LF2] addr=/size=/fnv=/tail=`）+ 大字体，判据 = 屏上 fnv 与
`scripts/lf2-expected.py` 的期望值对比（`0x5c53688e` 原始文件 / `0xbe44535d` 解压后），
并且 `addr` 一旦拿到就能与 GRUB 堆区间对照，直接把「重叠」钉死。

