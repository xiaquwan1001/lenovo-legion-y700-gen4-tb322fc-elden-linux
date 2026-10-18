#!/bin/bash
# Reboot the tablet until the panel actually inits (Q28 GOOD boot) — bounded.
# Checks: dmesg "Failed to initialize panel" absent AND card0-DSI-1 enabled.
set -u
T=${TAB:-root@192.168.7.1}
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 $T"
MAX=${MAX:-4}
wait_up() { # $1 timeout s
  local end=$(( $(date +%s) + $1 ))
  while [ "$(date +%s)" -lt "$end" ]; do
    if timeout 8 $SSH 'true' 2>/dev/null; then return 0; fi
    sleep 3
  done
  return 1
}
for i in $(seq 1 $MAX); do
  echo "[q28] attempt $i"
  timeout 15 $SSH 'sync; echo b > /proc/sysrq-trigger' 2>/dev/null || true
  sleep 20
  if ! wait_up 180; then echo "[q28] device did not come back"; exit 1; fi
  sleep 3
  out=$(timeout 20 $SSH 'echo "BOOTID=$(cat /proc/sys/kernel/random/boot_id)"; echo "PANELFAIL=$(dmesg | grep -c "Failed to initialize panel")"; echo "DSI=$(cat /sys/class/drm/card0-DSI-1/enabled 2>/dev/null)"; echo "UPTIME=$(cut -d. -f1 /proc/uptime)"' 2>/dev/null)
  echo "$out" | tr '\n' ' '; echo
  if echo "$out" | grep -q "PANELFAIL=0" && echo "$out" | grep -q "DSI=enabled"; then
    echo "[q28] GOOD boot on attempt $i"; exit 0
  fi
done
echo "[q28] still bad after $MAX attempts"; exit 2
