#!/bin/bash
# 24-scripts-index.sh — §24 scripts/README.md 索引新鲜度门（委托 scripts/gen-scripts-index.py --check）。
# 立此节的原因（2026-11-20，arch-audit P1#3 收尾件）：
# scripts/README.md（~333 入口）是生成的地图，脚本增改后会静默过期 ⇒ --check rc=1 判过期。
# 三态：rc=0 = ok；rc≠0 = FAIL（提示重新生成）；环境缺 python3 = SKIP（不装成 PASS）。
# 反作弊（照 §17/§23 口径，门自己空转 = 比没有门更糟）：临时把真件换成「删掉一行的坏副本」，
# 断言 --check 确实判过期（rc≠0）——即门真的在读内容、不是恒真；随后无条件还原真件（trap 兜底）。
# 耗时 ~5 s（--check 全量重建语料）⇒ 只进 ALL 档，不进 FAST。
. "$(dirname "$0")/_lib.sh"

section '24. scripts/README.md 索引新鲜度（生成器 ↔ 磁盘对账）'

GEN="$HELPERS/gen-scripts-index.py"
README="$ROOT/scripts/README.md"

if [ ! -f "$GEN" ]; then
  bad "scripts/gen-scripts-index.py 缺失（索引门的被委托件）"
  exit 0
fi
if ! command -v python3 >/dev/null 2>&1; then
  printf '  [warn] SKIP：环境缺 python3，无法对账 scripts/README.md 新鲜度\n'
  exit 0
fi
if [ ! -f "$README" ]; then
  bad "scripts/README.md 不存在 → 跑 python3 scripts/gen-scripts-index.py 重新生成"
  exit 0
fi
if ! head -1 "$README" | grep -q '本文件由.*gen-scripts-index.py 生成'; then
  bad "scripts/README.md 首行不是生成器标记（被手改或换件？）→ 跑 python3 scripts/gen-scripts-index.py 重新生成"
fi

# ---- 反作弊自检：坏副本（删一行）必须被判过期 ----
_bak=""
cleanup() { [ -n "$_bak" ] && mv -f "$_bak" "$README" 2>/dev/null; }
trap cleanup EXIT INT TERM
_bak=$(mktemp "${TMPDIR:-/tmp}/scripts-readme-bak.XXXXXX")
cp -f "$README" "$_bak" || { bad "反作弊自检准备失败：无法备份 scripts/README.md"; exit 0; }
# 删掉正文中一行（第 12 行起的第一条表行/正文行，避开生成器标记头 3 行）
sed -i '12d' "$README"
_rc=0
timeout 60 python3 "$GEN" --check >/dev/null 2>&1 || _rc=$?
if [ "$_rc" -ne 0 ]; then
  ok "反作弊自检通过（坏副本：删一行 ⇒ --check rc=$_rc 判过期，门在读内容）"
else
  bad "反作弊自检失败：坏副本（删一行）--check 仍 rc=0（门空转，恒真）"
fi
mv -f "$_bak" "$README"   # 还原真件；trap 兜底（中途异常也还原）
_bak=""
trap - EXIT INT TERM

# ---- 现有树实跑 ----
_rc=0
_out=$(timeout 120 python3 "$GEN" --check 2>&1) || _rc=$?
if [ "$_rc" -eq 0 ]; then
  ok "scripts/README.md 最新（$_out）"
else
  bad "scripts/README.md 过期（rc=$_rc）→ 跑 python3 scripts/gen-scripts-index.py 重新生成"
fi
