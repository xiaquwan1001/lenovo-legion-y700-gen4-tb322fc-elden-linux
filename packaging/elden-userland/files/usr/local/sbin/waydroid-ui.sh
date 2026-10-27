#!/bin/sh
# Show the full Waydroid UI on the running Phosh/Wayland session.
# XDG_RUNTIME_DIR 探测同 waydroid-session.sh（Alpine=/run/phosh，Debian=/run/user/<uid>）。
pick_runtime_dir() {
	for d in "${XDG_RUNTIME_DIR:-}" "/run/user/$(id -u)" /run/phosh \
		/run/user/1001 /run/user/1000 /run/user/0; do
		[ -n "$d" ] || continue
		[ -S "$d/wayland-0" ] && { printf '%s\n' "$d"; return 0; }
	done
	return 1
}

RT=$(pick_runtime_dir) || {
	echo "waydroid-ui: no wayland-0 socket (XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-unset})" >&2
	exit 1
}
export XDG_RUNTIME_DIR="$RT"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export HOME="${HOME:-/root}"
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
exec waydroid show-full-ui
