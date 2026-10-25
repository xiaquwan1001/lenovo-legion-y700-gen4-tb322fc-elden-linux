#!/bin/sh
# setup-session-greetd.sh — switch the TB322FC Alpine session between the
# legacy ad-hoc `phosh-session` loop and greetd+phrog+elogind (the
# postmarketOS 25.12 model).  Idempotent.  Run on the device (persistent
# root) as root, from a directory that also holds start-desktop.sh.
#
#   setup-session-greetd.sh install    # apk add + config + mode=greetd
#   setup-session-greetd.sh phosh      # rollback: mode=phosh (ad-hoc loop)
#   setup-session-greetd.sh status
#
# Why greetd+phrog: the ad-hoc loop starts phosh-session with no PAM/logind
# session -> `loginctl list-sessions` is empty -> elogind SetBrightness
# (U1/G1-28), PAM PIN (U2), seatd VT-bound restart (U5), HOME/dconf (U7) all
# break.  greetd creates a real session through PAM (pam_elogind.so).
#
# Seat backend: LIBSEAT_BACKEND=seatd is set by start-desktop.sh; the logind
# backend deactivates the session and makes phoc release DRM -> panel hang.
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
SWITCH=/etc/elden-session
GREETD_CONF=/etc/phrog/greetd-config.toml
GREETD_USER=greetd

require_root() { [ "$(id -u)" = 0 ] || { echo "need root" >&2; exit 1; }; }

install_start_desktop() {
	if [ -f "$HERE/start-desktop.sh" ]; then
		install -m 755 "$HERE/start-desktop.sh" /usr/local/sbin/start-desktop.sh
		install -m 755 "$HERE/fix-logind-poweroff.sh" /usr/local/sbin/fix-logind-poweroff.sh 2>/dev/null || true
		echo "[session] installed /usr/local/sbin/start-desktop.sh (mode-aware)"
	else
		echo "[session] WARN: $HERE/start-desktop.sh not found; device copy left unchanged" >&2
	fi
}

case "${1:-status}" in
	install)
		require_root
		echo "[session] apk add greetd greetd-phrog"
		apk add -q greetd greetd-phrog
		[ -f "$GREETD_CONF" ] || { echo "missing $GREETD_CONF after install" >&2; exit 1; }
		# seatd backend needs the greetd user in the 'seat' group; video/input
		# for direct DRM/input access as a fallback.
		adduser "$GREETD_USER" seat  2>/dev/null || true
		adduser "$GREETD_USER" video 2>/dev/null || true
		adduser "$GREETD_USER" input 2>/dev/null || true
		mkdir -p /run/greetd
		chown "$GREETD_USER:$GREETD_USER" /run/greetd
		chmod 700 /run/greetd
		install_start_desktop
		echo greetd > "$SWITCH"
		echo "[session] mode=greetd (greeter: phrog, PAM: /etc/pam.d/greetd)"
		echo "[session] reboot or restart the session to apply; rollback: $0 phosh"
		;;
	phosh)
		require_root
		echo phosh > "$SWITCH"
		install_start_desktop
		echo "[session] mode=phosh (legacy ad-hoc phosh-session loop)"
		;;
	status)
		echo "switch  = $(cat "$SWITCH" 2>/dev/null || echo phosh)"
		echo "greetd  = $(command -v greetd || echo MISSING)"
		echo "phrog   = $(command -v phrog || echo MISSING)"
		ls -l "$GREETD_CONF" 2>/dev/null || echo "config  = MISSING"
		echo -n "greetd user groups: "; id "$GREETD_USER" 2>/dev/null || echo "no greetd user"
		echo -n "sessions: "; loginctl list-sessions 2>/dev/null | tail -n +2 | wc -l
		;;
	*)
		echo "usage: $0 {install|phosh|status}" >&2; exit 2 ;;
esac
