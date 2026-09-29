#!/bin/sh
# Load the ath12k (WCN7861 "Peach") driver as a *module* after boot.
#
# Why a module:
#   As a built-in (CONFIG_ATH12K=y) the PCI probe runs synchronously inside the
#   kernel initcall phase. When the Peach WCN was not ready yet, MHI POWER_ON
#   waited for its 90s timeout, which blocked /init for ~90s; if MHI ever failed
#   to return at all, /init never ran (no USB/serial/network, backlight only).
#   Loading from userspace after boot avoids blocking entirely.
#
# Retry policy: if the first probe leaves the PCI device unbound, re-probe via
#   the driver's sysfs `bind`. NEVER unbind/remove a live ath12k device -- that
#   has been observed to hang the kernel.
#
# Firmware (all in /lib/firmware/ath12k/PEACH/hw2.0/):
#   amss.bin m3.bin aux_ucode.bin tmel.bin board-2.bin regdb.bin
#   qdss_trace_config.bin   (PEACH-only; missing => no wlan0)

DEV=/sys/bus/pci/devices/0000:01:00.0
DRV=/sys/bus/pci/drivers/ath12k_wifi7_pci
PHY=/sys/class/ieee80211/phy0

log() { echo "ath12k-load: $*"; }

sleep "${ATH12K_LOAD_DELAY:-8}"

if ! modprobe ath12k_pci 2>/dev/null; then
	log "modprobe ath12k_pci failed"
fi

for i in $(seq 1 60); do
	[ -e "$PHY" ] && { log "phy0 up"; exit 0; }
	[ -e "$DEV" ] || { sleep 5; continue; }
	# still being probed or already successfully bound -> leave it alone
	if [ ! -e "$DEV/driver" ]; then
		echo "$DEV" > "$DRV/bind" 2>/dev/null && log "re-bound $DEV (try $i)"
	fi
	sleep 5
done

log "gave up (no phy0)"
exit 1
