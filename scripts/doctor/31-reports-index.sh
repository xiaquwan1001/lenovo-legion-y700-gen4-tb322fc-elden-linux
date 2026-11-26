#!/bin/bash
# 31-reports-index.sh — §31 reports/README.md 新鲜度门（委托 scripts/reports-index.py --check）。
# 立此节的原因（2026-11-26，架构审计 A17）：`reports/` 是 694 篇 md 的落地处，
#   自述「机器生成、勿手改」的 reports/README.md 是**该目录内唯一的查全入口**；
#   但生成器此前**没有挂在任何门/钩子上**（`grep -rn reports-index scripts/*.sh
#   scripts/doctor/* .githooks/*` = 0 命中），实测自报 633 篇 vs 实际 693+ 篇 ⇒
#   入口长期指向 ~60 篇不存在的位置。与 §24（scripts/README.md）形成不对称。
# 三态：rc=0 = ok；rc≠0 = FAIL（提示重新生成）；环境缺 python3 = SKIP（不装成 PASS）。
# 反作弊（照 §17/§23/§24 口径，门空转比没有门更糟）：临时放一个 reports/zz-doctor-probe.md，
#   `--check` 必须 rc≠0；撤掉后必须 rc=0。生成器全程只读（--check 不写），真件不会被改。
# 耗时 ~1 s（只读标题行）⇒ 只进 ALL 档，不进 FAST。
. "$(dirname "$0")/_lib.sh"

section '31. reports/README.md 索引新鲜度（生成器 ↔ 磁盘对账）'

GEN="$HELPERS/reports-index.py"
IDX="$ROOT/reports/README.md"
_probe="$ROOT/reports/zz-doctor-probe.md"

rm -f "$_probe"   # 无条件清上一轮残留（被 SIGKILL 时 trap 不及运行）
cleanup() { rm -f "$_probe" 2>/dev/null; }
trap cleanup EXIT INT TERM

if [ ! -f "$GEN" ]; then
  bad "scripts/reports-index.py 缺失（索引门的被委托件）"
  exit 0
fi
if ! command -v python3 >/dev/null 2>&1; then
  printf '  [warn] SKIP：环境缺 python3，无法对账 reports/README.md 新鲜度\n'
  exit 0
fi
if [ ! -f "$IDX" ]; then
  bad "reports/README.md 不存在 → 跑 python3 scripts/reports-index.py 重新生成"
  exit 0
fi
if ! head -3 "$IDX" | grep -q '机器生成，勿手改'; then
  bad "reports/README.md 首部不是生成器标记（被手改或换件？）→ 跑 python3 scripts/reports-index.py 重新生成"
fi

# ---- 反作弊：临时新增一篇报告 ⇒ --check 必须判过期 ----
printf '# 一次性探针（doctor §31 反作弊用，正常不会存在）\n' > "$_probe"
_rc=0; timeout 120 python3 "$GEN" --check >/dev/null 2>&1 || _rc=$?
if [ "$_rc" -ne 0 ]; then ok "反作弊通过（新增 reports/zz-doctor-probe.md ⇒ --check rc=$_rc，门在读磁盘）"
else bad "反作弊失败：新增报告后 --check 仍 rc=0（门空转，不读磁盘）"; fi
rm -f "$_probe"
trap - EXIT INT TERM

# ---- 现有树实跑 ----
_rc=0
_out=$(timeout 120 python3 "$GEN" --check 2>&1) || _rc=$?
if [ "$_rc" -eq 0 ]; then
  ok "reports/README.md 最新（${_out##*：}）"
else
  bad "reports/README.md 过期（rc=$_rc）→ 跑 python3 scripts/reports-index.py 重新生成"
fi
