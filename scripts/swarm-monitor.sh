#!/usr/bin/env bash
# swarm-monitor.sh — 周期性采集 y700 swarm 进度摘要，追加到 logs/swarm-monitor.log
# 用法: scripts/swarm-monitor.sh [间隔秒=180] [总时长秒=10800]
set -u
INTERVAL="${1:-180}"
DURATION="${2:-10800}"
export PI_MESSENGER_PORT=9878
export PI_MESSENGER_DIR="$HOME/y700-elden/.pi/messenger"
export PI_MESSENGER_CWD="$HOME/y700-elden"
CLI="$HOME/.pi/agent/npm/node_modules/pi-messenger-swarm/dist/harness/cli.js"
ROOT="$HOME/y700-elden"
LOG="$ROOT/logs/swarm-monitor.log"
mkdir -p "$ROOT/logs"
DEADLINE=$(( $(date +%s) + DURATION ))
cd "$ROOT"
while [ "$(date +%s)" -lt "$DEADLINE" ]; do
  {
    echo "===== $(date '+%F %T') ====="
    node "$CLI" task list 2>&1 | sed -n '3,60p'
    echo "--- agents ---"
    node "$CLI" spawn list 2>&1 | sed -n '2,20p'
    echo "--- feed ---"
    node "$CLI" feed --limit 10 2>&1 | tail -12
    echo "--- device ---"
    timeout 8 ssh -o ConnectTimeout=4 -o StrictHostKeyChecking=no root@192.168.7.1 \
      'uptime | sed "s/.*load/load/"; waydroid status 2>/dev/null | head -2; dmesg 2>/dev/null | tail -1' 2>&1 | head -5
    echo
  } >> "$LOG" 2>&1
  # 全部任务 done 则提前结束（既无 in-progress 也无 todo）
  TL=$(node "$CLI" task list 2>&1)
  if ! echo "$TL" | grep -q "🔄" && ! echo "$TL" | grep -q "⬜"; then
    echo "===== $(date '+%F %T') ALL TASKS SETTLED =====" >> "$LOG"
    break
  fi
  sleep "$INTERVAL"
done
echo "monitor exit $(date '+%F %T')" >> "$LOG"
