#!/bin/sh
# Restart Waydroid container+session inside the running Phosh/Wayland session.
export XDG_RUNTIME_DIR=/run/phosh WAYLAND_DISPLAY=wayland-0 HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
waydroid session stop  >/dev/null 2>&1
waydroid container stop >/dev/null 2>&1
sleep 2
pgrep -f "waydroid container start" >/dev/null 2>&1 || setsid waydroid container start >/var/log/wd-container.log 2>&1 < /dev/null &
sleep 5
PHOC=$(pidof phoc | awk '{print $1}')
BUS=$(tr '\0' '\n' < /proc/$PHOC/environ | grep ^DBUS_SESSION_BUS_ADDRESS= | cut -d= -f2-)
DBUS_SESSION_BUS_ADDRESS="$BUS" setsid sh /usr/local/sbin/waydroid-session.sh >/var/log/wd-session.log 2>&1 < /dev/null &
sleep 50
echo "session log:"; tail -3 /var/log/wd-session.log
timeout 10 waydroid status 2>&1 | head -4
