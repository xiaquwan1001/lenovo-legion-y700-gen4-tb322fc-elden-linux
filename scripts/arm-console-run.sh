#!/bin/bash
# arm-console-run.sh — 零写盘启动一个显示臂，用串口内核控制台取证（不依赖 SSH）。
# usage: scripts/arm-console-run.sh <boot.img> <label> [wait_s]
# 设备必须已在 fastboot。输出 logs/arm-<label>-<ts>/{console.log,verdict.txt,...}
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT"
IMG=${1:?usage: arm-console-run.sh <boot.img> <label> [wait_s]}
LABEL=${2:?}
WAIT=${3:-200}
TTY=${TTY:-/dev/ttyACM0}
OUT=logs/arm-$LABEL-$(date +%Y%m%d-%H%M%S); mkdir -p "$OUT"
LOG=$OUT/console.log; : > "$LOG"

if ! fastboot devices 2>/dev/null | grep -q .; then
	echo "[arm] ❌ 设备不在 fastboot（需要物理 POR / Vol-+Power）" >&2; exit 2
fi
fastboot devices | tee "$OUT/fastboot-before.txt"

# 先清掉遗留的串口读进程（tty 只能被一个读者持有，否则 boot 日志抓不到）
for p in $(pgrep -f 'cat /dev/tty[A]CM0' 2>/dev/null); do kill "$p" 2>/dev/null; done
sleep 1

# 串口读线程：设备重启后 tty 会消失/重建，循环重连；只读，不写入设备
(
	while :; do
		[ -e "$TTY" ] && cat "$TTY" >> "$LOG" 2>/dev/null
		sleep 1
	done
) &
RD=$!
echo "$RD" > "$OUT/reader.pid"
trap 'kill "$RD" 2>/dev/null' EXIT

echo "[arm] boot $IMG  (label=$LABEL, wait=${WAIT}s)"
timeout 200 fastboot boot "$IMG" 2>&1 | tail -2 | tee "$OUT/fastboot-boot.log"
sleep "$WAIT"
kill "$RD" 2>/dev/null
sed -i 's/\r$//' "$LOG" 2>/dev/null

L1=$(grep -Ec 'command DMA timeout|bonded command DMA failed|Failed to initialize panel|sending dcs data .* failed' "$LOG" 2>/dev/null || echo 0)
L2=$(grep -Ec 'ctl [0-9]+ reset failure|frame done timeout|vblank wait timed out|vblank timeout' "$LOG" 2>/dev/null || echo 0)
PANEL=$(grep -c 'panel prepared' "$LOG" 2>/dev/null || echo 0)
UTS=$(grep -m1 -o '7\.[0-9][^ ]*' "$LOG" 2>/dev/null || echo unknown)
if [ "$L1" -gt 0 ]; then V=L1FAIL; elif [ "$L2" -gt 0 ]; then V=L2STORM; else V=NO-SIGNATURE; fi
{
	echo "label=$LABEL"
	echo "image=$IMG"
	echo "uts=$UTS"
	echo "L1=$L1 L2=$L2 panel_prepared=$PANEL"
	echo "VERDICT=$V"
} | tee "$OUT/verdict.txt"
echo "[arm] console=$LOG  ($(wc -l < "$LOG") lines)"
echo "[arm] OUT=$OUT"
