#!/bin/sh
# start-desktop.sh — Phosh (Wayland) desktop on the TB322FC panel.
#
# Runs on the persistent (disk) root only; /init launches it when
# $on_initramfs = 0 (i.e. root is /dev/sde79). Installed at
# /usr/local/sbin/start-desktop.sh on the device (canonical copy: scripts/).
#
# Replaces the earlier weston loop. Phosh needs udev (libinput/phoc device
# enumeration) and seatd, so both are started here. The session is restarted
# in a loop so the panel recovers if the compositor dies.
#
# 2026-09-30: system D-Bus is also started here — gsd-power (blank/wake and
# power-key management) exits at startup without it, leaving the panel stuck
# blank with no wake path. dbus-daemon-launch-helper must be root:messagebus
# 4750 or D-Bus activation (upowerd/polkitd) fails with EACCES.
set -u

mkdir -p /run/udev /run/phosh /run/dbus
chmod 700 /run/phosh

# System D-Bus: required by gsd-power / UPower / polkit (idle + wake path).
# /init starts it early (before net-up/start-desktop) — check the SOCKET, not a
# process name: two concurrent `dbus-daemon --system` starts each passed the
# old `pgrep dbus-daemon` guard and the one holding the path socket died
# (2026-09-30 boot race → no /run/dbus/system_bus_socket → NM/UPower dead).
if [ ! -S /run/dbus/system_bus_socket ]; then
	setsid dbus-daemon --system >/run/dbus.log 2>&1
	i=0
	while [ ! -S /run/dbus/system_bus_socket ] && [ "$i" -lt 50 ]; do
		sleep 0.1; i=$((i+1))
	done
fi

# Alpine ships the launch-helper root:root; D-Bus activation execs it as
# messagebus -> EACCES. Fix idempotently (rootfs rebuilds restore the bug).
chown root:messagebus /usr/libexec/dbus-daemon-launch-helper 2>/dev/null
chmod 4750 /usr/libexec/dbus-daemon-launch-helper 2>/dev/null

# udev: phoc's libinput backend only sees the touchscreen if udevd has run.
if ! pgrep -x udevd >/dev/null 2>&1; then
	/sbin/udevd --daemon 2>/dev/null
	sleep 1
	/sbin/udevadm trigger --action=add 2>/dev/null
	/sbin/udevadm settle --timeout=5 2>/dev/null
fi

# seatd: DRM/input seat for phoc (libseat).
pgrep -x seatd >/dev/null 2>&1 || seatd -g root >/run/seatd.log 2>&1 &

# elogind: provides the logind D-Bus API (org.freedesktop.login1) that
# gnome-session/phosh use for Power Off / Restart.  This rootfs has no
# systemd; without elogind the power menu just times out
# ("phosh-session-manager: Failed to shutdown: Timeout was reached").
# Package: `apk add elogind elogind-openrc` (2026-10-03).
#
# 2026-10-03: elogind's helpers /sbin/{poweroff,reboot,halt} are busybox
# applets that *without -f* only signal PID 1 instead of calling reboot(2).
# PID 1 here is the /init shell, so Power Off / Restart silently no-op'd and
# left elogind wedged (OperationInProgress).  Wrap them with -f first.
[ -x /usr/local/sbin/fix-logind-poweroff.sh ] && \
	/usr/local/sbin/fix-logind-poweroff.sh || true

# audio: UCM2 so WirePlumber exposes the AW88461 "Speakers" sink (the card's
# machine driver has no usable port, so ACP would otherwise give Dummy Output).
# PipeWire itself is started by its own /etc/xdg/autostart desktop entry.
[ -x /usr/local/sbin/audio-ucm/install.sh ] && \
	/usr/local/sbin/audio-ucm/install.sh || true
if [ -x /usr/libexec/elogind/elogind ] && ! pgrep -x elogind-daemon >/dev/null 2>&1; then
	/usr/libexec/elogind/elogind >/run/elogind.log 2>&1 &
fi

# /init inherits HOME=/ from the kernel (PID 1 env); phosh/phoc/gsd-* then
# resolve XDG config against '/' -> dconf user db lands in /.config/dconf/user,
# not /root/.config (2026-09-30: dark-mode/gtk-theme 'not persisting'). Pin it.
export HOME=/root
export XDG_RUNTIME_DIR=/run/phosh
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=Phosh:GNOME
export XDG_SESSION_DESKTOP=phosh
export GDK_BACKEND=wayland
export MOZ_ENABLE_WAYLAND=1

while true; do
	: > /run/phosh.log
	/usr/bin/phosh-session >>/run/phosh.log 2>&1
	echo "[start-desktop] phosh-session exited, restarting in 2s ($(date))" >>/run/phosh.log
	sleep 2
done
