#!/bin/bash
# q24-pmic-diff.sh A B [C D] -- 比较两份 PMIC dump；给出可选（同 boot 两次 dump）噪声基线做差集
set -uo pipefail
A=$1; B=$2; C=${3:-}; D=${4:-}
for s in 0-00 0-01 0-03 0-05 0-06 0-07 0-08 0-09; do
  [ -f "$A/$s.txt" ] || continue
  [ -f "$B/$s.txt" ] || continue
  diff "$A/$s.txt" "$B/$s.txt" | grep -E "^[<>]" | sed -e "s/^[<>] //" -e "s/:.*//" | sort -u > /tmp/pd_target.txt
  used=0
  if [ -n "$C" ] && [ -n "$D" ] && [ -f "$C/$s.txt" ] && [ -f "$D/$s.txt" ]; then
    diff "$C/$s.txt" "$D/$s.txt" | grep -E "^[<>]" | sed -e "s/^[<>] //" -e "s/:.*//" | sort -u > /tmp/pd_noise.txt
    used=1
  fi
  echo "===== $s  A-vs-B 差异地址 $(grep -c "" /tmp/pd_target.txt) 个 ====="
  echo "--- 按 0x100 块归类 ---"
  cut -c1-3 /tmp/pd_target.txt | sort | uniq -c | sort -rn | head -12
  echo "--- 具体地址与值（前 40）---"
  diff "$A/$s.txt" "$B/$s.txt" | grep -E "^[<>]" | head -60
  if [ "$used" = 1 ]; then
    comm -23 /tmp/pd_target.txt /tmp/pd_noise.txt > /tmp/pd_clean.txt
    echo "--- 扣噪声后差异地址 $(grep -c "" /tmp/pd_clean.txt) 个 ---"
    head -60 /tmp/pd_clean.txt
  fi
done