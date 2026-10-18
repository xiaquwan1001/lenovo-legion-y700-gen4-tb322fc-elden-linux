#!/bin/bash
# waydroid-cam-restart.sh — restart the headless Waydroid stack after a vendor.img swap.
# Uses the bracket trick so pgrep/pkill never match this script's own command line.
set -u
T=${TAB:-root@192.168.7.1}
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 $T"

timeout 120 $SSH 'lxc-stop -P /var/lib/waydroid/lxc -n waydroid -k >/dev/null 2>&1
  for p in $(pgrep -f "waydroid sess[i]on start") $(pgrep -f "waydroid containe[r] start") $(pgrep -f "dbus-run-sessio[n] -- waydroid"); do kill -9 $p 2>/dev/null; done
  sleep 2; lxc-ls -P /var/lib/waydroid/lxc 2>/dev/null' || true

timeout 60 $SSH 'mkdir -p /run/user/0; chmod 700 /run/user/0
  pgrep -x weston >/dev/null || (XDG_RUNTIME_DIR=/run/user/0 nohup weston --backend=headless-backend.so --socket=wayland-0 --idle-time=0 >/tmp/weston.log 2>&1 & sleep 4)
  nohup waydroid container start >/tmp/wdcm.log 2>&1 &
  sleep 6' || true

timeout 240 $SSH 'export XDG_RUNTIME_DIR=/run/user/0 WAYLAND_DISPLAY=wayland-0
  nohup dbus-run-session -- waydroid session start >/tmp/wd-session.log 2>&1 &
  for i in $(seq 1 40); do sleep 5; out=$(waydroid status 2>&1 | head -3); echo "$out" | grep -q "Container:.*RUNNING" && break; done
  echo "$out"' || true
