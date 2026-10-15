#!/bin/sh
# q24-dev-snap.sh — 单次快照（genpd/state_synced/模块/风暴计数）。 $1 = 标签
L=${1:-snap}
echo "### $L uptime=$(cut -d. -f1 /proc/uptime) bootid=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null)"
for a in ade0000 1760000; do
  p=/sys/devices/platform/soc@0/$a.clock-controller
  drv=$(basename "$(readlink -f "$p/driver" 2>/dev/null)" 2>/dev/null)
  echo "    dev $a driver=$drv state_synced=$(cat "$p/state_synced" 2>/dev/null)"
done
for g in mx mmcx mxc cx; do echo "    genpd $g = $(cat /sys/kernel/debug/pm_genpd/$g/current_state 2>/dev/null)"; done
echo "    lsmod-cam: $(lsmod | awk 'NR>1{print $1}' | grep -E 'camcc|cambist' | tr '\n' ' ')"
echo "    dpms=$(cat /sys/class/drm/card0-DSI-1/dpms 2>/dev/null) storm=$(dmesg | grep -c 'drm_crtc_wait_one_vblank') dpuwait=$(dmesg | grep -c 'wait for commit done returned -110') gmu=$(dmesg | grep -c 'a6xx_gmu_set_oob')"
echo "    phoc=$(pgrep -xc phoc 2>/dev/null) phosh=$(pgrep -xc phosh 2>/dev/null) gsdsaver=$(pgrep -xc gsd-screensaver 2>/dev/null)"
