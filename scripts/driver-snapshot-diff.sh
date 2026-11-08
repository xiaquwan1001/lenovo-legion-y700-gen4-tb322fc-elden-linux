#!/bin/bash
# driver-snapshot-diff.sh — 比对两次 driver-snapshot.sh 的输出，按「变了什么」排序输出。
#
# 用法：scripts/driver-snapshot-diff.sh <snapA> <snapB> [--full]
#   默认只打印 summary.tsv 的差异 + 各分节里有差异的行（截断到 200 行/节）
#   --full 打印完整 diff
#
# 退出码：0=完全一致；1=有差异（便于脚本化）
set -uo pipefail
A=${1:?snapA}; B=${2:?snapB}; FULL=0; [ "${3:-}" = "--full" ] && FULL=1
[ -d "$A" ] && [ -d "$B" ] || { echo "给两个快照目录" >&2; exit 2; }

rc=0
echo "=== A: $A"; echo "=== B: $B"; echo

echo "### summary.tsv（逐项对比）"
paste -d'|' \
  <(awk -F'\t' 'NR>1{printf "%s=%s\n",$1,$2}' "$A/summary.tsv" | sort) \
  <(awk -F'\t' 'NR>1{printf "%s=%s\n",$1,$2}' "$B/summary.tsv" | sort) 2>/dev/null \
| awk -F'|' '{
    split($1,a,"="); split($2,b,"=");
    an=a[1]; bn=b[1];
    if (an==bn) { if (a[2]!=b[2]) printf "CHANGED  %-24s A=%-14s B=%s\n", an, a[2], b[2]; }
    else printf "ALIGN??  %-24s A=%-14s B=%s\n", an, a[2], b[2];
  }'
echo

for f in meta power_supply typec usb power_domains display audio_sensor_input net_bt_cam storage_thermal errors; do
  [ -f "$A/$f.txt" ] && [ -f "$B/$f.txt" ] || continue
  if ! diff -q "$A/$f.txt" "$B/$f.txt" >/dev/null 2>&1; then
    rc=1
    echo "### $f.txt 有差异"
    if [ "$FULL" = 1 ]; then
      diff -u "$A/$f.txt" "$B/$f.txt" | sed -n '3,400p'
    else
      diff "$A/$f.txt" "$B/$f.txt" | grep -E '^[<>]' | head -60
    fi
    echo
  fi
done

[ "$rc" = 0 ] && echo "（两份快照完全一致）"
exit "$rc"
