#!/bin/sh
# time-sync.sh — wait for network, step the clock from NTP, then keep chronyd
# disciplining it.
#
# Why: the TB322FC PMIC RTC is read-only for us (hwclock -w → RTC_SET_TIME
# fails with ENODEV; hwclock -r works), so the clock comes up at 1970-01-01 and
# a wrong clock breaks TLS/HTTPS (apk, git, web) and file timestamps.  chrony
# is therefore re-run on every boot once a default route exists.
#
# Called from /init right after net-up.sh (background), or manually.
set -u
LOG=/run/time-sync.log

# Asia/Shanghai (idempotent; rootfs rebuilds may drop /etc/localtime)
[ -e /usr/share/zoneinfo/Asia/Shanghai ] && \
	ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# wait up to ~90 s for a default route (WiFi net-up.sh or usb0)
i=0
while [ $i -lt 180 ]; do
	ip route show default 2>/dev/null | grep -q . && break
	sleep 0.5; i=$((i + 1))
done
echo "[time-sync] $(date -u) default route after ~$((i / 2))s" >>"$LOG"

# one-shot step (chronyd -q steps the system clock, then exits)
timeout 90 chronyd -q "pool ntp.aliyun.com iburst" >>"$LOG" 2>&1
echo "[time-sync] after step: $(date -u)" >>"$LOG"

# keep it disciplined (RTC cannot be written, so no hwclock -w)
ps -eo comm 2>/dev/null | grep -qx chronyd || chronyd >>"$LOG" 2>&1
