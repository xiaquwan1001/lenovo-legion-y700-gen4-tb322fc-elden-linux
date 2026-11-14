#!/bin/bash
# 15-timeline.sh — §15 时间序健康：INDEX.md §0「现在一页」是否存在且没落后于最新会话证据。
# 立此节的原因（2026-11-14 M1）：入口文档曾长期与会话实测结论不一致（文档写 A、会话已实测为 B），
# 靠人肉考古发现。规则本体 = INDEX.md §2「时间序裁决」+ .pi/AGENT-OPS.md §0「开工三件事」。
#
# 判据（只用文件名/文件内容，不联网、不读 jsonl 正文）：
#   ① INDEX.md 有 `## 0. 现在一页` 段且含 `核对日期：YYYY-MM-DD`           ⇒ 缺则 FAIL（入口失效）
#   ② 该日期 ≥ 最新会话证据日期（*/sessions/*.md 文件名日期 + .pi/sessions/*.jsonl 文件名日期）
#      ⇒ 落后则 WARN（不阻塞提交，但不许装作没看见：跑 scripts/recent-sessions.sh N 对账后刷新日期）
. "$(dirname "$0")/_lib.sh"

section '15. 时间序健康（INDEX §0 核对日期 vs 最新会话证据）'

_idx="$ROOT/INDEX.md"
if [ ! -f "$_idx" ]; then
  bad "INDEX.md 缺失（唯一状态入口不存在）"
  exit 0
fi

if ! grep -q '^## 0\. 现在一页' "$_idx"; then
  bad "INDEX.md 缺 §0「现在一页」（新会话无法一页判读做到哪/卡什么/下一步）"
  exit 0
fi

_claim=$(grep -o '核对日期：20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]' "$_idx" | head -1 | sed 's/.*：//')
if [ -z "$_claim" ]; then
  bad "INDEX.md §0 缺「核对日期：YYYY-MM-DD」（无法判新旧）"
  exit 0
fi
ok "INDEX.md §0 现在一页存在，核对日期 = $_claim"

# 最新会话证据日期：两条来源取最大（文件名里就带日期，不依赖 mtime——clone/checkout 会重置它）
_latest=$( {
  ls "$ROOT"/*/sessions/*.md 2>/dev/null | sed -n 's#.*/\(20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]\)-.*#\1#p'
  ls "$ROOT"/.pi/sessions/*.jsonl 2>/dev/null | sed -n 's#.*/\(20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]\)T.*#\1#p'
} | sort | tail -1 )

if [ -z "$_latest" ]; then
  warnf "未找到会话证据（*/sessions/*.md 或 .pi/sessions/*.jsonl），跳过新旧比较"
elif [ "$_latest" \> "$_claim" ]; then
  warnf "INDEX §0 核对日期（$_claim）落后于最新会话证据（$_latest）：先跑 scripts/recent-sessions.sh 3 对账，再把 §0 改成一致并刷新日期"
else
  ok "INDEX §0 未落后于最新会话证据（最新 = $_latest）"
fi

# ---- ①b 跨文档矛盾：INDEX §0 的「在机 vkNN」必须出现在 DEVICE §1.1 首条 ----
# 反例（2026-11-14 实测）：INDEX §0 写「在机 = RAM 启动的 vk191」，而 DEVICE §1.1 首条挂着
# 「2026-11-13（当前状态，唯一权威）：在机内核 = vk190」+ 下面又一条「最新：vk191」⇒ 同一事实两套说法，
# 正是 §2「时间序裁决」禁止的形态。判据只用文件名/文本，不联网。
_dev="$ROOT/DEVICE/README.md"
if [ -f "$_dev" ]; then
  _idx_vk=$(awk '/^## 0\. 现在一页/,/^## 1\./' "$_idx" | grep -o '在机[^。；|]\{0,40\}' | grep -o 'vk[0-9]\+' | head -1)
  _dev_block=$(awk '/^### 1\.1 /{f=1;next} f&&/^### /{exit} f' "$_dev")
  _dev_vk=$(printf '%s\n' "$_dev_block" | sed -n '1,12p' | grep -o 'vk[0-9]\+' | head -1)
  _stars=$(printf '%s\n' "$_dev_block" | grep -c '^[- ]*★★')
  if [ -n "$_stars" ] && [ "$_stars" -ne 1 ]; then
    bad "DEVICE §1.1 有 $_stars 处 ★★ 权威行（只允许 1 处：多套「当前状态」= 读者无法判读）"
  fi
  if [ -z "$_idx_vk" ] || [ -z "$_dev_vk" ]; then
    warnf "无法从 INDEX §0 / DEVICE §1.1 提取「在机 vkNN」，跳过跨文档矛盾比较（请检查两处措辞）"
  elif [ "$_idx_vk" = "$_dev_vk" ]; then
    ok "跨文档一致：INDEX §0 与 DEVICE §1.1 首条都指向 $_idx_vk"
  else
    bad "跨文档矛盾：INDEX §0 在机 = $_idx_vk，DEVICE §1.1 首条 = $_dev_vk（按 §2 时间序裁决同轮改成一致）"
  fi
else
  warnf "DEVICE/README.md 缺失，跳过跨文档矛盾比较"
fi
