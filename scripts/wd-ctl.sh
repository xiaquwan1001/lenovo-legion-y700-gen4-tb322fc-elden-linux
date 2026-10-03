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
    ensure_pulse
    BUS=$(phosh_env | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p')
    echo "[$(date +%T)] === session start (bus=${BUS:-none}) ===" >> "$LOG"
    XDG_RUNTIME_DIR=/run/phosh WAYLAND_DISPLAY=wayland-0 HOME=/root \
      DBUS_SESSION_BUS_ADDRESS="$BUS" \
      setsid nohup waydroid --details-to-stdout session start >> "$LOG" 2>&1 < /dev/null &
    echo "session started (bus=${BUS:-none}) log=$LOG"
    ;;
  net)
    echo "waydroid0: $(ip -br addr show waydroid0 2>/dev/null)"
    echo "eth0     : $(container_eth0)"
    echo "lease    : $(cat /var/lib/misc/dnsmasq.waydroid0.leases 2>/dev/null || echo none)"
    echo "--- netd 摘要 ---"
    timeout 15 waydroid shell -- sh -c "logcat -d -b all 2>/dev/null | grep -iE 'unable to initialize table|XfrmController|RouteController|dhcp' | tail -5" 2>/dev/null
    ;;
  log)
    tail -n "${2:-40}" "$LOG" 2>/dev/null
    ;;
  elapsed)
    awk '/=== start ===/{s=$1} /Container is RUNNING|RUNNING/{if(s){print "start->RUNNING:", s, "->", $1}}' "$LOG" 2>/dev/null | tail -3
    ;;
  *)
    echo "usage: $0 {state|start|stop|session|net|log [n]|elapsed}" >&2; exit 1;;
esac
