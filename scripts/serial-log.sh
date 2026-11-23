#!/bin/bash
# ★ STALE 复判（2026-11-23，D5 批 4 / reports/scripts-hardening-4-20261123.md §2）：**保留 + 本头注，不归档**。
#   调用点：scripts/devlogs.sh:77 `exec scripts/serial-log.sh "$secs"` （活依赖，所以不能移走）。
#   ❌ 不要用它做 panic / 坏发取证：`cat /dev/ttyACM0` + `sleep 0.5` 的 open/close 循环会漏帧并给假阴性
#      （PITFALLS #622 家族；同族证据 PITFALLS/README.md #622、serial-tap.py:2-6）。
#   ✓ 取证真源 = `python3 scripts/serial-tap.py`（一次 open 长期持有 + select + 断线只重开一次）。
#   本件只适合「长时间盯着看有没有输出 / devlogs 里顺带抓一段」，不作为判据来源。
#
# Capture the tablet's serial console (kernel printk goes to ttyGS0 -> host /dev/ttyACM0).
# The gadget re-enumerates on every device reboot, so loop: cat | sleep.
#
# usage: scripts/serial-log.sh [seconds]      (default: run until killed)
set -u
cd "$(dirname "$0")/.."
mkdir -p logs
SECS=${1:-0}
LOG=logs/serial-$(date +%Y%m%d-%H%M%S).log
echo "[serial] -> $LOG"
: > "$LOG"
if ! [ -r /dev/ttyACM0 ]; then
	echo "[serial] /dev/ttyACM0 not readable (is the tablet in mainline Linux?)" >&2
	exit 1
fi
end=$(( $(date +%s) + SECS ))
while :; do
	cat /dev/ttyACM0 >> "$LOG" 2>/dev/null
	sleep 0.5
	if [ "$SECS" != 0 ] && [ "$(date +%s)" -ge "$end" ]; then break; fi
done
echo "[serial] done ($(wc -c < "$LOG") bytes)"
