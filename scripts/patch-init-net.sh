#!/bin/sh
# Add the WiFi bring-up hook to /init (idempotent), right after the ath12k hook.
set -e
cp -a /init "/init.bak-net-$(date +%Y%m%d-%H%M%S)"
if grep -q "net-up.sh" /init; then
	echo "[patch] already patched"
	grep -n "net-up" /init
	exit 0
fi
awk '
/ath12k-retry\.sh/ && !done {
	print
	print "[ \"$on_initramfs\" = 0 ] && [ -x /usr/local/sbin/net-up.sh ] && setsid /usr/local/sbin/net-up.sh >/run/net-up.log 2>&1 &"
	done = 1
	next
}
{ print }
' /init > /init.new
chmod 755 /init.new
mv /init.new /init
echo "[patch] done"
grep -nE "ath12k-retry|net-up" /init
