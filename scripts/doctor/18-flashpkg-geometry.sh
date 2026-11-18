#!/bin/bash
# 18-flashpkg-geometry.sh — §18 线刷包几何自检（委托 scripts/rawprogram-preflight.py）
# 立此节的原因（2026-11-18，LTBox 评估 P0-1..4）：写盘目标几何（LUN/起始扇区/跨度/镜像大小/
# 同 LUN 重叠）在 qdl 里几乎不校验，缺字段会退化成 0、镜像过大会被截断成半件，而退出码照样 0。
# 本节做两件事：① 检查器**自检**（内置坏包必须被抓，防它变成空转）② 仓内已知官方包实跑。
. "$(dirname "$0")/_lib.sh"

section '18. 线刷包几何（rawprogram 预检：字段/越界/重叠/大小/缺件）'
PRE="$HELPERS/rawprogram-preflight.py"
if [ ! -f "$PRE" ]; then
  bad "scripts/rawprogram-preflight.py 缺失"
else
  if _st=$(timeout 120 python3 "$PRE" --selftest 2>&1); then
    ok "检查器自检通过（坏包 4 类全被抓 / 正确包 0 FAIL）"
  else
    bad "检查器自检失败：$(printf '%s' "$_st" | grep 'SELFTEST' | head -2 | tr '\n' ' ')"
  fi
  PKG="$ROOT/backup/official-rom-15.10.259"
  if [ -f "$PKG/rawprogram4.xml" ] && [ -f "$PKG/gpt_main4.bin" ]; then
    if _pf=$(cd "$PKG" && timeout 180 python3 "$PRE" rawprogram4.xml --gpt gpt_main4.bin 2>&1); then
      ok "官方包 rawprogram4（81 节点）几何通过"
    else
      bad "官方包 rawprogram4 几何不通过：$(printf '%s' "$_pf" | grep 'FAIL ' | head -2 | tr '\n' ' ')"
    fi
  else
    ok "仓内无官方包 fixture（跳过实跑）"
  fi
fi
