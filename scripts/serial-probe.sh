#!/bin/bash
# serial-probe.sh — 独占串口并「敲一下」：把当前 ttyACM0 的输出与回声抓下来
#
# 为什么需要：设备只有一条控制台（ttyGS0 → 主机 /dev/ttyACM0）。多个读者会**分食**同一条流，
# 日志会出现空洞（2026-10-26 实测：常驻 fanout + 临时 cat 并存 ⇒ 关键行丢在另一个读者手里）。
# 本脚本：先杀掉所有 ttyACM 读者 → 独占打开 → 发一个换行 → 抓 N 秒原始输出。
#
# 用法（需要 root 或 dialout 组）：
#   sudo bash scripts/serial-probe.sh [秒数]        # 默认 6 s
#   sudo bash scripts/serial-probe.sh 15 /dev/ttyACM0
set -uo pipefail
SECS=${1:-6}
PORT=${2:-/dev/ttyACM0}
OUT=/tmp/serial-probe-$(date +%H%M%S).log

[ -c "$PORT" ] || { echo "没有 $PORT（设备不在或 gadget 未起）" >&2; exit 2; }

echo "[probe] 结束现有读者（避免分食同一条流）"
# 注意：不能用 `pkill -f ttyACM0` —— 会匹配到自己这条命令并把 shell 杀掉
# （PITFALLS 的 pkill-self-match）。这里按 /proc 精确比对 argv，排除自身与父进程。
self=$$
for pid in $(pgrep -f 'ttyACM' 2>/dev/null); do
	[ "$pid" = "$self" ] && continue
	cmd=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null) || continue
	case "$cmd" in
		*pkill*|*serial-probe*) continue ;;
		*cat\ /dev/ttyACM*|*serial-fanout*|*serial-capture*) kill "$pid" 2>/dev/null && echo "[probe] killed $pid: $cmd" ;;
	esac
done
sleep 1

echo "[probe] 独占 $PORT，抓 ${SECS}s，并送一个换行触发回声 → $OUT"
exec 3<>"$PORT" || exit 1
printf '\n' >&3 2>/dev/null || true
timeout "$SECS" cat <&3 > "$OUT" 2>/dev/null
exec 3<&- 3>&- 2>/dev/null
echo "[probe] $(stat -c %s "$OUT" 2>/dev/null || echo 0) 字节"
echo "----- 内容（原始） -----"
tr -d '\r' < "$OUT" | tail -60
echo "----- 结束 -----"
