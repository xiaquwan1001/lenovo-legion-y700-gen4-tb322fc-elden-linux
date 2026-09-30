#!/bin/sh
# Sample the panel / compositor state once a second into /root/dpms-watch.log.
# Used to catch what happens at screen blank and at wake.
# NOTE: pgrep/pkill here is busybox — `pgrep -x NAME` does NOT match the comm,
# so use `ps -eo comm | grep -cx NAME` for process checks.
D=/sys/class/drm/card0/card0-DSI-1
BL=/sys/class/backlight/aw99706-backlight
LOG=/root/dpms-watch.log
: > "$LOG"
while :; do
	printf "%s dpms=%s bright=%s bl_power=%s phoc=%s phosh=%s last=%s\n" \
		"$(date +%H:%M:%S)" \
		"$(cat $D/dpms 2>/dev/null)" \
		"$(cat $BL/brightness 2>/dev/null)" \
		"$(cat $BL/bl_power 2>/dev/null)" \
		"$(ps -eo comm | grep -cx phoc)" \
		"$(ps -eo comm | grep -cx phosh)" \
		"$(tail -1 /run/phosh.log 2>/dev/null | cut -c1-80)" >> "$LOG"
	sleep 1
done
