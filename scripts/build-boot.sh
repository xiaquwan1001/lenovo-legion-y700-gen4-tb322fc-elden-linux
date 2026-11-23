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
. "$ROOT/scripts/env-build.sh"   # 树默认取 patches/current-tree（日常线），KDIR= 可覆盖
KDIR=${KDIR:-$ROOT/linux}
OUT=$ROOT/out
IRAM=$ROOT/initramfs
MKBOOTIMG=${MKBOOTIMG:-$ROOT/scripts/mkbootimg.py}   # 2026-10-17 重写并从 tools/（gitignore）迁入 scripts/
ROOTFS=$OUT/initramfs-root
VERSION=${VERSION:-vk28}
mkdir -p "$OUT"

# ★ O_DIRECT 硬门（PITFALLS #513；2026-11-23 D5 批 4 / reports/scripts-hardening-4-20261123.md §3）
# 本件打印的 sha256 是**产物身份**（下一步就被 fastboot/kexec 刷/热重启的那一个图）⇒
# buffered 读可能给「稳定但错」的页缓存副本 ⇒ 默认拒绝（rc=90），显式
# ODIRECT_SHA_ALLOW_BUFFERED=1 才降级为告警（值只能当线索）。
ODIRECT_SHA=${ODIRECT_SHA:-$ROOT/scripts/odirect-sha.py}
sha_direct() {   # sha_direct <文件> → 64 位 sha256；文件不存在 → 空；拿不到真值 → rc=90
	local f=$1 v
	[ -n "$f" ] && [ -e "$f" ] || return 0
	v=$(timeout -k 10 1800 python3 "$ODIRECT_SHA" --tsv --require-odirect "$f" 2>/dev/null \
		| awk -F'\t' 'NR==1{print $3}')
	if [ -z "$v" ] || [ "${#v}" -ne 64 ]; then
		if [ "${ODIRECT_SHA_ALLOW_BUFFERED:-0}" = 1 ]; then
			v=$(sha256sum "$f" | cut -d' ' -f1)
			echo "WARN sha_direct: $f 未走 O_DIRECT ⇒ buffered 值 $v（ODIRECT_SHA_ALLOW_BUFFERED=1；判据不可信，#513）" >&2
		else
			echo "REFUSE sha_direct: $f 拿不到 O_DIRECT 结果 ⇒ 不发布该身份（#513：buffered 可能是稳定但错的页缓存副本）" >&2
			echo "        降级取证：ODIRECT_SHA_ALLOW_BUFFERED=1 重跑（值只能当线索）" >&2
			return 90
		fi
	fi
	printf '%s\n' "$v"
}
# 测试接缝：ODIRECT_SHA_LIB_ONLY=1 ⇒ 只定义函数、不进主流程
[ "${ODIRECT_SHA_LIB_ONLY:-0}" = 1 ] && { return 0 2>/dev/null || exit 0; }

KERNEL=${KERNEL_IMG:-$KDIR/arch/arm64/boot/Image.gz}
DTB=${DTB_FILE:-$KDIR/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb}
for f in "$KERNEL" "$DTB" "$IRAM/busybox" "$IRAM/init" "$IRAM/usb-gadget"; do
	[ -e "$f" ] || { echo "missing: $f"; exit 1; }
done

# 打包前硬门：拒绝死内核 / 陈旧内核 / 异树内核（PITFALLS #162；见 scripts/assert-kernel-sane.sh）。
# 绕过：SKIP_KERNEL_ASSERT=1 bash build-boot.sh ...
bash "$ROOT/scripts/assert-kernel-sane.sh" "$KERNEL" || { echo "== 打包中止：内核未通过身份闸门 =="; exit 1; }

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
# 根 label 默认值（2026-11-19 纠正）：现役根的 label 是 **linux**（GPT 手术表重建时 mkfs.ext4 -L linux），
# 旧的 linux17 已随 11-18 wipe 消失。默认写成 linux17 ⇒ 打出的 boot.img 找不到根 ⇒ panic=15 回 fastboot，
# 而重打路径“同输入逐字节相同”的自校验不会发现这个问题（它只证重打链可信，不证 label 对）。
CONSOLES="${CONSOLES:-console=ttyGS0,115200 console=tty0}"
ROOTARGS="${ROOTARGS-elden_root=LABEL=linux}"
# Slot suffix for A/B tooling (qbootctl).  The mainline cmdline has no
# `androidboot.slot_suffix`, so `qbootctl -m`/`-u` without an explicit SLOT
# argument silently fall back to slot a.  This device boots from slot b.
# Override with SLOT_SUFFIX= when a build targets slot a (or drop the arg).
SLOT_SUFFIX="${SLOT_SUFFIX:-_b}"
CMDLINE="${CMDLINE_OVERRIDE:-$CONSOLES loglevel=8 ignore_loglevel printk.devkmsg=on panic=15 clk_ignore_unused pd_ignore_unused arm-smmu.disable_bypass=0 $ROOTARGS androidboot.slot_suffix=$SLOT_SUFFIX${CMDLINE_EXTRA:+ $CMDLINE_EXTRA}}"
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
# #513 硬门：产物身份走 O_DIRECT（拿不到就 rc=90，而不是印一个可能错的 sha）
BSHA=$(sha_direct "$OUT/boot-elden-$VERSION.img") || exit 90
echo "sha256: $BSHA（O_DIRECT 直读）"

# --- 记录 manifest（可复现/审计，提交进 git）--------------------------
RAMDISK_FILE=$RAMDISK MKBOOTIMG_ARGS="${MKBOOTIMG_ARGS[*]}" CMDLINE="$CMDLINE" KDIR="$KDIR" \
	bash "$ROOT/scripts/build-manifest.sh" "$VERSION" "$OUT/boot-elden-$VERSION.img" || \
	echo "⚠️ manifest 生成失败"

echo
echo "Next: fastboot boot $OUT/boot-elden-$VERSION.img   （或 scripts/kexec-boot.sh 热重载）"
