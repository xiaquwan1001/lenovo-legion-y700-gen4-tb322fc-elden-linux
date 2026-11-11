#!/bin/bash
# phoc-build-launch.sh — 以 root 在**独立 session** 里启动 build-phoc-arm64.sh（脱离调用者的进程组，
# 避免 sudo_exec/tmux 退出时被连带杀掉），日志固定到 /tmp/phoc-build.log。
# 用法（需 root）：bash scripts/phoc-build-launch.sh
set -u
REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
LOG=${LOG:-/tmp/phoc-build.log}
: > "$LOG"
cd "$REPO"
setsid nohup bash "$REPO/scripts/build-phoc-arm64.sh" >>"$LOG" 2>&1 < /dev/null &
PID=$!
echo "launched pid=$PID log=$LOG"
sleep 3
if kill -0 "$PID" 2>/dev/null; then echo "alive after 3s"; else echo "DIED IMMEDIATELY — see $LOG"; tail -20 "$LOG"; fi
