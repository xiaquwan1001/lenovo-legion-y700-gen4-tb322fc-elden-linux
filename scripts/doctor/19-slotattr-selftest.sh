#!/bin/bash
# 19-slotattr-selftest.sh — §19 槽位属性工具自检（委托 slot-attr.py --selftest）
# 立此节的原因（2026-11-18）：`slot-attr.py` 是**恢复设备的唯一止血工具**，而它今天已经出过
# 两次「看着成功其实没做」（--image 只写主表、条目缺失仍 rc=0）。合成 GPT 自检把这三条钉死：
# ① show 能读两槽 ② mark-successful 主备**都**改 ③ 条目缺失必须非零退出。
. "$(dirname "$0")/_lib.sh"

section '19. 槽位/分区归属工具自检（槽属性双表同改 / 缺条目必拒 / 标签→LUN 归属）'
SA="$ROOT/scripts/slot-attr.py"
if [ ! -f "$SA" ]; then
  bad "scripts/slot-attr.py 缺失"
elif _out=$(timeout 120 python3 "$SA" --selftest 2>/dev/null); then
  ok "自检通过（$(printf '%s' "$_out" | tail -1 | sed 's/^== //')）"
else
  bad "自检失败：$(printf '%s' "$_out" | grep 'SELFTEST FAIL' | head -2 | tr '\n' ' ')"
fi

# 2026-11-19（脚本审查 P1-3）：分区名 → LUN 归属闸。历史事故形态 = 「按名字/默认设备写，写到另一个 LUN」，
# 且 GPT 主备条目缺/歧义时 rc 仍 0。`partlun.py --selftest` 钉四类：唯一解析 / 未知必拒 / 同名歧义必拒 /
# sysfs `target0:0:<lun>` 解析与不一致判定；有 EDL dump 时**还会**核对静态表 == dump 现扫。
PL="$ROOT/scripts/partlun.py"
if [ ! -f "$PL" ]; then
  bad "scripts/partlun.py 缺失（分区名→LUN 归属闸没了）"
elif _out2=$(timeout 120 python3 "$PL" --selftest 2>/dev/null); then
  ok "partlun 自检通过（$(printf '%s' "$_out2" | tail -1 | sed 's/^== //')）"
else
  bad "partlun 自检失败：$(printf '%s' "$_out2" | grep -c '^  FAIL') 项"
fi
