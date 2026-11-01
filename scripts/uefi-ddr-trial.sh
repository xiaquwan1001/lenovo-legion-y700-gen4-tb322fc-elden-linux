#!/bin/bash
# uefi-ddr-trial.sh — DDR 黑匣子专用上机循环（多条重复，只统计真正交棒的发次）
#
# 背景（2026-11-01 实测）：本机 ABL 对 `fastboot boot` 的接受/拒绝**非确定性** —— 同一份
# 镜像同 header 连续三次分别给出「交棒(HANDOFF)」「拒绝(NOJUMP)」「Invalid Parameter」。
# 所以判据必须是「重复 N 发 + 只认 HANDOFF 那几发」，不能拿单发下结论。
#
# 前置（人工/一次）：slot a 标 unbootable（`qbootctl -u a`）⇒ 崩后 ABL 不启 stock Android，
#   停在 fastboot（否则 Android 会在我们读之前把候选 DDR 窗口清零/覆盖）。
#   恢复兜底：`qbootctl -m a`。
#
# 用法：scripts/uefi-ddr-trial.sh --image <img> --label <L> [--shots 3] [--windows "0xFEF00000 0x89300000"]
# 每发流程：prep 窗口 → reboot bootloader → fastboot boot → 判定 → （HANDOFF）等 fastboot
#           → --set-active=b → reboot → 等 ssh → 读窗口。
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT"
TAB=${TAB:-root@192.168.7.1}
SSH="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=6 -o BatchMode=yes -o UserKnownHostsFile=/dev/null $TAB"
IMG=""; LABEL="ddr"; SHOTS=3; WINDOWS="0xFEF00000 0x89300000"; OUT=reports/artifacts/uefi-ddr-$(date +%Y%m%d-%H%M%S)
while [ $# -gt 0 ]; do case "$1" in
  --image) IMG=$2; shift 2;; --label) LABEL=$2; shift 2;; --shots) SHOTS=$2; shift 2;;
  --windows) WINDOWS=$2; shift 2;; --out) OUT=$2; shift 2;; *) echo "bad arg $1" >&2; exit 2;; esac; done
[ -f "$IMG" ] || { echo "no image: $IMG" >&2; exit 2; }
mkdir -p "$OUT"; echo "label=$LABEL image=$IMG sha=$(sha256sum "$IMG" | cut -c1-16) out=$OUT" | tee "$OUT/summary.txt"

wait_fb() { for i in $(seq 1 40); do timeout 5 fastboot devices 2>/dev/null | grep -q . && return 0; sleep 3; done; return 1; }
wait_ssh() { for i in $(seq 1 30); do timeout 6 $SSH true 2>/dev/null && return 0; sleep 5; done; return 1; }

handoff=0
for n in $(seq 1 "$SHOTS"); do
  echo "--- shot $n/$SHOTS ---" | tee -a "$OUT/summary.txt"
  if ! wait_ssh; then echo "  [skip] ssh 不在（设备不在 Linux）" | tee -a "$OUT/summary.txt"; continue; fi
  for pa in $WINDOWS; do python3 scripts/blackbox.py prep --pa "$pa" >/dev/null 2>&1; done
  timeout 30 $SSH 'nohup eldroid-bootctl reboot bootloader >/dev/null 2>&1 & true' >/dev/null 2>&1
  sleep 12; wait_fb || { echo "  [fail] fastboot 没起来（PITFALLS #368，需要物理断电）" | tee -a "$OUT/summary.txt"; break; }
  bt=$(timeout 120 fastboot boot "$IMG" 2>&1 | tr '\n' ' ')
  case "$bt" in
    *usb_read*|*"FAILED (usb_read failed"*) v=HANDOFF;; *"Booting "OKAY*) v=NOJUMP;; *) v=REJECT;; esac
  echo "  verdict=$v  abl='$(echo "$bt" | cut -c1-120)'" | tee -a "$OUT/summary.txt"
  if [ "$v" = HANDOFF ]; then
    handoff=$((handoff+1))
    if wait_fb; then
      timeout 20 fastboot --set-active=b >/dev/null 2>&1
      timeout 20 fastboot reboot >/dev/null 2>&1
      if wait_ssh; then
        for pa in $WINDOWS; do
          echo "  read $pa:" | tee -a "$OUT/summary.txt"
          python3 scripts/blackbox.py read --pa "$pa" 2>&1 | sed -n '2,8p' | sed 's/^/    /' | tee -a "$OUT/summary.txt"
        done
      else echo "  [fail] 回 Linux 超时" | tee -a "$OUT/summary.txt"; fi
    else echo "  [warn] 崩后没等到 fastboot" | tee -a "$OUT/summary.txt"; fi
  else
    # 未交棒：设备还在 fastboot，直接恢复
    timeout 20 fastboot --set-active=b >/dev/null 2>&1; timeout 20 fastboot reboot >/dev/null 2>&1
    wait_ssh || echo "  [fail] 回 Linux 超时" | tee -a "$OUT/summary.txt"
  fi
  sleep 12      # 拉开与下一次 reboot2 的间隔，避开 #368
done
echo "== 真正交棒 $handoff/$SHOTS 发 ==" | tee -a "$OUT/summary.txt"
