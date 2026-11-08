# 上机：p59 + GRUB chainload ESP Loader.efi（路线 B 第一发）— 2026-11-08 14:33

- fastboot boot p59 OKAY（Sending 1.487 s / Booting 10.106 s），镜像 sha 前置核对
- GRUB default=1 = 「Elden ESP loader（chainloader ESP 上的 Loader.efi）」，timeout 15
- ESP 内容（前置核对 sha 全一致）：/boot/boot.img（vk184 + `elden_bootloader=esp` 令牌，85 594 112 B）、
  /boot/dtbo.img（来自 dtbo_b，33 554 432 B）、/EFI/elden/Loader.efi（3a846511…，176 640 B）
- 观测：14:33:34 起 140 s 内 ssh 始终 down；之后 fastboot/adb/USB 三路全无 ⇒ 设备处于无 USB 的状态（挂死或已关机）
- 与上一发（diag 内核）不同点：上一发 ~75 s 内自动回 Linux（R54 fallback + boot_b）；本发 **4 min+ 未回**
