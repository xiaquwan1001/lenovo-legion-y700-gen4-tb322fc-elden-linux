#!/bin/bash
# lib-serial-source.sh — 串口日志的唯一采集实现（被 suspend/n5b 等采集脚本 source）。
#
# 背景（PITFALLS #359）：
#   /dev/ttyACM0 = root:dialout 660，本机用户不在 dialout 组；
#   而旧实现是 `[ -e 端口 ]` 判存在 + `stty || true` + `cat 2>/dev/null`
#   ⇒ 权限不足被吞成「日志文件存在但为空」，与「真的没有 panic」无法区分。
#   Q24/硬复位时 pstore 常为空（#197），串口是唯一证据源 ⇒ 这种假阴性会毁掉整轮结论。
#
# 两级来源：
#   ① relay：读常驻服务写的普通文件（scripts/install-serial-logger.sh，root 持端口，
#      重启后 gadget 重建节点也不丢；推荐，无需加组/重登）。
#   ② direct：自己开端口（需要 dialout 组或用 sudo 跑）。
# 两种都要过「有数据流过」的探针才算就绪 —— 端口存在 ≠ 采集在工作。
#
# 用法：
#   . "$(dirname "$0")/lib-serial-source.sh"
#   serial_start "$SLOG" || exit 3      # 失败即返回非 0（调用方决定是否降级）
#   serial_probe                        # 端到端探针（需设备 SSH 可达；不可达返回 2）
#   serial_stop

SERIAL_LOG=${SERIAL_LOG:-/var/log/elden-serial/ttyACM0.log}
SERIAL_PORT=${SERIAL_PORT:-/dev/ttyACM0}
SERIAL_DEV=${SERIAL_DEV:-root@192.168.7.1}
SERIAL_PROBE_TOKEN=${SERIAL_PROBE_TOKEN:-__elden_serial_probe_$$}

_serial_ssh() { timeout 20 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 -o BatchMode=yes "$SERIAL_DEV" "$@" 2>/dev/null; }

serial_start() {
	local slog=$1
	_ser_mode=none
	_ser_pid=
	_ser_base=0

	if [ -r "$SERIAL_LOG" ]; then
		_ser_base=$(stat -c %s "$SERIAL_LOG" 2>/dev/null || echo 0)
		printf '\n===== relay from %s (offset %s) %s =====\n' "$SERIAL_LOG" "$_ser_base" "$(date -Is)" >> "$slog"
		# -F: 日志被服务重建也要继续跟
		tail -c "+$((_ser_base + 1))" -F "$SERIAL_LOG" >> "$slog" 2>/dev/null &
		_ser_pid=$!
		_ser_mode=relay
		echo "  serial: relay $SERIAL_LOG (from offset $_ser_base, pid=$_ser_pid)"
		return 0
	fi

	# 直连端口：先证明可读，再开采集
	if [ -e "$SERIAL_PORT" ]; then
		if timeout 3 dd if="$SERIAL_PORT" bs=1 count=1 of=/dev/null 2>/dev/null; then
			( while true; do
				stty -F "$SERIAL_PORT" 115200 raw -echo 2>/dev/null || true
				printf '\n===== serial open %s =====\n' "$(date -Is)" >> "$slog"
				cat "$SERIAL_PORT" >> "$slog" 2>/dev/null
				sleep 0.3
			  done ) &
			_ser_pid=$!
			_ser_mode=direct
			echo "  serial: direct $SERIAL_PORT (pid=$_ser_pid)"
			return 0
		fi
		echo "  serial: UNREADABLE $SERIAL_PORT owner=$(stat -c '%U:%G %a' "$SERIAL_PORT") user=$(id -un)"
	elif [ ! -e "$SERIAL_PORT" ]; then
		echo "  serial: NOPORT $SERIAL_PORT"
	fi

	echo "  serial: 无可用来源。装常驻日志服务（推荐，一次性）："
	echo "     sudo bash scripts/install-serial-logger.sh"
	echo "  或临时授权： sudo setfacl -m u:$(id -un):rw $SERIAL_PORT"
	echo "  或加组（需重登）： sudo usermod -aG dialout $(id -un)"
	return 3
}

# 端到端探针：让设备往 console(ttyGS0) 写一行，看它是否出现在本机采集里。
# 返回 0=通 2=设备不可达 3=写不进去/没收到
serial_probe() {
	local slog=$1 out
	[ "$_ser_mode" = none ] && return 3
	out=$(_serial_ssh "echo $SERIAL_PROBE_TOKEN > /dev/ttyGS0") || return 2
	sleep 2
	if grep -q "$SERIAL_PROBE_TOKEN" "$slog" 2>/dev/null; then
		echo "  serial: ✅ 端到端探针通过（模式=$_ser_mode）"
		return 0
	fi
	echo "  serial: ⚠️ 探针未出现在日志里（模式=$_ser_mode）——设备侧 console 未指向该 tty 或中继断开"
	return 3
}

serial_stop() {
	[ -n "${_ser_pid:-}" ] || return 0
	kill "$_ser_pid" 2>/dev/null
	pkill -P "$_ser_pid" 2>/dev/null
	_ser_pid=
	return 0
}

serial_mode() { echo "${_ser_mode:-none}"; }

# 只判可用性、不起采集进程（给 `--check` 这类零副作用的预检用）。
serial_source_probe() {
	if [ -r "$SERIAL_LOG" ]; then echo "relay $SERIAL_LOG"; return 0; fi
	if [ -e "$SERIAL_PORT" ] && timeout 3 dd if="$SERIAL_PORT" bs=1 count=1 of=/dev/null 2>/dev/null; then
		echo "direct $SERIAL_PORT"; return 0
	fi
	if [ -e "$SERIAL_PORT" ]; then
		echo "unreadable $SERIAL_PORT ($(stat -c '%U:%G %a' "$SERIAL_PORT"))"
	else
		echo "noport $SERIAL_PORT"
	fi
	return 3
}
