#!/bin/sh
# bt-up.sh — bring up Bluetooth at boot on the TB322FC (elden).
#
# The QCA "brahma/peach" BT block is attached to the WCN7850-compatible UART
# (hci0).  btqca downloads qca/brhbtfw20.tlv + qca/brhbtnv20.bin and only then
# does /sys/class/bluetooth/hci0 appear ("QCA setup on UART is completed",
# typically ~30 s after boot).  BlueZ's bluetoothd is not started by anything in
# this minimal rootfs (no init system), so start it here and give the controller
# a friendly alias.
#
# Called from /init (background) after the system D-Bus is up, or manually.
set -u
LOG=/run/bt-up.log
BLUETOOTHD=/usr/lib/bluetooth/bluetoothd

log() { echo "bt-up: $*" >>"$LOG"; echo "bt-up: $*" > /dev/kmsg; }
: >"$LOG"

[ -x "$BLUETOOTHD" ] || { log "bluetoothd not installed (apk add bluez)"; exit 1; }

# system D-Bus must exist (started early by /init)
i=0
while [ ! -S /run/dbus/system_bus_socket ] && [ "$i" -lt 50 ]; do
	sleep 0.1; i=$((i+1))
done
[ -S /run/dbus/system_bus_socket ] || { log "no system bus"; exit 1; }

# wait for hci0 (up to 3 min; btqca firmware load takes ~30 s)
i=0
while [ ! -e /sys/class/bluetooth/hci0 ] && [ "$i" -lt 90 ]; do
	sleep 2; i=$((i+1))
done
[ -e /sys/class/bluetooth/hci0 ] || { log "hci0 never appeared"; exit 1; }
log "hci0 present after ~$((i*2))s"

# start bluetoothd (idempotent; -n = no fork, we background it)
if ! ps -eo comm 2>/dev/null | grep -qx bluetoothd; then
	setsid "$BLUETOOTHD" -n >/run/bluetoothd.log 2>&1
	sleep 1
	log "bluetoothd started"
else
	log "bluetoothd already running"
fi

# friendly name + power on the controller (best effort)
if command -v bluetoothctl >/dev/null 2>&1; then
	bluetoothctl system-alias elden >/dev/null 2>&1
	bluetoothctl power on >/dev/null 2>&1
	log "controller powered: $(bluetoothctl list 2>/dev/null | head -1)"
fi
