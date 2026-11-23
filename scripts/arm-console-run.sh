#!/bin/bash
# arm-console-run.sh — 零写盘启动一个显示臂，用串口内核控制台取证（不依赖 SSH）。
# usage: scripts/arm-console-run.sh <boot.img> <label> [wait_s]
# 设备必须已在 fastboot。输出 logs/arm-<label>-<ts>/{console.log,verdict.txt,...}
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT"
# ★ 2026-11-24（审计 §3 未做项 #1/#2 收口）：主机 fastboot 不在 PATH（#699）⇒ 统一走 lib-hosttools
. "$ROOT/scripts/lib-hosttools.sh"
ensure_hosttools --quiet
[ -n "${FB_BIN:-}" ] || { echo "[arm] ❌ 宿主机找不到 fastboot（lib-hosttools 已查 PATH 与 ~/.local/opt/platform-tools）" >&2; exit 2; }

IMG=${1:?usage: arm-console-run.sh <boot.img> <label> [wait_s]}
LABEL=${2:?}
WAIT=${3:-200}
TTY=${TTY:-/dev/ttyACM0}
OUT=logs/arm-$LABEL-$(date +%Y%m%d-%H%M%S); mkdir -p "$OUT"
LOG=$OUT/console.log; : > "$LOG"

# ★ #584（PITFALLS #584）：此处原为「fastboot devices 取不到全量就交给 grep -q 判空」的管道写法
# —— 管道把 SIGPIPE 送回 fastboot 客户端，打断设备侧 bulk 通道 ⇒ 之后 `fastboot devices` 恒空、
# `fastboot boot` 失败。
# 改成「取值式」：一次收全量输出到变量，再判空（不接任何管道）；同一发输出直接复用为
# fastboot-before.txt（不再为了打印多叫一次 fastboot）。
FB_OUT=$(timeout -k 5 10 "$FB_BIN" devices 2>&1); FB_RC=$?
case "$FB_OUT" in
*fastboot*) : ;;
*)
	case "$FB_RC" in
	127) echo "[arm] ❌ 宿主机找不到 fastboot（#699：在 ~/.local/opt/platform-tools/fastboot）" >&2 ;;
	124) echo "[arm] ❌ fastboot devices 超时（10 s）——USB/bulk 通道卡住，先物理 POR 再试" >&2 ;;
	*)   echo "[arm] ❌ 设备不在 fastboot（需要物理 POR / Vol-+Power）" >&2 ;;
	esac
	printf 'rc=%s raw=%s\n' "$FB_RC" "${FB_OUT:-<空>}" >&2
	exit 2 ;;
esac
printf '%s\n' "$FB_OUT" > "$OUT/fastboot-before.txt"

# 先清掉遗留的串口读进程（tty 只能被一个读者持有，否则 boot 日志抓不到）
for p in $(pgrep -f 'serial-tap.py --port /dev/tty[A]CM0' 2>/dev/null); do kill "$p" 2>/dev/null; done
sleep 1

# 串口读线程：2026-11-24 换 serial-tap.py（PITFALLS #622：`cat $TTY` 循环在 ttyACM 无数据时
# open/close 狂抖、真数据 0 行 ⇒ 用它会得到假阴性判定）。serial-tap = 一次 open 长期持有 + select，
# 设备侧 gadget 重建时只重开一次。只读，不写入设备。
(
	exec python3 "$ROOT/scripts/serial-tap.py" --port "$TTY" --out "$LOG"
) >"$OUT/serial-tap.out" 2>&1 &
RD=$!
echo "$RD" > "$OUT/reader.pid"
trap 'kill "$RD" 2>/dev/null' EXIT

echo "[arm] boot $IMG  (label=$LABEL, wait=${WAIT}s)"
timeout 200 "$FB_BIN" boot "$IMG" 2>&1 | tail -2 | tee "$OUT/fastboot-boot.log"
sleep "$WAIT"
kill "$RD" 2>/dev/null
sed -i 's/\r$//' "$LOG" 2>/dev/null

# grep -c 无命中时自己就打印 0（rc=1），旧写法 `|| echo 0` 会把它变成 "0\n0" ⇒
# `[ "$L1" -gt 0 ]` 报「需要整数」、verdict.txt 里写出 "L1=0⏎0"（判据被污染）。
L1=$(grep -Ec 'command DMA timeout|bonded command DMA failed|Failed to initialize panel|sending dcs data .* failed' "$LOG" 2>/dev/null); [ -n "$L1" ] || L1=0
L2=$(grep -Ec 'ctl [0-9]+ reset failure|frame done timeout|vblank wait timed out|vblank timeout' "$LOG" 2>/dev/null); [ -n "$L2" ] || L2=0
PANEL=$(grep -c 'panel prepared' "$LOG" 2>/dev/null); [ -n "$PANEL" ] || PANEL=0
UTS=$(grep -m1 -o '7\.[0-9][^ ]*' "$LOG" 2>/dev/null); [ -n "$UTS" ] || UTS=unknown
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
