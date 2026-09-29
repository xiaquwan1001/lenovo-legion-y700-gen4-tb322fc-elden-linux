#!/bin/sh
# Idempotently add the ath12k boot-retry hook to the on-disk /init.
set -e
cp -a /init "/init.bak-$(date +%Y%m%d-%H%M%S)"
if grep -q "ath12k-retry" /init; then
	echo "[patch-init] already patched"
	exit 0
fi
awk '
/^respawn ttyGS0 &$/ {
	print "[ \"$on_initramfs\" = 0 ] && [ -x /usr/local/sbin/ath12k-retry.sh ] && setsid /usr/local/sbin/ath12k-retry.sh >/run/ath12k-retry.log 2>&1 &"
}
{ print }
' /init > /init.new
chmod 755 /init.new
mv /init.new /init
echo "[patch-init] done"
grep -n "ath12k-retry" /init
