#!/usr/bin/env bash
# check-project-memory.sh — 校验「项目记忆就在仓库里」这条链路没断
#
# 背景（2026-11-02 变更）：项目记忆曾放在仓库之外（hermes 的
# ~/.pi/agent/projects-memory/<repo>/），再由 scripts/sync-hermes-memory.sh
# 单向快照进 .pi/hermes-memory-mirror/ 供异地备份 —— 两份副本、必然漂移。
#
# 现在唯一可写面 = 本仓库 `.pi/memory/`（MEMORY.md + skills/），
# 全局路径 `~/.pi/agent/projects-memory/<repo>` 只是指向它的**符号链接**，
# 以便 `mem -t project …` 等老检索入口继续可用。镜像目录已删除
# （旧脚本留档于 archive/2026-11-02-hermes-mirror-retired/）。
#
# 用法：
#   scripts/check-project-memory.sh          # 校验（exit 1 = 链路断了）
#   scripts/check-project-memory.sh --fix    # 重建缺失的符号链接
set -euo pipefail

ROOT=$(git rev-parse --show-toplevel)
REPO=$(basename "$ROOT")
SRC="$ROOT/.pi/memory"
LINK="$HOME/.pi/agent/projects-memory/$REPO"
MODE=${1:-check}

fail() { echo "check-project-memory: ❌ $*" >&2; exit 1; }

[ -f "$SRC/MEMORY.md" ] || fail "缺 $SRC/MEMORY.md（项目记忆 SSOT）"

if [ "$MODE" = "--fix" ]; then
	mkdir -p "$(dirname "$LINK")"
	[ -L "$LINK" ] && rm -f "$LINK"
	[ -e "$LINK" ] && fail "$LINK 是真实目录，先人工确认再删（可能有仓库外新增条目）"
	ln -s "$SRC" "$LINK"
	echo "check-project-memory: 已重建 $LINK -> $SRC"
fi

[ -L "$LINK" ] || fail "$LINK 不是符号链接（跑 --fix；若是真实目录先合并内容）"
[ "$(readlink -f "$LINK")" = "$(readlink -f "$SRC")" ] || fail "$LINK 指向 $(readlink -f "$LINK")，应为 $SRC"

grep -q . "$SRC/MEMORY.md" || fail "$SRC/MEMORY.md 是空的"

echo "check-project-memory: OK（$SRC ⇄ $LINK；记忆文件 $(find "$SRC" -maxdepth 1 -name '*.md' | wc -l) 个，项目技能 $(find "$ROOT/.pi/skills" -maxdepth 2 -name SKILL.md 2>/dev/null | wc -l) 个）"
