#!/bin/sh
# Bring up WiFi at boot: wait for wlan0 (created by ath12k-retry.sh), start
# wpa_supplicant with the saved network, then obtain an address via DHCP.
#
# wpa_supplicant runs in the background; udhcpc runs in background mode (-b) so
# it keeps retrying if the AP does not answer DHCP immediately.

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

ip link set "$IF" up
pkill wpa_supplicant 2>/dev/null
sleep 1

if wpa_supplicant -B -i "$IF" -c "$CONF" 2>/dev/null; then
	log "wpa_supplicant started on $IF"
else
	log "wpa_supplicant failed to start"
	exit 1
fi

# background DHCP; keep retrying on failure
udhcpc -b -i "$IF" -x hostname:elden -t 10 -T 3 >/dev/null 2>&1
log "dhcp client started"
