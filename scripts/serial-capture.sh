#!/bin/bash
# serial-capture.sh — 等 USB 串口节点出现后把内容落盘（给「设备 boot 起来但不知道卡在哪」用）
#
# 为什么需要：设备 reboot / fastboot boot 时 /dev/ttyACM0 会先消失再出现，
# `cat /dev/ttyACM0` 早跑一步就立即退出、日志 0 字节（2026-10-26 实测踩到）。
# 本脚本轮询等节点，出现后再 cat 到带时间戳的文件，并同时打印。
#
# 用法：
#   scripts/serial-capture.sh                  # 等最多 180 s，写到 /tmp/serial-HHMMSS.log
#   RECV_TIMEOUT=600 scripts/serial-capture.sh # 抓 10 分钟
#   SERIAL_PORT=/dev/ttyACM1 scripts/serial-capture.sh
# 停止：kill %1 / pkill -f serial-capture.sh（不会自杀，见 PITFALLS pkill-self-match）
set -uo pipefail
PORT=${SERIAL_PORT:-/dev/ttyACM0}
WAIT=${WAIT_TIMEOUT:-180}     # 等节点出现的最长秒数
RECV=${RECV_TIMEOUT:-600}     # 节点出现后抓多久
OUT=${OUT:-/tmp/serial-$(date +%H%M%S).log}

# DETACH=1：自分离重跑（给「先起捕获，再去 reboot / fastboot boot」的顺序用，
# 否则捕获会挂在调用它的 shell 上，设备一 reboot 就被一起收掉）。
if [ "${DETACH:-0}" = 1 ]; then
	DETACH=0 setsid nohup env DETACH=0 OUT="$OUT" bash "$0" >>/tmp/serial-capture-$RANDOM.log 2>&1 </dev/null &
	echo "started pid=$! log=$OUT"
	exit 0
fi

printf '[serial] 等 %s 出现（最多 %ss）…\n' "$PORT" "$WAIT"
i=0
while [ ! -c "$PORT" ]; do
	[ "$i" -ge "$WAIT" ] && { printf '[serial] %s 一直没出现，放弃（日志 %s）\n' "$PORT" "$OUT"; exit 2; }
	sleep 1; i=$((i + 1))
done
printf '[serial] 节点已出现，开始抓 %ss → %s\n' "$RECV" "$OUT"
timeout "$RECV" cat "$PORT" 2>/dev/null | tee "$OUT"
printf '\n[serial] 抓包结束：%s（%s 字节）\n' "$OUT" "$(stat -c %s "$OUT" 2>/dev/null || echo 0)"
