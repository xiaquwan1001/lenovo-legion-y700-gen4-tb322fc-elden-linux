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
KDIR=${KDIR:-$ROOT/linux}
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
# 唯一实现见 scripts/build-initramfs.sh（可复现 + 内嵌 /init 校验 + applet 合法性）。
# 这里不再重复逻辑，避免两份实现漂移（PITFALLS #109 同类教训）。
bash "$ROOT/scripts/build-initramfs.sh" slim

# --- 选择 ramdisk -------------------------------------------------------
# 显式优先：RAMDISK=/path/to.cpio.gz 覆盖一切（可复现构建要求记录到 manifest）。
# 默认候选把 **camera 覆盖层放在首位**，否则默认构建会漏掉相机模块（vk49 的教训）。
#   RAMDISK_KIND=busybox   只打最小 busybox initramfs（out/initramfs-slim.cpio.gz）
#   RAMDISK_KIND=full      用完整 test 载具（out/initramfs-full-elden.cpio.gz，含固件）
#   RAMDISK_KIND=rootfs    用磁盘根 rootfs（默认）
if [ -n "${RAMDISK:-}" ]; then
	:   # 显式指定
elif [ "${RAMDISK_KIND:-rootfs}" = busybox ]; then
	RAMDISK="$OUT/initramfs-slim.cpio.gz"
elif [ "${RAMDISK_KIND:-rootfs}" = full ]; then
	RAMDISK="$OUT/initramfs-full-elden.cpio.gz"
	[ -e "$RAMDISK" ] || { echo "缺 $RAMDISK，先跑 scripts/build-initramfs.sh full" >&2; exit 1; }
else
	RAMDISK=""
	for c in "$OUT/rootfs-overlaid-camera.cpio.gz" "$OUT/rootfs-overlaid.cpio.gz" "$OUT/rootfs.cpio.gz" "$OUT/rootfs-vk11.cpio.gz"; do
		[ -e "$c" ] && { RAMDISK="$c"; break; }
	done
	[ -n "$RAMDISK" ] || { echo "⚠️ 找不到 rootfs cpio，回退 busybox"; RAMDISK="$OUT/initramfs-slim.cpio.gz"; }
fi
echo "ramdisk: $RAMDISK ($(du -h "$RAMDISK" | cut -f1))"

# --- cmdline（与 vk27 一致）-------------------------------------------
# ROOTARGS: use '-' (not ':-') so an explicit empty value means "RAM-only"
# (no disk root); the Alpine ramdisk then runs entirely from RAM.
#   VERSION=vk40-ram ROOTARGS= bash build-boot.sh   -> pure-RAM bring-up image
CONSOLES="${CONSOLES:-console=ttyGS0,115200 console=tty0}"
ROOTARGS="${ROOTARGS-elden_root=LABEL=linux17}"
# Slot suffix for A/B tooling (qbootctl).  The mainline cmdline has no
# `androidboot.slot_suffix`, so `qbootctl -m`/`-u` without an explicit SLOT
# argument silently fall back to slot a.  This device boots from slot b.
# Override with SLOT_SUFFIX= when a build targets slot a (or drop the arg).
SLOT_SUFFIX="${SLOT_SUFFIX:-_b}"
CMDLINE="$CONSOLES loglevel=8 ignore_loglevel printk.devkmsg=on panic=15 clk_ignore_unused pd_ignore_unused arm-smmu.disable_bypass=0 $ROOTARGS androidboot.slot_suffix=$SLOT_SUFFIX${CMDLINE_EXTRA:+ $CMDLINE_EXTRA}"
echo "cmdline: $CMDLINE"

dd if=/dev/zero of="$OUT/dtbo-dummy.img" bs=4096 count=1 2>/dev/null

# 可复现：固定时间戳（默认取内核 Image.gz 的 mtime，可用 env 覆盖）。
# SOURCE_DATE_EPOCH 已在上面打包 initramfs 时设定；此处不会再变。
export SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-$(stat -c %Y "$KERNEL")}

MKBOOTIMG_ARGS=(--header_version 2 \
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
	-o "$OUT/boot-elden-$VERSION.img")
python3 "$MKBOOTIMG" "${MKBOOTIMG_ARGS[@]}"

cp -a "$OUT/boot-elden-$VERSION.img" "$OUT/boot-elden.img"
echo
ls -la "$OUT/boot-elden-$VERSION.img"
echo "sha256: $(sha256sum "$OUT/boot-elden-$VERSION.img" | cut -d' ' -f1)"

# --- 记录 manifest（可复现/审计，提交进 git）--------------------------
RAMDISK_FILE=$RAMDISK MKBOOTIMG_ARGS="${MKBOOTIMG_ARGS[*]}" CMDLINE="$CMDLINE" KDIR="$KDIR" \
	bash "$ROOT/scripts/build-manifest.sh" "$VERSION" "$OUT/boot-elden-$VERSION.img" || \
	echo "⚠️ manifest 生成失败"

echo
echo "Next: fastboot boot $OUT/boot-elden-$VERSION.img   （或 scripts/kexec-boot.sh 热重载）"
