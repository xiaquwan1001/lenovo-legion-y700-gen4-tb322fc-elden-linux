#!/bin/sh
# device-side: clean restart of headless waydroid (avoids pgrep matching the caller)
set -u
stop_all() {
  lxc-stop -P /var/lib/waydroid/lxc -n waydroid -k >/dev/null 2>&1
  sleep 2
  for p in $(pgrep -f 'waydroid session') $(pgrep -f 'waydroid container') $(pgrep -f 'dbus-run-session'); do
    [ "$p" = "$$" ] && continue
    kill -9 "$p" 2>/dev/null
  done
  sleep 2
}
stop_all
mkdir -p /run/user/0; chmod 700 /run/user/0
pgrep -x weston >/dev/null || {
  XDG_RUNTIME_DIR=/run/user/0 setsid weston --backend=headless-backend.so \
    --socket=wayland-0 --idle-time=0 >/tmp/weston.log 2>&1 &
  sleep 4
}
export XDG_RUNTIME_DIR=/run/user/0 WAYLAND_DISPLAY=wayland-0
setsid waydroid container start >/tmp/wdcm.log 2>&1 </dev/null &
sleep 8
setsid dbus-run-session -- waydroid session start >/tmp/wd-session.log 2>&1 </dev/null &
for i in $(seq 1 30); do
  sleep 5
  waydroid status 2>&1 | grep -q 'Container:.*RUNNING' && break
done
waydroid status 2>&1 | head -4
