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

# XDG autostart 里 `X-GNOME-Autostart-Delay` 在当前 gnome-session 版本**已不生效**
# （日志： "no longer manages session services"）⇒ 本条目可能在 phoc 建 socket 之前就执行。
# 所以这里**等** socket 出现（≤30 s），不要一看到没有就退出（否则 autostart 永远失败）。
i=0
while :; do
	RT=$(pick_runtime_dir) && break
	i=$((i + 1))
	if [ "$i" -ge 60 ]; then
		echo "waydroid-ui: no wayland-0 socket after 30s (XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-unset})" >&2
		exit 1
	fi
	sleep 0.5
done
export XDG_RUNTIME_DIR="$RT"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export HOME="${HOME:-/root}"
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
exec waydroid show-full-ui
