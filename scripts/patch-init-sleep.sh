#!/bin/sh
# Sleep / power policy hook for /init  (idempotent)
#
# Why (PITFALLS §64): this bring-up kernel advertises
#   /sys/power/state   = freeze mem disk
#   /sys/power/mem_sleep = s2idle [deep]     <-- "deep" = PSCI SYSTEM_SUSPEND,
#                                              not supported on this bring-up
#                                              tree -> entering `mem` hangs the
#                                              machine (screen dead, must power
#                                              cycle).
# Fix: force s2idle so `mem` is survivable, and turn a soft lockup into a panic
# so any hang leaves a stack in ramoops (pstore), readable after reboot.
#
# Usage: on the device (persistent root):  sh patch-init-sleep.sh
#        inside the ramdisk rootfs:        on_initramfs block also applies.
set -e

MARK="elden sleep policy"
cp -a /init "/init.bak-sleep-$(date +%Y%m%d-%H%M%S)"

if grep -q "$MARK" /init; then
	echo "[patch] already patched"
	grep -n "sleep policy" -A4 /init
	exit 0
fi

BLOCK='# --- elden sleep policy (PITFALLS §64) -------------------------------------
# Prefer s2idle: "deep" (PSCI system suspend) is not supported by this tree and
# hangs the machine on first suspend. Only switch if the kernel offers s2idle.
if [ -w /sys/power/mem_sleep ] && grep -q "s2idle" /sys/power/mem_sleep 2>/dev/null; then
	echo s2idle > /sys/power/mem_sleep 2>/dev/null
	echo "[init] sleep policy: mem_sleep=$(cat /sys/power/mem_sleep)" > /dev/kmsg
fi
# Make a soft lockup fatal so a hang is preserved in ramoops (pstore).
[ "$on_initramfs" = 0 ] && echo 1 > /proc/sys/kernel/softlockup_panic 2>/dev/null
# --- end elden sleep policy --------------------------------------------------'

# Insert right after the on_initramfs detection (before anything can suspend).
awk -v blk="$BLOCK" '
/^echo "\[init\] root fs type=/ { print; print blk; done=1; next }
{ print }
' /init > /init.new
chmod 755 /init.new
mv /init.new /init
echo "[patch] done"
grep -n "sleep policy" -A3 /init | head -20
