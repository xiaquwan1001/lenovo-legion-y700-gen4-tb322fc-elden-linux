#!/bin/bash
# 收口指针（script-redundancy-audit S15，2026-11-13）：设备侧整目录部署的统一实现 = scripts/deploy-modules.sh
#       （带备份 + 读回校验）；本脚本是历史/专用形态（模块热载循环），新代码勿复制其传输逻辑。

# mod-loop.sh — the fast iteration ring: rebuild ONE module dir, push it, reload
# on the device.  No kernel rebuild, no boot image, no fastboot, no reboot (~30 s).
#
# Requires the target driver to be built as a module (=m).  If it is =y, this
# script refuses and tells you to flip the tristate (see patches/fragment-modular*.config;
# 日常线已应用 v1+v2 两层，快照 patches/config-vk163-modular-v2-20261026).
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
DIR=${DIR#"$KDIR/"}
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
	# 2026-11-09 PITFALLS #584：先落变量再判断（`| grep -q` 的 SIGPIPE 会打断 fastboot 通道）
	_fbd=$(timeout 8 fastboot devices 2>/dev/null)
	if [ -z "$_fbd" ]; then
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

# Collect the .ko files straight from the build tree instead of going through
# `modules_install`.  Two independent silent-failure paths lived in that hop:
#   * its destination comes from include/config/kernel.release, which an `M=` build
#     never refreshes ⇒ modules staged under the wrong <KV> and the device kept the
#     OLD module while every line below reported success;
#   * it needs the *global* modules.order, which goes missing as soon as .config
#     churns ⇒ "no .ko staged" (which used to be misreported as "driver is built-in").
# Reading the .ko from $KDIR/$DIR needs neither.  Layout on the device is the flat
# `updates/` convention, and `depmod -a` rebuilds the index anyway.
KO_LIST=$(find "$KDIR/$DIR" -maxdepth 1 -name '*.ko' 2>/dev/null | sort)
if [ -z "$KO_LIST" ] && [ -d "$KDIR/$DIR" ]; then
	KO_LIST=$(find "$KDIR/$DIR" -name '*.ko' 2>/dev/null | sort)
fi
if [ -z "$KO_LIST" ]; then
	echo "[mod] ❌ no .ko for $DIR under $KDIR/$DIR" >&2
	echo "      若本应= y 到内核里（非模块），就没东西可热载：把 tristate 翻成 =m：" >&2
	echo "        FRAG=\"patches/fragment-modular.config patches/fragment-modular-v2.config\" SNAP=patches/config-<snap> scripts/apply-kernel-fragment.sh" >&2
	echo "      若是刚改完 .config 导致 modules.order 丢失：先跑一遍全量 'make modules'。" >&2
	exit 1
fi
NAMES=$(echo "$KO_LIST" | xargs -n1 basename | sed 's/\.ko$//')
echo "[mod] built: $(echo "$NAMES" | tr '\n' ' ')"

# Everything is uploaded as updates/<name>.ko.  updates/ outranks the in-tree
# kernel/ copy in depmod's search order, so the freshly built one wins; the
# build-id check below then proves which one actually got loaded.
STAGE=$(mktemp -d); trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/updates"
for ko in $KO_LIST; do cp -f "$ko" "$STAGE/updates/"; done

# Upload the staged `updates/` tree as-is and extract it into <KV>/ on the device.
tar_names=$(ls -l "$STAGE/updates")
TAR=$(mktemp --suffix=.tar.gz); trap 'rm -rf "$STAGE" "$TAR"' EXIT
( cd "$STAGE" && tar czf "$TAR" updates )
[ -s "$TAR" ] || { echo "[mod] staging tarball empty ($tar_names)" >&2; exit 1; }

echo "[mod] uploading to /lib/modules/$KV ..."
$SSH "mkdir -p /lib/modules/$KV"
$SSH "cat > /var/tmp/modloop.tar.gz" < "$TAR"
$SSH "tar xzf /var/tmp/modloop.tar.gz -C /lib/modules/$KV && depmod -a '$KV' && rm -f /var/tmp/modloop.tar.gz && echo '[mod] extracted + depmod'"

[ "$DO_RELOAD" = 1 ] || { echo "[mod] --no-reload → staged only"; exit 0; }

[ -n "$RELOAD" ] && NAMES="$RELOAD"
echo "[mod] reloading: $(echo "$NAMES" | tr '\n' ' ')"
RELOAD_FAILED=0
for m in $NAMES; do
	# `.ko` basenames use '-' (qcom-camss); lsmod/modprobe use '_' (qcom_camss).
	# Comparing the raw name made the `rmmod` step never fire and `modprobe qcom-camss`
	# always fail — with the error swallowed, so the script still printed
	# "reloaded qcom-camss" (2026-10-27).  Normalise, and never report success on failure.
	mu=$(echo "$m" | tr '-' '_')
	rc=0
	$SSH "set -e
		if lsmod | grep -q '^$mu '; then modprobe -r '$mu' || rmmod -f '$mu' || exit 10; fi
		if ! modprobe '$mu'; then exit 11; fi
		if lsmod | grep -q '^$mu '; then echo '[mod] reloaded $m (as $mu)'; else exit 12; fi" || rc=$?
	case $rc in
	0) ;;
	10) echo "[mod] ❌ $m: rmmod failed (still in use?) — device keeps the OLD module" >&2; RELOAD_FAILED=1 ;;
	11) echo "[mod] ❌ $m: modprobe $mu failed (vermagic/name?) — device keeps the OLD module" >&2; RELOAD_FAILED=1 ;;
	12) echo "[mod] ❌ $m: modprobe returned 0 but $mu is not loaded" >&2; RELOAD_FAILED=1 ;;
	*) echo "[mod] ❌ $m: ssh/setup error rc=$rc" >&2; RELOAD_FAILED=1 ;;
	esac
done

# Proof that the module on the device is the one just built, not a leftover.
# A green "[mod] reloaded" line is NOT proof (it was confidently wrong once).
if command -v readelf >/dev/null 2>&1 && [ -n "${KO_LIST:-}" ]; then
	for ko in $KO_LIST; do
		want=$(readelf -n "$ko" 2>/dev/null | sed -n 's/.*Build ID: //p' | head -1)
		[ -n "$want" ] || continue
		mu=$(basename "$ko" .ko | tr '-' '_')
		got=$($SSH "cat /sys/module/$mu/notes/.note.gnu.build-id 2>/dev/null" 2>/dev/null \
			| python3 -c 'import sys; d=sys.stdin.buffer.read(); i=d.find(b"GNU"); print(d[i+4:i+24].hex() if i>=0 else "")' 2>/dev/null || true)
		if [ -n "$got" ] && [ "$got" = "$want" ]; then
			echo "[mod] ✅ build-id match $mu: $want"
		elif [ -n "$got" ]; then
			echo "[mod] ❌ build-id MISMATCH $mu: running=$got built=$want (device is NOT running the new module)" >&2
			RELOAD_FAILED=1
		else
			echo "[mod] (build-id unavailable for $mu — verify manually)" >&2
		fi
	done
fi

echo "[mod] evidence:"
$SSH "dmesg | tail -20; echo '---'; lsmod | grep -E '$(echo "$NAMES" | tr '\n' '|' | sed 's/|$//')' || true"

[ "$RELOAD_FAILED" = 0 ] || { echo "[mod] ❌ 热载未确认成功 —— 不要把本次构建当作已在设备上生效" >&2; exit 1; }
