#!/usr/bin/env bash
# serial-logger.sh — 跨重启自动重连抓取平板调试串口 (ttyACM)。
# 用法: scripts/serial-logger.sh [LOGPATH]  (默认 logs/serial-<ts>.log)
# 停止: kill "$(cat /tmp/q28_serial_logger.pid)"
set -u
PORT="${SERIAL_PORT:-/dev/ttyACM0}"
LOG="${1:-logs/serial-$(date +%Y%m%d-%H%M%S).log}"
PIDF=/tmp/q28_serial_logger.pid
trap "pkill -P $$ 2>/dev/null; exit 0" TERM INT
echo $$ > "$PIDF"
mkdir -p "$(dirname "$LOG")"
echo "[serial-logger] pid=$$ port=$PORT -> $LOG"
while true; do
  if [ -e "$PORT" ]; then
    stty -F "$PORT" 115200 raw -echo 2>/dev/null || true
    printf "\n===== serial opened %s =====\n" "$(date +%H:%M:%S)" >> "$LOG"
    # 用 exec 方式让 cat 成为本 while 的阻塞子进程；断开时 cat 退出→回到循环重连
    cat "$PORT" >> "$LOG" 2>/dev/null & CPID=$!
    wait $CPID 2>/dev/null
    kill $CPID 2>/dev/null
    printf "\n===== serial closed %s =====\n" "$(date +%H:%M:%S)" >> "$LOG"
  fi
  sleep 0.3
done
