# G1-29「启动菜单 + 绕开 boot.img」主机侧备料：GRUB arm64-efi 全链在 QEMU 实测通过

> 线：G1-29 后半（p58 之后的剩余项）。**本轮零上机**：只动主机 + QEMU。
> 承接 `reports/uefi-p58-sdccdxe-handoff-success-20261107.md` §5「BDS/GRUB 菜单 + 直接从 FAT/EXT4 读 kernel+initrd」。

---

## 0. 结论（三件，都带复现命令）

1. **arm64 GRUB 可在本机（x86）造出来**：Ubuntu 不发 `grub-efi-arm64-bin`（只有 amd64/ia32 模块），
   从 ubuntu-ports 取 arm64 deb 解包即可交叉用。
   `scripts/grub-arm64-standalone.sh` ⇒ `build/grub-arm64/grubaa64.efi`（6 877 184 B，
   `7993adfc1e505a6b1173d35735d06f5cefbfaf8aeeacb58096ea0158b37fc3e0`，**两次重建 sha 相同 = 可复现**）。
2. **「从 ext4 读 kernel/initrd」这条链在 QEMU 端到端跑通**：AAVMF(BDS) → 找到 FAT 卷上的
   `\EFI\BOOT\BOOTAA64.EFI` → 本 GRUB → `search --label linux17` 命中 **ext4** 卷 → 读到
   `/boot/grub/grub.cfg` → 显示菜单 → `linux /boot/Image`（vk184 的 EFI-stub 内核，63 MB **未压缩**）+
   `initrd`（64 MB）+ `devicetree`（153 KB）→ 内核打出 `Linux version 7.3.1-debug-vk184-…`
   （随后因 virt 机器缺 SM8750 硬件而 panic，**属预期**，不影响「链成立」的判定）。
3. **这套 cmdline/文件布局是设备形状的**，不是玩具：kernel/initrd/dtb/cmdline 全部由
   `scripts/grub-bootfiles.sh` 从 **`out/boot-elden-vk184.img`** 解出（boot.img 里 kernel 是 gzip，
   GRUB 不认 ⇒ 必须先解压成裸 Image），生成的 `grub.cfg` 直接沿用 boot.img 头里的那串 cmdline。

## 1. 复现（全部可重跑）

```bash
# 1) 造 arm64 GRUB（首次会从 ustc 镜像取 deb，缓存进 build/grub-arm64/）
scripts/grub-arm64-standalone.sh
#   → 自校验：PE machine=ARM64 + 嵌入的前缀桩 cfg 在产物里；末尾打印 sha256

# 2) 从 boot.img 解出 Image/initrd/elden.dtb + 生成设备形状的 grub.cfg（纯主机，不碰设备）
scripts/grub-bootfiles.sh --boot-img out/boot-elden-vk184.img --out /tmp/grubtest/bf
#   → Image 63 443 456 B / initrd.img 64 622 358 B / elden.dtb 153 089 B / grub.cfg（12 个 cmdline 参数）

# 3) QEMU 端到端（FAT 卷用 qemu 的 vvfat 由目录合成，免 root/免 mformat）
#    ESP 目录 = build/grub-arm64/grubaa64.efi 放到 EFI/BOOT/BOOTAA64.EFI
#    ext4 卷   = mkfs.ext4 -L linux17 -d <含 /boot/{Image,initrd.img,elden.dtb,grub/grub.cfg} 的目录>
qemu-system-aarch64 -M virt -cpu cortex-a72 -smp 2 -m 2G \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/AAVMF/AAVMF_CODE.no-secboot.fd \
  -drive if=pflash,format=raw,file=vars.fd \
  -drive if=none,id=esp,file=fat:rw:$ESP_DIR,format=raw -device virtio-blk-device,drive=esp \
  -drive if=none,id=root,file=ext4.img,format=raw   -device virtio-blk-device,drive=root \
  -nographic -serial mon:stdio
```

实测引导输出（节选，`/tmp/grubtest/qemu3.log`）：

