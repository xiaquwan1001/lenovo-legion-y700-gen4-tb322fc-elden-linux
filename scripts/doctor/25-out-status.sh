#!/bin/bash
# 25-out-status.sh — §25 out/ 造件生命周期账本门（委托 scripts/out-status.py --check）。
# 立此节的原因（2026-11-20，.pi/reports/cleanup-audit-20261120/arch-audit.md §5 #6）：
# out/ 87G 只有 §23「大件必须有报告」一道门，没有 active/verified/superseded/pending 生命周期状态
# ⇒ 每次瘦身都要全量考古。真源 = 入库账本 versions/out-artifacts.tsv。
# 规则：① >200MB 的 out/ 一级目录必须在账本；② 状态词合法（四词表）、依据非空；③
# pending/active 目录必须真实存在（防「账本说禁删但已丢」）。out/ 不存在 ⇒ SKIP（WARN，不算 PASS）。
# 耗时：全量 du 一遍 out/（~2 s）⇒ 只进全量档，不进 fast。
. "$(dirname "$0")/_lib.sh"

section '25. out/ 造件生命周期账本（active/verified/superseded/pending ↔ 磁盘）'
GEN="$HELPERS/out-status.py"
LEDGER="$ROOT/versions/out-artifacts.tsv"

if [ ! -f "$GEN" ]; then
  bad "scripts/out-status.py 缺失（生命周期账本门的被委托件）"
  exit 0
fi
if ! command -v python3 >/dev/null 2>&1; then
  printf '  [warn] SKIP：环境缺 python3，无法对账 out/ 生命周期账本\n'
  exit 0
fi
if [ ! -f "$LEDGER" ]; then
  bad "versions/out-artifacts.tsv 不存在 → 跑 python3 scripts/out-status.py --init 生成（人工复核后入库）"
  exit 0
fi

# 反作弊先跑：三类坏件合成树（缺登记 / 非法状态 / pending 失踪）必须各被抓一条 FAIL。
if timeout 60 python3 "$GEN" --selftest >/dev/null 2>&1; then
  ok "selftest 通过（三类坏件：大件缺登记 / 非法状态词 / pending 失踪，各 1 条 FAIL）"
else
  bad "out-status --selftest 失败（门可能空转，口径同 §18/§19/§20/§22/§23）"
fi

# 现有树实跑（out/ 不存在 ⇒ 门自身打 SKIP WARN 行，rc=0，不算 PASS）。
_rc=0
_os=$(timeout 300 python3 "$GEN" --check 2>&1) || _rc=$?
printf '%s\n' "$_os" | grep -E '^  \[(ok|FAIL|warn)\]' | grep -v '账本 .* 条' || true
if [ "$_rc" -eq 0 ] && printf '%s' "$_os" | grep -q '^  \[FAIL\]'; then
  bad "out-status --check rc=0 但打 FAIL 行（退出码与判据不一致）"
elif printf '%s' "$_os" | grep -q '^  \[FAIL\]'; then
  bad "out/ 生命周期账本 FAIL：$(printf '%s' "$_os" | grep '^  \[FAIL\]' | head -2 | tr '\n' ' ')"
else
  _sum=$(printf '%s' "$_os" | grep '账本 .* 条')
  ok "生命周期账本对账过（${_sum#  [ok]   }）"
fi
