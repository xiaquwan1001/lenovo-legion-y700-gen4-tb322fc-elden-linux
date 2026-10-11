#!/bin/bash
# q28-cold-run.sh — one cold-POR Q28 sample: assume the DEVICE IS ALREADY IN
# FASTBOOT (user did a physical POR + Vol-/+Power), `fastboot boot` the image,
# then capture three-state display verdict + survival gate.
#
# usage: scripts/q28-cold-run.sh <boot.img> [label]
# verdict: NOCARD | STORM | GOOD | GOOD-NOSURVIVE | NOROUTE | FAIL
# Discipline:
#   * cold path == real POR (PITFALLS #163/#164); never run this over a warm reset
#   * three-state + card0 hard gate (#165/#167)
#   * survival gate >=60s interactive (#172) — a clean-GOOD boot may freeze
#   * one record per sample written via scripts/trial.sh record
set -uo pipefail
ROOT=/home/xuqianhui1001/y700-elden
cd "$ROOT"
IMG=${1:?usage: q28-cold-run.sh <boot.img> [label]}
LABEL=${2:-$(basename "$IMG" .img)}
TAB=root@192.168.7.1
SSH="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=6 -b 0"
OUT=$ROOT/logs/q28-cold-$(date +%Y%m%d-%H%M%S)-$LABEL
mkdir -p "$OUT"
S() { timeout "${2:-25}" $SSH "$TAB" "$1" 2>/dev/null; }

echo "[cold] IMG=$IMG LABEL=$LABEL OUT=$OUT"

# --- 0) must already be in fastboot ---------------------------------------
if ! fastboot devices 2>/dev/null | grep -q .; then
	echo "[cold] ❌ 设备不在 fastboot。请先物理断电冷起，按住 Vol- + 电源 进 fastboot。" >&2
	exit 2
fi
fastboot devices | tee "$OUT/fastboot-before.txt"

# --- 1) boot ---------------------------------------------------------------
echo "[cold] fastboot boot $IMG"
timeout 180 fastboot boot "$IMG" 2>&1 | tail -4 | tee "$OUT/fastboot-boot.log"

# --- 2) wait for SSH -------------------------------------------------------
up=0
for i in $(seq 1 30); do
	[ "$(S 'echo up' 6)" = up ] && { up=1; echo "[cold] ssh up after $((i*5))s"; break; }
	sleep 5
done
if [ "$up" != 1 ]; then
	S 'echo up' 6 >"$OUT/no-ssh.txt" 2>&1
	bash scripts/trial.sh record --label "$LABEL" --image "$IMG" --reset por \
		--deploy "fastboot boot (cold fb after user POR)" --probe q28 \
		--verdict NOROUTE --logdir "$OUT" --note "no SSH within 150s" >/dev/null 2>&1 || true
	echo "VERDICT=NOROUTE"; exit 10
fi

# --- 3) forensic capture ---------------------------------------------------
S 'uname -a; echo ---; cat /proc/uptime; echo ---; cat /proc/cmdline' >"$OUT/env.txt" 2>&1
S 'dmesg' >"$OUT/dmesg.txt" 2>&1
S 'ls /sys/class/drm/; echo ---; for d in /sys/class/drm/card0-*; do [ -e "$d/status" ] && echo "$(basename $d) status=$(cat $d/status) dpms=$(cat $d/dpms 2>/dev/null)"; done; echo "phoc=$(pgrep -xc phoc) phosh=$(pgrep -xc phosh)"; echo "bright=$(cat /sys/class/backlight/*/brightness 2>/dev/null)"' >"$OUT/drm.txt" 2>&1
# prefer the L1/L2-separated v2 judge; fall back to v1 if absent
PROBE=scripts/q28-devprobe2.sh
[ -f "$PROBE" ] || PROBE=scripts/q28-devprobe.sh
$SSH "$TAB" 'sh -s' < "$PROBE" >"$OUT/probe.txt" 2>&1 || true
grep -oE 'l1=[0-9]+ l2=[0-9]+' "$OUT/probe.txt" >"$OUT/l1l2.txt" 2>/dev/null || true
V=$(grep -oE 'VERDICT=[A-Z]+' "$OUT/probe.txt" | head -1 | cut -d= -f2); V=${V:-UNKNOWN}

# --- 4) survival gate (>=60s interactive) ----------------------------------
echo "[cold] VERDICT(display)=$V ; survival gate 65s ..."
sleep 65
ALIVE=$(S 'echo alive; uptime' 10)
if printf '%s' "$ALIVE" | grep -q alive; then
	echo "$ALIVE" >"$OUT/survive.txt"
	S 'dmesg | tail -30' >"$OUT/dmesg-after65.txt" 2>&1
	if [ "$V" = GOOD ]; then V=GOOD; else :; fi
else
	echo "no ssh after 65s (froze/collapsed)" >"$OUT/survive.txt"
	[ "$V" = GOOD ] && V=GOOD-NOSURVIVE
fi

echo "VERDICT=$V"
bash scripts/trial.sh record --label "$LABEL" --image "$IMG" --reset por \
	--deploy "fastboot boot (cold fb after user POR)" --probe q28 \
	--verdict "$V" --logdir "$OUT" --note "cold POR; survival gate 65s; see logs" 2>/dev/null \
	|| echo "[cold] (record skipped)"
echo "[cold] logs -> $OUT"
