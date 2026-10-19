#!/bin/bash
# gen-history.sh — 从 git log 机械生成 HISTORY/days/*.md，并现查统计。
#
# 用法:
#   scripts/gen-history.sh            # 生成/刷新 HISTORY/days/*.md（幂等；未变化的日文件不产生 diff）
#   scripts/gen-history.sh --check    # 对账 days 条目数 == git rev-list --count HEAD（收尾时的重生成提示）
#   scripts/gen-history.sh --stats    # 现查全部统计（总提交数 / 逐日 / type 分布）。README 不写死数字，写死必漂。
#
# 纪律：days/*.md 是派生物，永不手工编辑；HISTORY/README.md 不写死任何计数。
set -euo pipefail
cd "$(dirname "$0")/.."
DAYS="HISTORY/days"

# 日期分桶用 git 默认（本机）时区；**不要**在这里改 TZ —— 改一次会把跨午夜的提交整体换日，
# 17 个日档同时改名+重排（一次性全树 churn）。若换机器/换时区重生成，先看 --stats 的覆盖区间是否变化。
# 固定缩写长度：git 会随对象增多自动把 %h 从 7 位变 8 位，导致 17 个日档每行 hash 同时变。
ABBREV=10

if [ "${1:-}" = "--stats" ]; then
  head_n=$(git rev-list --count HEAD)
  short=$(git rev-parse --short HEAD)
  days=$(git log --date=short --format=%ad | sort -u | wc -l)
  echo "总提交数 = $head_n    当前 HEAD = $short"
  echo "覆盖区间 = $(git log --date=short --format=%ad | tail -1) → $(git log -1 --date=short --format=%ad)（$days 个自然日）"
  awk -v a="$head_n" -v b="$days" 'BEGIN{printf "平均每日 = %.1f 条\n", a/b}'
  echo "峰值日 = $(git log --date=short --format=%ad | sort | uniq -c | sort -rn | head -1 | awk '{print $2"（"$1" 条）"}')"
  echo "--- 逐日（旧→新）---"
  git log --date=short --format=%ad | sort | uniq -c | awk '{printf "%s  %s\n", $2, $1}'
  echo "--- type top10（口径 = subject 首个 ^[a-z_]+，只反映书写习惯）---"
  git log --format=%s | grep -oE '^[a-z_]+' | sort | uniq -c | sort -rn | head -10 | awk '{printf "%-12s %s\n", $2, $1}'
  echo "--- type 种数 = $(git log --format=%s | grep -oE '^[a-z_]+' | sort -u | wc -l)"
  exit 0
fi

if [ "${1:-}" = "--check" ]; then
  total=$(cat "$DAYS"/*.md | grep -cE '^- [0-9a-f]{7,} ' || true)
  head=$(git rev-list --count HEAD)
  # 回填历史分支（history/*）的提交也要计入：它们不是 HEAD 祖先但已进 days/
  hist=$(git rev-list --count HEAD $(git for-each-ref --format='%(refname:short)' 'refs/heads/history/*' 'refs/remotes/*/history/*' 2>/dev/null | sort -u) 2>/dev/null || echo "$head")
  echo "days 条目合计 = $total"
  echo "git rev-list --count HEAD = $head（含回填历史分支 = $hist）"
  head=$hist
  if [ "$total" = "$head" ]; then
    echo "OK: 对账一致"
  else
    echo "落后 $((head - total)) 条 — 收尾时跑一次 scripts/gen-history.sh"
    exit 1
  fi
  exit 0
fi

mkdir -p "$DAYS"
# 只删除"不再存在的日期"文件；已存在的日文件按内容覆盖写。
# 内容只由 git log 决定 ⇒ 未变化的日文件逐字节相同，git 不产生 diff（不是"反复删改"）。
# 历史范围 = HEAD 的提交 **加上** 已回填但不在 HEAD 祖先里的历史分支（history/*）。
# 背景（2026-10-19 实测）：2026-09-28～10-02 那 5 个日档记录的是 `history/pre-vk34` 的提交，
# 它们不是 HEAD 的祖先；只按 HEAD 生成会把这 5 天永久删掉（= 丢历史账）。
RANGE=HEAD
for ref in $(git for-each-ref --format='%(refname:short)' 'refs/heads/history/*' 'refs/remotes/*/history/*' 2>/dev/null | sort -u); do
  git rev-parse --verify -q "$ref" >/dev/null || continue
  grep -qxF "$(git rev-parse "$ref")" /dev/null 2>/dev/null || true
  RANGE="$RANGE $ref"
done

tmp=$(mktemp)
# shellcheck disable=SC2086
git -c core.abbrev="$ABBREV" log $RANGE --format=%ad'%x09'%h'%x09'%s --date=short | tac > "$tmp"

keep=""
for date in $(cut -f1 "$tmp" | sort -u); do
  n=$(awk -F'\t' -v d="$date" '$1==d' "$tmp" | wc -l)
  file="$DAYS/$date.md"
  keep="$keep $file"
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

# 清理已不存在的日期（例如提交被 rewrite 后该日为空）
for f in "$DAYS"/*.md; do
  [ -e "$f" ] || continue
  case " $keep " in *" $f "*) ;; *) rm -f "$f"; echo "removed stale $f" ;; esac
done

echo "生成 $(ls -1 "$DAYS"/*.md | wc -l) 个日文件（abbrev=$ABBREV）"
