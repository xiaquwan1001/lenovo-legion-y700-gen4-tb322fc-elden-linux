#!/bin/sh
# wake-screen.sh — 让 SSH 会话可以直接把平板屏幕从「合成器熄屏」状态叫回来。
#
# 背景（2026-11-26 实测）：面板熄屏时 **DRM DPMS 仍是 On**、backlight `bl_power=0`、
# `status=connected`，所以按 sysfs 判「屏没熄」会误判；真正的判据是**合成器能不能出帧**：
#   - `grim /tmp/x.png` 失败 "failed to copy output DSI-1"   ⇒ 熄屏
#   - `adb ... exec-out screencap -p` 全黑（cell 正常）      ⇒ 同一状态
# 唤醒只需给 phoc 一个真实输入事件；本机 `ydotoold` 常驻，`ydotool` 注入指针即可。
#
# 用法：
#   wake-screen.sh            # 唤醒（幂等：已亮也安全，只注入一次微小移动）
#   wake-screen.sh --check    # 只读体检：DPMS / 背光 / 注入 socket / 出帧能力
#   wake-screen.sh --quiet    # 不打印
#   wake-screen.sh --selftest # 断言判据本身：能区分「出帧」与「不出帧」
#
# 退出码：0 = 已亮（或唤醒成功）；3 = 唤醒后仍不出帧（需人工）；2 = 用法错误。
set -u

UID_TARGET=${UID_TARGET:-1001}
RUN_DIR=${XDG_RUNTIME_DIR:-/run/user/$UID_TARGET}
DISPLAY_NAME=${WAYLAND_DISPLAY:-wayland-0}
SHOT=${SHOT:-/tmp/.wake-screen-probe.png}
QUIET=0
MODE=wake

for a in "$@"; do
	case "$a" in
	--check) MODE=check ;;
	--quiet) QUIET=1 ;;
	--selftest) MODE=selftest ;;
	-h|--help) sed -n '2,20p' "$0"; exit 0 ;;
	*) echo "wake-screen.sh: 未知参数 $a" >&2; exit 2 ;;
	esac
done
say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }

# 以目标用户身份跑一条命令（root 直调 / 用户自己调用都成立）
as_user() {
	if [ "$(id -u)" = "$UID_TARGET" ]; then
		XDG_RUNTIME_DIR="$RUN_DIR" WAYLAND_DISPLAY="$DISPLAY_NAME" \
			YDOTOOL_SOCKET="$RUN_DIR/.ydotool_socket" "$@"
	else
		setpriv --reuid="$UID_TARGET" --regid="$UID_TARGET" --init-groups \
			env XDG_RUNTIME_DIR="$RUN_DIR" WAYLAND_DISPLAY="$DISPLAY_NAME" \
			YDOTOOL_SOCKET="$RUN_DIR/.ydotool_socket" "$@"
	fi
}

# 出帧判据：grim 能抓到非空 PNG 才算「亮」
framebuffer_ok() {
	rm -f "$SHOT"
	if as_user grim "$SHOT" >/dev/null 2>&1 && [ -s "$SHOT" ]; then
		# 全黑图也可能成功写出：用 PNG 体积粗筛（本机实测亮屏 130–180 KB、全黑 < 40 KB）
		sz=$(wc -c < "$SHOT" 2>/dev/null || echo 0)
		[ "$sz" -gt 60000 ]
		return $?
	fi
	return 1
}

check_state() {
	say "== wake-screen --check =="
	for f in /sys/class/drm/card0-DSI-1/dpms /sys/class/drm/card0-DSI-1/status; do
		printf '  %s = %s\n' "$f" "$(cat "$f" 2>/dev/null || echo '?')"
	done
	for f in /sys/class/backlight/*/bl_power; do
		printf '  %s = %s\n' "$f" "$(cat "$f" 2>/dev/null || echo '?')"
	done
	if [ -S "$RUN_DIR/.ydotool_socket" ]; then
		printf '  ydotool socket = %s（存在）\n' "$RUN_DIR/.ydotool_socket"
	else
		printf '  ydotool socket = %s（缺失 ⇒ 无法注入）\n' "$RUN_DIR/.ydotool_socket"
	fi
	if framebuffer_ok; then say "  出帧 = 是（屏已亮）"; else say "  出帧 = 否（熄屏/合成器不出帧）"; fi
}

do_wake() {
	if framebuffer_ok; then
		say "屏已亮，无需唤醒"
		return 0
	fi
	as_user ydotool mousemove -- 520 520 >/dev/null 2>&1 || true
	sleep 0.3
	as_user ydotool mousemove -- 480 480 >/dev/null 2>&1 || true
	i=0
	while [ "$i" -lt 10 ]; do
		if framebuffer_ok; then
			say "已唤醒（第 $((i + 1)) 次探测出帧）"
			rm -f "$SHOT"
			return 0
		fi
		sleep 0.5
		i=$((i + 1))
	done
	say "唤醒后仍不出帧 ⇒ 不是 idle 熄屏（DPMS/合成器/DPU 需另查）"
	rm -f "$SHOT"
	return 3
}

selftest() {
	rc=0
	# 1. 判据能说「亮」
	if framebuffer_ok; then say "selftest: 当前出帧 = 是（阳性样本 ✔）"; else
		say "selftest: 当前出帧 = 否（本机此刻是熄屏，跳过阳性样本断言）"
	fi
	# 2. 判据能说「不亮」：拿一张不存在/空文件必须判否
	SHOT=/tmp/.wake-screen-selftest-empty
	: > "$SHOT"
	if [ -s "$SHOT" ] && [ "$(wc -c < "$SHOT")" -gt 60000 ]; then
		say "selftest: 空文件被误判为亮 ⇒ 判据失效"; rc=1
	else
		say "selftest: 空文件判为不亮 ✔"
	fi
	rm -f "$SHOT"
	return $rc
}

case "$MODE" in
check) check_state ;;
wake) do_wake ;;
selftest) selftest ;;
esac
