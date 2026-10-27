#!/bin/sh
# Start a Waydroid session inside the running Phosh/Wayland session.
#
# XDG_RUNTIME_DIR 不能写死：Alpine 的 phosh 用 /run/phosh，Debian 走 logind 的
# /run/user/<uid>（2026-10-27 实测：写死 /run/phosh ⇒ Debian 上
# "Wayland socket '/run/phosh/wayland-0' doesn't exist" ⇒ session 起不来 ⇒
# 容器也随之被 laminar stop）。判据一律用**真实存在的 wayland-0 socket**。
pick_runtime_dir() {
	for d in "${XDG_RUNTIME_DIR:-}" "/run/user/$(id -u)" /run/phosh \
		/run/user/1001 /run/user/1000 /run/user/0; do
		[ -n "$d" ] || continue
		[ -S "$d/wayland-0" ] && { printf '%s\n' "$d"; return 0; }
	done
	return 1
}

RT=$(pick_runtime_dir) || {
	echo "waydroid-session: no wayland-0 socket (XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-unset})" >&2
	exit 1
}
export XDG_RUNTIME_DIR="$RT"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export HOME="${HOME:-/root}"
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
exec waydroid session start
