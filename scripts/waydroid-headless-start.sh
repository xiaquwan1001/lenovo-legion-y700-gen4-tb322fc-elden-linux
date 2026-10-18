#!/bin/bash
# Start Waydroid headless: headless weston + waydroid session + container.
# For Q28-bad boots where no compositor/display is available.
set -u
T=${TAB:-root@192.168.7.1}
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 $T"

timeout 60 $SSH 'pkill -x weston 2>/dev/null; mkdir -p /run/user/0; chmod 700 /run/user/0; true' || true

timeout 60 $SSH 'XDG_RUNTIME_DIR=/run/user/0 nohup weston --backend=headless-backend.so --socket=wayland-0 --idle-time=0 >/tmp/weston.log 2>&1 & sleep 4; ls /run/user/0/ | tr "\n" " "' || true
echo

timeout 90 $SSH 'export XDG_RUNTIME_DIR=/run/user/0 WAYLAND_DISPLAY=wayland-0; nohup dbus-run-session -- waydroid session start >/tmp/wd-session2.log 2>&1 & sleep 30; waydroid status 2>&1 | head -4; echo ---; tail -6 /tmp/wd-session2.log' || true
