#!/usr/bin/env bash
# y700-harness-restart.sh — 只重启 harness（保留任务板/注册/运行中的 spawn）
set -u
PAT='dist/harness/ser''ver'
for p in $(pgrep -f "$PAT" 2>/dev/null); do kill -TERM "$p" 2>/dev/null; done
sleep 1
cd "$HOME/y700-elden"
# 自愈 peer 软链
PEER="$HOME/.pi/agent/npm/node_modules/@earendil-works/pi-coding-agent"
[ -e "$PEER" ] || ln -sfn "$HOME/.local/share/fnm/node-versions/v24.21.0/installation/lib/node_modules/@earendil-works/pi-coding-agent" "$PEER"
export PI_MESSENGER_PORT=9878
export PI_MESSENGER_DIR="$HOME/y700-elden/.pi/messenger"
export PI_MESSENGER_CWD="$HOME/y700-elden"
# setsid：彻底脱离 pi/终端的会话，pi 重启不会带走 harness
setsid nohup node "$HOME/.pi/agent/npm/node_modules/pi-messenger-swarm/dist/harness/server.js" > /tmp/y700-harness.log 2>&1 < /dev/null &
disown 2>/dev/null || true
sleep 2
curl -s http://127.0.0.1:9878/health; echo
