#!/bin/bash
# 根分区空间看门狗：repo sync 期间若 / 可用空间低于阈值，就停掉 sync（可断点续传），
# 避免把根分区写满导致系统异常。
# 用法: setsid nohup ./space-watch.sh > space-watch.log 2>&1 &
THRESHOLD_GB=20
INTERVAL=60
cd "$(dirname "$0")" || exit 1

while true; do
  avail_gb=$(df --output=avail -BG / | tail -1 | tr -dc '0-9')
  running=$(pgrep -f 'sync-resume\.sh' | wc -l)
  if [ "$running" -eq 0 ]; then
    echo "[$(date '+%F %T')] sync-resume.sh 已结束，看门狗退出"
    exit 0
  fi
  if [ "$avail_gb" -lt "$THRESHOLD_GB" ]; then
    echo "[$(date '+%F %T')] ⚠️ 根分区仅剩 ${avail_gb}G (<${THRESHOLD_GB}G)，停止 sync 以免写满"
    # 用 pgid 精准终止，避免 pkill -f 误伤自身
    pgid=$(ps -o pgid= -p "$(pgrep -f 'main\.py.*sync' | head -1)" 2>/dev/null | tr -d ' ')
    [ -n "$pgid" ] && kill -TERM -"$pgid" 2>/dev/null
    sleep 5
    pkill -f 'sync-resume\.sh' 2>/dev/null
    echo "[$(date '+%F %T')] 已停止。清理/迁移后重新运行 ./sync-resume.sh 即可续传。"
    exit 1
  fi
  echo "[$(date '+%F %T')] avail=${avail_gb}G  tree=$(du -sh . 2>/dev/null | cut -f1)"
  sleep "$INTERVAL"
done
