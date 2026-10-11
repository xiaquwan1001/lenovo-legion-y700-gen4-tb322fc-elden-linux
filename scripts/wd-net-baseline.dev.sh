#!/bin/sh
# wd-net-baseline.dev.sh — RUN ON DEVICE (as root). 起 Waydroid 并取容器网络基线(A)。
# 会话必须以 user 1000 起（root 会 D-Bus 跨 UID NoReply）。零写盘、不刷机。
set -u
echo "kernel=$(uname -r) date=$(date '+%F %T')"
ip rule >/dev/null 2>&1 && echo "ip rule: OK" || echo "ip rule: unsupported (no IP_ADVANCED_ROUTER)"

modprobe bridge 2>/dev/null
rc-service waydroid-container start >/dev/null 2>&1
sleep 4

P=$(pidof phosh | awk '{print $1}')
BUS=$(tr '\0' '\n' < /proc/$P/environ | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p')
setpriv --reuid=1000 --regid=1000 --init-groups \
  env HOME=/home/xuqianhui1001 XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 \
  DBUS_SESSION_BUS_ADDRESS="$BUS" \
  setsid nohup waydroid session start >/tmp/wds.log 2>&1 </dev/null &
echo "session launched"

for i in $(seq 1 24); do
  sleep 5
  st=$(lxc-info -P /var/lib/waydroid/lxc -n waydroid -sH 2>/dev/null)
  [ "$st" = RUNNING ] && { echo "container RUNNING at $((i*5))s"; break; }
done

echo "=== waydroid status ==="; waydroid status 2>&1 | head -5
echo "=== container route tables (99/1002/main) ==="
timeout 12 waydroid shell -- sh -c 'echo "[main]"; ip route; echo "[99]"; ip route show table 99; echo "[1002]"; ip route show table 1002' 2>&1 | head -20
echo "=== ping gw ==="; timeout 12 waydroid shell -- ping -c2 -W2 192.168.240.1 2>&1 | tail -3
echo "=== ping 223.5.5.5 (CN) ==="; timeout 15 waydroid shell -- ping -c2 -W3 223.5.5.5 2>&1 | tail -3
echo "=== curl baidu (container) ==="; timeout 15 waydroid shell -- sh -c 'curl -s -m8 -o /dev/null -w "code=%{http_code}\n" http://www.baidu.com' 2>&1 | tail -2
echo "=== netd errors ==="; timeout 15 waydroid shell -- sh -c 'logcat -d -b all 2>/dev/null | grep -iE "netd|RouteController|No such device" | tail -6' 2>&1 | tail -8
