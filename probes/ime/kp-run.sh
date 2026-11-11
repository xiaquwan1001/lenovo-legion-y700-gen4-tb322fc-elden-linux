#!/bin/sh
set -u
U=1001
DBUS="unix:path=/run/user/1001/bus"
envs="XDG_RUNTIME_DIR=/run/user/1001 DBUS_SESSION_BUS_ADDRESS=$DBUS WAYLAND_DISPLAY=wayland-0 GTK_IM_MODULE=fcitx QT_IM_MODULE=fcitx"
env $envs setpriv --reuid=$U --regid=$U --init-groups python3 /tmp/kimpanel-probe.py 25 > /tmp/kp.log 2>&1 &
sleep 5
echo "=== owner of org.kde.impanel ==="; env XDG_RUNTIME_DIR=/run/user/1001 DBUS_SESSION_BUS_ADDRESS=$DBUS setpriv --reuid=$U --regid=$U --init-groups busctl --user list 2>/dev/null | grep -i impanel
echo "=== focus GTK3 entry (fcitx arm) ==="
env $envs setpriv --reuid=$U --regid=$U --init-groups timeout 9 python3 /home/xuqianhui1001/ime-gtk3-entry.py >/dev/null 2>&1
sleep 3
echo "=== kimpanel calls seen by stub ==="; cat /tmp/kp.log
