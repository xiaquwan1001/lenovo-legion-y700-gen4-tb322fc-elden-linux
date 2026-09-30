#!/bin/sh
# net-up.sh (NM) — bring up WiFi at boot via NetworkManager, with the old
# manual wpa_supplicant+udhcpc path kept as an automatic fallback.
#
# Ordering: NetworkManager needs the system D-Bus, which start-desktop.sh also
# starts; whichever runs first creates it (idempotent). usb0 must stay
# unmanaged (99-unmanaged.conf) so this can never break the USB SSH lifeline.
#
# 2026-09-30: switched from manual wpa_supplicant to NM so phosh's status bar
# and Settings→Network work.  First-time profile creation is done once with
# `nmcli device wifi connect "<ssid>" password "<psk>"` (persisted by NM).
set -u
IF=wlan0
CONF=/etc/wpa_supplicant/wpa_supplicant.conf
MANUAL=/usr/local/sbin/net-up-manual.sh
LOG=/run/net-up.log

log() { echo "net-up: $*" >>"$LOG"; echo "net-up: $*" > /dev/kmsg; }
have_addr() { ip -4 addr show "$IF" 2>/dev/null | grep -q "inet "; }

: >"$LOG"

# system D-Bus (started early by /init; here only ensure it exists — socket
# check avoids the boot race that killed the path socket on 2026-09-30)
if [ ! -S /run/dbus/system_bus_socket ]; then
	setsid dbus-daemon --system >>"$LOG" 2>&1
	i=0
	while [ ! -S /run/dbus/system_bus_socket ] && [ "$i" -lt 50 ]; do
		sleep 0.1; i=$((i+1))
	done
fi

# never let NM manage the USB gadget
mkdir -p /etc/NetworkManager/conf.d
cp -f /usr/local/sbin/99-unmanaged.conf /etc/NetworkManager/conf.d/99-unmanaged.conf 2>/dev/null

# wait for wlan0 (up to 3 min; created by ath12k-retry.sh)
i=0
while [ ! -e "/sys/class/net/$IF" ] && [ "$i" -lt 90 ]; do sleep 2; i=$((i+1)); done
[ -e "/sys/class/net/$IF" ] || { log "$IF never appeared"; exit 1; }

# start NetworkManager if not already running
if ! ps -eo comm 2>/dev/null | grep -qx NetworkManager; then
	NetworkManager >>"$LOG" 2>&1
	log "NetworkManager started"
fi

# wait for an IPv4 address (NM auto-connects the saved profile)
i=0
while [ "$i" -lt 40 ]; do
	have_addr && { log "$IF up via NM: $(ip -4 addr show $IF | grep -o 'inet [0-9.]*')"; exit 0; }
	sleep 2; i=$((i+1))
done

# fallback: manual path (also useful if NM is not installed/working)
log "NM did not bring up $IF in ~80s; falling back to manual"
[ -x "$MANUAL" ] && exec "$MANUAL"
exit 1
