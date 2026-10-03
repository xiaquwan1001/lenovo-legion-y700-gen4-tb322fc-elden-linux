#!/bin/sh
# Start the system D-Bus early and exactly once in /init (idempotent), before
# the ath12k/net-up/start-desktop hooks.  Both net-up.sh and start-desktop.sh
# used to start it concurrently; each passed the old `pgrep dbus-daemon` guard
# and the daemon holding the path socket died -> no /run/dbus/system_bus_socket
# (2026-09-30 boot race: NM + UPower + polkit all dead).
set -e
cp -a /init "/init.bak-dbus-$(date +%Y%m%d-%H%M%S)"
if grep -q "system_bus_socket" /init; then
	echo "[patch] already patched"
	grep -n "system_bus_socket" /init
	exit 0
fi
awk '
/ath12k-retry\.sh/ && !done {
	print "# --- system D-Bus: single early owner (NM/UPower/polkit depend on it) ---"
	print "if [ \"$on_initramfs\" = 0 ]; then"
	print "\tmkdir -p /run/dbus"
	print "\tchown root:messagebus /usr/libexec/dbus-daemon-launch-helper 2>/dev/null"
	print "\tchmod 4750 /usr/libexec/dbus-daemon-launch-helper 2>/dev/null"
	print "\tif [ ! -S /run/dbus/system_bus_socket ]; then"
	print "\t\tsetsid dbus-daemon --system >/run/dbus.log 2>&1"
	print "\t\ti=0"
	print "\t\twhile [ ! -S /run/dbus/system_bus_socket ] && [ \"$i\" -lt 50 ]; do sleep 0.1; i=$((i+1)); done"
	print "\tfi"
	print "\techo \"[init] system dbus: $([ -S /run/dbus/system_bus_socket ] && echo up || echo FAILED)\" > /dev/kmsg"
	print "fi"
	print			# re-emit the original ath12k-retry line (do NOT drop it)
	done = 1
	next
}
{ print }
' /init > /init.new
chmod 755 /init.new
mv /init.new /init
echo "[patch] done"
grep -nE "system_bus_socket|ath12k-retry|net-up|time-sync" /init
