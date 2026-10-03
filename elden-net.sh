#!/bin/bash
# Configure the host side of the TB322FC USB-NCM link (tablet is 192.168.7.1).
# Run once per tablet boot (the NCM iface re-enumerates and loses its addrs):
#   sudo bash ~/y700-elden/elden-net.sh
set -e
IF=$(ip -br link | awk '/enx/{print $1; exit}')
if [ -z "$IF" ]; then
	echo "no enx (USB-NCM) interface found - is the gadget up?" >&2
	exit 1
fi
ip addr flush dev "$IF" 2>/dev/null || true
ip addr add 192.168.7.2/24 dev "$IF"
ip link set "$IF" up
echo "interface : $IF"
echo "host ip   : 192.168.7.2/24"
echo "tablet    : 192.168.7.1"
echo
echo "now:  ssh -o StrictHostKeyChecking=no root@192.168.7.1"
