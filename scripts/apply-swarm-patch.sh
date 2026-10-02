#!/usr/bin/env bash
# apply-swarm-patch.sh — 重新应用 pi-messenger-swarm 的 worker 脱离补丁
#
# 背景：本机 pi-messenger-swarm 的 harness daemon 与其它项目（如 lobcorp）共用
# node_modules，且共享 /tmp/pi-messenger-swarm.log。当其它项目重启其 harness 时，
# 我们的 harness 会被一并 SIGTERM；worker 的 stdout 是管道，harness 一死管道断开，
# worker 因 SIGPIPE 秒退（表现为任务反复 "agent crashed - task auto-unclaimed"）。
#
# 补丁内容：spawn 时把 worker 的 stdout/stderr 重定向到日志文件并 detached，
# 使其在 harness 重启后仍存活（新 harness 经 reconcileAndRestoreOrphans 重新接管）。
# 详见 patches/pi-messenger-swarm-detach-spawn.patch。
#
# 用法: scripts/apply-swarm-patch.sh [--restart]
set -euo pipefail
ROOT="$HOME/y700-elden"
TARGET="$HOME/.pi/agent/npm/node_modules/pi-messenger-swarm/dist/swarm/spawn.js"
PATCHED="$ROOT/patches/pi-messenger-swarm-spawn.js.patched"

if [ ! -f "$PATCHED" ]; then
  echo "缺少 $PATCHED" >&2; exit 1
fi
if grep -q "LOCAL PATCH (y700-elden)" "$TARGET" 2>/dev/null; then
  echo "已打过补丁：$TARGET"
else
  cp "$TARGET" "$TARGET.pre-y700-patch.$(date +%s)" 2>/dev/null || true
  cp "$PATCHED" "$TARGET"
  echo "已应用补丁：$TARGET"
fi
node --check "$TARGET" && echo "语法 OK"

if [ "${1:-}" = "--restart" ]; then
  # 全量重启（软重启不重新加载模块，必须换进程）
  "$ROOT/scripts/swarm.sh" --stop >/dev/null 2>&1 || true
  sleep 1
  "$ROOT/scripts/swarm.sh" --start >/dev/null 2>&1 || true
  echo "harness 已重启"
fi
