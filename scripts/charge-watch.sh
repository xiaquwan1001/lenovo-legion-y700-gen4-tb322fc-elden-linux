#!/bin/sh
# charge-watch.sh — keep the qcom-battmgr charger settings applied.
#
# Two things must be (re)applied at runtime on mainline:
#   1. input_current_limit: the ADSP defaults it to 100 mA, which makes the
#      tablet net-discharge even while plugged in.  Set it to current_max.
#   2. optional battery-care limit from /etc/charge.conf (LIMIT=off|55..100).
#
# The charger is re-detected on every (re)plug and the limit resets, so poll and
# re-apply.  Started by /init (see patch-init-charge.sh) or manually.
set -u
USB=/sys/class/power_supply/qcom-battmgr-usb
BAT=/sys/class/power_supply/qcom-battmgr-bat
CONF=/etc/charge.conf
LOG=/run/charge-watch.log
CCTL=/usr/local/sbin/charge-ctl.sh

log() { echo "$(date '+%H:%M:%S') $*" >>"$LOG"; }
: >"$LOG"
log "started"

while true; do
	# 1. charging power: pull the ADSP-negotiated maximum
	if [ -e "$USB/online" ] && [ "$(cat "$USB/online")" = 1 ]; then
		cur=$(cat "$USB/input_current_limit" 2>/dev/null)
		max=$(cat "$USB/current_max" 2>/dev/null)
		if [ -n "$cur" ] && [ -n "$max" ] && [ "$cur" -lt "$max" ]; then
			echo "$max" >"$USB/input_current_limit" 2>/dev/null && \
				log "input_current_limit $cur -> $max uA"
		fi
	fi

	# 2. optional battery-care limit
	if [ -f "$CONF" ]; then
		. "$CONF" 2>/dev/null
		if [ -n "${LIMIT:-}" ] && [ "$LIMIT" != off ] && [ -x "$CCTL" ]; then
			end=$(cat "$BAT/charge_control_end_threshold" 2>/dev/null)
			[ -n "$end" ] && [ "$end" != "$LIMIT" ] && "$CCTL" limit "$LIMIT" >/dev/null 2>&1
		fi
	fi

	sleep 10
done
