#!/usr/bin/env bash
# swarm.sh — 在 y700-elden 项目内调用 pi-messenger-swarm，避免分桶/自杀坑
# 坑1: harness 服务器若带 PI_MESSENGER_DIR 启动，会把所有项目写进那个桶 → 这里强制清除
# 坑2: pkill -f 模式会匹配本命令行 → 一律用 pgrep 取 PID
set -euo pipefail
CLI="$HOME/.pi/agent/npm/node_modules/pi-messenger-swarm/dist/harness/cli.js"
cd "$HOME/y700-elden"
# 自愈：peer 依赖软链可能被 pi 重装擦除
PI_PEER="$HOME/.local/share/fnm/node-versions/v24.21.0/installation/lib/node_modules/@earendil-works/pi-coding-agent"
PEER="$HOME/.pi/agent/npm/node_modules/@earendil-works/pi-coding-agent"
[ -e "$PEER" ] || ln -sfn "$PI_PEER" "$PEER"
# 独立端口+独立数据目录：与 lobcorp 的 harness 完全隔离，互不干扰
export PI_MESSENGER_PORT=9878
export PI_MESSENGER_DIR="$HOME/y700-elden/.pi/messenger"
export PI_MESSENGER_CWD="$HOME/y700-elden"
# 协调者身份：若当前已有 PI_AGENT_NAME（worker 环境）则保留，避免 worker 经本脚本冒充 SageYak
export PI_AGENT_NAME="${PI_AGENT_NAME:-SageYak}"
# 固定频道，避免 re-join 时漂移到 #sage-yak-2 看不到任务板
export PI_MESSENGER_CHANNEL=sage-yak
# 固定协调会话桶：本项目的任务板在 channel #sage-yak 的 session 01a0f868。
# 若被其它 pi 进程写过 session-id，CLI 会漂到新桶看不到任务板。每次调用前校正：
printf '01a0f868-28d4-7683-9444-6604cb9137f5' > "$HOME/y700-elden/.pi/messenger/session-id"
exec node "$CLI" "$@"
