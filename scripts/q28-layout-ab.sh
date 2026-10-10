#!/bin/bash
# q28-layout-ab.sh — 溯源实验设备驱动：固定路径 Linux → reboot2 bootloader → fastboot boot，
# 每个镜像按 SEQ 顺序各跑一轮，q28-devprobe 三态判定，逐轮落 reports/trials 记录。
# 用法：SEQ="oct8 a aa vk64c-repro" bash scripts/q28-layout-ab.sh
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD
TAB=root@192.168.7.1
D=out/q28-layout
SSH="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 $TAB"
S(){ timeout "${2:-25}" $SSH "$1" 2>/dev/null; }
declare -A IMG=( [oct8]="$D/boot-q28-oct8.img" [a]="$D/boot-q28-a.img" [aa]="$D/boot-q28-aa.img" [vk64c-repro]="$D/boot-q28-vk64c-repro.img" )
SEQ=${SEQ:-"oct8 a aa vk64c-repro vk64c-repro aa a oct8"}
echo "[ab] SEQ=$SEQ  $(date -Is)"
i=0
for tag in $SEQ; do
  i=$((i+1))
  img=${IMG[$tag]:-}
  [ -n "$img" ] && [ -e "$img" ] || { echo "[ab] unknown/missing image tag=$tag"; continue; }
  echo "==== run $i tag=$tag img=$img $(date -Is)"
  # 1) 从当前 Linux 暖复位进 bootloader
  S '(sleep 2; reboot2 bootloader) >/dev/null 2>&1 &' || true
  # 2) 等 fastboot
  ok=0; for _ in $(seq 1 18); do fastboot devices 2>/dev/null | grep -q . && { ok=1; break; }; sleep 5; done
  if [ $ok != 1 ]; then echo "[ab] NO-FASTBOOT tag=$tag"; continue; fi
  # 3) fastboot boot（零写盘）
  timeout 180 fastboot boot "$img" 2>&1 | tail -2
  # 4) 等 SSH
  up=0; for _ in $(seq 1 36); do [ "$(S 'echo up' 6)" = up ] && { up=1; break; }; sleep 5; done
  LOGDIR=reports/trials/$(date -u +%Y%m%dT%H%M%SZ)-layout-$tag; mkdir -p "$LOGDIR"
  if [ $up != 1 ]; then echo "[ab] NOROUTE tag=$tag"; 
     bash scripts/trial.sh record --label "layout-$tag" --image "$img" --reset warm \
        --deploy "reboot2+fastboot-boot" --probe q28 --verdict NOROUTE --logdir "$LOGDIR" --note "run$i" >/dev/null
     continue; fi
  S 'uname -a; cut -d" " -f1 /proc/uptime' >"$LOGDIR/env.txt" 2>&1
  S 'dmesg' >"$LOGDIR/dmesg.txt" 2>&1
  timeout 40 $SSH 'sh -s' < scripts/q28-devprobe.sh >"$LOGDIR/probe.txt" 2>&1 || true
  V=$(grep -oE 'VERDICT=[A-Z]+' "$LOGDIR/probe.txt" | head -1 | cut -d= -f2)
  [ -n "$V" ] || V=UNKNOWN
  echo "[ab] tag=$tag VERDICT=$V  | $(grep -E 'drm=\[' "$LOGDIR/probe.txt" | head -1)"
  cat "$LOGDIR/probe.txt" | sed -n '1,4p'
  bash scripts/trial.sh record --label "layout-$tag" --image "$img" --reset warm \
     --deploy "reboot2+fastboot-boot" --probe q28 --verdict "$V" --logdir "$LOGDIR" --note "run$i seq=$SEQ" 2>&1 | grep RECORD
done
echo "[ab] DONE $(date -Is)"
