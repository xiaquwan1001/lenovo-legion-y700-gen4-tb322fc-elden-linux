#!/bin/bash
# serial-fanout.sh — 读一个 tty 并把内容追加到文件（供 systemd 服务常驻运行）。
#
# 与 scripts/serial-logger.sh 的区别：这是**面向 systemd 的一次性前台进程**，
# 由 systemd 负责重连（Restart=always + BindsTo=设备节点），日志落 0644 普通文件，
# 让非 dialout 组的用户也能读（PITFALLS #359）。
#
# 用法： serial-fanout.sh [PORT] [LOGFILE]
set -u
PORT=${1:-/dev/ttyACM0}
LOG=${2:-/var/log/elden-serial/$(basename "$PORT").log}

mkdir -p "$(dirname "$LOG")"
echo "===== serial-fanout start $(date -Is) port=$PORT log=$LOG =====" >> "$LOG"

# 串口参数：115200 8N1、raw、无回显、不参与流控。
# 失败时**必须报错退出**，交给 systemd 重试 —— 静默继续会让日志为空而看起来像"没输出"。
stty -F "$PORT" 115200 raw -echo -crtscts 2>>"$LOG" || {
	echo "===== stty failed on $PORT $(date -Is) =====" >> "$LOG"
	exit 1
}

# exec 后 cat 是本服务的唯一子进程；tty 断开时 cat 退出 → 本脚本退出 → systemd 重开。
exec cat "$PORT" >> "$LOG"
