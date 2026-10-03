#!/usr/bin/env bash
# start-y700-harness.sh — 启动/重启 y700 专属 swarm harness（端口 9878，独立数据目录）
set -u
PAT='dist/harness/ser''ver'
for p in $(pgrep -f "$PAT" 2>/dev/null); do
  kill -TERM "$p" 2>/dev/null
done
sleep 1
cd "$HOME/y700-elden"
export PI_MESSENGER_PORT=9878
export PI_MESSENGER_DIR="$HOME/y700-elden/.pi/messenger"
export PI_MESSENGER_CWD="$HOME/y700-elden"
mkdir -p "$PI_MESSENGER_DIR"
nohup node "$HOME/.pi/agent/npm/node_modules/pi-messenger-swarm/dist/harness/server.js" \
  > /tmp/y700-harness.log 2>&1 &
echo "started pid $!"
sleep 2
curl -s "http://127.0.0.1:9878/health" && echo || { echo "HEALTH FAIL"; tail -20 /tmp/y700-harness.log; }
