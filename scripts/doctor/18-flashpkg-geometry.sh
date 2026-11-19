#!/bin/bash
# 18-flashpkg-geometry.sh — §18 线刷包几何自检（委托 scripts/rawprogram-preflight.py）
# 立此节的原因（2026-11-18，LTBox 评估 P0-1..4）：写盘目标几何（LUN/起始扇区/跨度/镜像大小/
# 同 LUN 重叠）在 qdl 里几乎不校验，缺字段会退化成 0、镜像过大会被截断成半件，而退出码照样 0。
# 本节做两件事：① 检查器**自检**（内置坏包必须被抓，防它变成空转）② 仓内已知官方包实跑。
. "$(dirname "$0")/_lib.sh"

section '18. 线刷包几何（rawprogram 预检：字段/越界/重叠/大小/缺件/split-super/偏移）'
PRE="$HELPERS/rawprogram-preflight.py"
if [ ! -f "$PRE" ]; then
  bad "scripts/rawprogram-preflight.py 缺失"
else
  if _st=$(timeout 120 python3 "$PRE" --selftest 2>&1); then
    ok "检查器自检通过（内置坏包全被抓：R1 缺字段/R2 越界/R3 重叠/R4 超跨/R5 缺件/R6 split-super 缺片/R7 属性与偏移）"
  else
    bad "检查器自检失败：$(printf '%s' "$_st" | grep 'SELFTEST' | head -2 | tr '\n' ' ')"
  fi
  PKG="$ROOT/backup/official-rom-15.10.259"
  # 2026-11-19：从「只跑 rawprogram4」扩到**整包 6 个 XML + 6 张主表**——只有给全 LUN 的表，
  # `NUM_DISK_SECTORS-5.` 这类表达式才解析得出来（只给 0 号表时 LUN1..5 的 BackupGPT 节点会报
  # 「字段不是整数」，是**真判据**不是假阳性）。整包实跑还能覆盖 split-super 齐备（super_1..8）
  # 与 userdata 缺件豁免（官方包刻意不带 userdata_*）。
  if [ -f "$PKG/rawprogram4.xml" ] && [ -f "$PKG/gpt_main4.bin" ]; then
    _args=""
    for i in 0 1 2 3 4 5; do
      [ -f "$PKG/gpt_main$i.bin" ] && _args="$_args --gpt-for $i=$PKG/gpt_main$i.bin"
    done
    if _pf=$(cd "$PKG" && timeout 180 python3 "$PRE" $_args rawprogram*.xml 2>&1); then
      ok "官方包整包（6 XML / $(printf '%s' "$_pf" | sed -n 's/.*预检：\([0-9]*\) 个 program.*/\1/p' | head -1) 节点 / super 8 片齐备）几何通过"
    else
      bad "官方包整包几何不通过：$(printf '%s' "$_pf" | grep 'FAIL ' | head -2 | tr '\n' ' ')"
    fi
  else
    ok "仓内无官方包 fixture（跳过实跑）"
  fi
fi
