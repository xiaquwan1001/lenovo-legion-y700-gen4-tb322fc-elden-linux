#!/bin/bash
# build-boot.sh — 打包 fastboot 可启动 boot.img（kernel + Alpine rootfs ramdisk + DTB）
#
# 用法：
#   VERSION=vk28 bash build-boot.sh          # 生成 out/boot-elden-vk28.img（并覆盖 boot-elden.img）
#   RAMDISK_KIND=busybox bash build-boot.sh  # 只打最小 busybox initramfs（调试用）
#
# 说明：设备实际启动用的是 **Alpine rootfs 当 initramfs**（与 vk27 一致：
#       ramdisk = out/rootfs-vk11.cpio.gz，cmdline 以 elden_root=LABEL=linux17 结尾）。
#       已用 vk27 原内核 + 原 ramdisk 复现验证：输出与 out/boot-elden-vk27.img **逐字节相同**。
set -e
ROOT=${ROOT:-$HOME/y700-elden}
KDIR=$ROOT/linux
OUT=$ROOT/out
IRAM=$ROOT/initramfs
MKBOOTIMG=$ROOT/tools/mkbootimg/mkbootimg.py
ROOTFS=$OUT/initramfs-root
VERSION=${VERSION:-vk28}
mkdir -p "$OUT"

KERNEL=$KDIR/arch/arm64/boot/Image.gz
DTB=$KDIR/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb
for f in "$KERNEL" "$DTB" "$IRAM/busybox" "$IRAM/init" "$IRAM/usb-gadget"; do
	[ -e "$f" ] || { echo "missing: $f"; exit 1; }
done

# --- 最小 initramfs（fallback）-----------------------------------------
rm -rf "$ROOTFS"
mkdir -p "$ROOTFS"/{bin,dev,proc,sys,tmp,mnt,etc}
cp "$IRAM/busybox" "$ROOTFS/bin/busybox"
chmod 755 "$ROOTFS/bin/busybox"
sed 's/\r$//' "$IRAM/init" > "$ROOTFS/init"
chmod 755 "$ROOTFS/init"
sed 's/\r$//' "$IRAM/usb-gadget" > "$ROOTFS/bin/usb-gadget"
chmod 755 "$ROOTFS/bin/usb-gadget"
mknod -m 600 "$ROOTFS/dev/console" c 5 1 2>/dev/null || true
( cd "$ROOTFS" && find . -print0 | cpio --null -o -H newc --owner=0:0 2>/dev/null | gzip -9 ) > "$OUT/initramfs.cpio.gz"
echo "initramfs(busybox): $(du -h "$OUT/initramfs.cpio.gz" | cut -f1)"

# --- 选择 ramdisk：默认用 Alpine rootfs（与 vk27 一致）------------------
if [ "${RAMDISK_KIND:-rootfs}" = busybox ]; then
	RAMDISK="$OUT/initramfs.cpio.gz"
else
	RAMDISK=""
	for c in "$OUT/rootfs-overlaid.cpio.gz" "$OUT/rootfs.cpio.gz" "$OUT/rootfs-vk11.cpio.gz"; do
		[ -e "$c" ] && { RAMDISK="$c"; break; }
	done
	[ -n "$RAMDISK" ] || { echo "⚠️ 找不到 rootfs cpio，回退 busybox"; RAMDISK="$OUT/initramfs.cpio.gz"; }
fi
echo "ramdisk: $RAMDISK ($(du -h "$RAMDISK" | cut -f1))"

# --- cmdline（与 vk27 一致）-------------------------------------------
# ROOTARGS: use '-' (not ':-') so an explicit empty value means "RAM-only"
# (no disk root); the Alpine ramdisk then runs entirely from RAM.
#   VERSION=vk40-ram ROOTARGS= bash build-boot.sh   -> pure-RAM bring-up image
CONSOLES="${CONSOLES:-console=ttyGS0,115200 console=tty0}"
ROOTARGS="${ROOTARGS-elden_root=LABEL=linux17}"
CMDLINE="$CONSOLES loglevel=8 ignore_loglevel printk.devkmsg=on panic=15 clk_ignore_unused pd_ignore_unused arm-smmu.disable_bypass=0 $ROOTARGS${CMDLINE_EXTRA:+ $CMDLINE_EXTRA}"
echo "cmdline: $CMDLINE"

dd if=/dev/zero of="$OUT/dtbo-dummy.img" bs=4096 count=1 2>/dev/null

python3 "$MKBOOTIMG" \
	--header_version 2 \
	--os_version 15.0.0 --os_patch_level 2025-08 \
	--kernel "$KERNEL" \
	--ramdisk "$RAMDISK" \
	--dtb "$DTB" \
	--cmdline "$CMDLINE" \
	--base 0x00000000 \
	--kernel_offset 0x00008000 \
	--ramdisk_offset 0x01000000 \
	--second_offset 0x00f00000 \
	--tags_offset 0x00000100 \
	--dtb_offset 0x01f00000 \
	--pagesize 4096 \
	-o "$OUT/boot-elden-$VERSION.img"

cp -a "$OUT/boot-elden-$VERSION.img" "$OUT/boot-elden.img"
echo
ls -la "$OUT/boot-elden-$VERSION.img"
echo "sha256: $(sha256sum "$OUT/boot-elden-$VERSION.img" | cut -d' ' -f1)"
echo
echo "Next: adb reboot bootloader && fastboot boot $OUT/boot-elden-$VERSION.img"
