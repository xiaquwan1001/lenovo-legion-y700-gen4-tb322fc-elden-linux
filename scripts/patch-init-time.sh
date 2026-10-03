#!/bin/sh
# Add the NTP time-sync hook to /init (idempotent), right after the net-up hook.
set -e
cp -a /init "/init.bak-time-$(date +%Y%m%d-%H%M%S)"
if grep -q "time-sync.sh" /init; then
	echo "[patch] already patched"
	grep -n "time-sync" /init
	exit 0
fi
awk '
/net-up\.sh/ && !done {
	print
	print "[ \"$on_initramfs\" = 0 ] && [ -x /usr/local/sbin/time-sync.sh ] && setsid /usr/local/sbin/time-sync.sh >/dev/null 2>&1 &"
	done = 1
	next
}
{ print }
' /init > /init.new
chmod 755 /init.new
mv /init.new /init
echo "[patch] done"
grep -nE "net-up|time-sync" /init
