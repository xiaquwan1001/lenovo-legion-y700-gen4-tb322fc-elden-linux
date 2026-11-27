#!/bin/bash
# serial-console.sh — 设备串口控制台（/dev/ttyACM0）的**唯一仲裁入口**
#
# 背景（2026-11-27 实测踩到）：
#   `scripts/serial-fanout.sh` 由 systemd 常驻、**独占**打开 /dev/ttyACM0（写日志到
#   /var/log/elden-serial/ttyACM0.log）。于是任何 `cat /dev/ttyACM0` 都报
#   `Device or resource busy`，人想往串口敲一条命令（例如 initramfs shell 里跑 e2fsck）
#   完全做不到；同时 ModemManager 也会去嗅这个 CDC-ACM 并往里灌 `AT`（日志里成片
#   `/bin/sh: AT: not found`），既污染控制台又会抢占端口。
#
# 本脚本把三件事收成一个入口：
#   tail [-n N] [-f]   读日志文件（**不碰端口**，任何时刻都能用）
#   send "<命令>"      停 logger → 独占端口写入 → 读回输出 → 恢复 logger（默认读 6 s）
#   attach             交互：停 logger 后把端口接到当前终端（Ctrl-C 结束并恢复 logger）
#
# 子命令语义与退出码：
#   0 = 成功；2 = 端口不存在/未连接；3 = logger 停不下来（拒绝抢占）；4 = 用错
#
# 用法：
#   scripts/serial-console.sh tail -n 80
#   scripts/serial-console.sh send 'e2fsck -y /dev/sda17'
#   SERIAL_READ_SEC=30 scripts/serial-console.sh send 'reboot -f'
#   scripts/serial-console.sh attach
#
# 环境变量：PORT（默认 /dev/ttyACM0）、LOG（默认 /var/log/elden-serial/<port>.log）、
#           SERVICE（默认 elden-serial-logger.service）、BAUD（默认 115200）、
#           SERIAL_READ_SEC（send 的读回秒数，默认 6）
set -uo pipefail

PORT=${PORT:-/dev/ttyACM0}
LOG=${LOG:-/var/log/elden-serial/$(basename "$PORT").log}
SERVICE=${SERVICE:-elden-serial-logger.service}
BAUD=${BAUD:-115200}
READ_SEC=${SERIAL_READ_SEC:-6}
LOCK=/run/lock/elden-serial-console.lock

die() { printf 'serial-console: %s\n' "$*" >&2; exit "${2:-1}"; }

usage() {
	sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
	exit 4
}

need_port() {
	[ -e "$PORT" ] || die "端口不存在：$PORT（设备没连上/没起 USB gadget）" 2
}

take_lock() {
	mkdir -p "$(dirname "$LOCK")" 2>/dev/null || true
	exec 9>"$LOCK" 2>/dev/null || true
	if command -v flock >/dev/null 2>&1; then
		flock -w 10 9 || die "另一个 serial-console 正在用端口（锁 $LOCK）"
	fi
}

# logger 停了才算拿到端口；停不下来就不抢（宁可报错，也不和常驻采集打架）
stop_logger() {
	command -v systemctl >/dev/null 2>&1 || return 0
	sudo -n systemctl stop "$SERVICE" >/dev/null 2>&1 || sudo systemctl stop "$SERVICE" >/dev/null 2>&1
	local i=0
	while [ "$i" -lt 15 ]; do
		state=$(systemctl is-active "$SERVICE" 2>/dev/null)
		[ "$state" != "active" ] && return 0
		sleep 0.2; i=$((i + 1))
	done
	die "停不掉 $SERVICE（仍有进程占着 $PORT），拒绝抢占" 3
}

start_logger() {
	command -v systemctl >/dev/null 2>&1 || return 0
	sudo -n systemctl start "$SERVICE" >/dev/null 2>&1 || sudo systemctl start "$SERVICE" >/dev/null 2>&1 || true
}

cleanup() { start_logger; }
trap cleanup EXIT

cmd_tail() {
	local n=40 follow=0
	while [ $# -gt 0 ]; do
		case "$1" in
			-n) n=$2; shift 2 ;;
			-f) follow=1; shift ;;
			*) die "tail: 未知参数 $1" 4 ;;
		esac
	done
	[ -f "$LOG" ] || die "日志不存在：$LOG（logger 没在跑？）"
	if [ "$follow" = 1 ]; then tail -n "$n" -F "$LOG"; else tail -n "$n" "$LOG"; fi
}

cmd_send() {
	local line=${1:-}
	[ -n "$line" ] || die "send 需要一条命令" 4
	need_port; take_lock
	# ★ 安全闸（2026-11-27 实测踩到）：系统正常启动时 ttyGS0 上挂着**磁盘根的登录提示**，
	#   盲发命令会变成“拿命令当用户名 + 密码提示”（实测：`echo X` 被当成用户名）。
	#   所以要求调用方先确认现场是 initramfs shell。给了环境变量才真发。
	if [ "${SERIAL_CONSOLE_SEND_OK:-0}" != 1 ]; then
		printf 'serial-console: 拒绝裸发。先看清楚现场（日志最后 3 行）：\n' >&2
		[ -f "$LOG" ] && tail -n 3 "$LOG" | tr -d '\r' | sed 's/^/    /' >&2
		printf '确认是在 initramfs shell（提示符 `~ #`）后，用：\n  SERIAL_CONSOLE_SEND_OK=1 %s send %q\n' "$0" "$line" >&2
		exit 5
	fi
	stop_logger
	# raw 模式：不要回显、不要行规程（否则 CR/LF 会互相改写）
	stty -F "$PORT" "$BAUD" raw -echo 2>/dev/null || true
	printf '\n%s\n' "$line" > "$PORT" || die "写端口失败：$PORT"
	sleep "$READ_SEC"
	timeout -k 2 "$READ_SEC" cat "$PORT" 2>/dev/null \
		| tr -d '\r' | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' \
		| grep -v '^[[:space:]]*$'
}

cmd_attach() {
	need_port; take_lock; stop_logger
	stty -F "$PORT" "$BAUD" raw -echo 2>/dev/null || true
	printf 'attached to %s（Ctrl-C 退出并恢复 %s）\n' "$PORT" "$SERVICE" >&2
	# 读侧后台跑，写侧跟 stdin：这样既能看输出也能敲命令
	cat "$PORT" &
	local reader=$!
	while IFS= read -r line; do printf '%s\n' "$line" > "$PORT"; done
	kill "$reader" 2>/dev/null || true
}

case "${1:-}" in
	tail)   shift; cmd_tail "$@" ;;
	send)   shift; cmd_send "$@" ;;
	attach) shift; cmd_attach ;;
	*|--help|-h) usage ;;
esac
