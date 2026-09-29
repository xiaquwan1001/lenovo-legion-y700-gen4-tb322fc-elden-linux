#!/bin/bash
# Pack boot.img (header v2) from kernel + rootfs.
# usage: pack.sh [rootfs.cpio.gz] [out.img]
set -eu
cd "$(dirname "$0")"
ROOTFS=${1:-out/rootfs-vk7.cpio.gz}
OUT=${2:-out/boot-elden-latest.img}
CMDLINE="console=ttyGS0,115200 console=tty0 loglevel=8 ignore_loglevel printk.devkmsg=on panic=15 clk_ignore_unused pd_ignore_unused arm-smmu.disable_bypass=0"
# Default: boot the on-disk root on the 65 GiB partition /dev/sda17 (LABEL=linux17).
# Build a RAM-only debug image with: EXTRA_CMDLINE="" pack.sh ...
# Fall back to the old 2.3 GiB root with: EXTRA_CMDLINE="elden_root=LABEL=linux"
CMDLINE="$CMDLINE ${EXTRA_CMDLINE-elden_root=LABEL=linux17}"
python3 tools/mkbootimg/mkbootimg.py --header_version 2 --os_version 15.0.0 --os_patch_level 2025-08 \
  --kernel linux/arch/arm64/boot/Image.gz --ramdisk "$ROOTFS" \
  --dtb linux/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb --cmdline "$CMDLINE" \
  --base 0x00000000 --kernel_offset 0x00008000 --ramdisk_offset 0x01000000 \
  --second_offset 0x00f00000 --tags_offset 0x00000100 --dtb_offset 0x01f00000 \
  --pagesize 4096 -o "$OUT"
SZ=$(( $(stat -c%s "$OUT") / 1048576 ))
echo "[pack] $OUT = ${SZ} MiB"
[ "$SZ" -le 96 ] || echo "[pack] WARNING: >96 MiB, fastboot boot may reject (boot_a=0x6000000)"
