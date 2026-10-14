#!/bin/bash
# gen-history.sh — 从 git log 机械生成 HISTORY/days/*.md。
# 用法:
#   scripts/gen-history.sh          # 生成 HISTORY/days/*.md
#   scripts/gen-history.sh --check  # 对账 days 条目数 == git rev-list --count HEAD
set -euo pipefail
cd "$(dirname "$0")/.."
DAYS="HISTORY/days"

if [ "${1:-}" = "--check" ]; then
  total=$(cat "$DAYS"/*.md | grep -cE '^- [0-9a-f]{7} ')
  head=$(git rev-list --count HEAD)
  echo "days 条目合计 = $total"
  echo "git rev-list --count HEAD = $head"
  if [ "$total" = "$head" ]; then echo "OK: 对账一致"; else echo "FAIL: 不一致"; exit 1; fi
  exit 0
fi

mkdir -p "$DAYS"
rm -f "$DAYS"/*.md

# git log 默认新→旧；tac 翻转为旧→新，保证组内时间升序。
# 每行: YYYY-MM-DD \t hash \t subject
tmp=$(mktemp)
git log --format=%ad'%x09'%h'%x09'%s --date=short | tac > "$tmp"

for date in $(cut -f1 "$tmp" | uniq); do
  n=$(awk -F'\t' -v d="$date" '$1==d' "$tmp" | wc -l)
  file="$DAYS/$date.md"
  {
    echo "# $date — 提交记录（$n 条）"
    echo
    echo '> 由 `scripts/gen-history.sh` 从 `git log` 机械生成，**请勿手工编辑**。'
    echo '> 该日全部提交，按提交时间升序。逐提交权威 = `HISTORY/`；会话视角见 `../../SESSIONS/`。'
    echo
    awk -F'\t' -v d="$date" '$1==d { printf "- %s %s\n", $2, $3 }' "$tmp"
  } > "$file"
done
rm -f "$tmp"
echo "生成 $(ls -1 "$DAYS"/*.md | wc -l) 个日文件"
