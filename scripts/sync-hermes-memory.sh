#!/usr/bin/env bash
# sync-hermes-memory.sh — hermes 项目记忆 → 仓库内只读镜像（异地备份用）
#
# 背景：hermes 把项目记忆放在【仓库之外】（~/.pi/agent/projects-memory/<repo>/），
# 不受本仓库 git 纳管 ⇒ 磁盘损坏即不可恢复。本脚本把它【单向快照】进
# .pi/hermes-memory-mirror/，随仓库一起推 USTC GitLab / GitHub。
#
# 方向严格单向：源 = hermes 活文件（唯一可写面）；镜像 = 只读快照，勿手改。
#
# 用法：
#   scripts/sync-hermes-memory.sh          # 刷新镜像 + 重写 MANIFEST.sha256
#   scripts/sync-hermes-memory.sh --check  # 只比对；镜像过期则 exit 1
set -euo pipefail

ROOT=$(git rev-parse --show-toplevel)
REPO=$(basename "$ROOT")
SRC=${HERMES_PROJECT_MEMORY:-"$HOME/.pi/agent/projects-memory/$REPO"}
DST="$ROOT/.pi/hermes-memory-mirror"
MODE=${1:-sync}

[ -d "$SRC" ] || { echo "sync-hermes-memory: 源目录不存在: $SRC" >&2; exit 1; }

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/skills"

if [ -f "$SRC/MEMORY.md" ]; then
	cp -p "$SRC/MEMORY.md" "$stage/MEMORY.md"
fi
if [ -d "$SRC/skills" ]; then
	rsync -a --exclude '.DS_Store' "$SRC/skills/" "$stage/skills/"
fi

cat > "$stage/MIRROR.md" <<EOF
# hermes 项目记忆 — 只读镜像（勿手改）

本目录是 **生成物**：由 \`scripts/sync-hermes-memory.sh\` 从**仓库之外**的 hermes
活文件单向快照而来，随本仓库一起异地备份（USTC GitLab / GitHub）。

| 项 | 值 |
|---|---|
| 源（唯一可写面） | \`~/.pi/agent/projects-memory/$REPO/\` |
| 快照内容 | \`MEMORY.md\` + \`skills/*/SKILL.md\` |
| 不含 | hermes 自动滚动的 \`.MEMORY.md.recovery-*\` / \`.retired-*\`（派生历史，约 26 M） |
| 刷新 | \`scripts/sync-hermes-memory.sh\` |
| 一致性自检 | \`scripts/sync-hermes-memory.sh --check\` |

**方向纪律**：要改记忆就改 hermes 活文件（\`memory_add\` 等工具），改完跑一次同步；
**不要**直接编辑本目录 —— 下次同步会原样覆盖。
EOF

( cd "$stage" && find . -type f ! -name MANIFEST.sha256 -print0 | LC_ALL=C sort -z \
    | xargs -0 sha256sum ) > "$stage/MANIFEST.sha256"

if [ "$MODE" = "--check" ]; then
	if diff -r -q "$stage" "$DST" >/dev/null 2>&1; then
		echo "sync-hermes-memory: OK（镜像与 hermes 活文件一致）"
		exit 0
	fi
	echo "sync-hermes-memory: 镜像已过期 —— 跑 scripts/sync-hermes-memory.sh 刷新并提交" >&2
	diff -r -q "$stage" "$DST" 2>&1 | head -20 >&2
	exit 1
fi

mkdir -p "$DST"
rsync -a --delete "$stage/" "$DST/"
echo "sync-hermes-memory: 已刷新 $DST"
echo "  文件 $(find "$DST" -type f | wc -l) 个 / $(du -sh "$DST" | cut -f1)"
git -C "$ROOT" status --short -- .pi/hermes-memory-mirror || true
