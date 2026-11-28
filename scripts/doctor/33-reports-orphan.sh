#!/bin/bash
# 33-reports-orphan.sh — §33 reports/ 孤儿真值门（委托 scripts/reports-orphan-check.py --check）。
#
# 立此节的原因（2026-11-28，doc-drift 审计 S7）：同一条「reports/ 无孤儿」判据曾有两套实现、
#   同一次审计内结论相反 —— §8f（scripts/doctor/s07-08-docs.py）的语料是「全仓任意 md/sh/py/tsv，
#   文件名出现过即算」，连 reports/README.md 这个机器全量目录都算指针 ⇒ 判别力≈0、恒 [ok]；
#   专职门 scripts/reports-orphan-check.py 用「角度层语料（7 个角度 README ± 顶层 md ± sessions/）
#   + 反作弊（单行 ≤4 个报告名、去路径后 ≥8 字真用途句、通用句/同句复用不算）」⇒ 同一时刻 rc=1
#   （实测 12 篇孤儿）。现在真值只认本节，§8f 已在措辞上降级为「粗筛」（判据本体未改、仍只 WARN）。
# 三态（三态都写清，缺一态就等于把未知装成 PASS）：
#   rc=0 = ok ；rc=1 = FAIL（有孤儿）；rc=2 = FAIL（reports/ 缺失或无 *.md，判据无法执行）；
#   其余 rc（124 = 超时 / 崩溃）= warn「判据异常退出」，**不当成 PASS**；缺 python3 = SKIP（warn）。
# 反作弊（照 §31/§24 口径：门空转比没有门更糟）：本门自己**不**往 reports/ 写探针 ——
#   §31（同一轮并发跑）已占用 reports/zz-doctor-probe.md 做它自己的反作弊，任何一方写孤儿文件
#   都会让另一方的「干净树」判定瞬间变红（假 FAIL）。改用被委托件自带的 `--selftest`：15 条断言
#   含端到端「假孤儿 ⇒ rc=1 / 补指针 ⇒ rc=0」的双向翻转（在临时目录里做，零写盘）；自测红 ⇒ 本门红。
# 并发隔离（实测存在的假红窗口）：§31 的探针在 reports/ 停留 ~1–2 s，落在本门 ~2.4 s 的全量扫描
#   窗口内就会被当孤儿。处置：若**唯一**孤儿是 §31 的探针名，等 1 s 复扫一次，以复扫为准；
#   复扫仍红（探针残留 = §31 被异常打断 / 真孤儿）则照红并点名，不静默放过。
# 耗时：--check 全仓角度语料扫描实测 2.4 s（759 篇）+ --selftest 0.04 s ⇒ 只进 ALL 档，
#   不进 FAST（fast 档总预算 6 s，加进来会恒响墙钟 WARN；fast 档的孤儿兜底仍是 §8f 粗筛）。
. "$(dirname "$0")/_lib.sh"

section '33. reports/ 孤儿（角度层指针）真值门 — 委托 scripts/reports-orphan-check.py'

GATE="$HELPERS/reports-orphan-check.py"
OUT=$(mktemp "${TMPDIR:-/tmp}/orphan-gate.XXXXXX") || { bad "无法建临时文件（判据未核）"; exit 0; }
trap 'rm -f "$OUT"' EXIT INT TERM

if [ ! -f "$GATE" ]; then
  bad "scripts/reports-orphan-check.py 缺失（孤儿真值门的被委托件）→ 恢复该脚本再跑"
  exit 0
fi
if ! command -v python3 >/dev/null 2>&1; then
  printf '  [warn] SKIP：环境缺 python3，reports/ 孤儿真值**未核**（§8f 粗筛仍在跑，但它不算真值）\n'
  exit 0
fi

# 跑一次 --check（清单默认打印，用于区分「§31 探针」与「真孤儿」）
_check() {
  _rc=0
  timeout 120 python3 "$GATE" --check --root "$ROOT" > "$OUT" 2>&1 || _rc=$?
  return "$_rc"
}
_orphans() { sed -n '/^-- 孤儿清单/,$p' "$1" | sed -n 's/^  \([^ ].*\)$/\1/p'; }

_check; _rc=$?
_orph=$(_orphans "$OUT")
_retried=0
if [ "$_rc" -eq 1 ] && [ -n "$_orph" ] \
   && [ "$(printf '%s\n' "$_orph" | grep -cvE '^zz-doctor-probe\.md$')" -eq 0 ]; then
  sleep 1                      # §31 探针的并发窗口：等它撤掉再复扫一次
  _check; _rc=$?
  _orph=$(_orphans "$OUT")
  _retried=1
fi

_gate_line=$(sed -n 's/^  \[gate\] //p' "$OUT" | head -1)
_note=""
[ "$_retried" -eq 1 ] && _note=", 已排除并发窗内 §31 探针"

case "$_rc" in
  0) ok "reports/ 无孤儿（${_gate_line:-all 刻度 0 孤儿}${_note}）" ;;
  1) if [ "$_retried" -eq 1 ]; then
       bad "reports/zz-doctor-probe.md 仍残留（§31 反作弊探针未被撤掉：§31 被 SIGKILL / 异常退出？）→ 删掉该文件后复跑"
     elif [ -n "$_orph" ]; then
       bad "有孤儿报告 $(printf '%s\n' "$_orph" | wc -l) 篇（rc=1，${_gate_line:-all 刻度}）→ 在角度层补**合规**指针（单行 ≤4 篇 + 一句真用途句；reports/README.md、INDEX.md、HISTORY、TASKS/dim 都不在语料里）；明细：python3 scripts/reports-orphan-check.py --check；判据与落点见 .pi/plans/2026-11-28-doc-drift.md M2"
     else
       bad "判据判红（rc=1）但解析不到孤儿清单（输出格式变了？）→ 单跑 python3 scripts/reports-orphan-check.py --check 核"
     fi ;;
  2) bad "判据无法执行（rc=2：reports/ 不存在或无 *.md）→ 检查工作树是否完整（本门的判据没跑成）" ;;
  *) warnf "判据异常退出（rc=$_rc，超时 124 / 崩溃？）—— 孤儿真值本轮**未核**，不要当成 PASS" ;;
esac

# ---- 反作弊：被委托件自带 --selftest（含端到端红/绿翻转；零写盘）----
_src=0
_st=$(timeout 120 python3 "$GATE" --selftest 2>&1) || _src=$?
_stsum=$(printf '%s\n' "$_st" | sed -n 's/^SELFTEST: //p' | head -1)
if [ "$_src" -eq 0 ]; then
  ok "反作弊通过（--selftest ${_stsum:-FAIL=0}：假孤儿判红、补指针转绿、reports/README.md 不算指针）"
else
  bad "反作弊失败（--selftest rc=$_src，${_stsum:-无汇总行}）→ 判据自身坏了，本门绿了也不算数"
fi
