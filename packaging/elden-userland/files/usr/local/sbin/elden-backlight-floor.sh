#!/bin/sh
# elden-backlight-floor.sh — 背光下限守护（防止「看起来像黑屏」）
#
# 为什么需要（实测事故，2026-10-23）：
#   驱动默认 `aw99706-backlight/brightness=160/4095`（≈4%），加上
#   `gnome-settings-daemon` 的自动亮度（ambient-enabled=true）在冷起后可把亮度压回低档。
#   面板其实 GOOD（card0-DSI-1=connected/enabled、DSI 0 错误、会话 active、phoc 在跑），
#   人看到的现象却是「设备没响应 / 黑屏」——2026-10-23 因此误判一次设备状态。
#
# 策略：ambient 自动亮度关闭（用户态 gsettings，见 reports/backlight-floor-20261023.md）
#   + 本守护把亮度钳在 FLOOR 之上（默认 1024/4095 ≈ 25%）。
#
# 用法：
#   elden-backlight-floor.sh --once        # 立即钳一次（幂等）
#   elden-backlight-floor.sh --loop [sec]  # 常驻轮询（默认 20 s）
#   elden-backlight-floor.sh --check       # 只打印，不写
# 退出码：0 正常；1 找不到 backlight 设备；2 写失败。
set -u
FLOOR=${BACKLIGHT_FLOOR:-1024}
SYS=/sys/class/backlight

bl_dir() {
	for d in "$SYS"/*; do
		[ -r "$d/brightness" ] && { echo "$d"; return 0; }
	done
	return 1
}

# clamp_once [quiet] —— quiet=1 时只在**发生钳位**时打印（供 --loop 用，避免日志刷屏）
clamp_once() {
	local quiet=${1:-0}
	d=$(bl_dir) || return 1
	cur=$(cat "$d/brightness" 2>/dev/null) || return 1
	max=$(cat "$d/max_brightness" 2>/dev/null || echo 4095)
	floor=$FLOOR
	[ "$floor" -gt "$max" ] && floor=$max
	if [ "$cur" -lt "$floor" ]; then
		printf '%s' "$floor" > "$d/brightness" 2>/dev/null || return 2
		printf '%s: %s -> %s (max %s)\n' "$(basename "$d")" "$cur" "$floor" "$max"
	elif [ "$quiet" = 0 ]; then
		printf '%s: %s (>= %s, unchanged)\n' "$(basename "$d")" "$cur" "$floor"
	fi
	return 0
}

check() {
	d=$(bl_dir) || return 1
	printf '%s brightness=%s max=%s floor=%s\n' "$(basename "$d")" \
		"$(cat "$d/brightness")" "$(cat "$d/max_brightness" 2>/dev/null || echo ?)" "$FLOOR"
}

case "${1:---once}" in
	--once)  clamp_once; exit $? ;;
	--check) check; exit $? ;;
	--loop)
		iv=${2:-20}
		# 首次等设备/驱动就绪（Q28 坏发时面板可能一直不出现，故不因一次失败退出）
		for _ in $(seq 1 30); do bl_dir >/dev/null 2>&1 && break; sleep 2; done
		while :; do
			clamp_once 1 2>&1 || true
			sleep "$iv"
		done ;;
	*) echo "usage: $0 --once|--check|--loop [interval_s]" >&2; exit 64 ;;
esac
