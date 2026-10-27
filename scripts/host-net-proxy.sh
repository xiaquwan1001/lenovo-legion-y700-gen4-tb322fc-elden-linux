#!/bin/bash
# host-net-proxy.sh — 把主机的本地代理暴露给设备（USB-NCM 侧），幂等
#
# 背景（2026-10-27 实测）：设备的 GMS / 容器出网依赖「宿主代理」，历史配方写的是
#   `192.168.7.9:7897`。但主机 Clash 现在**只监听 127.0.0.1:7890**（不再是 0.0.0.0:7897），
#   结果是设备到 7890/7897 都不通、容器里 `http_proxy` 设了也是死的（本轮容器原值是 `null`）。
# 不改用户的代理配置：主机侧做一次端口暴露 192.168.7.9:7897 -> 127.0.0.1:7890。
#
# 实现用 systemd 自带的 systemd-socket-activate + systemd-socket-proxyd（无需装 socat）。
# 自己写 python 中继会间歇丢 TLS 首包（实测 6 连里挂 2–3 发），别回头用。
#
# 用法：
#   scripts/host-net-proxy.sh            # 起（幂等；已在跑只报告）
#   scripts/host-net-proxy.sh --check    # 只检查；退出码 = 问题数
#   scripts/host-net-proxy.sh --stop
# 环境变量：UPSTREAM_PORT（默认 7890）、EXPOSE_IP（默认 192.168.7.9）、EXPOSE_PORT（默认 7897）
set -uo pipefail

UPSTREAM_PORT="${UPSTREAM_PORT:-7890}"
EXPOSE_IP="${EXPOSE_IP:-192.168.7.9}"
EXPOSE_PORT="${EXPOSE_PORT:-7897}"
RUN_DIR="${XDG_RUNTIME_DIR:-/tmp}"
PIDFILE="$RUN_DIR/elden-host-net-proxy.pid"
ACTIVATE=$(command -v systemd-socket-activate || echo /usr/bin/systemd-socket-activate)
PROXYD=/lib/systemd/systemd-socket-proxyd

log() { printf '[host-net-proxy] %s\n' "$*"; }

upstream_up() { ss -ltn 2>/dev/null | awk '{print $4}' | grep -qE "(^|:)${UPSTREAM_PORT}$"; }
exposed_up()  { ss -ltn 2>/dev/null | awk '{print $4}' | grep -q "${EXPOSE_IP}:${EXPOSE_PORT}$"; }

stop_fwd() {
  local pid
  pid=$(cat "$PIDFILE" 2>/dev/null || true)
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    log "已停止暴露 (pid $pid)"
  fi
  rm -f "$PIDFILE"
}

start_fwd() {
  [ -x "$ACTIVATE" ] || { log "缺少 $ACTIVATE"; return 1; }
  [ -x "$PROXYD" ]   || { log "缺少 $PROXYD";   return 1; }
  setsid "$ACTIVATE" -l "${EXPOSE_IP}:${EXPOSE_PORT}" "$PROXYD" "127.0.0.1:${UPSTREAM_PORT}" \
    >"$RUN_DIR/elden-host-net-proxy.log" 2>&1 &
  echo $! >"$PIDFILE"
  sleep 1
}

check() {
  local n=0
  upstream_up || { log "PROBLEM: 上游代理 127.0.0.1:$UPSTREAM_PORT 无监听（Clash/代理没起？）"; n=$((n + 1)); }
  exposed_up  || { log "PROBLEM: 未暴露 $EXPOSE_IP:$EXPOSE_PORT（跑一次本脚本）"; n=$((n + 1)); }
  if [ "$n" -eq 0 ]; then
    code=$(curl -s -o /dev/null -w '%{http_code}' -m 8 \
      -x "http://$EXPOSE_IP:$EXPOSE_PORT" https://www.gstatic.com/generate_204 2>/dev/null || true)
    if [ "$code" = "204" ]; then log "OK: 经 $EXPOSE_IP:$EXPOSE_PORT 取 generate_204 = 204"
    else log "PROBLEM: 经 $EXPOSE_IP:$EXPOSE_PORT 取 generate_204 = ${code:-fail}"; n=$((n + 1)); fi
  fi
  return "$n"
}

case "${1:-}" in
  --stop)  stop_fwd; exit 0 ;;
  --check) check; exit $? ;;
  "")
    if exposed_up && [ -f "$PIDFILE" ]; then log "已在跑（$EXPOSE_IP:$EXPOSE_PORT -> 127.0.0.1:$UPSTREAM_PORT）"
    else stop_fwd; start_fwd || exit 1; fi
    check || exit $?
    ;;
  *) echo "用法: $0 [--check|--stop]" >&2; exit 2 ;;
esac
