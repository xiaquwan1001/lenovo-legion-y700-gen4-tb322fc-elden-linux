#!/bin/bash
# space-watch2.sh — 监控新盘空间，快满时自动停 repo sync
# 2026-10-02: 树已迁到 1T Samsung（/mnt/Samsung）；旧 /mnt/data 盘已下线
MNT=/mnt/Samsung
WARN=120      # GiB 低于此警告
STOP=70       # GiB 低于此停止 sync
while true; do
  avail=$(df -BG --output=avail "$MNT" | tail -1 | tr -dc '0-9')
  ts=$(date '+%F %T')
  if [ "$avail" -lt "$STOP" ]; then
    echo "[$ts] ⛔ 可用 ${avail}G < ${STOP}G，停止 sync"
    pkill -f 'sync-resume2.sh'; pkill -f 'sync-adaptive.sh'
    pgrep -f 'repo/main.py' | xargs -r kill
    pgrep -x git | xargs -r kill
    exit 0
  elif [ "$avail" -lt "$WARN" ]; then
    echo "[$ts] ⚠️  可用 ${avail}G（<${WARN}G）"
  else
    echo "[$ts] ok 可用 ${avail}G"
  fi
  sleep 120
done
