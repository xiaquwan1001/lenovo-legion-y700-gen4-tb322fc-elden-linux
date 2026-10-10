#!/bin/bash
# q28-ab-delay.sh — 同一时间窗内对 base(delay=0) vs exp(delay=1000) 各跑 N 轮，
# 统计 Q28 坏发率，判定 "命令 DMA 前插 settle delay 能否压制 Q28"。
# 复用 q28-boot-cycle.sh 的 GOOD/BAD 判据（command DMA timeout / panel init fail / dpms off）。
# 纪律：每轮 RAM 直启（fastboot boot）不扣槽位；结束 fastboot reboot 回 boot_b。
set -uo pipefail
cd "$(dirname "$0")/.."
N=${1:-4}
BASE=out/boot-elden-vk84-q28delay-base.img
EXP=out/boot-elden-vk84-q28delay-exp.img
RUNLOG=logs/q28-ab-$(date +%Y%m%d-%H%M%S).log
mkdir -p logs
exec > >(tee -a "$RUNLOG") 2>&1
echo "### q28-ab-delay start $(date '+%F %T') N=$N base=$BASE exp=$EXP"

run_arm() { # $1=img $2=label $3=n
  local img=$1 label=$2 n=$3 good=0 bad=0 env=0 i v
  for i in $(seq 1 "$n"); do
    echo "----- [$label] cycle $i/$n $(date '+%T') -----"
    timeout -k 15 300 bash scripts/q28-boot-cycle.sh "$img" "$label-$i"; rc=$?
    case $rc in
      0) good=$((good+1)); echo "[$label $i] GOOD";;
      10) bad=$((bad+1)); echo "[$label $i] BAD(Q28)";;
      *) env=$((env+1)); echo "[$label $i] ENV-ERR rc=$rc";;
    esac
  done
  echo "RESULT[$label] good=$good bad=$bad env=$env of $n"
  eval "$label"_GOOD=$good "$label"_BAD=$bad "$label"_ENV=$env
}

# 交替跑，让温度/充电等时间相关因素在两组间均摊（控制混淆）
run_arm "$BASE" BASE "$N"
run_arm "$EXP"  EXP  "$N"

echo
echo "### SUMMARY $(date '+%F %T')"
echo "BASE(delay0): good=$BASE_GOOD bad=$BASE_BAD env=$BASE_ENV / $N"
echo "EXP (delay1000): good=$EXP_GOOD bad=$EXP_BAD env=$EXP_ENV / $N"
# 收尾：回持久 boot_b（vk64），交回日常态
if fastboot devices 2>/dev/null | grep -q HA2EXB0E; then
  echo "### restoring boot_b: fastboot reboot"
  timeout 30 fastboot reboot 2>&1 | tail -1
fi
echo "### q28-ab-delay done"
