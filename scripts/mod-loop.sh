#!/bin/bash
# mod-loop.sh — the fast iteration ring: rebuild ONE module dir, push it, reload
# on the device.  No kernel rebuild, no boot image, no fastboot, no reboot (~30 s).
#
# Requires the target driver to be built as a module (=m).  If it is =y, this
# script refuses and tells you to flip the tristate (see patches/fragment-modular.config).
#
# usage:
#   scripts/mod-loop.sh sound/soc/qcom            # build dir, push, reload all its .ko
#   scripts/mod-loop.sh drivers/bluetooth --no-reload
#   scripts/mod-loop.sh sound/soc/codecs --reload snd-soc-wcd939x
#   scripts/mod-loop.sh drivers/foo --bootstrap    # 设备 KV != 树 KV 时：编内核+全模块、零写盘
#                                                  # fastboot boot 匹配内核、推全模块，再热载
#   scripts/mod-loop.sh drivers/foo --allow-mismatch  # 不匹配也强上（vermagic 不符则 modprobe 必败）
#
# Env: TAB=root@192.168.7.1, ROOT=<repo>, RAMDISK_KIND=<full|rootfs>（--bootstrap 用）
set -euo pipefail
ROOT=${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
OUT=${OUT:-$ROOT/out}
. "$ROOT/scripts/env-build.sh"
TAB=${TAB:-root@192.168.7.1}
SSH="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 $TAB"

# --- device lock (serialize across concurrent agents; see scripts/device-lock.sh) ---
. "$(dirname "$0")/lib-device-lock.sh"
device_lock_acquire

DIR=""; RELOAD=""; DO_RELOAD=1; BOOTSTRAP=0; ALLOW_MISMATCH=0
while [ $# -gt 0 ]; do
	case "$1" in
		--reload) RELOAD=$2; shift ;;
		--no-reload) DO_RELOAD=0 ;;
		--bootstrap) BOOTSTRAP=1 ;;
		--allow-mismatch) ALLOW_MISMATCH=1 ;;
		-h|--help) sed -n '2,18p' "$0"; exit 0 ;;
		*) DIR=$1 ;;
	esac
	shift
