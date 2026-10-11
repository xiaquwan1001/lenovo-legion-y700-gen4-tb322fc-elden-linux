#!/bin/sh
# wd-c1-verify.dev.sh — RUN ON DEVICE (as root). 验证 vk103（IPv4+IPv6 多路由表）下
# netd 是否自建 per-network 路由（= 去 workaround）。**不注入任何 workaround 路由**。
set -u
echo "kernel=$(uname -r) date=$(date '+%F %T')"
echo "=== host ip rule ==="; ip rule 2>&1 | head -5
echo "=== config ==="; zcat /proc/config.gz 2>/dev/null | grep -E "IP_ADVANCED_ROUTER|IP_MULTIPLE_TABLES|IPV6_MULTIPLE_TABLES"
modprobe bridge 2>/dev/null
rc-service waydroid-container start >/dev/null 2>&1
sleep 4
P=$(pidof phosh | awk '{print $1}')
BUS=$(tr '\0' '\n' < /proc/$P/environ | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p')
setpriv --reuid=1000 --regid=1000 --init-groups \
  env HOME=/home/xuqianhui1001 XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 \
  DBUS_SESSION_BUS_ADDRESS="$BUS" \
  setsid nohup waydroid session start >/tmp/wds.log 2>&1 </dev/null &
echo "session launched; waiting container..."
for i in $(seq 1 24); do sleep 5; st=$(lxc-info -P /var/lib/waydroid/lxc -n waydroid -sH 2>/dev/null); [ "$st" = RUNNING ] && { echo "container RUNNING at $((i*5))s"; break; }; done
# 给 netd 一点时间建表
sleep 15
echo "=== waydroid status ==="; waydroid status 2>&1 | head -5
echo "=== container ip rule ==="; timeout 15 waydroid shell -- ip rule 2>&1 | head -8
echo "=== container tables (no workaround injected by us) ==="
timeout 15 waydroid shell -- sh -c 'echo "[main]"; ip route; echo "[1002]"; ip route show table 1002; echo "[99]"; ip route show table 99' 2>&1 | head -20
echo "=== egress w/o workaround ==="
echo -n "curl baidu : "; timeout 20 waydroid shell -- sh -c 'curl -s -m12 -o /dev/null -w "code=%{http_code}\n" http://www.baidu.com' 2>&1 | tail -1
echo -n "ping gw    : "; timeout 12 waydroid shell -- ping -c2 -W2 192.168.240.1 2>&1 | tail -1
echo "=== netd init log ==="; timeout 15 waydroid shell -- sh -c 'logcat -d -b all 2>/dev/null | grep -iE "RouteController|failed to add interface|not assigned to any netId|Network is unreachable" | tail -8' 2>&1 | tail -10
