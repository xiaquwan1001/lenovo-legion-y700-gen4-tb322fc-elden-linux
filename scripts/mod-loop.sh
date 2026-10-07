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
#
# Env: TAB=root@192.168.7.1, ROOT=<repo>
set -euo pipefail
ROOT=${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
. "$ROOT/scripts/env-build.sh"
TAB=${TAB:-root@192.168.7.1}
SSH="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 $TAB"

# --- device lock (serialize across concurrent agents; see scripts/device-lock.sh) ---
. "$(dirname "$0")/lib-device-lock.sh"
device_lock_acquire

DIR=""; RELOAD=""; DO_RELOAD=1
while [ $# -gt 0 ]; do
	case "$1" in
		--reload) RELOAD=$2; shift ;;
		--no-reload) DO_RELOAD=0 ;;
		-h|--help) sed -n '2,16p' "$0"; exit 0 ;;
		*) DIR=$1 ;;
	esac
	shift
done
[ -n "$DIR" ] || { echo "usage: mod-loop.sh <module-dir-relative-to-kernel-root>" >&2; exit 2; }
DIR=${DIR#"$ROOT/linux/"}

KV=$(kbuild -s kernelrelease)
RUNKV=$($SSH 'uname -r' 2>/dev/null || true)
echo "[mod] tree KV=$KV  device KV=${RUNKV:-?}"
if [ -n "$RUNKV" ] && [ "$RUNKV" != "$KV" ]; then
	echo "[mod] REFUSING: device runs $RUNKV but tree builds $KV (vermagic mismatch)." >&2
	echo "      Boot a kernel built from this tree first (kexec or fastboot)." >&2
	exit 1
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

# tar only the staged module subtree, preserving kernel/<path> layout.
TAR=$(mktemp --suffix=.tar.gz); trap 'rm -rf "$STAGE" "$TAR"' EXIT
( cd "$STAGE/lib/modules/$KV" && tar czf "$TAR" kernel )

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
