#!/bin/bash
# serial-fanout.sh — 读一个 tty 并把内容追加到文件（供 systemd 常驻运行）。
#
# 与 scripts/serial-logger.sh 的区别：这是**面向 systemd 的前台进程**，由本脚本
# **自己**负责重连（systemd 只保证进程活着），日志落 0644 普通文件，
# 让非 dialout 组的用户也能读（PITFALLS #359）。
#
# ★ 为什么不用 systemd 的 BindsTo=dev-ttyACM0.device（2026-10-20 实测踩到）：
#   设备一重启节点消失 ⇒ BindsTo 会**正常停止** service，
#   而 Restart=always **不覆盖 BindsTo 触发的停止** ⇒ 节点回来后服务永久停着，
#   日志停在旧内容，采集侧把它当成「没有 panic」——又是一次静默假阴性。
#   ⇒ 改成脚本内部等节点 + 重连，systemd 只做 Restart=always 兜底。
#
# 用法： serial-fanout.sh [PORT] [LOGFILE]
set -u
PORT=${1:-/dev/ttyACM0}
LOG=${2:-/var/log/elden-serial/$(basename "$PORT").log}

mkdir -p "$(dirname "$LOG")"
echo "===== serial-fanout start $(date -Is) port=$PORT log=$LOG =====" >> "$LOG"

# 等节点出现（设备重启期间会消失；最多等 10 min 再退出交给 systemd）
wait_port() {
	local t=0
	while [ ! -e "$PORT" ]; do
		[ "$t" -ge 600 ] && return 1
		sleep 1
		t=$((t + 1))
	done
	return 0
}

while true; do
	wait_port || {
		echo "===== $PORT 600s 未出现，退出交给 systemd =====" >> "$LOG"
		exit 1
	}
	# 串口参数：115200 8N1、raw、无回显、不参与流控。
	# 失败时**必须记日志并重试** —— 静默继续会让日志为空而看起来像「没输出」。
	if stty -F "$PORT" 115200 raw -echo -crtscts 2>>"$LOG"; then
		echo "===== serial open $PORT $(date -Is) =====" >> "$LOG"
		cat "$PORT" >> "$LOG"
		echo "===== serial closed $PORT (rc=$?) $(date -Is) =====" >> "$LOG"
	else
		echo "===== stty failed on $PORT $(date -Is) =====" >> "$LOG"
	fi
	# 节点可能被重建：等它回来，避免对已死 fd 空转
	sleep 1
done