done
[ -n "$DIR" ] || { echo "usage: mod-loop.sh <module-dir-relative-to-kernel-root> [--bootstrap|--allow-mismatch]" >&2; exit 2; }
DIR=${DIR#"$ROOT/linux/"}

# --bootstrap：设备未跑本树内核时，构建内核+全模块 → 零写盘 fastboot boot → 推全模块。
# 使“一个驱动改一次 = 30 s 热载”真正对日常可用（否则每次都得先手动编内核+重启）。
bootstrap_kernel() {
	local img="$OUT/boot-elden-modloop-dev.img"
	local rk=${RAMDISK_KIND:-full}
	[ -e "$OUT/initramfs-full-elden.cpio.gz" ] || rk=rootfs
	echo "[mod] --bootstrap：构建树内核（KV=$KV）+ 全模块"
	kbuild Image.gz dtbs
	kbuild modules
	VERSION=modloop-dev RAMDISK_KIND="$rk" bash "$ROOT/scripts/build-boot.sh" || {
		echo "[mod] build-boot.sh 失败（内核闸门？见 scripts/assert-kernel-sane.sh）" >&2; exit 1; }
	if ! fastboot devices 2>/dev/null | grep -q .; then
		echo "[mod] --bootstrap 需要设备在 fastboot（fastboot boot 零写盘）。" >&2
		echo "      镜像已就绪：$img" >&2
		echo "      手动：fastboot boot $img   或   scripts/to-fastboot.sh --boot $img" >&2
		exit 1
	fi
	echo "[mod] fastboot boot $img"
	timeout 180 fastboot boot "$img" 2>&1 | tail -2
	local i=0
	while [ $i -lt 30 ]; do $SSH 'echo up' 2>/dev/null | grep -q up && break; sleep 5; i=$((i+1)); done
	$SSH 'echo up' 2>/dev/null | grep -q up || { echo "[mod] 引导后 SSH 未起（150s）——试 --deploy none 已 boot 的内核，或查 PITFALLS #170" >&2; exit 1; }
	# dev KV 的模块在设备盘上通常不存在 → 一次性推全量（后续本函数不再做，只热载单模块）
	local STAGE; STAGE=$(mktemp -d)
	local TAR; TAR=$(mktemp --suffix=.tar.gz)
	kbuild INSTALL_MOD_PATH="$STAGE" modules_install >/dev/null
	( cd "$STAGE/lib/modules/$KV" && find . -name '*.ko*' -print0 | tar czf "$TAR" --null -T - ) || true
	$SSH "mkdir -p /lib/modules/$KV"
	$SSH "cat > /var/tmp/modloop-all.tar.gz" < "$TAR"
	$SSH "tar xzf /var/tmp/modloop-all.tar.gz -C /lib/modules/$KV && depmod -a '$KV' && rm -f /var/tmp/modloop-all.tar.gz && echo '[mod] all modules installed'"
	rm -rf "$STAGE" "$TAR"
	RUNKV=$($SSH 'uname -r' 2>/dev/null || true)
	echo "[mod] bootstrap 完成，device KV=${RUNKV:-?}"
}

KV=$(kbuild -s kernelrelease)
RUNKV=$($SSH 'uname -r' 2>/dev/null || true)
echo "[mod] tree KV=$KV  device KV=${RUNKV:-?}"
[ -z "$RUNKV" ] && echo "[mod] ⚠️  设备不可达（$TAB）——无法校验 vermagic；热载会失败，只有 --no-reload 构建有意义。" >&2
if [ -n "$RUNKV" ] && [ "$RUNKV" != "$KV" ]; then
	[ "$BOOTSTRAP" = 1 ] && bootstrap_kernel
	if [ -n "$RUNKV" ] && [ "$RUNKV" != "$KV" ]; then
		if [ "$ALLOW_MISMATCH" = 1 ]; then
			echo "[mod] ⚠️  --allow-mismatch：设备 $RUNKV ≠ 树 $KV；vermagic 不符时 modprobe 必败（只作诊断）" >&2
		else
			echo "[mod] REFUSING: device runs $RUNKV but tree builds $KV (vermagic mismatch)." >&2
			echo "      热载要求设备跑本棵树的树内内核。任选：" >&2
			echo "        scripts/mod-loop.sh $DIR --bootstrap        # 自动编内核+全模块，fastboot 零写盘引导后热载" >&2
			echo "        scripts/iterate.sh kernel --boot            # 手动全量内核→引导" >&2
			echo "        scripts/mod-loop.sh $DIR --allow-mismatch   # 明知 vermagic 不符也强上（仅诊断）" >&2
			exit 1
		fi
	fi
fi

echo "[mod] building M=$DIR ..."
if ! kbuild M="$DIR" modules 2>&1 | tail -5; then
	echo "[mod] build failed" >&2; exit 1
fi

STAGE=$(mktemp -d); trap 'rm -rf "$STAGE"' EXIT
kbuild M="$DIR" INSTALL_MOD_PATH="$STAGE" modules_install >/dev/null

KO_LIST=$(find "$STAGE/lib/modules/$KV" -name '*.ko' 2>/dev/null | sort)
if [ -z "$KO_LIST" ]; then
	echo "[mod] no .ko staged for $DIR." >&2
	echo "      Likely the driver is built-in (=y). Flip it to =m:" >&2
	echo "        scripts/apply-kernel-fragment.sh  (FRAG=patches/fragment-modular.config)" >&2
	exit 1
fi
NAMES=$(echo "$KO_LIST" | xargs -n1 basename | sed 's/\.ko$//')
echo "[mod] staged: $(echo "$NAMES" | tr '\n' ' ')"

# tar only the staged module subtree, preserving whatever layout modules_install
# produced.  NOTE (2026-10-09 fix): `M=<dir> modules_install` does NOT always create
# a `kernel/` prefix -- for single-dir M= builds it stages the .ko flat (or under
# extra/), so taping the literal `kernel` dir failed with "kernel: cannot stat".
# Tar the .ko files by relative path instead; the device extracts to the same layout
# and `depmod -a` rebuilds the index anyway.
TAR=$(mktemp --suffix=.tar.gz); trap 'rm -rf "$STAGE" "$TAR"' EXIT
( cd "$STAGE/lib/modules/$KV" && find . -name '*.ko' -print0 | tar czf "$TAR" --null -T - )
[ -s "$TAR" ] || { echo "[mod] staging tarball empty (no .ko under $STAGE/lib/modules/$KV)" >&2; exit 1; }

echo "[mod] uploading to /lib/modules/$KV ..."
$SSH "mkdir -p /lib/modules/$KV"
$SSH "cat > /var/tmp/modloop.tar.gz" < "$TAR"
$SSH "tar xzf /var/tmp/modloop.tar.gz -C /lib/modules/$KV && depmod -a '$KV' && rm -f /var/tmp/modloop.tar.gz && echo '[mod] extracted + depmod'"

[ "$DO_RELOAD" = 1 ] || { echo "[mod] --no-reload → staged only"; exit 0; }

[ -n "$RELOAD" ] && NAMES="$RELOAD"
echo "[mod] reloading: $(echo "$NAMES" | tr '\n' ' ')"
for m in $NAMES; do
	# -w lets modprobe handle dependencies; fall back to rmmod+modprobe.
	$SSH "lsmod | grep -q '^$m ' && { modprobe -r '$m' 2>/dev/null || rmmod -f '$m' 2>/dev/null; }; modprobe '$m' 2>/dev/null && echo '[mod] reloaded $m' || echo '[mod] WARN: modprobe $m failed'" || true
done

echo "[mod] evidence:"
$SSH "dmesg | tail -20; echo '---'; lsmod | grep -E '$(echo "$NAMES" | tr '\n' '|' | sed 's/|$//')' || true"
