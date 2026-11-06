#!/bin/bash
# 09-sessions.sh — §9 SESSIONS/ 快照一致性（委托 scripts/check-sessions.sh）。
# check-sessions.sh 自 2026-10-14 落地后长期无人调用（审查发现），此处固定并入门禁。
# 抽检数固定 3（doctor 应快；全量抽检可手动跑 bash scripts/check-sessions.sh 20）。
. "$(dirname "$0")/_lib.sh"

section '9. SESSIONS/ 快照一致性（委托 check-sessions.sh）'
if [ ! -f "$HELPERS/check-sessions.sh" ]; then
  warnf "scripts/check-sessions.sh 缺失，跳过"
else
  _cs=$(bash "$HELPERS/check-sessions.sh" 3 2>&1); _csrc=$?
  _csl=$(printf '%s\n' "$_cs" | grep -E '^checks OK=|ALL PASS|FAIL' | tail -2 | tr '\n' ' ')
  if [ $_csrc -eq 0 ]; then
    ok "SESSIONS 快照与源一致（$_csl）"
  else
    bad "SESSIONS 快照与源不一致（$_csl）→ 跑 bash scripts/check-sessions.sh 看细节"
  fi
fi
