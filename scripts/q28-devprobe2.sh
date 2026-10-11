#!/bin/sh
# q28-devprobe2.sh — device-side Q28 classification, L1/L2-separated (POSIX sh).
#
# Why v2: the old q28-devprobe.sh collapsed every DPU/DSI error into one
# `storm_sig` count.  That conflates
#   L1 = panel/DSI bring-up actually failed (cmd-DMA timeout, panel init -EIO)
#   L2 = *downstream* DPU errors (ctl reset / frame done / vblank timeouts)
# which also appear transiently on healthy boots, and it says nothing about
# whether a compositor/session actually came up.  Per DOSSIER #164 L2 is a
# consequence of L1, so only L1 is a real Q28 bad boot.
#
# Verdicts:
#   NOCARD   = no /sys/class/drm/card0 (DSI probe never completed)
#   L1FAIL   = card0 present but L1 signatures (panel/DSI init failed)   <- real Q28
#   L2STORM  = card0 + no L1, but L2 DPU errors present                  <- check session
#   GOOD     = card0 + connector connected + session up + L1=0
#   NOROUTE  = card0 present, no connected connector
#
# Prints a machine-readable KEY=VALUE block; callers grep VERDICT.
echo "uname=$(uname -r) uptime=$(cut -d' ' -f1 /proc/uptime)s"
DSIPLL=$(dmesg | grep -c 'DSI PLL(0) lock failed')
DLFAIL=$(dmesg | grep -c 'Failed to create device link')
L1=$(dmesg | grep -Ec 'command DMA timeout|bonded command DMA failed|Failed to initialize panel|sending dcs data .* failed')
L2=$(dmesg | grep -Ec 'ctl [0-9]+ reset failure|frame done timeout|vblank wait timed out|drm_crtc_wait_one_vblank')
HAS=0; for f in /sys/class/drm/card0; do [ -d "$f" ] && HAS=1; done
CONN=""
for d in /sys/class/drm/card0-*; do
  [ -e "$d/status" ] && CONN="$CONN $(basename $d)=$(cat $d/status)"
done
CONNECTED=$(echo "$CONN" | grep -c connected)
PHOC=$(pgrep -xc phoc 2>/dev/null); [ -n "$PHOC" ] || PHOC=0
PHOSH=$(pgrep -xc phosh 2>/dev/null); [ -n "$PHOSH" ] || PHOSH=0
WL=0; [ -e /run/user/1000/wayland-0 ] && WL=1
BL=$(cat /sys/class/backlight/*/brightness 2>/dev/null | head -1)
SESSION=0
[ "$PHOC" -gt 0 ] && SESSION=1
[ "$PHOSH" -gt 0 ] && SESSION=1
[ "$WL" -eq 1 ] && SESSION=1
echo "DSI_PLL_lockfail=$DSIPLL device_link_fail=$DLFAIL card0=$HAS l1=$L1 l2=$L2 storm_sig=$((L1+L2)) session=$SESSION phoc=$PHOC phosh=$PHOSH wayland=$WL backlight=${BL:-none} connected=$CONNECTED"
echo "connectors:$CONN"
if [ "$HAS" -eq 0 ]; then
  echo "VERDICT=NOCARD"
elif [ "$L1" -gt 0 ]; then
  echo "VERDICT=L1FAIL"
elif [ "$CONNECTED" -ge 1 ] && [ "$SESSION" -eq 1 ]; then
  echo "VERDICT=GOOD"
elif [ "$CONNECTED" -ge 1 ] && [ "$SESSION" -eq 0 ]; then
  echo "VERDICT=GOOD-NOSESSION"
elif [ "$L2" -gt 0 ]; then
  echo "VERDICT=L2STORM"
else
  echo "VERDICT=NOROUTE"
fi
