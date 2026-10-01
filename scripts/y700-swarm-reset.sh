#!/usr/bin/env bash
# y700-swarm-reset.sh — 清空 y700 项目 swarm 任务板并重启 harness（保留身份注册）
set -u
PAT='dist/harness/ser''ver'
for p in $(pgrep -f "$PAT" 2>/dev/null); do kill -TERM "$p" 2>/dev/null; done
sleep 1
D="$HOME/y700-elden/.pi/messenger"
rm -rf "$D/tasks" "$D/channels" "$D/agents" "$D/spawn-runtimes.json"
rm -f "$D/registry"/*.json
cd "$HOME/y700-elden"
export PI_MESSENGER_PORT=9878 PI_MESSENGER_DIR="$D" PI_MESSENGER_CWD="$HOME/y700-elden"
nohup node "$HOME/.pi/agent/npm/node_modules/pi-messenger-swarm/dist/harness/server.js" > /tmp/y700-harness.log 2>&1 &
sleep 2
printf '%s\n' "$(cat "$HOME/y700-elden/scripts/.coord-session" 2>/dev/null || echo coord-y700)" > "$D/session-id"
echo "harness restarted; health:"; curl -s http://127.0.0.1:9878/health; echo
