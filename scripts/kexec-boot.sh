#!/bin/bash
# kexec-boot.sh — hot-reload a new kernel WITHOUT fastboot/ABL/AVB.
#
# Uses kexec_file_load (CONFIG_KEXEC_FILE=y, KEXEC_SIG off) with the *uncompressed*
# arm64 Image (kexec cannot take Image.gz).  The device's kexec-tools (2.0.32)
# and the kernel config are already in place; this script just wires them up.
#
# usage:
#   scripts/kexec-boot.sh --load-only        # verify it LOADS (safe: does not switch)
#   scripts/kexec-boot.sh                    # load + execute (switch kernel now)
#   scripts/kexec-boot.sh --ram              # RAM-only (drop root=? args)
#   scripts/kexec-boot.sh --command-line "..."   # override cmdline
#   scripts/kexec-boot.sh --image path --dtb path
#
# Safety: if the new kernel panics, the SoC watchdog/slot returns control; a
# failed `kexec -l` leaves the current kernel running.  First test `--load-only`.
set -euo pipefail
ROOT=${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
KDIR=$ROOT/linux
TAB=${TAB:-root@192.168.7.1}
SSH="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 $TAB"

# --- device lock (serialize across concurrent agents; see scripts/device-lock.sh) ---
if [ "${DEVICE_LOCK_HELD:-0}" != 1 ]; then
	exec 9>>"${DEVICE_LOCK:-/tmp/elden-device-$(echo "$TAB" | tr -c 'A-Za-z0-9' '_').lock}"
	flock -w "${LOCK_WAIT:-300}" 9 || { echo "[lock] device busy — another agent holds it" >&2; exit 1; }
	export DEVICE_LOCK_HELD=1
fi

IMAGE=$KDIR/arch/arm64/boot/Image
DTB=$KDIR/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb
INITRD=""
MODE=run
CMDLINE=""

while [ $# -gt 0 ]; do
	case "$1" in
		--load-only) MODE=load ;;
		--ram) MODE=ram ;;
		--image) IMAGE=$2; shift ;;
		--dtb) DTB=$2; shift ;;
		--initrd) INITRD=$2; shift ;;
		--command-line) CMDLINE=$2; shift ;;
		-h|--help) sed -n '2,20p' "$0"; exit 0 ;;
		*) echo "unknown arg: $1" >&2; exit 2 ;;
	esac
	shift
done

[ -f "$IMAGE" ] || { echo "missing kernel Image (uncompressed): $IMAGE" >&2; exit 1; }
case "$IMAGE" in *.gz) echo "ERROR: kexec needs the UNCOMPRESSED Image, not $IMAGE" >&2; exit 1;; esac
[ -f "$DTB" ] || { echo "missing DTB: $DTB" >&2; exit 1; }

# Reuse the running kernel's cmdline unless overridden (keeps disk root, console).
if [ -z "$CMDLINE" ]; then
	CMDLINE=$($SSH 'cat /proc/cmdline' 2>/dev/null || true)
fi
[ -n "$CMDLINE" ] || { echo "cannot read /proc/cmdline from device (set --command-line)" >&2; exit 1; }
if [ "$MODE" = ram ]; then
	# strip root= / elden_root= for a pure-RAM boot
	CMDLINE=$(echo "$CMDLINE" | sed -E 's/(elden_root|root)=[^ ]*//g' | tr -s ' ')
fi

echo "[kexec] device=$TAB"
echo "[kexec] running: $($SSH 'uname -r' 2>/dev/null || echo '?')"
echo "[kexec] image:   $IMAGE ($(du -h "$IMAGE" | cut -f1))"
echo "[kexec] dtb:     $DTB"
echo "[kexec] cmdline: $CMDLINE"

# kexec must be present on the device.
$SSH 'command -v kexec >/dev/null || { echo "no kexec on device" >&2; exit 1; }'

echo "[kexec] transferring..."
D=/var/tmp/kexec-$$
$SSH "mkdir -p $D"
$SSH "cat > $D/Image" < "$IMAGE"
$SSH "cat > $D/dtb"   < "$DTB"
if [ -n "$INITRD" ]; then $SSH "cat > $D/initrd" < "$INITRD"; fi

LOAD="kexec -s -l $D/Image --dtb=$D/dtb"
[ -n "$INITRD" ] && LOAD="$LOAD --initrd=$D/initrd"
LOAD="$LOAD --command-line='$CMDLINE'"

echo "[kexec] loading: $LOAD"
if ! $SSH "$LOAD"; then
	echo "[kexec] LOAD FAILED — kernel not switched (safe)." >&2
	echo "        常见原因：内核缺 CONFIG_KEXEC_FILE，或 Image 非未压缩 arm64。" >&2
	$SSH "rm -rf $D" || true
	exit 1
fi
echo "[kexec] loaded OK."

if [ "$MODE" = load ]; then
	echo "[kexec] --load-only → 不执行；内存中的 kexec 载荷随下次重启失效。"
	$SSH "rm -rf $D" || true
	exit 0
fi

echo "[kexec] executing (device will switch kernel; SSH will drop)..."
# -e does not return; subshell so the SSH error is expected.
$SSH "sync; kexec -e" || true
echo "[kexec] waiting for the device to come back..."
for i in $(seq 1 60); do
	sleep 3
	if timeout 6 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$TAB" 'uname -r' 2>/dev/null; then
		echo "[kexec] back (~$((i*3))s)"; exit 0
	fi
done
echo "[kexec] device did not return; fall back to scripts/to-fastboot.sh + fastboot boot" >&2
exit 1
