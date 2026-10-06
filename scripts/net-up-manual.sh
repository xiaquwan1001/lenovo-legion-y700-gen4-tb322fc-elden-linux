#!/bin/sh
# net-up-manual.sh — WiFi bring-up without NetworkManager (fallback path).
#
# Wait for wlan0 (created by ath12k-retry.sh), take it away from any other
# manager, start wpa_supplicant with the saved network, then obtain an address
# via DHCP.  wpa_supplicant runs in the background; udhcpc runs in background
# mode (-b) so it keeps retrying if the AP does not answer DHCP immediately.
#
# Invoked by net-up.sh (the NM version) when NM could not get an address, and
# usable stand-alone on a device without NetworkManager.
#
# Rule (PITFALLS #117): **one manager/supplicant per interface**.  This script
# used to `pkill wpa_supplicant` and start its own instance while NM was still
# running: NM kept re-activating wlan0 (periodic deauth) *and* respawned its
# supplicant 0.75 s later, so two supplicants ended up fighting over wlan0 and
# DHCP never completed.  Detach the interface from NM first, then stop the
# supplicants, then take over.

IF=wlan0
CONF=/etc/wpa_supplicant/wpa_supplicant.conf

log() {
	echo "net-up: $*"
	echo "net-up: $*" > /dev/kmsg
}

[ -f "$CONF" ] || { log "no $CONF"; exit 1; }

# wait for wlan0 (up to 3 min)
i=0
while [ ! -e "/sys/class/net/$IF" ] && [ "$i" -lt 90 ]; do
	sleep 2
	i=$((i + 1))
done
[ -e "/sys/class/net/$IF" ] || { log "$IF never appeared"; exit 1; }

# --- take over the interface (exactly one supplicant) ------------------------
nm_running=0
if command -v nmcli >/dev/null 2>&1 && ps -eo comm 2>/dev/null | grep -qx NetworkManager; then
	nm_running=1
	nmcli device disconnect "$IF" >/dev/null 2>&1
	nmcli device set "$IF" managed no >/dev/null 2>&1
	log "detached $IF from NetworkManager"
fi

if [ "$nm_running" = 1 ]; then
	# NM's D-Bus supplicant (`wpa_supplicant -u`); wlan0 is unmanaged now, so
	# NM will not use it again for this interface.
	pkill -x wpa_supplicant 2>/dev/null
else
	# no NM: only ever kill a previous manual instance of ours
	pkill -f "wpa_supplicant -B -i $IF" 2>/dev/null
fi
sleep 1

ip link set "$IF" up

if wpa_supplicant -B -i "$IF" -c "$CONF" 2>/dev/null; then
	log "wpa_supplicant started on $IF"
else
	log "wpa_supplicant failed to start"
	exit 1
fi

# background DHCP; keep retrying on failure
udhcpc -b -i "$IF" -x hostname:elden -t 10 -T 3 >/dev/null 2>&1
log "dhcp client started"
