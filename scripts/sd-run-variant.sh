#!/bin/bash
# sd-run-variant.sh — boot one sleep-death (熄屏→关机) candidate zero-write and
# collect quantitative evidence.  Host-side driver; device actions are performed
# by this script only when the device is free (another session may hold it).
#
# usage: scripts/sd-run-variant.sh <variant> [cycles]
#   e.g. scripts/sd-run-variant.sh sd-noN2 5
#
# Sequence: (if Linux up) ssh reboot bootloader -> fastboot boot <img> ->
#           wait SSH -> verify uname -r == expected -> run g1-22-dpms-test.sh ->
#           watch for reset (SSH drop / boot_id change).
#
# Every network/step has a timeout; a hard deadline bounds the whole run.
set -u
ROOT=${ROOT:-/home/xuqianhui1001/y700-elden}
DEV=192.168.7.1
VAR=${1:?usage: sd-run-variant.sh <variant> [cycles]}
CYCLES=${2:-5}
IMG=$ROOT/out/boot-elden-$VAR.img
MAN=$ROOT/out/boot-elden-$VAR.manifest
STAMP=$(date +%Y%m%d-%H%M%S)
LOG=$ROOT/logs/sd-$VAR-$STAMP.log
WATCH=${WATCH:-180}          # seconds to watch for a reset after the DPMS test
SSH="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=6 -o BatchMode=yes root@$DEV"

[ -e "$IMG" ] || { echo "no image $IMG" >&2; exit 2; }
[ -e "$MAN" ] || { echo "no manifest $MAN" >&2; exit 2; }
EXP_UTS=$(grep -h '^kernel_uts=' "$MAN" | sed 's/kernel_uts=Linux version //; s/ (elden@y700//')
echo "variant=$VAR image=$IMG expected_uts=$EXP_UTS log=$LOG"
exec > >(tee -a "$LOG") 2>&1

# 1) switch to bootloader (only if currently in Linux)
if timeout 12 $SSH 'true' 2>/dev/null; then
	echo "[run] Linux reachable -> reboot bootloader"
	timeout 15 $SSH 'sync; reboot bootloader' || true
else
	echo "[run] SSH not reachable (already fastboot / other session?)"
fi

# 2) wait for fastboot device
ok=0
for i in $(seq 1 40); do
	if timeout 10 fastboot devices 2>/dev/null | grep -q fastboot; then ok=1; break; fi
	sleep 2
done
[ "$ok" = 1 ] || { echo "[run] ABORT: no fastboot device after 80s"; exit 1; }

# 3) zero-write boot
echo "[run] fastboot boot $IMG"
timeout 120 fastboot boot "$IMG" || { echo "[run] fastboot boot failed"; exit 1; }

# 4) wait for SSH
ok=0
for i in $(seq 1 60); do
	if timeout 8 $SSH 'true' 2>/dev/null; then ok=1; break; fi
	sleep 2
done
[ "$ok" = 1 ] || { echo "[run] ABORT: SSH never came up (boot failed / reset loop?)"; exit 1; }

GOT_UTS=$(timeout 10 $SSH 'uname -r' 2>/dev/null)
echo "[run] running kernel: $GOT_UTS"
if [ "$GOT_UTS" != "$EXP_UTS" ]; then
	echo "[run] WARNING: UTS mismatch (expected $EXP_UTS) — candidate did NOT boot; result invalid"
fi
BOOT_ID0=$(timeout 10 $SSH 'cat /proc/sys/kernel/random/boot_id' 2>/dev/null)
echo "[run] boot_id=$BOOT_ID0"

# 5) run quantitative DPMS test on device
timeout 30 scp -o StrictHostKeyChecking=no -o ConnectTimeout=6 \
	"$ROOT/scripts/g1-22-dpms-test.sh" root@$DEV:/tmp/g1-22-dpms-test.sh >/dev/null 2>&1 || true
echo "[run] --- DPMS test ($CYCLES cycles) ---"
if ! timeout 180 $SSH "sh /tmp/g1-22-dpms-test.sh $CYCLES"; then
	echo "[run] DPMS test string ended early -> possible reset during test"
fi

# 6) watch window for a reset
echo "[run] --- watch ${WATCH}s for reset ---"
res="stable"
for i in $(seq 1 "$WATCH"); do
	u=$(timeout 8 $SSH 'cut -d" " -f1 /proc/uptime' 2>/dev/null)
	if [ -z "$u" ]; then
		sleep 3
		u=$(timeout 8 $SSH 'cut -d" " -f1 /proc/uptime' 2>/dev/null)
		[ -z "$u" ] && { res="ssh_lost"; break; }
	fi
	sleep 1
done
if [ "$res" = stable ]; then
	BID=$(timeout 10 $SSH 'cat /proc/sys/kernel/random/boot_id' 2>/dev/null)
	[ "$BID" != "$BOOT_ID0" ] && res="reset(boot_id changed)"
	# uptime must not jump backwards
fi
echo "[run] RESULT=$res  variant=$VAR  boot_id0=$BOOT_ID0"
echo "[run] log=$LOG"
