#!/bin/sh
# ath12k (WCN7861 "Peach") boot-time re-probe.
#
# The built-in ath12k PCI probe runs in the kernel initcall phase and the very
# first probe always fails because the Peach WCN is not ready that early (MHI
# POWER_ON times out; patch 0001 reduces the wait from 90s to 3s). The device
# is then left *unbound*, so phy0/wlan0 never appear. Binding the still-unbound
# device once the WCN is up creates wlan0.
#
# Safety: only ever bind a device that currently has NO driver. Never
# unbind/remove a live ath12k device -- that has been observed to hang the
# kernel.
#
# Every step is logged to /dev/kmsg (visible via dmesg) as well as the log file
# passed on the command line by /init.

DEVNAME=0000:01:00.0
DEV=/sys/bus/pci/devices/$DEVNAME
DRV=/sys/bus/pci/drivers/ath12k_wifi7_pci
PHY=/sys/class/ieee80211/phy0

log() {
	echo "ath12k-retry: $*"
	echo "ath12k-retry: $*" > /dev/kmsg
}

log "started (pid $$)"
sleep 12
log "awake, starting re-probe loop"

i=0
while [ "$i" -lt 60 ]; do
	i=$((i + 1))

	if [ -e "$PHY" ]; then
		log "phy0 up (try $i)"
		exit 0
	fi
	if [ ! -e "$DEV" ]; then
		sleep 2
		continue
	fi
	if [ -e "$DEV/driver" ]; then
		log "device bound but no phy0 yet (try $i)"
		sleep 5
		continue
	fi

	log "binding unbound device (try $i)"
	# NOTE: the sysfs `bind` attribute takes the *device name*, not the path.
	if echo "$DEVNAME" > "$DRV/bind" 2>/dev/null; then
		log "bind write ok (try $i)"
	else
		log "bind write failed (try $i)"
	fi
	sleep 5
done

log "gave up, no phy0"
exit 1
