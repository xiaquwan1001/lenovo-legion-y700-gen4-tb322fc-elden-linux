#!/bin/bash
# Helpers for TB322FC mainline bring-up.
# NOTE: this device's fastboot does not like long batched scripts — each
# fastboot action below is a SINGLE command. If `fastboot boot` fails with
# "Write to device failed", run `fastboot reboot bootloader` first, wait, retry.
set -u
cd "$(dirname "$0")" || exit 1
DUMMY=out/dtbo-dummy.img

# --- device lock (serialize across concurrent agents; see scripts/device-lock.sh) ---
TAB=${TABLET:-root@192.168.7.1}
. "$(dirname "$0")/scripts/lib-device-lock.sh"
device_lock_acquire

# 等待统一走 scripts/lib-wait.sh（2026-11-05 脚本审计）：先判后睡 + 退避，
# 并且 wait_linux 用「boot_id 变了」判「新内核已经在跑」，不再把「重启前的旧系统还在答」
# 当成成功（旧实现的假成功形态）。
. "$(dirname "$0")/scripts/lib-wait.sh"
wait_fastboot() { wait_until "fastboot 上线" 120 wa_fastboot_alive && { echo "[cycle] fastboot ok"; return 0; }; echo "[cycle] fastboot timeout"; return 1; }
wait_linux()   { wait_reboot wa_ssh_alive 180 && { echo "[cycle] linux up: ssh root@192.168.7.1"; return 0; }; echo "[cycle] linux timeout"; return 1; }

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
