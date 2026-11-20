#!/bin/bash
# 23-out-manifest.sh — §23 out/ 造件「报告↔镜像」账本门（委托 scripts/out-manifest-check.py）。
# 立此节的原因（2026-11-20，.pi/reports/cleanup-audit-20261120/arch-audit.md §5 #2/#5/#6）：
# out/ 87G 造件没有账本门禁，删错 android-slim-v3-20261119 这种唯一可用 final 件即毁证据链。
# 规则（防误报）：out/<name>/ 含 >200MB 件或 >1 个 .img ⇒ 必须有 reports/<name>.md
# 或任一 reports/*.md 引用 out/<name>，否则 WARN（不 FAIL）。豁免表
# scripts/out-manifest-exempt.tsv 空理由必须 FAIL（照 §17 反作弊口径）。
. "$(dirname "$0")/_lib.sh"

section '23. out/ 造件账本门（大件/多镜像 ↔ 报告）'
if [ ! -f "$HELPERS/out-manifest-check.py" ]; then
  bad "scripts/out-manifest-check.py 缺失"
  exit 0
fi

# 反作弊先跑：4 类合成样本（有报告=过 / 无报告=warn / 豁免带理由=过 / 空理由=FAIL）。
# 门自己空转 = 比没有门更糟（口径同 §18/§19/§20/§22）。
if timeout 60 python3 "$HELPERS/out-manifest-check.py" --selftest >/dev/null 2>&1; then
  ok "selftest 通过（4 类合成样本：报告命中 / 无报告 warn / 带理由豁免 / 空理由 FAIL）"
else
  bad "out-manifest-check --selftest 失败（门可能空转）"
fi

# 现有树实跑（WARN 不阻塞；豁免表坏 / 空理由 ⇒ FAIL）。
if _om=$(timeout 300 python3 "$HELPERS/out-manifest-check.py" 2>&1); then
  _nwarn=$(printf '%s' "$_om" | grep -c '^  \[warn\]')
  _nex=$(grep -vc '^#\|^$' "$ROOT/scripts/out-manifest-exempt.tsv" 2>/dev/null || echo 0)
  ok "现有树实跑过（触发 $(printf '%s' "$_om" | grep -o '触发门禁的 out/ 目录 [0-9]*' | grep -o '[0-9]*$') 个，WARN $_nwarn 条，豁免 $_nex 条）"
else
  bad "out/ 造件账本门 FAIL：$(printf '%s' "$_om" | grep '^  \[FAIL\]' | head -2 | tr '\n' ' ')"
fi
