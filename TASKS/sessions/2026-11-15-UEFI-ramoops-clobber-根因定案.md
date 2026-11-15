# 2026-11-15 UEFI GRUB 路径：initrd 被 ramoops 覆盖 —— 根因定案

- **日期**：2026-11-15（21:00–21:35，三发上机，零写盘；ESP 已回滚 Loader-r73 `6e51fc60…`，`/boot/Image` 已还原 vk190 `0cdb7a45…`）
- **主题**：把 `TASKS/sessions/2026-11-15-UEFI-ShotAB-…md` §8 里「破坏发生在 fill 之后 → 解包之中」夹出的区间，落到具体责任方
- **结论**：**责任方 = Mu UEFI 的 `AllocatePages`（把 initrd buffer 分配进 DTB 的 `ramoops@c2000000` 保留区）
  × 内核 ramoops 控制台（t=0.0269 s 起就往那 8 MB 里写）**；不是 GRUB、不是 FDT 交接、不是位置/尺寸玄学
- **证据指针**：`reports/uefi-grub-initrd-rootcause-20261115.md`（正文）、`reports/artifacts/uefi-dbg-initrd-20261115/`（dmesg + 屏照）、`patches/local/uefi-initrd-probe-20261115/`（可复现探针）
- **★SSOT 待并入**：`INDEX.md` §0 第 4 条、`PITFALLS` #665、`TASKS/README.md` §4 N1 行

## 1. 做了什么（主机侧 40 min，可复用）

1. 给内核加**initrd 取证探针**（`init/initramfs.c`）：`ELDEN[resv]/[unpack-in]/[unpack-out]/[diag]`，
   FNV-1a 抽样规则与 `scripts/lf2-expected.py` 逐字一致 → 能直接和主机期望值（`sum=0x5c53688e`）比；
   panic 时用 `panic_notifier` 在栈底**重打一遍**（每行停 1.8 s）⇒ 拍屏终于不用抢滚屏。
2. 给 EFI stub 加打印（`kaslr.c` / `efi-stub-helper.c`）：KASLR 落点、initrd buffer 地址。
3. 给 `arch/arm64/mm/init.c` 加打印：`phys_initrd_start/size` + DRAM 范围 + `memblock.reserved` 重叠项。
   **坑**：采样内容不能放这里——`__va(initrd)` 那时还没映射，读一下整机挂死无声（QEMU 实测）。
4. GRUB 菜单改大字（`big.pf2` 96 px + `gfxmode=3040x1904x32`）：v1 菜单字太小（用户反馈）。

## 2. 三发

| 发 | 变量 | 结局 |
|---|---|---|
| 1 | `elden-noramoops.dtb`（**只删掉 8 MB ramoops 节点**）+ 64 MB initrd + 同一内核 | **起进 SSH（32 s）**：`ELDEN[unpack-in] phys=0xc18b0000 sum=0x5c53688e`、`unpack-out` 同值、解包 **2.31 s** |
| 2 | 同上，DTB 换回 `elden.dtb`（有 ramoops） | **失败**，回落 b 槽（cmdline 无 `elden_bootmenu`，内核 `00002-g4da9a8b`）；pstore 无新记录 |
| 3 | （未做）ramoops 搬到 initrd span 之外 | 备选，用来证明「只要不重叠就行」 |

## 3. 判读要点

- **initrd span 与保留区求交**才是判据：旧 6 发 base `0xc23e0000` ⇒ ramoops 盖住 buffer **前 4.3 MB**；
  本轮 base `0xc18b0000` ⇒ ramoops 盖住 **+7.67 MB 处 8 MB**。两处都表现为「解出几 MB 就坏」。
- **地址平移不是玄学**：本机 Mu 无 `EFI_RNG_PROTOCOL` ⇒ KASLR 退化 ⇒ 内核落点只由 Image 尺寸决定
  ⇒ 内核 +1 MB（内建 initramfs）就让 initrd buffer 整体挪了 ~11 MB。
- **pstore 必然留不下失败现场**：panic 记录写的就是那块被自己写乱的缓冲（§4 of report）。
  本轮能拿到干净 dmesg，是因为**第 1 发起得来**，直接 SSH 取 `dmesg`。

## 4. 设备现态（收尾）

- ESP `BOOTAA64.EFI` = Loader-r73 `6e51fc60…`（本轮 staged 的 `grub-dbg-initrd*` 已清，ESP 350 M/511 M）
- `/boot/Image` = vk190 `0cdb7a45…`（`/boot/Image.vk190-pre-dbg.bak` 同 sha，`/boot/Image.dbg` 已删）
- 新增设备件（留作复跑）：`/boot/elden-noramoops.dtb` `818f4d85…`、`/boot/initrd-slim.img` `2e2942bc…`
- `boot_a` 未动、未 flash 任何分区；本轮全部走 `fastboot boot` RAM 起
- **主机侧串口日志加限**：`/var/log/elden-serial/ttyACM0.log` 已涨到 **2.9 GB**（`elden-serial-logger.service` 常驻 append 无上限）
  ⇒ 已截断 + 新增 `/etc/logrotate.d/elden-serial`（`hourly` / `maxsize 100M` / `rotate 4` / `compress` / **`copytruncate`**；
  不能用 rename —— 写入进程拿着 fd，会继续写旧 inode 变成「日志停在旧文件」那类假阴性）

## 5. 下一步（建议顺序）

1. **内核侧修法（可上游）**：`drivers/pstore/ram.c` 的 `ramoops_probe()` 里，zone 与 `initrd_start/initrd_end`
   重叠时拒绝注册（尤其不注册 console）并 `pr_err`。
2. **GRUB 侧临时修法**：`devicetree` 之后遍历 `/reserved-memory/*`，对每个 range `AllocatePages` 占位（永不释放）。
3. **别把「删 ramoops / 挪 ramoops」写进 SSOT**当修法：`splash_region`（`0xfc800000+43 MB`）、
   `trust-ui-vm`/`oem-vm`（`0xf3800000–0xfc800000`）等 46 段同样是 Mu 眼里的空闲区，冲突只是被挪走。
4. 未决：`alloc magic is broken at 0xbffa227a0`（GRUB 堆被清零，≈47.9 GB）不落在任何 `reserved-memory` 段内
   ⇒ 同源（所有权冲突）但作用对象不同，需另设探针（GRUB 侧「分配后立刻回读」）才能钉死。
