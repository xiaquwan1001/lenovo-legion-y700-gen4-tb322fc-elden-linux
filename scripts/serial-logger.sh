#!/usr/bin/env bash
# ★ RETIRED-for-forensics（2026-11-23，D5 批 4 / reports/scripts-hardening-4-20261123.md §2）：**保留文件，但退出「取证工具」序列**。
#   为什么：PITFALLS #622 —— 本件的 `cat $PORT &` + 重连循环在本机会 open/close 狂抖（拿 EOF 立即退出），
#   日志里只有 opened/closed 标记、真数据 0 行；另有孤儿 `cat` 占住 /dev/ttyACM0 的已知隐患
#   （.pi/memory/failures-device.md:95）。⇒ 用它取 panic / Q28 坏发证据会得出**假阴性**。
#   ✓ 取证真源 = `python3 scripts/serial-tap.py`（一次 open 长期持有 + select + 断线重开一次）。
#   ✓ 2026-11-24：`DEVICE/README.md` 的「主机串口 logger」指针已改为 serial-tap.py（审计 §5 批 3 第 12 条收口）。
#
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
