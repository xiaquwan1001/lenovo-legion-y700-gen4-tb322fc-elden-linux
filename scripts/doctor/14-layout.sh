#!/bin/bash
# 14-layout.sh — §14 顶层布局注册表（委托 scripts/check-layout.sh）。
# 立此节的原因（2026-11-03 项目整理）：根目录条目会随专题自发增长（现 46 项），没有注册表
# 就无法判断「这个目录能不能删、要不要入库」。真源 versions/layout.tsv，人读面见 INDEX.md §2。
. "$(dirname "$0")/_lib.sh"

section '14. 顶层布局注册表（委托 check-layout.sh）'
if [ ! -f "$HELPERS/check-layout.sh" ]; then
  bad "scripts/check-layout.sh 缺失"
else
  if _lo=$(bash "$HELPERS/check-layout.sh" 2>&1); then
    ok "顶层条目全部已登记（$(printf '%s' "$_lo" | grep -o 'entries=[0-9]*' | head -1)）"
  else
    bad "布局注册表不一致：$(printf '%s' "$_lo" | grep '^FAIL' | head -3 | sed 's/^FAIL: //' | tr '\n' ' ')"
  fi
fi
