#!/bin/bash
# build-initramfs.sh — 可复现地构建 initramfs 资产（唯一真源 = initramfs/init）
#
# 用法：
#   scripts/build-initramfs.sh slim
#       → out/initramfs-slim.cpio.gz
#         最小 busybox root，只够 switch_root；**无 /lib/firmware**，
#         仅用于纯 RAM 研究。切勿用它做驱动/DTS 验证（vk60 的教训：内置探针
#         在 RAM 阶段 -ENOENT 且不重试 ⇒ 外设全废，属 C 层干扰）。
#
#   scripts/build-initramfs.sh full [BASE]
#       → out/initramfs-full-elden.cpio.gz
#         含 /lib/firmware 的完整 ramdisk，**只把 /init 换成唯一真源**。
#         这是驱动/DTS 版本验证的标准载具：内核与 DTB 之外无 C 层变量。
#         BASE 可为 boot.img（自动解包取 ramdisk）或 .cpio.gz；缺省
#         out/boot-elden-vk61.img（已验证可启动）。
#
#   scripts/build-initramfs.sh verify
#       重建并与现有资产比 sha（可复现性门），并校验内嵌 /init == 真源。
#
# 可复现三要素（缺一不可，2026-10-06 实测）：mtime 钉到 SOURCE_DATE_EPOCH +
# cpio --reproducible（inode/设备号归零）+ gzip -n（不写时间戳/名字）+ 固定顺序。
set -eu

ROOT=${ROOT:-$HOME/y700-elden}
OUT=$ROOT/out
INIT=$ROOT/initramfs/init
BB=$ROOT/initramfs/busybox
APPLETS=$ROOT/initramfs/busybox-applets.txt
UNPACK=${UNPACK:-$ROOT/scripts/mkbootimg.py}   # 2026-10-17: 由重写的 mkbootimg --unpack 取代丢失的 tools/mkbootimg/unpack_bootimg.py
mkdir -p "$OUT"

die() { echo "[initramfs] FATAL: $*" >&2; exit 1; }
[ -f "$INIT" ] || die "唯一真源缺失: $INIT"

# 固定时间戳：默认取真源 init 的 mtime（env 可覆盖）。
export SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-$(stat -c %Y "$INIT")}

# 可复现打包：参数 <源目录> <输出 .cpio.gz>
pack() {
	_src=$1; _out=$2
	find "$_src" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} + 2>/dev/null || true
	( cd "$_src" && find . -print0 | LC_ALL=C sort -z \
		| cpio --null --reproducible -o -H newc --owner=0:0 2>/dev/null | gzip -n -9 ) > "$_out"
}

# 校验 <载具 .cpio.gz|ramdisk> 内嵌 /init == 唯一真源
check_init() {
	_f=$1
	rm -rf /tmp/bi-check.$$; mkdir -p /tmp/bi-check.$$
	( cd /tmp/bi-check.$$ && gzip -dc "$_f" | cpio -idm --quiet 2>/dev/null )
	if [ ! -f /tmp/bi-check.$$/init ]; then
		rm -rf /tmp/bi-check.$$; return 1
	fi
	diff <(sed 's/\r$//' "$INIT") <(sed 's/\r$//' /tmp/bi-check.$$/init) >/dev/null 2>&1
	_r=$?
	rm -rf /tmp/bi-check.$$
	return $_r
}

build_slim() {
	[ -x "$BB" ] || die "缺 busybox: $BB"
	[ -f "$APPLETS" ] || die "缺 applet 名单: $APPLETS"
	R=/tmp/bi-slim.$$
	rm -rf "$R"; mkdir -p "$R"/{bin,dev,proc,sys,tmp,mnt,etc}
	cp "$BB" "$R/bin/busybox"; chmod 755 "$R/bin/busybox"
	while read -r _a; do
		[ -n "$_a" ] && [ "$_a" != busybox ] && ln -sf busybox "$R/bin/$_a"
	done < "$APPLETS"
	[ -f "$R/bin/busybox" ] && [ ! -L "$R/bin/busybox" ] || die "applet 链接近乎替换了真二进制"
	sed 's/\r$//' "$INIT" > "$R/init"; chmod 755 "$R/init"
	[ -f "$ROOT/initramfs/usb-gadget" ] && { sed 's/\r$//' "$ROOT/initramfs/usb-gadget" > "$R/bin/usb-gadget"; chmod 755 "$R/bin/usb-gadget"; }
	mknod -m 600 "$R/dev/console" c 5 1 2>/dev/null || true
	pack "$R" "$OUT/initramfs-slim.cpio.gz"
	rm -rf "$R"
	check_init "$OUT/initramfs-slim.cpio.gz" || die "slim 内嵌 /init != 真源"
	echo "[initramfs] slim → $OUT/initramfs-slim.cpio.gz  $(stat -c%s "$OUT/initramfs-slim.cpio.gz") B  sha=$(sha256sum "$OUT/initramfs-slim.cpio.gz" | cut -c1-16)"
}

