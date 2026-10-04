#!/bin/bash
# Helpers for TB322FC mainline bring-up.
# NOTE: this device's fastboot does not like long batched scripts — each
# fastboot action below is a SINGLE command. If `fastboot boot` fails with
# "Write to device failed", run `fastboot reboot bootloader` first, wait, retry.
set -u
cd "$(dirname "$0")"
DUMMY=out/dtbo-dummy.img

# --- device lock (serialize across concurrent agents; see scripts/device-lock.sh) ---
TAB=${TABLET:-root@192.168.7.1}
if [ "${DEVICE_LOCK_HELD:-0}" != 1 ]; then
	exec 9>>"${DEVICE_LOCK:-/tmp/elden-device-$(echo "$TAB" | tr -c 'A-Za-z0-9' '_').lock}"
	flock -w "${LOCK_WAIT:-300}" 9 || { echo "[lock] device busy — another agent holds it" >&2; exit 1; }
	export DEVICE_LOCK_HELD=1
fi

wait_fastboot() { for i in $(seq 1 60); do sleep 2; timeout 6 fastboot devices 2>/dev/null | grep -q . && { echo "[cycle] fastboot ok (~$((i*2))s)"; return 0; }; done; echo "[cycle] fastboot timeout"; return 1; }
wait_linux()   { for i in $(seq 1 60); do sleep 3; ping -c1 -W1 192.168.7.1 >/dev/null 2>&1 && timeout 8 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@192.168.7.1 true 2>/dev/null && { echo "[cycle] linux up (~$((i*3))s): ssh root@192.168.7.1"; return 0; }; done; echo "[cycle] linux timeout"; return 1; }

case "${1:-}" in
  --soft)  echo "[cycle] soft reboot -> fastboot"; ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 root@192.168.7.1 'sync; (sleep 1; reboot -f) >/dev/null 2>&1 &' || true; wait_fastboot ;;
  # NOTE 2026-09-29: after the b-slot bring-up (HANDOFF §24) the tablet boots Linux
  # on its own, so reboot -f returns to LINUX, not fastboot. Use `--fastboot` (BCB)
  # or the physical keys to reach fastboot; use scripts/flash-b.sh to update the
  # kernel without fastboot at all.
  --fastboot) echo "[cycle] soft reboot -> fastboot via misc BCB (bootonce-bootloader)";
          ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 root@192.168.7.1 \
            'M=/dev/disk/by-partlabel/misc; dd if=/dev/zero of=$M bs=4096 count=1 conv=fsync 2>/dev/null; printf "bootonce-bootloader" | dd of=$M bs=1 conv=fsync 2>/dev/null; sync; (sleep 1; reboot -f) >/dev/null 2>&1 &' || true; wait_fastboot ;;
  --dtbo)  echo "[cycle] flash dummy dtbo (both slots)"; fastboot flash dtbo_a "$DUMMY"; fastboot flash dtbo_b "$DUMMY" ;;
  --wait)  wait_linux ;;
  --recover) fastboot reboot bootloader; wait_fastboot ;;
  "")      echo "usage: cycle.sh <boot.img> | --soft | --fastboot | --dtbo | --recover | --wait"; exit 1 ;;
  *)       IMG=$1; [ -f "$IMG" ] || { echo "no such image: $IMG"; exit 1; }; echo "[cycle] fastboot boot $IMG"; fastboot boot "$IMG" && wait_linux ;;
esac
