#!/bin/bash
# 10-history.sh — §10 HISTORY 对账（<0.1 s）。
# 立此节的原因（2026-10-19 整理轮）：HISTORY/README.md 曾写死「总提交数 448 / 生成时 HEAD」，
# 而实际 493，且 days/ 缺 10-15～10-19 整整 5 天 —— 因为 doctor 从不看 HISTORY。
# 判据两档：FAIL = README 又写死计数；WARN = days/ 落后于 git（正常收尾态）。
. "$(dirname "$0")/_lib.sh"

section '10. HISTORY 对账（days 覆盖 / README 不写死数字）'
if grep -qE '^\| *总提交数 *\|' HISTORY/README.md 2>/dev/null; then
  bad "HISTORY/README.md 又写死了提交数（应改为 scripts/gen-history.sh --stats 现查）"
else
  ok "HISTORY/README.md 无写死计数"
fi
_hd=$(cat HISTORY/days/*.md 2>/dev/null | grep -cE '^- [0-9a-f]{7,} ' || true)
# 判据不能简单写「days 条数 == HEAD 条数」：收尾时「重生成 days → 提交」这一步本身会让
# HEAD +1，于是永远差 1 条、永远 WARN（无法收敛）。改为判「最近一次生成覆盖到哪个提交」。
_headh=$(git rev-parse --short=10 HEAD 2>/dev/null || true)
_prevh=$(git rev-parse --short=10 HEAD~1 2>/dev/null || true)
_days_all=$(cat HISTORY/days/*.md 2>/dev/null || true)
if [ -n "$_headh" ] && printf '%s' "$_days_all" | grep -q "^- $_headh "; then
  ok "HISTORY/days 新鲜（覆盖 HEAD ${_headh}，共 ${_hd} 条）"
elif [ -n "$_prevh" ] && printf '%s' "$_days_all" | grep -q "^- $_prevh "; then
  ok "HISTORY/days 新鲜（覆盖 HEAD~1 ${_prevh}；本次提交仅改文档，共 ${_hd} 条）"
else
  warnf "HISTORY/days 落后（未覆盖 HEAD ${_headh} 或 HEAD~1 ${_prevh}）→ 跑一次 scripts/gen-history.sh"
fi
