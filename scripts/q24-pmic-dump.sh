#!/bin/bash
# q24-pmic-dump.sh LABEL -- 把指定 SPMI slave 的 regmap registers 全量 dump 到 logs/q24-pmic-<LABEL>-<ts>/
# 目的：PON/故障寄存器在 PMIC 的常电域里跨重启保持，用「Q24 死后 dump」vs「正常重启后 dump」做差分。
set -uo pipefail
LABEL=$1; [ -z "$LABEL" ] && LABEL=x
OUT=/home/xuqianhui1001/y700-elden/logs/q24-pmic-$LABEL-$(date +%Y%m%d-%H%M%S)
mkdir -p "$OUT"
SSH=(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=6 -o BatchMode=yes root@192.168.7.1)
S(){ timeout "${2:-40}" "${SSH[@]}" "$1" 2>&1; }
S "cut -d. -f1 /proc/uptime; cat /proc/sys/kernel/random/boot_id; uname -r" > "$OUT/env.txt"
for s in 0-00 0-01 0-03 0-05 0-06 0-07 0-08 0-09; do
  S "cat /sys/kernel/debug/regmap/$s/registers" > "$OUT/$s.txt" 2>&1
  echo "$s $(wc -l < "$OUT/$s.txt") 行"
done
echo "OUT=$OUT"