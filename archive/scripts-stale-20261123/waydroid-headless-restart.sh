#!/bin/bash
# Clean restart of the headless Waydroid stack (Q28-bad boots, no compositor).
set -u
T=${TAB:-root@192.168.7.1}
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 $T"
WANT=${1:-1}

timeout 90 $SSH 'lxc-stop -P /var/lib/waydroid/lxc -n waydroid -k >/dev/null 2>&1; sleep 2;
 for p in $(pgrep -f "waydroid (container|session) start"); do kill $p 2>/dev/null; done
 pkill -f "dbus-run-session -- waydroid" 2>/dev/null
 rc-service waydroid-container stop >/dev/null 2>&1
 sleep 2
 lxc-ls -P /var/lib/waydroid/lxc' || true
echo

timeout 60 $SSH 'rc-service waydroid-container start 2>&1 | tail -2; sleep 3; rc-service waydroid-container status 2>&1 | head -2' || true

if [ "$WANT" = 1 ]; then
  timeout 300 $SSH 'export XDG_RUNTIME_DIR=/run/user/0 WAYLAND_DISPLAY=wayland-0
    pgrep -x weston >/dev/null || { nohup weston --backend=headless-backend.so --socket=wayland-0 --idle-time=0 >/tmp/weston.log 2>&1 & sleep 4; }
    nohup dbus-run-session -- waydroid session start >/tmp/wd-session.log 2>&1 &
    sleep 30
    waydroid status 2>&1 | head -4' || true
fi
