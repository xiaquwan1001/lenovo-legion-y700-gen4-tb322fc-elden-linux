#!/bin/bash
# 19-slotattr-selftest.sh — §19 槽位属性工具自检（委托 slot-attr.py --selftest）
# 立此节的原因（2026-11-18）：`slot-attr.py` 是**恢复设备的唯一止血工具**，而它今天已经出过
# 两次「看着成功其实没做」（--image 只写主表、条目缺失仍 rc=0）。合成 GPT 自检把这三条钉死：
# ① show 能读两槽 ② mark-successful 主备**都**改 ③ 条目缺失必须非零退出。
. "$(dirname "$0")/_lib.sh"

section '19. 槽位属性工具自检（合成 GPT：双表同改 / 缺条目必拒）'
SA="$ROOT/scripts/slot-attr.py"
if [ ! -f "$SA" ]; then
  bad "scripts/slot-attr.py 缺失"
elif _out=$(timeout 120 python3 "$SA" --selftest 2>/dev/null); then
  ok "自检通过（$(printf '%s' "$_out" | tail -1 | sed 's/^== //')）"
else
  bad "自检失败：$(printf '%s' "$_out" | grep 'SELFTEST FAIL' | head -2 | tr '\n' ' ')"
fi
