#!/usr/bin/env bash
# 从设备 dd 出完整 super 分区 (22GiB, ~18min @ USB2 速度)
OUT=/home/xuqianhui/mnt/Samsung/l2/super.img.raw
LOG=/home/xuqianhui/mnt/Samsung/l2/dump.log
EXPECTED=23622320128

echo "start $(date '+%F %T')" > "$LOG"
rm -f "$OUT"
timeout -k 60 1800 adb exec-out "su -c 'dd if=/dev/block/sda10 bs=4194304'" > "$OUT" 2>>"$LOG"
rc=$?
size=$(stat -c%s "$OUT" 2>/dev/null || echo 0)
echo "rc=$rc size=$size expected=$EXPECTED $(date '+%F %T')" >> "$LOG"
if [ "$rc" = "0" ] && [ "$size" = "$EXPECTED" ]; then
  echo "RESULT: OK" >> "$LOG"
else
  echo "RESULT: FAIL" >> "$LOG"
fi
