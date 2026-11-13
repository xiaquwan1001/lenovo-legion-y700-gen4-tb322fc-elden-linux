# B16：QEMU 复刻 GRUB → vk188 → 串口 dmesg 全链（2026-11-13，主机侧）

> 任务（todo-inventory B16 / `uefi-vk188-fbcon-20261112.md` §5 未完成项）：在 QEMU 里复刻
> 「AAVMF → GRUB → EFI-stub → vk188 内核 → dmesg」，替掉 UEFI 线拍屏取证。
> **结果：PASS 4/4，单轮 ≈ 35 s。** 配方已固化为 `scripts/qemu-full-chain-smoke.sh`（可重复跑）。

## §1 判据实测（判据 = `uefi-vk188-fbcon-20261112.md` §四 通道表 + survey §3 配方 B）

串口日志（`/tmp/qfc/serial.log`，本轮实跑）：

```
UEFI firmware (version 2025.11-3ubuntu7.3 …)          ← AAVMF
BdsDxe: starting Boot0002 "UEFI Misc Device"          ← BDS 扫到 ESP
GNU GRUB  version 2.14  （菜单 "vk188 qemu-smoke"，timeout 2 s）
[    0.000000] Linux version 7.3.1-debug-vk188-sysfbfb-00002-g4da9a8b69fc8-dirty …
[    0.000000] efi: EFI v2.7 by Ubuntu distribution of EDK II     ← EFI-stub 交接成功
[    0.361681] Unpacking initramfs...
[    0.696223] [drm] Initialized simpledrm 1.0.0 for simple-framebuffer.0
[    0.722848] Console: switching to colour frame buffer device 100x37   ← ramfb fbcon 有后端
[    0.943721] Run /init as init process
```

四判据：J1 Linux version ✔ / J2 efi: EFI v2（stub 交接）✔ / J3 Run /init ✔ / J4 ramfb fbcon ✔。

## §2 相对 11-12 调研报告的四个修正（都是本轮实测踩到）

1. **不要用 `-drive file=fat:rw:DIR`（vvfat）**：GRUB 报 `error: file '/boot/Image' not found`
   （search --file 也找不到；vvfat 对大文件/目录布局不可靠）。**改用 mkfs.vfat 真镜像**
   （灌文件用 pyfatfs，宿主无 mtools/sudo）。
2. GRUB cfg 必须**显式 `search --no-floppy --file --set=root /boot/Image`**；standalone 件不猜 root。
3. 内核串口判据用 `console=ttyAMA0,115200 earlycon=pl011,0x09000000 keep_bootcon`
   （设备的 ttyGS0/efifb 在 virt 上不存在）；`-M virt` 必须 `acpi=off`（不变）。
4. GRUB 阶段与内核阶段**可以共用 ramfb**（调研报告说 GRUB 只能 virtio-gpu——本轮 GRUB 菜单在
   ramfb 下正常显示；standalone 件内嵌了 efi_gop/gfxterm）。

## §3 用法

```bash
bash scripts/qemu-full-chain-smoke.sh            # 4/4 PASS → rc=0
bash scripts/qemu-full-chain-smoke.sh --keep <Image> <initrd>   # 自定义件、保留现场
```

适用边界不变（survey §1.11）：virt 上**不能**复现 `#558`（本平台 UEFI 内存图）、A/B 槽、AVB、DSI——
本脚本的定位是「GRUB cfg/内核 stub/cmdline/fbcon 的 30 秒回归环」，不是上机替代。
