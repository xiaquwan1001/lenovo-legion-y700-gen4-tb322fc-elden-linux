#!/bin/sh
echo "===PKG==="
apk info -v iio-sensor-proxy 2>/dev/null
echo "--- policy ---"
apk policy iio-sensor-proxy 2>/dev/null
echo "===ALPINE==="
cat /etc/alpine-release
echo "===TOOLCHAIN==="
command -v abuild || echo no-abuild
apk info -e alpine-sdk >/dev/null 2>&1 && echo alpine-sdk-present || echo no-alpine-sdk
ls -d /home/*/ 2>/dev/null
echo "===BOOT-TIMING==="
echo "now: $(date -u)"
echo "uptime-sec: $(cut -d. -f1 /proc/uptime)"
echo "===IIOSP-PROC==="
ps -o pid,etime,args 2>/dev/null | grep -i iio-sensor | grep -v grep
echo "===PHOSH-PROC==="
ps -o pid,etime,args 2>/dev/null | grep -i phosh | grep -v grep | head -3
echo "===IIOSP-LOG==="
tail -60 /var/log/messages 2>/dev/null | grep -i -E "iio|sensor|ssc" | tail -30
