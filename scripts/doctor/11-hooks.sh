#!/bin/bash
# 11-hooks.sh — §11 提交钩子生效性（hooksPath 必须指向 .githooks）。
# 立此节的原因（2026-10-19 实测）：.githooks/{pre-commit,commit-msg} 早就写好、文档也一直
# 声称门会跑，但 `git config core.hooksPath` 是空的、.git/hooks/pre-commit 不存在
# ⇒ **两个钩子从未执行过一次**。「文档承诺了一个不存在的门」只能靠机器对账发现。
. "$(dirname "$0")/_lib.sh"

section '11. 提交钩子生效性（hooksPath 必须指向 .githooks）'
_hp=$(git config --get core.hooksPath || true)
if [ "$_hp" = ".githooks" ]; then
  ok "core.hooksPath = .githooks"
else
  bad "core.hooksPath='${_hp}' → 钩子未生效（跑一次 git config core.hooksPath .githooks）"
fi
for _h in pre-commit commit-msg; do
  if [ -x ".githooks/$_h" ]; then ok ".githooks/$_h 可执行"; else bad ".githooks/$_h 缺失或不可执行"; fi
done
