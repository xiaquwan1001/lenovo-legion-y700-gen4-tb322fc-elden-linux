#!/bin/sh
# q24-dev-keepawake.sh — 实验期间禁止自动熄屏（否则 idle 会把 S1/S2 的「不熄屏」污染）。
. /tmp/q24-dev-sess.sh || exit 1
run_gs set org.gnome.desktop.session idle-delay "uint32 0"
run_gs set org.gnome.desktop.screensaver lock-enabled false
run_gs set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0
run_gs set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 0
echo "idle-delay=$(run_gs get org.gnome.desktop.session idle-delay 2>&1)"
echo "lock-enabled=$(run_gs get org.gnome.desktop.screensaver lock-enabled 2>&1)"
echo "sleep-ac=$(run_gs get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 2>&1)"
echo "dpms=$(cat /sys/class/drm/card0-DSI-1/dpms 2>/dev/null)"
