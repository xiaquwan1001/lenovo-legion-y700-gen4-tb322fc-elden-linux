#!/bin/sh
# q24-dev-blank.sh — 真实熄屏/唤醒 + 硬门读数（PITFALLS #198）。 $1 = true|false
set -u
case "${1:-true}" in on|true|1) V=true;; off|false|0) V=false;; *) V=$1;; esac
. /tmp/q24-dev-sess.sh || exit 1
ga(){ run_gdbus GetActive 2>&1; }
dp(){ cat /sys/class/drm/card0-DSI-1/dpms 2>/dev/null; }
bp(){ cat /sys/class/backlight/*/bl_power 2>/dev/null | head -1; }
br(){ cat /sys/class/backlight/*/brightness 2>/dev/null | head -1; }
echo "GATE_BEFORE active=$(ga) dpms=$(dp) bl_power=$(bp) bright=$(br)"
echo "SETACTIVE_$V=$(run_gdbus SetActive "$V" 2>&1)"
sleep 3
echo "GATE_AFTER3 active=$(ga) dpms=$(dp) bl_power=$(bp) bright=$(br)"
sleep 2
echo "GATE_AFTER5 active=$(ga) dpms=$(dp) bl_power=$(bp) bright=$(br)"
