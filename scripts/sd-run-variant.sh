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
	echo "[run] Linux reachable -> reboot bootloader (eldroid-bootctl)"
	timeout 15 $SSH 'sync; eldroid-bootctl reboot bootloader 2>/dev/null || reboot bootloader' || true
else
	echo "[run] SSH not reachable (already fastboot / other session?)"
fi

# 2) wait for fastboot device
ok=0
for i in $(seq 1 60); do
	if timeout 10 fastboot devices 2>/dev/null | grep -q fastboot; then ok=1; break; fi
	sleep 2
done
[ "$ok" = 1 ] || { echo "[run] ABORT: no fastboot device after 120s"; exit 1; }

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

# 4b) wait for a graphical session (needed for the wlr-randr DPMS trigger)
for i in $(seq 1 30); do
	timeout 8 $SSH 'pidof phosh >/dev/null 2>&1 || pidof phoc >/dev/null 2>&1' && break
	sleep 3
done
echo "[run] pid1=$(timeout 8 $SSH 'ps -o comm= -p 1' 2>/dev/null) phosh=$(timeout 8 $SSH 'pidof phosh' 2>/dev/null) init_mode=$(timeout 8 $SSH 'cat /etc/elden-init-mode 2>/dev/null' 2>/dev/null)"
echo "[run] root=$(timeout 8 $SSH 'findmnt -n -o SOURCE /' 2>/dev/null)"

# 5) run quantitative DPMS test on device
timeout 30 scp -o StrictHostKeyChecking=no -o ConnectTimeout=6 \
	"$ROOT/scripts/g1-22-dpms-test.sh" root@$DEV:/tmp/g1-22-dpms-test.sh >/dev/null 2>&1 || true
echo "[run] --- DPMS test ($CYCLES cycles) ---"
if ! timeout 180 $SSH "sh /tmp/g1-22-dpms-test.sh $CYCLES"; then
	echo "[run] DPMS test string ended early -> possible reset during test"
fi

# 6) watch window for a reset (survive the reboot and confirm via boot_id)
echo "[run] --- watch ${WATCH}s for reset ---"
res="stable"
t=0
while [ "$t" -lt "$WATCH" ]; do
	BID=$(timeout 8 $SSH 'cat /proc/sys/kernel/random/boot_id' 2>/dev/null)
	if [ -n "$BID" ]; then
		if [ "$BID" != "$BOOT_ID0" ]; then res="reset_confirmed(boot_id_changed)"; break; fi
		sleep 2; t=$((t + 2)); continue
	fi
	# SSH gone -> keep waiting for it to come back within the window
echo "[run] SSH lost at t=${t}s — waiting for reboot/return ..."
	for j in $(seq 1 20); do
		sleep 3; t=$((t + 3))
		BID=$(timeout 8 $SSH 'cat /proc/sys/kernel/random/boot_id' 2>/dev/null)
		if [ -n "$BID" ]; then
			if [ "$BID" != "$BOOT_ID0" ]; then res="reset_confirmed(boot_id_changed)"; else res="ssh_blip_returned(same_boot)"; fi
			break
		fi
	done
	[ "$res" != stable ] && break
done
[ "$res" = stable ] && [ -n "$(timeout 8 $SSH 'cat /proc/sys/kernel/random/boot_id' 2>/dev/null)" ] && \
	res="stable(${WATCH}s_no_reset)"
echo "[run] RESULT=$res  variant=$VAR  boot_id0=$BOOT_ID0"
echo "[run] log=$LOG"
