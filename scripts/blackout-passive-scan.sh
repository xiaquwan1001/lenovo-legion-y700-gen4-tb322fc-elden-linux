#!/bin/sh
# 黑屏期诊断：被动扫描（只听 beacon）能否听到该 AP
BR() { iw dev wlan0 station dump 2>/dev/null | grep "beacon rx" | tr -d " \t" | cut -d: -f2; }
LOST() { dmesg | grep -ac "Connection to AP 00:00"; }
T() { cut -d. -f1 /proc/uptime; }

echo "=== uname: $(uname -r) | $(uname -v)"
echo "=== uptime: $(T)"
i=0
while [ $i -lt 40 ]; do dmesg | grep -q "wlan0: associated" && break; sleep 2; i=$((i+1)); done
echo "assoc at $(T)  beacon_rx=$(BR)  lost=$(LOST)"
sleep 8

echo "--- 被动扫描 #1（黑屏窗口）t=$(T) ---"
timeout 45 iw dev wlan0 scan passive > /tmp/ps1.txt 2>&1
echo "rc=$? BSS=$(grep -c '^BSS' /tmp/ps1.txt)  P40命中=$(grep -c 'P40 Pro' /tmp/ps1.txt)"
echo "beacon_rx=$(BR) lost=$(LOST)"
sleep 30

echo "--- 被动扫描 #2（黑屏窗口）t=$(T) ---"
timeout 45 iw dev wlan0 scan passive > /tmp/ps2.txt 2>&1
echo "rc=$? BSS=$(grep -c '^BSS' /tmp/ps2.txt)  P40命中=$(grep -c 'P40 Pro' /tmp/ps2.txt)"
echo "beacon_rx=$(BR) lost=$(LOST)"

echo "--- 等待恢复 ---"
i=0
while [ $i -lt 20 ]; do
	sleep 10
	rx=$(BR)
	[ -n "$rx" ] && [ "$rx" -gt 50 ] && break
	i=$((i+1))
done
echo "恢复观察 t=$(T) beacon_rx=$(BR) lost=$(LOST)"

echo "--- 被动扫描 #3（对照：恢复后）t=$(T) ---"
timeout 45 iw dev wlan0 scan passive > /tmp/ps3.txt 2>&1
echo "rc=$? BSS=$(grep -c '^BSS' /tmp/ps3.txt)  P40命中=$(grep -c 'P40 Pro' /tmp/ps3.txt)"

echo "--- 汇总 t=$(T) ---"
echo "beacon_rx=$(BR) lost=$(LOST)"
iw dev wlan0 link | head -3
nmcli -f GENERAL.STATE,IP4.ADDRESS device show wlan0 2>&1 | tr -d " " | tr "\n" " "
echo
echo "ps1/ps2/ps3 里的 P40 行:"
grep -h -B1 "SSID: P40 Pro" /tmp/ps1.txt /tmp/ps2.txt /tmp/ps3.txt | grep "^BSS" | head -6
