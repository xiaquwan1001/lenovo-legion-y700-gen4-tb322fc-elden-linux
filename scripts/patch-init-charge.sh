#!/bin/sh
# Add the charge-watch hook to /init (idempotent), after time-sync.
# Runs ON THE DEVICE.
set -e
cp -a /init "/init.bak-charge-$(date +%Y%m%d-%H%M%S)"
if grep -q "charge-watch.sh" /init; then
	echo "[patch] already patched"
	grep -n "charge-watch" /init
	exit 0
fi
awk '
/time-sync\.sh/ && !done {
	print
	print "[ \"$on_initramfs\" = 0 ] && [ -x /usr/local/sbin/charge-watch.sh ] && setsid /usr/local/sbin/charge-watch.sh >/run/charge-watch.log 2>&1 &"
	done = 1
	next
}
{ print }
' /init > /init.new
chmod 755 /init.new
mv /init.new /init
echo "[patch] done"
grep -nE "ath12k-retry|net-up|time-sync|bt-up|charge-watch" /init
