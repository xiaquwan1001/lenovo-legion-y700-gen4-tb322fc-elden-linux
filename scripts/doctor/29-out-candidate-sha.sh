#!/bin/bash
# 29-out-candidate-sha.sh — §29 上机候选件 sha 账目门（委托 scripts/out-candidate-sha.py --check）
# 立此节的原因（2026-11-24）：out/ 原有两道账本门（§23「大件必须有报告」、§25 「生命周期状态 ↔ 磁盘」），
# 但**没有一道门核对「账本里的候选件与它自己的 sha 记录是否一致」**。本机 RAM 有随机单字节翻转的取证记录，
# 一枚 boot/esp 件若与它的 .sha256 / SHA256SUMS 对不上，刷下去就是一次不可归因的失败。
# 判据只认机器可读记录（.sha256 侧车 / SHA256SUMS*）；记录与件不一致 = FAIL，件无记录 = WARN。
# 耗时：只扫账本里 active/pending/verified 的目录（当前 ~3 s）⇒ 只进全量档。
. "$(dirname "$0")/_lib.sh"

section '29. 上机候选件 sha 账目（候选件 ↔ .sha256/SHA256SUMS，账本状态 active/pending/verified）'
GEN="$HELPERS/out-candidate-sha.py"
if [ ! -f "$GEN" ]; then
  bad "scripts/out-candidate-sha.py 缺失（候选件 sha 门的被委托件）"
  exit 0
fi
if ! command -v python3 >/dev/null 2>&1; then
  printf '  [warn] SKIP：环境缺 python3，无法核对候选件 sha\n'
  exit 0
fi

# 反作弊先跑：正例 3 件 / 反例（sha 错）必抓 / 缺记录与腐坏记录各一条 WARN
if _st=$(timeout 120 python3 "$GEN" --selftest 2>&1); then
  ok "$(printf '%s' "$_st" | grep 'selftest PASS' | head -1 | sed 's/^== //')"
else
  bad "out-candidate-sha --selftest 失败：$(printf '%s' "$_st" | grep '\[FAIL\]' | head -2 | tr '\n' ' ')"
fi

_rc=0
_out=$(timeout 600 python3 "$GEN" --check 2>&1) || _rc=$?
printf '%s\n' "$_out" | grep -E '^  \[(ok|warn|FAIL)\]' || true
if [ "$_rc" -ne 0 ]; then
  bad "候选件 sha 不一致 $(_rc=$?; printf '%s' "$_out" | grep -c '^  \[FAIL\]') 条（刷机前必须重出该件）"
elif printf '%s' "$_out" | grep -q '^  \[FAIL\]'; then
  bad "脚本 rc=0 但有 FAIL 行（退出码与判据不一致）"
else
  ok "$(printf '%s' "$_out" | grep '^== ' | tail -1 | sed 's/^== //')"
fi
