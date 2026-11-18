#!/bin/bash
# 17-shell-hygiene.sh — §17 设备命令静态卫生（委托 scripts/check-shell-hygiene.py）。
# 立此节的原因（2026-11-18）：四板块脚本审查里同一类缺陷（无 timeout / 缺 BatchMode /
# fastboot 输出进管道 / pkill -f 裸字面量 / 管道后取 $?）在 20+ 脚本里重复出现，且每次都靠人工
# 复读才发现。本节把它变成硬门：命中未豁免 = FAIL；豁免必须写进
# versions/shell-hygiene-baseline.txt 并附理由。
. "$(dirname "$0")/_lib.sh"

section '17. 设备命令静态卫生（timeout/BatchMode/管道/pkill）'
if [ ! -f "$HELPERS/check-shell-hygiene.py" ]; then
  bad "scripts/check-shell-hygiene.py 缺失"
elif _hy=$(timeout 120 python3 "$HELPERS/check-shell-hygiene.py" --verbose 2>&1); then
  _n=$(printf '%s' "$_hy" | grep -o '未豁免合计 [0-9]*' | grep -o '[0-9]*')
  ok "无未豁免命中（豁免 $(grep -vc '^#\|^$' "$ROOT/versions/shell-hygiene-baseline.txt" 2>/dev/null || echo 0) 条已登记）"
else
  bad "未豁免的设备命令卫生命中：$(printf '%s' "$_hy" | grep '^    ' | head -3 | awk -F: '{print $1":"$2}' | tr '\n' ' ')"
fi
