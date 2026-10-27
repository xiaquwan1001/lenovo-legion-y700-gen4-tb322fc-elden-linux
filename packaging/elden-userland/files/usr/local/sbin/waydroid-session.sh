#!/bin/sh
# Start a Waydroid session inside the running Phosh/Wayland session.
#
# 三件事（都在本脚本里兜底，因为它们都只表现为"Waydroid 起不来"）：
#   ① XDG_RUNTIME_DIR 不能写死：Alpine 的 phosh 用 /run/phosh，Debian 走 logind 的
#      /run/user/<uid> ⇒ 探测**真实存在的 wayland-0 socket**，并**等**它出现（≤30 s）。
#      （PITFALLS #435/#437：XDG autostart 可能在 phoc 建 socket 之前就执行）
#   ② 网桥兜底：`waydroid0` 不在就先 `waydroid-net.sh start`
#      （PITFALLS #434：容器起时会 attach veth 到 waydroid0，网桥缺失 ⇒ lxc-start 直接失败）
#   ③ "session 在跑但容器没起"自愈：`systemctl restart waydroid-container` 之后，
#      waydroid-container 只是 D-Bus mainloop，**不会**自己起容器；老 session 又不会重新握手
#      ⇒ 状态一直是 Session RUNNING / Container STOPPED。这里主动 stop+start 一次。
#      注意 `Container: FROZEN` 是正常省电态（Android 自己 suspend），**不要**把它当坏。
pick_runtime_dir() {
	for d in "${XDG_RUNTIME_DIR:-}" "/run/user/$(id -u)" /run/phosh \
		/run/user/1001 /run/user/1000 /run/user/0; do
		[ -n "$d" ] || continue
		[ -S "$d/wayland-0" ] && { printf '%s\n' "$d"; return 0; }
	done
	return 1
}

i=0
while :; do
	RT=$(pick_runtime_dir) && break
	i=$((i + 1))
	if [ "$i" -ge 60 ]; then
		echo "waydroid-session: no wayland-0 socket after 30s (XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-unset})" >&2
		exit 1
	fi
	sleep 0.5
done
export XDG_RUNTIME_DIR="$RT"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export HOME="${HOME:-/root}"
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# ② 网桥兜底
NETSH=/usr/lib/waydroid/data/scripts/waydroid-net.sh
if [ -x "$NETSH" ] && ! ip link show waydroid0 >/dev/null 2>&1; then
	"$NETSH" start >/dev/null 2>&1 || true
fi

# ③ 半死状态自愈（Session 在跑 / Container 不在跑，且不是 FROZEN）
ST=$(waydroid status 2>/dev/null || true)
if printf '%s\n' "$ST" | grep -q 'Session:.*RUNNING' &&
   ! printf '%s\n' "$ST" | grep -qE 'Container:.*(RUNNING|FROZEN)'; then
	echo "waydroid-session: stale session (container down) → restarting session" >&2
	waydroid session stop >/dev/null 2>&1 || true
	sleep 2
fi

exec waydroid session start