build_full() {
	base=${1:-$OUT/boot-elden-vk61.img}
	[ -f "$base" ] || die "BASE 不存在: $base"
	R=/tmp/bi-full.$$; mkdir -p "$R"
	case "$base" in
		*.img)  python3 "$UNPACK" --unpack "$base" --unpack-dir "$R/unpack" >/dev/null 2>&1 || die "解包 $base 失败"
			rd="$R/unpack/ramdisk" ;;
		*.cpio.gz|*.cpio) rd="$base" ;;
		*) die "无法识别的 BASE 类型: $base" ;;
	esac
	[ -f "$rd" ] || die "取不到 ramdisk"
	mkdir -p "$R/root"
	( cd "$R/root" && gzip -dc "$rd" | cpio -idm --quiet 2>/dev/null ) || die "解开 ramdisk 失败"
	[ -f "$R/root/init" ] || die "基底 ramdisk 没有 /init"
	sed 's/\r$//' "$INIT" > "$R/root/init"; chmod 755 "$R/root/init"
	# --- 注入 stock split CDSP 固件（2026-10-07 G1-11）---------------------------
	# mainline q6v5_pas 在 switch_root 之前从 initramfs 加载固件；磁盘 rootfs 副本
	# 不生效。CDSP 必须用 stock split 镜像（cdsp.mdt + cdsp.bNN + cdsp_dtb.mdt +
	# cdsp_dtb.bNN）；单文件 cdsp_dtb.mbn 被 TZ PAS init 拒（-22）。见
	# archive/topics/CDSP-FIX-2026-10-07.md、PITFALLS #127。
	FWDIR="$R/root/lib/firmware/qcom/sm8750"
	FWBAK="$ROOT/backup/fw/modem/image"
	if [ -d "$FWDIR" ] && [ -f "$FWBAK/cdsp.mdt" ]; then
		cp -f "$FWBAK/cdsp.mdt" "$FWDIR"/
		cp -f "$FWBAK"/cdsp.b[0-9][0-9] "$FWDIR"/ 2>/dev/null || true
		cp -f "$FWBAK/cdsp_dtb.mdt" "$FWDIR"/
		cp -f "$FWBAK"/cdsp_dtb.b[0-9][0-9] "$FWDIR"/ 2>/dev/null || true
		echo "[initramfs] + stock split CDSP firmware (cdsp.mdt / cdsp_dtb.mdt)"
	else
		echo "[initramfs] WARN: 未注入 split CDSP 固件（缺 $FWBAK/cdsp.mdt 或无 $FWDIR）" >&2
	fi
	pack "$R/root" "$OUT/initramfs-full-elden.cpio.gz.new"
	mv "$OUT/initramfs-full-elden.cpio.gz.new" "$OUT/initramfs-full-elden.cpio.gz"
	rm -rf "$R"
	check_init "$OUT/initramfs-full-elden.cpio.gz" || die "full 内嵌 /init != 真源"
	echo "[initramfs] full → $OUT/initramfs-full-elden.cpio.gz  $(stat -c%s "$OUT/initramfs-full-elden.cpio.gz") B  sha=$(sha256sum "$OUT/initramfs-full-elden.cpio.gz" | cut -c1-16)"
	echo "[initramfs] 基底: $base"
}

case "${1:-}" in
	slim)   build_slim ;;
	full)   shift; build_full "$@" ;;
	verify)
		for spec in "slim:initramfs-slim.cpio.gz" "full:initramfs-full-elden.cpio.gz"; do
			k=${spec%%:*}; f=${spec#*:}
			[ -f "$OUT/$f" ] || continue
			before=$(sha256sum "$OUT/$f" | cut -d' ' -f1)
			case $k in slim) build_slim >/dev/null;; full) build_full >/dev/null;; esac
			after=$(sha256sum "$OUT/$f" | cut -d' ' -f1)
			[ "$before" = "$after" ] && echo "[initramfs] $k 可复现 OK ($before)" || die "$k 不可复现: $before != $after"
		done ;;
	*) die "用法: $0 <slim|full [BASE]|verify>" ;;
esac