```
GNU GRUB  version 2.14
…  Elden Linux（GRUB 直启；内核/initrd 在 linux17） …
[    0.000000][    T0] Booting Linux on physical CPU 0x0000000000 [0x410fd083]
[    0.000000][    T0] Linux version 7.3.1-debug-vk184-00002-g4da9a8b69fc8 …
[    0.000000][    T0] Kernel panic - not syncing: Oops - Undefined instruction: Fatal exception
```

- **一处必须的测试改写**：QEMU 上没有 `ttyGS0`，故测试 cfg 额外加了 `console=ttyAMA0,115200`；
  其余一字未改（含 `devicetree` 行、63 MB Image、64 MB initrd）。
- **早前的一次「静默」也是同一个原因**：不带 `console=ttyAMA0` 时内核确实起来了，只是串口没输出
  ⇒ 判「链不通」会误判（记 `PITFALLS #558` 的同族：**判据通道自身要先验证**）。

## 2. 设备侧还差什么（都要写盘/上机，未做）

| # | 事项 | 阻塞点 |
|---|---|---|
| D1 | **建一个 FAT ESP**：本机 GPT **尾部有 262 144 扇区（1024 MiB）空闲**（`sgdisk -p /dev/sda` 实测），可**纯追加** 512 MiB ESP，不必缩 `userdata` | 写盘 ⇒ 需用户批准 + GPT 备份（`scripts/gpt-dump.sh`、`backup/<SN>-<容量>/`） |
| D2 | ESP 上放 `\EFI\BOOT\BOOTAA64.EFI` = 本 GRUB 件 + 设备 `/boot` 放 `Image/initrd.img/elden.dtb` + `/boot/grub/grub.cfg` | `scripts/grub-bootfiles.sh --device root@192.168.7.1 --apply` 只写 `/boot`（安全）；ESP 那半同上需批准 |
| D3 | **UEFI 侧要改成「让 BDS 走默认启动项」**：现世代（p58）用 `R13` 强制 `LoadImage/StartImage` FV 里的 `LinuxLoader`（`BootIntoFastboot=TRUE` 那条路），BDS 菜单根本轮不到 | 新一代配方（p59）需要新增/撤销补丁 + 1 发上机验证 |
| D4 | 验证 `devicetree` 是否必需：Mu UEFI 若已通过 EFI config table 传 DT，`devicetree` 行可去掉 | 需上机看 `dmesg | head` 的 DT 来源；先按「显式给」写，最稳 |
| D5 | 内核侧确认：`boot_b` 里的 kernel 是 **gzip**，`/boot/Image` 必须是解压后的 EFI-stub PE（本轮已解出并验过 `MZ`+`ARMd`） | 无阻塞（脚本已做） |

## 3. 判据（下一发上机怎么算成）

- ESP 建好后：`fastboot boot` p58 件 → BDS 屏上出现 **GRUB 菜单**（不是直接进 Linux），
  选第一项 → 内核起来后 `/proc/cmdline` **不含** `androidboot.slot_suffix=_b`（GRUB 的 cmdline 由我们给），
  且 `findmnt /` = `/dev/sda17`（linux17）。
- 端到端「绕开 boot.img」的排他判据 = **改一个只存在于 `/boot/grub/grub.cfg` 的令牌**
  （例：`elden_bootmenu=grub`）能在 `/proc/cmdline` 里看到，且 `boot_b` 的 sha 未变。

## 4. 产物

- `scripts/grub-arm64-standalone.sh`（造 GRUB，自校验 PE+嵌入 cfg，sha 可复现）
- `scripts/grub-bootfiles.sh`（boot.img → Image/initrd/dtb/grub.cfg；`--device … --apply` 只写 `/boot`）
- `build/grub-arm64/grubaa64.efi`（`7993adfc…`，6 877 184 B）+ 缓存的 arm64 deb（sha 已钉在脚本里）
- 计划与风险：`.pi/plans/2026-11-08-g1-29-menu-esp-p59.md`
- QEMU 现场日志（临时）：`/tmp/grubtest/qemu{2,3}.log`
