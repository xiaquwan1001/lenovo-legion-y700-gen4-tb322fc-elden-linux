#!/bin/bash
# 24-scripts-index.sh — §24 scripts/README.md 索引新鲜度门（委托 scripts/gen-scripts-index.py --check）。
# 立此节的原因（2026-11-20，arch-audit P1#3 收尾件）：
# scripts/README.md（~333 入口）是生成的地图，脚本增改后会静默过期 ⇒ --check rc=1 判过期。
# 三态：rc=0 = ok；rc≠0 = FAIL（提示重新生成）；环境缺 python3 = SKIP（不装成 PASS）。
# 新鲜度判据 = **结构指纹**（入口清单/分组/shebang/头注释），**不含引用计数**
#   —— 2026-11-20 grow-loop #4 实测：把「全仓文档提到该 basename 的行数」算进指纹，任何文档
#   改一行就判过期，门变成噪声（连续两轮被拦），于是改成结构比对（改文档不再触发，增删脚本仍触发）。
# 反作弊（照 §17/§23 口径，门空转比没有门更糟）：两个方向各验一次 ——
#   ① 坏 fp（改坏 README 头里的指纹十六进制）⇒ --check 必须 rc≠0；
#   ② 真结构变更（临时放一个 scripts/zz-doctor-probe.sh）⇒ --check 必须 rc≠0，撤掉后必须 rc=0。
# 两处都无条件还原（trap 兜底）。耗时 ~2 s（结构模式不扫引用语料）⇒ 只进 ALL 档，不进 FAST。
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
if ! head -5 "$README" | grep -q '本文件由.*gen-scripts-index.py 生成'; then
  bad "scripts/README.md 首行不是生成器标记（被手改或换件？）→ 跑 python3 scripts/gen-scripts-index.py 重新生成"
fi

# ---- 反作弊自检（两个方向）----
_bak=""
_probe="$ROOT/scripts/zz-doctor-probe.sh"
cleanup() { [ -n "$_bak" ] && mv -f "$_bak" "$README" 2>/dev/null; rm -f "$_probe" 2>/dev/null; }
trap cleanup EXIT INT TERM
_bak=$(mktemp "${TMPDIR:-/tmp}/scripts-readme-bak.XXXXXX")
cp -f "$README" "$_bak" || { bad "反作弊自检准备失败：无法备份 scripts/README.md"; exit 0; }

# ① 坏指纹
sed -i 's/结构指纹 fp=\([0-9a-f]\{4\}\)[0-9a-f]*/结构指纹 fp=\10000/' "$README"
_rc=0; timeout 60 python3 "$GEN" --check >/dev/null 2>&1 || _rc=$?
if [ "$_rc" -ne 0 ]; then ok "反作弊①通过（改坏指纹 ⇒ --check rc=$_rc）"
else bad "反作弊①失败：改坏指纹后 --check 仍 rc=0（门空转）"; fi
mv -f "$_bak" "$README"; _bak=""

# ② 真结构变更：临时加一个脚本
printf '#!/bin/sh\n# 一次性探针（doctor §24 反作弊用，正常不会存在）\n' > "$_probe"
_rc=0; timeout 60 python3 "$GEN" --check >/dev/null 2>&1 || _rc=$?
if [ "$_rc" -ne 0 ]; then ok "反作弊②通过（新增脚本 ⇒ --check rc=$_rc，门在读磁盘）"
else bad "反作弊②失败：新增 scripts/$(basename "$_probe") 后 --check 仍 rc=0（门没看磁盘）"; fi
rm -f "$_probe"
_rc=0; timeout 60 python3 "$GEN" --check >/dev/null 2>&1 || _rc=$?
if [ "$_rc" -eq 0 ]; then ok "反作弊②收尾：撤掉探针后 --check rc=0（可复原）"
else bad "反作弊②收尾失败：撤掉探针后 --check 仍 rc=$_rc（有残留）"; fi
trap - EXIT INT TERM

# ---- 现有树实跑 ----
_rc=0
_out=$(timeout 120 python3 "$GEN" --check 2>&1) || _rc=$?
if [ "$_rc" -eq 0 ]; then
  ok "scripts/README.md 最新（$_out）"
else
  bad "scripts/README.md 过期（rc=$_rc）→ 跑 python3 scripts/gen-scripts-index.py 重新生成"
fi
