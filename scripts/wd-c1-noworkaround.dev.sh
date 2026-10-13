#!/bin/sh
# wd-c1-noworkaround.dev.sh — C1 验收（**在设备上以 root 运行**）
#
# 目的：禁用「容器默认路由 workaround」（blank_screen.rc bind-mount + ip route replace default）
#       后，验证容器能否靠**内核 netd 策略路由**（CONFIG_IP_ADVANCED_ROUTER / IP_MULTIPLE_TABLES /
#       IPV6_MULTIPLE_TABLES）自建默认路由并出网。
#
# 前提：内核必须带上述 config（vk126-c1 及以后）。判据：
#   ① 宿主/容器 ip rule 正常列出（非 "Operation not supported"）
#   ② 容器 ip route 自带 default via 192.168.240.1（**没有任何人手工注入**）
#   ③ netd logcat 无 "Failed to initialize RouteController"
#   ④ 容器 ping 网关 + curl（带宿主代理）通
#
# 用法（设备上）： sh /root/wd-c1-noworkaround.dev.sh
# 末尾自动还原 config_nodes（workaround 文件恢复；对下一次容器启动生效）。
set -u

NODES=/var/lib/waydroid/lxc/waydroid/config_nodes
STAMP=$(date +%Y%m%d-%H%M%S)
BK="$NODES.bak-c1now-$STAMP"
LXC_DIR=/var/lib/waydroid/lxc

say() { echo "[$(date +%T)] $*"; }
lxc_state() { lxc-info -P "$LXC_DIR" -n waydroid -sH 2>/dev/null || echo UNKNOWN; }
eth0() { timeout 8 waydroid shell -- ip -br addr show eth0 2>/dev/null | head -1; }

say "=== C1 no-workaround verification  stamp=$STAMP"
say "kernel : $(uname -r)"
say "config : $(zcat /proc/config.gz 2>/dev/null | grep -E 'CONFIG_(IP_ADVANCED_ROUTER|IP_MULTIPLE_TABLES|IP_ROUTE_MULTIPATH|IPV6_MULTIPLE_TABLES)=' | tr '\n' ' ')"
say "host ip rule:"; ip rule 2>&1 | head -6

# --- 1) 干净起点 -----------------------------------------------------------
say "--- stopping container/session"
pkill -f 'waydroid session' 2>/dev/null || true
lxc-stop -P "$LXC_DIR" -n waydroid -k 2>/dev/null || true
pkill -9 -f 'waydroid container start' 2>/dev/null || true
sleep 3

# --- 2) 禁用 workaround ----------------------------------------------------
cp -a "$NODES" "$BK"
sed -i 's|^\([[:space:]]*lxc\.mount\.entry[[:space:]]*=[[:space:]]*/root/wd/blank_screen\.rc.*\)|#C1-DISABLED \1|' "$NODES"
say "--- workaround line now: $(grep -n 'blank_screen.rc' "$NODES" | head -1)"
say "--- backup: $BK"

# --- 3) 起容器（不注入任何路由） -------------------------------------------
modprobe bridge 2>/dev/null || true
modprobe veth 2>/dev/null || true
modprobe fuse 2>/dev/null || true
say "--- starting container"
waydroid container start >/tmp/wd-c1-container.log 2>&1 &
for i in $(seq 1 30); do sleep 5; st=$(lxc_state); [ "$st" = RUNNING ] && { say "container RUNNING at $((i*5))s"; break; }; done
say "lxc=$st"
for i in $(seq 1 24); do sleep 5; e=$(eth0); echo "$e" | grep -q '192.168.240.1[0-9][0-9]' && { say "eth0 ip at $((i*5))s: $e"; break; }; done
sleep 15   # 给 netd 时间建表

# --- 4) 判据 ---------------------------------------------------------------
say "=== [1] host ip rule"; ip rule 2>&1 | head -6
say "=== [2] container ip rule (netd 自建)"; timeout 20 waydroid shell -- ip rule 2>&1 | head -10
say "=== [3] container ip route (期望自带 default)"; timeout 20 waydroid shell -- ip route 2>&1 | head -8
say "=== [3b] container per-net tables"
timeout 20 waydroid shell -- sh -c 'for t in 99 1002 1003; do echo "[table $t]"; ip route show table $t 2>&1; done' 2>&1 | head -20
say "=== [4] netd log"
timeout 20 waydroid shell -- sh -c 'logcat -d -b all 2>/dev/null | grep -iE "RouteController|unable to initialize table|XfrmController|no default route" | tail -8' 2>&1 | tail -12
say "=== [5] egress"
printf 'ping gw    : '; timeout 12 waydroid shell -- ping -c2 -W2 192.168.240.1 2>&1 | tail -1
printf 'ping 223.5.5.5 : '; timeout 12 waydroid shell -- ping -c2 -W2 223.5.5.5 2>&1 | tail -1
printf 'curl baidu : '; timeout 25 waydroid shell -- sh -c 'curl -s -m15 -o /dev/null -w "code=%{http_code}\n" http://www.baidu.com' 2>&1 | tail -1
printf 'dns        : '; timeout 15 waydroid shell -- sh -c 'getprop | grep -i dns | head -3' 2>&1 | tr '\n' ' '; echo
say "=== [6] host side"
printf 'masq  : '; iptables-legacy -t nat -S POSTROUTING 2>/dev/null | grep -c MASQUERADE
printf 'fwd   : '; cat /proc/sys/net/ipv4/ip_forward

# --- 5) 还原 workaround 文件（下一次容器启动生效） -------------------------
cp -a "$BK" "$NODES"
say "--- config_nodes restored from $BK (takes effect on next container start)"
say "=== DONE"
