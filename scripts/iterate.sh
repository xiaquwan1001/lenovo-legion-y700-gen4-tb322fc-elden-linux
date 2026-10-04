#!/bin/bash
# iterate.sh — 统一迭代入口（日常用它，取代根目录 build.sh/pack.sh/cycle.sh 集群）。
#
# 四档速度，从快到慢：
#   mod <dir>   模块快环：编该目录模块 → 推设备 → rmmod/modprobe。**不重启**（~30s）
#               需先一次性应用 patches/fragment-modular.config（见该文件）。
#   dtb         只重编 DTB → 用 kexec 热加载（无 fastboot、无 ABL、无重启按钮）
#   kernel      重编 Image+DTB → 用 kexec 热加载
#   ram         重编并用 fastboot boot 起一个纯 RAM 变体（零写盘，兜底/取证用）
#
# 启动方式（kernel/dtb 用）：
#   --kexec   热重载（默认；无 fastboot）         → scripts/kexec-boot.sh
#   --boot    fastboot 零写盘启动                 → scripts/to-fastboot.sh --boot
#   --flash   在 Linux 内 dd 进 boot_b 再重启     → scripts/to-fastboot.sh --flash
#
# 用法：
#   scripts/iterate.sh mod sound/soc/codecs
#   scripts/iterate.sh dtb                        # 改 DTS 后的最快路径
#   scripts/iterate.sh kernel --boot VERSION=vk50 # 完整镜像，fastboot 零写盘验证
#   scripts/iterate.sh ram  VERSION=vk50-ram
set -euo pipefail
ROOT=${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
. "$ROOT/scripts/env-build.sh"
KDIR=$ROOT/linux
OUT=$ROOT/out

# 自动版本号：SSOT = versions/vk-registry.tsv（lane.sh alloc 原子分配，flock）。
# 绝不扫 out/ 猜号——并发两个构建必扫出同一个数（旧 bug）。
next_vk() {
	if [ -x "$ROOT/scripts/lane.sh" ]; then
		local v
		if v=$(bash "$ROOT/scripts/lane.sh" alloc "${VK_LANE:-adhoc}" "iterate.sh" 2>/dev/null); then
			echo "$v"; return
		fi
	fi
	# 兜底：registry 不可用时退回扫描（仅单进程安全）
	local n
	n=$(ls "$OUT"/boot-elden-vk*.img 2>/dev/null | sed -n 's/.*vk\([0-9]\+\)\.img$/\1/p' | sort -n | tail -1)
	echo "vk$(( ${n:-0} + 1 ))"
}

CMD=${1:-}; shift || true
METHOD=kexec
ARGS=()
while [ $# -gt 0 ]; do
	case "$1" in
		--kexec) METHOD=kexec ;;
		--boot)  METHOD=boot ;;
		--flash) METHOD=flash ;;
		*) ARGS+=("$1") ;;
	esac
	shift
done

# 与 build-boot.sh 相同的候选顺序（camera 覆盖层优先）。
pick_ramdisk() {
	for c in "$OUT/rootfs-overlaid-camera.cpio.gz" "$OUT/rootfs-overlaid.cpio.gz" "$OUT/rootfs.cpio.gz" "$OUT/rootfs-vk11.cpio.gz"; do
		[ -e "$c" ] && { echo "$c"; return; }
	done
	echo ""
}

boot_it() {
	local ver=$1 img=$2 rd=$3
	case "$METHOD" in
		kexec)
			echo "[iterate] kexec hot-reload (no fastboot)"
			[ -n "$rd" ] || { echo "no rootfs cpio for --initrd" >&2; exit 1; }
			bash "$ROOT/scripts/kexec-boot.sh" --initrd "$rd" ;;
		boot)
			echo "[iterate] fastboot zero-write boot"
			bash "$ROOT/scripts/to-fastboot.sh" --boot "$img" ;;
		flash)
			echo "[iterate] dd into boot_b then fastboot"
			bash "$ROOT/scripts/to-fastboot.sh" --flash "$img" ;;
	esac
}

case "$CMD" in
	mod)
		[ ${#ARGS[@]} -ge 1 ] || { echo "usage: iterate.sh mod <driver-dir>" >&2; exit 2; }
		exec bash "$ROOT/scripts/mod-loop.sh" "${ARGS[@]}" ;;

	dtb)
		echo "[iterate] dtb-only"
		kbuild dtbs
		;;

	kernel)
		echo "[iterate] kernel + dtb"
		kbuild Image.gz dtbs
		;;

	ram)
		VERSION=${VERSION:-$(next_vk)-ram}
		echo "[iterate] RAM-only variant"
		kbuild Image.gz dtbs
		ROOTARGS= VERSION="$VERSION" bash "$ROOT/scripts/build-boot.sh"
		bash "$ROOT/scripts/to-fastboot.sh" --boot "$OUT/boot-elden-$VERSION.img"
		exit 0 ;;

	*)
		sed -n '2,25p' "$0"; exit 2 ;;
esac

# kernel/dtb 共用：打包 boot.img + manifest（既是 kexec 的指纹来源，也是回退镜像）
VERSION=${VERSION:-$(next_vk)}
RAMDISK=$(pick_ramdisk)
[ -n "$RAMDISK" ] || { echo "找不到 rootfs cpio（kexec 需要 --initrd）" >&2; exit 1; }
VERSION="$VERSION" RAMDISK="$RAMDISK" bash "$ROOT/scripts/build-boot.sh"
boot_it "$VERSION" "$OUT/boot-elden-$VERSION.img" "$RAMDISK"
