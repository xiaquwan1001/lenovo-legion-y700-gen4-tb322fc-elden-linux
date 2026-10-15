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
. "$(dirname "$0")/scripts/lib-device-lock.sh"
device_lock_acquire

wait_fastboot() { for i in $(seq 1 60); do sleep 2; timeout 6 fastboot devices 2>/dev/null | grep -q . && { echo "[cycle] fastboot ok (~$((i*2))s)"; return 0; }; done; echo "[cycle] fastboot timeout"; return 1; }
wait_linux()   { for i in $(seq 1 60); do sleep 3; ping -c1 -W1 192.168.7.1 >/dev/null 2>&1 && timeout 8 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@192.168.7.1 true 2>/dev/null && { echo "[cycle] linux up (~$((i*3))s): ssh root@192.168.7.1"; return 0; }; done; echo "[cycle] linux timeout"; return 1; }

case "${1:-}" in
  --soft)  echo "[cycle] soft reboot -> fastboot"; ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 root@192.168.7.1 'sync; echo b > /proc/sysrq-trigger' || true; wait_fastboot ;;
  # NOTE 2026-09-29: after the b-slot bring-up (HANDOFF §24) the tablet boots Linux
  # on its own, so reboot -f returns to LINUX, not fastboot. Use `--fastboot` (BCB)
  # or the physical keys to reach fastboot; use scripts/flash-b.sh to update the
  # kernel without fastboot at all.
  # ★ 2026-10-15 修（PITFALLS #288）：原实现用 `(sleep 1; reboot -f) &`，实测该路径
  #   在本机当前状态下【会挂起、根本不重启】（`/sbin/reboot` 是 elden-powerwrap，
  #   openrc 分支 exec busybox reboot；sysrq-b 是当前唯一可靠通道）。
  #   注意：`reboot -f` 不影响 misc BCB 的写入，故只替换"重启"这一步。
  --fastboot) echo "[cycle] soft reboot -> fastboot via misc BCB (bootonce-bootloader)";
          echo "[cycle] ⚠ PITFALLS #65：BCB 写法【未被 ABL 采纳】(2026-10-03 实测：misc 首 20B 确为" bootonce-bootloader" 但 reboot 后仍启 Linux)。"
          echo "[cycle] ⚠ 2026-10-15 实测补充：本次走该路径后设备先落 BL、随即进了 Q28 坏发版本，需人工干预 => 该路径不可靠，进 fastboot 请用物理键。"
          ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 root@192.168.7.1 \
            'M=/dev/disk/by-partlabel/misc; dd if=/dev/zero of=$M bs=4096 count=1 conv=fsync 2>/dev/null; printf "bootonce-bootloader" | dd of=$M bs=1 conv=fsync 2>/dev/null; sync; echo b > /proc/sysrq-trigger' || true; wait_fastboot ;;
  --dtbo)  echo "[cycle] flash dummy dtbo (both slots)"; fastboot flash dtbo_a "$DUMMY"; fastboot flash dtbo_b "$DUMMY" ;;
  --wait)  wait_linux ;;
  --recover) fastboot reboot bootloader; wait_fastboot ;;
  "")      echo "usage: cycle.sh <boot.img> | --soft | --fastboot | --dtbo | --recover | --wait"; exit 1 ;;
  *)       IMG=$1; [ -f "$IMG" ] || { echo "no such image: $IMG"; exit 1; }; echo "[cycle] fastboot boot $IMG"; fastboot boot "$IMG" && wait_linux ;;
esac
