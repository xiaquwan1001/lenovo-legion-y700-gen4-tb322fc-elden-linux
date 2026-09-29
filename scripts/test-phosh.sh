#!/bin/sh
# Run Phosh on the DRM panel for on-device verification, replacing the weston loop.
# Launched over ssh; keeps running in background. Log -> /run/phosh.log
set -u

# 1) stop weston loop / weston / any previous phosh attempt
pkill -x start-desktop.sh 2>/dev/null
pkill -x weston 2>/dev/null
pkill -x weston-terminal 2>/dev/null
pkill -x weston-keyboard 2>/dev/null
pkill -x weston-desktop-shell 2>/dev/null
pkill -x phoc 2>/dev/null
pkill -x phosh 2>/dev/null
pkill -f 'gnome-session-binary' 2>/dev/null
pkill -f 'dbus-run-session' 2>/dev/null
sleep 2

# 2) udev (libinput needs it to see the touchscreen)
mkdir -p /run/udev
/sbin/udevd --daemon 2>/dev/null || true
sleep 1
/sbin/udevadm trigger --action=add 2>/dev/null || true
/sbin/udevadm settle --timeout=5 2>/dev/null || true

# 3) runtime dir + seat
mkdir -p /run/phosh
chmod 700 /run/phosh
pkill -x seatd 2>/dev/null
seatd -g root >/run/seatd-phosh.log 2>&1 &
sleep 1

export XDG_RUNTIME_DIR=/run/phosh
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=Phosh:GNOME
export XDG_SESSION_DESKTOP=phosh
export GDK_BACKEND=wayland
export MOZ_ENABLE_WAYLAND=1

echo "[test-phosh] starting phosh-session at $(date)"
: > /run/phosh.log
# PHOSH_SESSION_BIN lets us pass extra gnome-session flags (e.g.
# "gnome-session --disable-acceleration-check").
[ -n "${PHOSH_SESSION_BIN:-}" ] && export PHOSH_SESSION_BIN
setsid /usr/bin/phosh-session >> /run/phosh.log 2>&1 &
echo "[test-phosh] launched pid $!"
