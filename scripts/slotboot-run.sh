#!/bin/bash
# slotboot-run.sh — P2「槽位正常启动路径」最小形态上机（2026-11-01）
#   1) 把 marks 载荷写进 boot_b（96 MiB，AVB testkey），读回校验
#   2) reboot（正常 boot 路径，不走 fastboot boot）
#   3) 采样 150 s：lsusb / fastboot / ssh 三态，逐秒时间线
# 零交互；恢复由 slotboot-recover.sh 负责。
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT"
OUT=reports/artifacts/uefi-slotboot-20261101
TAB=${TAB:-root@192.168.7.1}
IMG=reports/artifacts/uefi-ddr-20261101/slotb-uefi-marks.img
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes -o UserKnownHostsFile=/dev/null"

echo "=== [1/3] flash boot_b  $(date -Is)"
sha256sum "$IMG"
cat "$IMG" | timeout 600 ssh $SSH_OPTS "$TAB" '
set -e
dd of=/dev/disk/by-partlabel/boot_b bs=1M conv=fsync 2>/dev/null
sync
dd if=/dev/disk/by-partlabel/boot_b bs=1M count=96 2>/dev/null | sha256sum
' > "$OUT/flash-readback.txt" 2>&1
cat "$OUT/flash-readback.txt"
RB=$(grep -o '^[0-9a-f]\{64\}' "$OUT/flash-readback.txt" | head -1)
WANT=$(sha256sum "$IMG" | cut -d' ' -f1)
echo "readback=$RB"
echo "want    =$WANT"
[ "$RB" = "$WANT" ] || { echo "!!! readback mismatch, abort before reboot"; exit 1; }

echo "=== [2/3] reboot (normal boot path)  $(date -Is)"
timeout 20 ssh $SSH_OPTS "$TAB" 'sync; (sleep 1; reboot) >/dev/null 2>&1 &' || true

echo "=== [3/3] sampling 150 s"
: > "$OUT/timeline.tsv"
start=$(date +%s)
for i in $(seq 1 150); do
  t=$(( $(date +%s) - start ))
  usb=$(lsusb 2>/dev/null | grep -E '18d1:|17ef:|05c6:' | tr '\n' ';')
  fb=$(timeout 6 fastboot devices 2>/dev/null | tr '\n' ';')
  ss="down"
  timeout 6 ssh $SSH_OPTS "$TAB" 'true' 2>/dev/null && ss="up"
  printf '%3d\tusb=[%s]\tfb=[%s]\tssh=%s\n' "$t" "$usb" "$fb" "$ss" >> "$OUT/timeline.tsv"
  if [ "$ss" = "up" ] && [ "$t" -gt 20 ]; then echo "ssh back at ${t}s"; break; fi
  sleep 1
done
echo "=== last 12 samples"
tail -12 "$OUT/timeline.tsv"
echo "=== distinct states"
awk -F'\t' '{print $2"|"$3"|"$4}' "$OUT/timeline.tsv" | uniq -c
