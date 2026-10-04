#!/bin/bash
# Flash a mainline boot image into slot b *from inside Linux* — no fastboot needed.
#
# Why: after the b-slot bring-up (HANDOFF §24) the tablet boots Linux on its own,
# and `reboot -f` returns to Linux, so the old `cycle.sh --soft` -> fastboot loop
# no longer exists. boot_b is a plain block device we own: sign the image with
# our AVB key (scripts/sign-boot-b.sh) and dd it.
#
# usage: scripts/flash-b.sh [in.img] [--reboot]
#        default in.img = out/boot-elden-vk40.img
set -eu
cd "$(dirname "$0")/.."
TAB=${TABLET:-root@192.168.7.1}

# --- device lock (serialize across concurrent agents; see scripts/device-lock.sh) ---
if [ "${DEVICE_LOCK_HELD:-0}" != 1 ]; then
	exec 9>>"${DEVICE_LOCK:-/tmp/elden-device-$(echo "$TAB" | tr -c 'A-Za-z0-9' '_').lock}"
	flock -w "${LOCK_WAIT:-300}" 9 || { echo "[lock] device busy — another agent holds it" >&2; exit 1; }
	export DEVICE_LOCK_HELD=1
fi
REBOOT=0
IN=out/boot-elden-vk40.img
for a in "$@"; do
	case "$a" in
		--reboot) REBOOT=1 ;;
		*) IN=$a ;;
	esac
done

echo "[flash-b] signing $IN"
./scripts/sign-boot-b.sh "$IN" >/dev/null
SHA=$(sha256sum bootslot-b/boot_b.img | cut -d' ' -f1)
echo "[flash-b] image sha256=$SHA  (96 MiB, signed with bootslot-b/avb.key)"

echo "[flash-b] uploading..."
scp -q -o StrictHostKeyChecking=no bootslot-b/boot_b.img "$TAB:/tmp/boot_b.img"

echo "[flash-b] writing boot_b..."
ssh -o StrictHostKeyChecking=no "$TAB" '
set -e
D=/dev/disk/by-partlabel/boot_b
dd if=/tmp/boot_b.img of=$D bs=1M conv=fsync 2>&1 | tail -1
sync
rm -f /tmp/boot_b.img
dd if=$D bs=1M count=96 2>/dev/null | sha256sum | cut -d" " -f1
' > /tmp/flash-b-readback.txt
RB=$(tail -1 /tmp/flash-b-readback.txt)
echo "[flash-b] readback sha256=$RB"
[ "$SHA" = "$RB" ] || { echo "[flash-b] MISMATCH — boot_b NOT updated cleanly" >&2; exit 1; }
echo "[flash-b] OK"

if [ "$REBOOT" = 1 ]; then
	echo "[flash-b] rebooting..."
	ssh -o StrictHostKeyChecking=no "$TAB" 'sync; (sleep 1; reboot -f) >/dev/null 2>&1 &' || true
	echo "[flash-b] waiting for Linux..."
	for i in $(seq 1 90); do
		sleep 2
		ping -c1 -W1 192.168.7.1 >/dev/null 2>&1 && timeout 8 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
			"$TAB" 'uptime' 2>/dev/null && { echo "[flash-b] up (~$((i*2))s)"; break; }
	done
	timeout 15 ssh -o StrictHostKeyChecking=no "$TAB" 'cat /proc/version' || true
fi
