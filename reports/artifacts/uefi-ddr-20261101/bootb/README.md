# boot_b 变体（实验用，二进制不入库：可用 mkbootimg.py 从 out/boot-elden-vk183-fastrpc.img 重出）

三份都是 **vk183 原样内核/ramdisk/dtb**，只改 cmdline 加 DDR 黑匣子保留位（保证窗口不被内核分配）：

| 件 | 追加的 cmdline | 用途 |
|---|---|---|
| `boot-elden-vk183-bb1.img` | `memmap=1M$0xBFF00000` | 首试（`/dev/mem` 仍 EPERM，已废） |
| `boot-elden-vk183-bb2.img` | `memmap=1M$0xBFF00000 iomem=relaxed` | 证明 arm64 不认 `iomem=relaxed`（已废） |
| `boot-elden-vk183-bb3.img` | `memmap=1M$0xE3F00000 memmap=1M$0xC2500000` | **在机件**（2026-11-01 13:00 起） |

重建方式：
```
python3 scripts/mkbootimg.py --unpack bootslot-b/boot_b-device-backup-20261101.img --unpack-dir /tmp/ub
python3 scripts/mkbootimg.py --header_version 2 --os_version 15.0.0 --os_patch_level 2025-08 \
  --kernel /tmp/ub/kernel --ramdisk /tmp/ub/ramdisk --dtb /tmp/ub/dtb \
  --cmdline "<原 cmdline> memmap=1M\$0xE3F00000 memmap=1M\$0xC2500000" \
  --base 0 --kernel_offset 0x8000 --ramdisk_offset 0x01000000 --second_offset 0x00f00000 \
  --tags_offset 0x100 --dtb_offset 0x01f00000 --pagesize 4096 -o out/boot-elden-x.img
bash scripts/flash-b.sh out/boot-elden-x.img
```
回退：`bash scripts/flash-b.sh bootslot-b/boot_b-device-backup-20261101.img`（sha `aedae5f1…`，与原在机件逐字节相同）。
