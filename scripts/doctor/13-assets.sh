#!/bin/bash
# 13-assets.sh — §13 文档引用的资产路径存在性（委托 scripts/check-doc-assets.sh）。
# 立此节的原因（2026-10-27）：三条 lane 的产物提交在各自 worktree 分支上，主仓 main 只落了
# 收口总结 ⇒ TASKS/README.md §7 引用的路径在主仓不存在，下个会话按路径找不到就会重做一遍。
# §8 只查「报告是否被引用」，不查「被引用的路径是否存在」，本节补的正是后半句。
. "$(dirname "$0")/_lib.sh"

section '13. 文档引用的资产路径（委托 check-doc-assets.sh）'
if [ ! -f "$HELPERS/check-doc-assets.sh" ]; then
  bad "scripts/check-doc-assets.sh 缺失"
else
  if _da=$(bash "$HELPERS/check-doc-assets.sh" 2>&1); then
    ok "文档资产路径齐全（$(printf '%s' "$_da" | grep -o 'checked=[0-9]*' | head -1)）"
  else
    bad "文档引用了不存在的路径：$(printf '%s' "$_da" | grep '^MISSING' | head -3 | awk '{print $2}' | tr '\n' ' ')"
  fi
fi
