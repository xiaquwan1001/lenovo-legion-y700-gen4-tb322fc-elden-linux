#!/bin/sh
# openrc-enable.sh — switch the TB322FC (elden) persistent root from the ad-hoc
# "/init starts every service by hand" model to native Alpine OpenRC.
#
# WHY: /init (PID1, a shell) + /usr/local/sbin/start-desktop.sh hand-start
# dbus/udevd/seatd/elogind/greetd with pgrep guards and accumulated patch-init-*
# fixes.  Alpine already ships OpenRC 0.63 + every *-openrc service file, but
# /etc/runlevels/* is empty and nothing ever runs `openrc`.  This script wires
# it up.
#
# HOW: /init keeps the early lifeline (usb-gadget, usb0, sshd, ttyGS0/GS1) and
# then, when /etc/elden-init-mode == openrc, `exec /sbin/init` -> /etc/inittab
# -> `openrc sysinit/boot/default`.  PID1 becomes busybox init, so the poweroff
# signal path + `::shutdown:/sbin/openrc shutdown` work (G1-25 root fix; the
# /sbin/{poweroff,reboot,halt} `-f` wrappers can then be retired).
#
# SAFETY: usb0 + sshd are up before the handoff, so a bad OpenRC boot is still
# reachable over SSH -> `openrc-enable.sh revert; reboot`.  Legacy mode is the
# default and leaves the previous behaviour byte-for-byte intact.
#
# usage (on the device):  openrc-enable.sh [enable|revert|status]
set -u

MODE_FILE=/etc/elden-init-mode
BRINGUP=/etc/local.d/elden-bringup.start
GREETD_CONF=/etc/conf.d/greetd

# Services OpenRC should own.  Deliberately NOT here:
#   networking / dhcpcd / wpa_supplicant -> NetworkManager owns wlan0
#     (double-supplicant is a known bug, PITFALLS #117)
#   chronyd -> time-sync.sh steps the clock first (device RTC is read-only and
#     the clock boots at 1970, so chrony must not be the first thing to start)
#   sshd / usb-gadget / getty  -> /init keeps these for the recovery lifeline
SYSINIT="devfs procfs sysfs cgroups dmesg modules sysctl hostname"
BOOT="hwclock seedrng udev udev-trigger udev-settle localmount bootmisc"
DEFAULT="dbus elogind seatd greetd networkmanager bluetooth polkit rtkit udisks2 elden-hapticd local"

write_payload() {
	install -d -m755 /etc/local.d /etc/conf.d

	cat >"$BRINGUP" <<'EOF'
#!/bin/sh
# OpenRC `local` payload — helpers with no OpenRC service equivalent.
# networkmanager/bluetooth services own their daemons; ath12k-retry just
# re-probes the WCN so wlan0 appears (NM connects when it does).  time-sync
# steps the 1970 clock from NTP and then keeps chronyd running.
for h in ath12k-retry charge-watch time-sync; do
	[ -x "/usr/local/sbin/$h.sh" ] && setsid "/usr/local/sbin/$h.sh" >"/run/$h.log" 2>&1 &
done
# bluetoothd is started by the `bluetooth` service; hci0 shows up ~30 s later
# once btqca loads the firmware, so set the alias/power state a bit after boot.
(
	sleep 30
	command -v bluetoothctl >/dev/null 2>&1 || exit 0
	bluetoothctl system-alias elden >/dev/null 2>&1
	bluetoothctl power on >/dev/null 2>&1
) &
exit 0
EOF
	chmod 755 "$BRINGUP"

	# greetd must use the seatd backend: the logind backend deactivates the
	# session and phoc releases DRM -> the panel goes dark (see USERLAND-PKGS
	# §4 / Q24).  The session script also exports it, but greetd itself picks a
	# backend before the session runs.
	echo 'export LIBSEAT_BACKEND=seatd' >"$GREETD_CONF"
	chmod 644 "$GREETD_CONF"
}

add_runlevels() {
	for s in $SYSINIT; do rc-update add "$s" sysinit >/dev/null 2>&1; done
	for s in $BOOT;    do rc-update add "$s" boot    >/dev/null 2>&1; done
	for s in $DEFAULT; do rc-update add "$s" default >/dev/null 2>&1; done
}

enable() {
	write_payload
	add_runlevels
	install_forensics
	echo openrc >"$MODE_FILE"
	echo "enabled: /etc/elden-init-mode=openrc"
	info
	echo "reboot to hand PID1 to /sbin/init (or: echo legacy >$MODE_FILE; reboot to undo)"
}

# G1-22/Q24 forensics: a shutdown-runlevel marker so a *clean userland* poweroff
# can be told apart from a *hard reset* (USB VBUS auto-powers-on, so "it came
# back" proves nothing).  Canonical source: scripts/elden-powerlog.initd,
# deployed to /usr/local/sbin/elden-powerlog.initd.
install_forensics() {
	if [ -f /usr/local/sbin/elden-powerlog.initd ]; then
		install -m755 /usr/local/sbin/elden-powerlog.initd /etc/init.d/elden-powerlog
		rc-update add elden-powerlog shutdown >/dev/null 2>&1 || true
	else
		echo "note: /usr/local/sbin/elden-powerlog.initd missing; shutdown marker not installed" >&2
	fi
}

revert() {
	echo legacy >"$MODE_FILE"
	echo "reverted: /etc/elden-init-mode=legacy (services left in runlevels; harmless)"
}

info() {
	echo "--- runlevels ---"
	for r in sysinit boot default shadow; do
		[ -d "/etc/runlevels/$r" ] && printf '%-8s %s\n' "$r" "$(ls /etc/runlevels/$r 2>/dev/null | tr '\n' ' ')"
	done
	echo "--- mode --- $(cat $MODE_FILE 2>/dev/null || echo '(unset -> legacy)')"
	echo "--- payload --- $([ -x $BRINGUP ] && echo present || echo MISSING)  $([ -f $GREETD_CONF ] && echo conf.d || echo no-conf)"
}

case "${1:-status}" in
	enable)  enable ;;
	revert)  revert ;;
	status)  info ;;
	*) echo "usage: $0 [enable|revert|status]" >&2; exit 2 ;;
esac
