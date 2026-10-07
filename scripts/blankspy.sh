#!/bin/sh
# blankspy.sh — one-second forensic heartbeat around screen blank (G1-22/Q24).
#
# The failure ("no-op idle blank" or "short power-press blank" -> the device
# looks powered off) leaves no post-mortem because the rootfs is ext4 and the
# machine dies before anything is flushed.  This writes a synced line per
# second to /root/blankspy.log, so after the auto-reboot (USB VBUS) the last
# few lines show the state right before the event:
#   - dpms flips Off and then the log just stops  -> died during blank
#   - logind/gsd power action right before        -> userland
# Pair with /etc/init.d/elden-powerlog (shutdown-runlevel marker) to tell a
# clean poweroff from a hard reset.
#
# usage (device):  setsid /usr/local/sbin/blankspy.sh >/dev/null 2>&1 &
set -u
LOG=/root/blankspy.log
CONN=${CONN:-DSI-1}
: >"$LOG"

prev=""
while :; do
	dpms=$(cat /sys/class/drm/card*-"$CONN"/dpms 2>/dev/null | head -1)
	bl=$(cat /sys/class/backlight/aw99706-backlight/brightness 2>/dev/null)
	php=$(ps -eo comm 2>/dev/null | grep -cx phoc)
	pho=$(ps -eo comm 2>/dev/null | grep -cx phosh)
	ses=$(loginctl list-sessions --no-legend 2>/dev/null | wc -l)
	up=$(upower -i "$(upower -e 2>/dev/null | grep -i bat | head -1)" 2>/dev/null | sed -n 's/ *percentage: *//p' | head -1)
	cur="dpms=$dpms bl=$bl phoc=$php phosh=$pho sess=$ses bat=$up"
	# log every line, flag transitions (dpms flip is the interesting moment)
	if [ "$cur" != "$prev" ]; then
		printf '%s | up=%ss | %s | CHANGED\n' "$(date '+%T')" "$(cut -d. -f1 /proc/uptime)" "$cur" >>"$LOG"
	else
		printf '%s | up=%ss | %s\n' "$(date '+%T')" "$(cut -d. -f1 /proc/uptime)" "$cur" >>"$LOG"
	fi
	prev="$cur"
	sync
	sleep 1
done
