#!/bin/bash
# to-fastboot.sh — reliable Linux → fastboot, using the PSCI vendor-reset hook.
#
# `cycle.sh --soft` (plain `reboot -f`) no longer reaches fastboot after the
# b-slot bring-up, and `cycle.sh --fastboot` (misc BCB) was NOT honoured by ABL.
# The working path is the PSCI SYSTEM_RESET2 vendor reset added in vk41:
#     eldroid-bootctl reboot bootloader
#
# usage:
#   scripts/to-fastboot.sh                       # reboot to fastboot, wait
#   scripts/to-fastboot.sh --flash out/boot-elden-vk49.img
#                                                # sign+dd into boot_b FIRST
#                                                # (stays in Linux), then fastboot
#   scripts/to-fastboot.sh --boot out/x.img      # reboot to fastboot + fastboot boot
set -euo pipefail
ROOT=${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
TAB=${TAB:-root@192.168.7.1}
SSH="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 $TAB"

# --- device lock (serialize across concurrent agents; see scripts/device-lock.sh) ---
if [ "${DEVICE_LOCK_HELD:-0}" != 1 ]; then
	exec 9>>"${DEVICE_LOCK:-/tmp/elden-device-$(echo "$TAB" | tr -c 'A-Za-z0-9' '_').lock}"
	flock -w "${LOCK_WAIT:-300}" 9 || { echo "[lock] device busy — another agent holds it" >&2; exit 1; }
	export DEVICE_LOCK_HELD=1
fi

FLASH=""; BOOT=""
while [ $# -gt 0 ]; do
	case "$1" in
		--flash) FLASH=$2; shift ;;
		--boot)  BOOT=$2; shift ;;
		-h|--help) sed -n '2,18p' "$0"; exit 0 ;;
		*) echo "unknown arg: $1" >&2; exit 2 ;;
	esac
	shift
done

if [ -n "$FLASH" ]; then
	echo "[to-fastboot] flashing boot_b from inside Linux first..."
	bash "$ROOT/scripts/flash-b.sh" "$FLASH"
fi

echo "[to-fastboot] device -> fastboot (PSCI vendor reset)..."
$SSH 'sync; eldroid-bootctl reboot bootloader' || true

echo "[to-fastboot] waiting for fastboot..."
ok=0
for i in $(seq 1 45); do
	sleep 2
	if timeout 6 fastboot devices 2>/dev/null | grep -q .; then
		echo "[to-fastboot] fastboot ok (~$((i*2))s)"; ok=1; break
	fi
done
[ "$ok" = 1 ] || { echo "[to-fastboot] fastboot timeout — check USB cable / physical keys" >&2; exit 1; }

if [ -n "$BOOT" ]; then
	echo "[to-fastboot] fastboot boot $BOOT"
	fastboot boot "$BOOT"
	echo "[to-fastboot] booting; use --wait helper (cycle.sh --wait) or ping 192.168.7.1"
fi
