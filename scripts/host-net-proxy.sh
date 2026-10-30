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
#   scripts/host-net-proxy.sh            # 起（幂等；已在跑/被 systemd 接管只报告）
#   scripts/host-net-proxy.sh --check    # 只检查；退出码 = 问题数
#   scripts/host-net-proxy.sh --stop     # 停临时进程（不动 systemd unit）
#   scripts/host-net-proxy.sh --foreground       # 给 systemd unit 用：前台 exec，不 fork/不写 pidfile
#   scripts/host-net-proxy.sh --wait-upstream N  # 等 127.0.0.1:$UPSTREAM_PORT 就绪，最多 N 秒（unit 的 ExecStartPre）
# 环境变量：UPSTREAM_PORT（默认 7890）、EXPOSE_IP（默认 192.168.7.9）、EXPOSE_PORT（默认 7897）
#
# 【开机自启（推荐，取代手工启动）】—— unit 文件在仓库 scripts/systemd/ 下，
# 安装（用户级，无需 root；登录后自动起，Bettbox 后起也会自愈）：
#   mkdir -p ~/.config/systemd/user
#   cp scripts/systemd/host-net-proxy.service ~/.config/systemd/user/
#   systemctl --user daemon-reload
#   systemctl --user enable --now host-net-proxy.service
#   # 可选：不登录也在后台跑（需 root 一次）  sudo loginctl enable-linger "$USER"
# 现状查看/回退：
#   systemctl --user status host-net-proxy.service
#   systemctl --user disable --now host-net-proxy.service && rm ~/.config/systemd/user/host-net-proxy.service
# 取证报告：reports/waydroid-proxy-systemd-20261030.md
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

unit_active() { systemctl --user is-active --quiet host-net-proxy.service 2>/dev/null; }

# 给 unit 的 ExecStartPre 用：等上游代理起来（Bettbox 后启动场景）
wait_upstream() {
  local deadline=$(( $(date +%s) + ${1:-30} )) i=0
  while [ "$(date +%s)" -lt "$deadline" ]; do
    upstream_up && { log "上游 127.0.0.1:$UPSTREAM_PORT 已就绪（等待 ${i}s）"; return 0; }
    sleep 1; i=$((i + 1))
  done
  log "WAIT: ${1:-30}s 内上游 127.0.0.1:$UPSTREAM_PORT 仍未监听（继续暴露端口，后端恢复后自动可用）"
  return 0   # 不阻塞 unit 启动：socket-proxyd 按连接转发，上游后起也能用
}

case "${1:-}" in
  --stop)  stop_fwd; exit 0 ;;
  --check) check; exit $? ;;
  --wait-upstream) wait_upstream "${2:-30}"; exit 0 ;;
  --foreground)
    [ -x "$ACTIVATE" ] || { log "缺少 $ACTIVATE"; exit 1; }
    [ -x "$PROXYD" ]   || { log "缺少 $PROXYD";   exit 1; }
    log "前台中继 $EXPOSE_IP:$EXPOSE_PORT -> 127.0.0.1:$UPSTREAM_PORT"
    exec "$ACTIVATE" -l "${EXPOSE_IP}:${EXPOSE_PORT}" "$PROXYD" "127.0.0.1:${UPSTREAM_PORT}"
    ;;
  "")
    if unit_active; then log "已由 systemd unit host-net-proxy.service 接管（本脚本不再另起进程）"
    elif exposed_up && [ -f "$PIDFILE" ]; then log "已在跑（$EXPOSE_IP:$EXPOSE_PORT -> 127.0.0.1:$UPSTREAM_PORT）"
    else stop_fwd; start_fwd || exit 1; fi
    check || exit $?
    ;;
  *) echo "用法: $0 [--check|--stop|--foreground|--wait-upstream N]" >&2; exit 2 ;;
esac
