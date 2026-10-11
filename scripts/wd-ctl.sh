#!/bin/sh
# wd-ctl.sh — Waydroid 设备端控制/查询（**全部快速返回，绝不长等待**）
#
# 用法（设备上 root）：
#   wd-ctl.sh state      # 一次性输出全部关键状态（<2s）
#   wd-ctl.sh start      # 后台启动容器，立即返回
#   wd-ctl.sh stop       # 停止容器
#   wd-ctl.sh session    # 后台启动会话（自动取 phosh 的 dbus bus），立即返回
#   wd-ctl.sh net        # 容器网络快照
#   wd-ctl.sh log [n]    # 控制日志尾
#   wd-ctl.sh elapsed    # 从日志时间戳算容器启动耗时
set -u
LXC_DIR=/var/lib/waydroid/lxc
LOG=/var/log/wd-ctl.log

phosh_env() {   # 输出 "bus wayland xdg"
  P=$(pidof phosh 2>/dev/null | awk '{print $1}')
  [ -n "${P:-}" ] || { echo ""; return; }
  tr '\0' '\n' < "/proc/$P/environ" 2>/dev/null
}

lxc_state() { lxc-info -P "$LXC_DIR" -n waydroid -sH 2>/dev/null || echo UNKNOWN; }

# 重启后 /run/phosh/pulse/native 不存在 → LXC 挂载失败，容器起不来（已实测）
ensure_pulse() {
  mkdir -p /run/phosh/pulse
  [ -e /run/phosh/pulse/native ] || { touch /run/phosh/pulse/native; echo "(created pulse socket)"; }
}

container_eth0() {
  timeout 8 waydroid shell -- ip -br addr show eth0 2>/dev/null | head -1
}

case "${1:-state}" in
  state)
    echo "kernel : $(uname -r)"
    echo "lxc    : $(lxc_state)"
    echo "wd     : $(timeout 10 waydroid status 2>/dev/null | tr '\n' ' ')"
    echo "procs  : $(ps -eo pid,args 2>/dev/null | grep -c '[/]usr/bin/waydroid')"
    echo "cmgr   : $(dbus-send --system --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.NameHasOwner string:id.waydro.ContainerManager 2>/dev/null | tail -1)"
    echo "eth0   : $(container_eth0)"
    echo "lease  : $(cat /var/lib/misc/dnsmasq.waydroid0.leases 2>/dev/null | tr '\n' ' ' || echo none)"
    echo "logtail: $(tail -n 1 "$LOG" 2>/dev/null)"
    ;;
  start)
    ensure_pulse
    echo "[$(date +%T)] === start ===" >> "$LOG"
    setsid nohup waydroid container start >> "$LOG" 2>&1 < /dev/null &
    echo "started (pid=$!) log=$LOG"
    ;;
  stop)
    echo "[$(date +%T)] === stop ===" >> "$LOG"
    pkill -9 -f 'waydroid container start' 2>/dev/null || true
    lxc-stop -P "$LXC_DIR" -n waydroid -k 2>/dev/null || true
    echo stopped
    ;;
  session)
    # 会话必须以会话用户身份跑：root 连用户 system bus 会 D-Bus 跨 UID NoReply（本会话实测）。
    ensure_pulse
    UID_=${SESSION_UID:-1000}
    UHOME=$(getent passwd "$UID_" | cut -d: -f6); UHOME=${UHOME:-/home/xuqianhui1001}
    BUS=$(phosh_env | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p')
    echo "[$(date +%T)] === session start (bus=${BUS:-none}) ===" >> "$LOG"
    setpriv --reuid="$UID_" --regid="$UID_" --init-groups \
      env HOME="$UHOME" XDG_RUNTIME_DIR=/run/user/$UID_ WAYLAND_DISPLAY=wayland-0 \
      DBUS_SESSION_BUS_ADDRESS="$BUS" \
      setsid nohup waydroid --details-to-stdout session start >> "$LOG" 2>&1 < /dev/null &
    echo "session started (user=$UID_ bus=${BUS:-none}) log=$LOG"
    ;;
  net)
    echo "waydroid0: $(ip -br addr show waydroid0 2>/dev/null)"
    echo "eth0     : $(container_eth0)"
    echo "lease    : $(cat /var/lib/misc/dnsmasq.waydroid0.leases 2>/dev/null || echo none)"
    echo "--- netd 摘要 ---"
    timeout 15 waydroid shell -- sh -c "logcat -d -b all 2>/dev/null | grep -iE 'unable to initialize table|XfrmController|RouteController|dhcp' | tail -5" 2>/dev/null
    ;;
  route)
    # 可靠注入容器默认路由（历史 blank_screen.rc workaround 生效不可靠；本命令手工也证明有效）。
    # 依赖：waydroid0=192.168.240.1。仅在内核无 netd 策略路由/ netd 未下发时用。
    # 注意：必须等容器 eth0 拿到 IP（否则 "Network is unreachable"）。
    for _i in $(seq 1 20); do
      [ "$(lxc_state)" = RUNNING ] && break
      sleep 3
    done
    [ "$(lxc_state)" = RUNNING ] || { echo "container not RUNNING; start container+session first" >&2; exit 1; }
    _ok=0
    for _i in $(seq 1 40); do
      if container_eth0 | grep -q '192.168.240.1[0-9][0-9]'; then _ok=1; break; fi
      sleep 3
    done
    [ "$_ok" = 1 ] || echo "warn: eth0 IP not seen after 120s, attempting anyway" >&2
    for _i in $(seq 1 15); do
      timeout 12 waydroid shell -- ip route replace default via 192.168.240.1 dev eth0 >/tmp/wdroute.$$ 2>&1 && break
      grep -q RTNETLINK /tmp/wdroute.$$ && { sleep 2; continue; }
      break
    done
    cat /tmp/wdroute.$$ 2>/dev/null | tail -2; rm -f /tmp/wdroute.$$
    echo "--- container ip route ---"
    timeout 12 waydroid shell -- ip route 2>&1 | head -4
    ;;
  egress)
    echo -n "ping gw  : "; timeout 12 waydroid shell -- ping -c2 -W2 192.168.240.1 2>&1 | tail -1
    echo -n "curl baidu: "; timeout 15 waydroid shell -- sh -c 'curl -s -m8 -o /dev/null -w "code=%{http_code}\n" http://www.baidu.com' 2>&1 | tail -1
    ;;
  log)
    tail -n "${2:-40}" "$LOG" 2>/dev/null
    ;;
  elapsed)
    awk '/=== start ===/{s=$1} /Container is RUNNING|RUNNING/{if(s){print "start->RUNNING:", s, "->", $1}}' "$LOG" 2>/dev/null | tail -3
    ;;
  *)
    echo "usage: $0 {state|start|stop|session|net|route|egress|log [n]|elapsed}" >&2; exit 1;;
esac
