#!/bin/sh
set -u
U=1001; H=/home/xuqianhui1001; DBUS="unix:path=/run/user/1001/bus"
run() { env XDG_RUNTIME_DIR=/run/user/1001 DBUS_SESSION_BUS_ADDRESS=$DBUS WAYLAND_DISPLAY=wayland-0 setpriv --reuid=$U --regid=$U --init-groups "$@"; }
gv() { run gdbus call --session --dest sm.puri.OSK0 --object-path /sm/puri/OSK0 --method org.freedesktop.DBus.Properties.Get sm.puri.OSK0 Visible 2>&1; }
run gdbus call --session --dest sm.puri.OSK0 --object-path /sm/puri/OSK0 --method sm.puri.OSK0.SetVisible false >/dev/null 2>&1
: > /tmp/elden-ime-focusd.log
env XDG_RUNTIME_DIR=/run/user/1001 DBUS_SESSION_BUS_ADDRESS=$DBUS WAYLAND_DISPLAY=wayland-0 \
  GTK_IM_MODULE=fcitx QT_IM_MODULE=fcitx \
  setpriv --reuid=$U --regid=$U --init-groups timeout 12 python3 /home/xuqianhui1001/ime-gtk3-entry.py >/dev/null 2>&1 &
P=$!; sleep 4; echo "focused: $(gv)"; wait $P 2>/dev/null
sleep 2; echo "window closed+2s: $(gv)"
echo "--- focusd log ---"; cat /tmp/elden-ime-focusd.log
echo "--- stevia dbus interface ---"
run gdbus introspect --session --dest sm.puri.OSK0 --object-path /sm/puri/OSK0 2>/dev/null | head -25
run gdbus call --session --dest sm.puri.OSK0 --object-path /sm/puri/OSK0 --method sm.puri.OSK0.SetVisible false >/dev/null 2>&1
