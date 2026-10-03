#!/bin/sh
# Add the Bluetooth bring-up hook to /init (idempotent), right after the
# time-sync hook.  Runs ON THE DEVICE.
set -e
cp -a /init "/init.bak-bt-$(date +%Y%m%d-%H%M%S)"
if grep -q "bt-up.sh" /init; then
	echo "[patch] already patched"
	grep -n "bt-up" /init
	exit 0
fi
awk '
/time-sync\.sh/ && !done {
	print
	print "[ \"$on_initramfs\" = 0 ] && [ -x /usr/local/sbin/bt-up.sh ] && setsid /usr/local/sbin/bt-up.sh >/run/bt-up.log 2>&1 &"
	done = 1
	next
}
{ print }
' /init > /init.new
chmod 755 /init.new
mv /init.new /init
echo "[patch] done"
grep -nE "ath12k-retry|net-up|time-sync|bt-up" /init
