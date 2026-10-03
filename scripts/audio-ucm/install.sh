#!/bin/sh
# install.sh — deploy the ALSA UCM2 config for Lenovo-Y700-Gen4 (TB322FC/elden).
#
# Without it, ACP/WirePlumber sees the card but cannot create a Speaker sink
# (only "Dummy Output" / "Pro Audio"), because the machine driver advertises no
# usable port.  The UCM defines a HiFi verb + "Speaker" device that also turns
# on the Secondary MI2S route (numid 8) and lifts the AW88461 gains from their
# default-muted value.
#
# Idempotent; call from start-desktop.sh before the session (and thus before
# PipeWire's XDG autostart) starts.  A rebuilt rootfs needs this again.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
UCM=/usr/share/alsa/ucm2
mkdir -p "$UCM/Qualcomm/sm8750/Lenovo-Y700-Gen4" "$UCM/conf.d/sm8750"
cp "$HERE/HiFi.conf"                "$UCM/Qualcomm/sm8750/Lenovo-Y700-Gen4/HiFi.conf"
cp "$HERE/Lenovo-Y700-Gen4.conf"    "$UCM/conf.d/sm8750/Lenovo-Y700-Gen4.conf"
echo "[audio-ucm] installed UCM for Lenovo-Y700-Gen4"
