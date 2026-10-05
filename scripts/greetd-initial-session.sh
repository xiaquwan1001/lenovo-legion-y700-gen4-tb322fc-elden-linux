#!/bin/sh
# greetd-initial-session.sh — TB322FC session "path A": greetd [initial_session]
# auto-logins root and runs phosh-session directly (no phrog greeter, no PIN).
#
# Why: gives a REAL elogind/logind session through PAM (pam_elogind), which the
# ad-hoc phosh-session loop cannot.  Fixes U1 brightness (elogind needs a
# session), U2 PIN (PAM stack), U5 seatd/seat ownership, U7 HOME/dconf.
# Chosen by user 2026-10-05; a normal user + phrog greeter is deferred until a
# concrete need (a real security/auth use case) appears.
#
# Idempotent.  Run on the device (persistent root) as root:
#   greetd-initial-session.sh install    # write wrapper+config, mode=greetd
#   greetd-initial-session.sh status
#   greetd-initial-session.sh phosh      # rollback (delegates to setup-session-greetd.sh)
#
# Seat backend MUST be seatd (LIBSEAT_BACKEND=seatd in the wrapper): the logind
# backend deactivates the session and phoc releases DRM -> CRTC off -> panel
# hang (same failure class as Q24).  See postmarketOS pmos-xiaomi-thunder#7.
set -eu

SWITCH=/etc/elden-session
CONF=/etc/greetd/config.toml
WRAP=/usr/local/sbin/elden-session-root
GREETD=/usr/sbin/greetd

install_path_a() {
	mkdir -p /etc/greetd

	cat > "$WRAP" <<'WRAPPER'
#!/bin/sh
# greetd initial_session target (path A, auto-login root).  greetd runs this
# through PAM (pam_elogind) so a real logind session exists for root.
export LIBSEAT_BACKEND=seatd
export XDG_CURRENT_DESKTOP=Phosh:GNOME
export XDG_SESSION_DESKTOP=phosh
export XDG_SESSION_TYPE=wayland
export GDK_BACKEND=wayland
export MOZ_ENABLE_WAYLAND=1
export HOME=/root
[ -n "$XDG_RUNTIME_DIR" ] || export XDG_RUNTIME_DIR=/run/user/0
mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null || true
chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null || true
exec /usr/bin/phosh-session
WRAPPER
	chmod 755 "$WRAP"

	cat > "$CONF" <<'CONF'
# /etc/greetd/config.toml — TB322FC path A: auto-login root, no greeter.
# Start: /usr/sbin/greetd -c /etc/greetd/config.toml  (LIBSEAT_BACKEND=seatd)
# NOTE: greetd requires a [default_session]; we set it to the same session so
# that after phosh exits the session is simply restarted (appliance-like),
# instead of dropping to a greeter (which would need a login user).
[terminal]
vt = 7

[initial_session]
command = "/usr/local/sbin/elden-session-root"
user = "root"

[default_session]
command = "/usr/local/sbin/elden-session-root"
user = "root"
CONF

	echo greetd > "$SWITCH"
	echo "[path-A] wrote $WRAP + $CONF ; mode=greetd"
	echo "[path-A] reboot (or restart the session) to apply; rollback: $0 phosh"
}

status() {
	echo "switch = $(cat "$SWITCH" 2>/dev/null || echo phosh)"
	echo "config = $CONF $([ -f "$CONF" ] && echo '(present)' || echo '(MISSING)')"
	ls -l "$WRAP" 2>/dev/null || echo "wrapper = MISSING"
	echo -n "sessions: "; loginctl list-sessions 2>/dev/null | tail -n +2 | wc -l
}

case "${1:-status}" in
	install)
		[ "$(id -u)" = 0 ] || { echo "need root" >&2; exit 1; }
		[ -x "$GREETD" ] || { echo "$GREETD missing (apk add greetd)" >&2; exit 1; }
		install_path_a
		;;
	phosh)
		[ "$(id -u)" = 0 ] || { echo "need root" >&2; exit 1; }
		HERE=$(cd "$(dirname "$0")" && pwd)
		if [ -x "$HERE/setup-session-greetd.sh" ]; then
			"$HERE/setup-session-greetd.sh" phosh
		else
			echo phosh > "$SWITCH"
			echo "[path-A] mode=phosh (rollback)"
		fi
		;;
	status) status ;;
	*) echo "usage: $0 {install|phosh|status}" >&2; exit 2 ;;
esac
