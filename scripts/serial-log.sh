#!/bin/bash
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
