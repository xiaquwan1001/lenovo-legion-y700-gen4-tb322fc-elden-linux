#!/bin/bash
# q28-layout-one.sh <tag> — 单发实验：设备在 fastboot 则直接 fastboot boot；在 Linux 则 reboot2 进
# fastboot 再 boot。等 SSH→q28-devprobe 三态判定→落 trial 记录。HANG/NOROUTE 一律如实记录并退出非 0。
set -uo pipefail
cd "$(dirname "$0")/.."
TAG=${1:?usage: q28-layout-one.sh <tag>}
D=out/q28-layout
TAB=root@192.168.7.1
SSH="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 $TAB"
S(){ timeout "${2:-25}" $SSH "$1" 2>/dev/null; }
# 复位/进 fastboot 前的系统就绪门（防未就绪即 reboot2 → 无 USB 通道挂机）
. "$(dirname "$0")/lib-boot-ready.sh"
case "$TAG" in
  oct8) IMG=$D/boot-q28-oct8.img; KPAY=8efb2731 ;;
  a)    IMG=$D/boot-q28-a.img;    KPAY=? ;;
  aa)   IMG=$D/boot-q28-aa.img;   KPAY=? ;;
  vk64c-repro) IMG=$D/boot-q28-vk64c-repro.img; KPAY=? ;;
  *) echo "unknown tag $TAG"; exit 2 ;;
esac
[ -e "$IMG" ] || { echo "missing $IMG"; exit 2; }

if ! timeout 8 fastboot devices 2>/dev/null | grep -q .; then
  if [ "$(S 'echo up')" = up ]; then
    echo "[one] 设备在 Linux，reboot2 bootloader…"
    boot_ready_or_die
    S '(sleep 2; reboot2 bootloader) >/dev/null 2>&1 &' || true
    ok=0; for _ in $(seq 1 18); do timeout 8 fastboot devices 2>/dev/null | grep -q . && { ok=1; break; }; sleep 5; done
    [ $ok = 1 ] || { echo "[one] NO-FASTBOOT（设备可能已挂）"; exit 3; }
  else
    echo "[one] 设备既不在 fastboot 也不可达 → 挂死，需物理恢复"; exit 3
  fi
fi

echo "[one] fastboot boot $IMG ($TAG)"
timeout 180 fastboot boot "$IMG" 2>&1 | tail -2
up=0; for _ in $(seq 1 30); do [ "$(S 'echo up' 6)" = up ] && { up=1; break; }; sleep 5; done
LOG=reports/trials/$(date -u +%Y%m%dT%H%M%SZ)-layout-$TAG; mkdir -p "$LOG"
if [ $up != 1 ]; then
  echo "[one] NOROUTE/HANG tag=$TAG（150s 无 SSH）"
  echo "no SSH within 150s; device may be hung (see logs/q28-layout-ab.log precedent)" > "$LOG/README.txt"
  bash scripts/trial.sh record --label "layout-$TAG" --image "$IMG" --reset warm \
     --deploy "fastboot-boot" --probe q28 --verdict HANG --logdir "$LOG" \
     --note "kernel_payload_sha=$KPAY; no SSH 150s (HANG or boot fail)" 2>&1 | tail -2
  exit 4
fi
S 'uname -a; cut -d" " -f1 /proc/uptime' >"$LOG/env.txt" 2>&1
S 'dmesg' >"$LOG/dmesg.txt" 2>&1
timeout 40 $SSH 'sh -s' < scripts/q28-devprobe.sh >"$LOG/probe.txt" 2>&1 || true
V=$(grep -oE 'VERDICT=[A-Z]+' "$LOG/probe.txt" | head -1 | cut -d= -f2); [ -n "$V" ] || V=UNKNOWN
echo "[one] tag=$TAG VERDICT=$V"
sed -n '1,4p' "$LOG/probe.txt"
bash scripts/trial.sh record --label "layout-$TAG" --image "$IMG" --reset warm \
   --deploy "fastboot-boot" --probe q28 --verdict "$V" --logdir "$LOG" --note "kernel_payload_sha=$KPAY" 2>&1 | grep -E 'RECORD|VERDICT'
