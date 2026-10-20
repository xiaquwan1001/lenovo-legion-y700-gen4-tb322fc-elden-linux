#!/bin/bash
# suspend-boot-panic-capture.sh — 把「CONFIG_SUSPEND=y 后启动即死」(vk128/vk129) 变成可判定的 panic 栈
#
# 背景（reports/suspend-enable-vk128-vk129-fail-20261018.md）：
#   vk128/vk129 = 在机 vk127 config + 只加 suspend 组（15 项 diff），两次上机都是
#   「fastboot 交接后只亮背光、SSH 不通、约十几秒后关机」。已排除的替代解释：
#     · 模块树失配 —— 已从镜像内读出 UTS = 7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty，
#       与 vk127 逐字相同（2026-10-19 实查）；
#     · 配置污染 —— vk129 的 diff 只剩 15 项 suspend 连带项。
#   尚未取到的东西：**panic 栈**（`/sys/fs/pstore` 当时未查，报告 §3 写明未执行）。
#
# 本脚本做一件事：带着证据采集能力刷一次 armed 镜像，然后无论如何回滚到 vk127。
#   采集通道两条：
#     ① 串口 console=ttyGS0 → 宿主 /dev/ttyACM0（cmdline 已带；若挂在 gadget 起来之前则拿不到）
#     ② ramoops/pstore（DT ramoops@c2000000 16 KiB、CONFIG_PSTORE_RAM=y、printk.always_kmsg_dump 已在 cmdline）
#        —— 这条与串口无关，panic 一定能留住（除非不是 panic 而是纯挂死）
#
# 用法：
#   scripts/suspend-boot-panic-capture.sh                  # 默认 --arm vk129
#   scripts/suspend-boot-panic-capture.sh --arm vk128
#   scripts/suspend-boot-panic-capture.sh --wait 300       # 等设备回来的上限（秒）
#   scripts/suspend-boot-panic-capture.sh --no-rollback    # 调试用：失败后不自动回滚（危险）
#
# 纪律（PITFALLS）：
#   · fastboot 客户端不接 head/grep -q（SIGPIPE 会卡 gadget，#199）→ 一律先落文件再判
#   · 判活只认 SSH + uname；`fastboot boot` 在本机不可靠（RAM 内核不生效）⇒ 必须 flash
#   · 刷完必须能回滚：rollback 镜像 bootslot-b/boot_b-vk127.img 缺失时直接拒绝执行
set -uo pipefail
ROOT=${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
ARM=vk129
WAIT=${WAIT:-240}
ROLLBACK=1
DEV=root@192.168.7.1
SERIAL_PORT=${SERIAL_PORT:-/dev/ttyACM0}
TS=$(date +%Y%m%d-%H%M%S)
LOG=$ROOT/logs/suspend-capture-$TS.log
SLOG=$ROOT/logs/suspend-capture-$TS.serial.log
RUNDIR=$ROOT/logs/suspend-capture-$TS.pstore
mkdir -p "$ROOT/logs" "$RUNDIR"
exec > >(tee -a "$LOG") 2>&1

while [ $# -gt 0 ]; do
	case "$1" in
		--arm) ARM=$2; shift 2;;
		--wait) WAIT=$2; shift 2;;
		--no-rollback) ROLLBACK=0; shift;;
		*) echo "unknown arg: $1"; exit 64;;
	esac
done

IMG=$ROOT/bootslot-b/boot_b-$ARM.img
RB=$ROOT/bootslot-b/boot_b-vk127.img
echo "### suspend boot panic capture $(date '+%F %T')  arm=$ARM  log=$LOG"

[ -f "$IMG" ] || { echo "❌ 缺 armed 镜像 $IMG"; exit 1; }
[ -f "$RB" ]  || { echo "❌ 缺回滚镜像 $RB（拒绝执行：刷坏就没有退路）"; exit 1; }

# 所有 fastboot 调用：单条、不接管道
FB() { timeout 30 fastboot "$@" >"$RUNDIR/fb.txt" 2>&1; local rc=$?; sed 's/^/    fastboot> /' "$RUNDIR/fb.txt"; return $rc; }
SSH() { timeout 25 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 -o BatchMode=yes "$DEV" "$@" 2>/dev/null; }

fb_present() { timeout 15 fastboot devices >"$RUNDIR/dev.txt" 2>&1; grep -q HA2EXB0E "$RUNDIR/dev.txt"; }
ssh_alive()  { SSH true; }

wait_ssh() { local t=0; while [ "$t" -lt "${1:-$WAIT}" ]; do ssh_alive && return 0; sleep 5; t=$((t+5)); done; return 1; }

# --- 串口记录（跨重连）---
start_serial() {
	[ -e "$SERIAL_PORT" ] || { echo "⚠️ 无 $SERIAL_PORT：只能靠 ramoops"; return 0; }
	( while true; do
		stty -F "$SERIAL_PORT" 115200 raw -echo 2>/dev/null || true
		printf "\n===== serial open %s =====\n" "$(date +%H:%M:%S)" >> "$SLOG"
		cat "$SERIAL_PORT" >> "$SLOG" 2>/dev/null
		sleep 0.3
	  done ) & SER_PID=$!
	echo "serial logger pid=$SER_PID -> $SLOG"
}
stop_serial() { [ -n "${SER_PID:-}" ] && kill "$SER_PID" 2>/dev/null && pkill -P "$SER_PID" 2>/dev/null; return 0; }

rollback() {
	[ "$ROLLBACK" -eq 1 ] || { echo "⚠️ --no-rollback：设备可能停在 $ARM"; return 0; }
	echo "-- 回滚 boot_b → vk127"
	if ! fb_present; then
		echo "   不在 fastboot，尝试从系统内切："
		ssh_alive && SSH 'reboot bootloader' >/dev/null 2>&1
		local t=0; while [ $t -lt 120 ]; do fb_present && break; sleep 5; t=$((t+5)); done
	fi
	fb_present || { echo "❌ 回滚失败：设备既不在 fastboot 也不在 SSH，需要人工按键（音量- + 电源）"; return 1; }
	FB flash boot_b "$RB" || { echo "❌ 回滚 flash 失败"; return 1; }
	FB reboot || true
	wait_ssh "$WAIT" || { echo "❌ 回滚后 SSH 未起来"; return 1; }
	echo "✅ 回滚完成：$(SSH 'uname -r' | tr -d '\r')"
}

cleanup() { stop_serial; }
trap cleanup EXIT

# --- 0. 前置 ---
fb_present || { echo "❌ 设备不在 fastboot（先让用户进 BL：关机后音量- + 电源）"; exit 1; }
echo "-- 当前 boot_b 内核（回滚前确认可回退目标）" 
SSH 'uname -r' | sed 's/^/    /' || true
echo "-- armed 镜像 $(basename "$IMG") sha=$(sha256sum "$IMG" | cut -d' ' -f1)"

# --- 1. 刷 armed 镜像 ---
start_serial
FB flash boot_b "$IMG" || { echo "❌ flash 失败"; exit 1; }
FB reboot || true

# --- 2. 等设备回来 / 观察死亡 ---
echo "-- 等待设备（上限 ${WAIT}s）：成功=SSH 可用；失败=只亮背光/关机/回落到 fastboot"
DEADLINE=$((SECONDS + WAIT))
VERDICT=UNKNOWN
while [ $SECONDS -lt $DEADLINE ]; do
	if ssh_alive; then
		U=$(SSH 'uname -r' | tr -d '\r')
		case "$U" in
			*"${ARM}"*) VERDICT=BOOTED; echo "    SSH 可用，uname=$U ⇒ 本次其实起来了";;
			*)           VERDICT=FALLBACK; echo "    SSH 可用但 uname=$U ⇒ 回落到别的内核";;
		esac
		break
	fi
	if grep -qE "Kernel panic|Internal error|Unable to handle kernel|synchronous external abort" "$SLOG" 2>/dev/null; then
		VERDICT=PANIC_ON_SERIAL; echo "    串口出现 panic 关键字"; break
	fi
	sleep 5
done
[ "$VERDICT" = UNKNOWN ] && echo "    ${WAIT}s 内没有 SSH ⇒ 与历史两次同型（启动早期死亡）"
sleep 5
stop_serial

# --- 3. 取证 ---
echo "-- 串口日志：$SLOG"
[ -s "$SLOG" ] && { echo "   末尾 40 行："; tail -40 "$SLOG" | sed 's/^/    | /'; } || echo "    (空：内核在 gadget 起来前就没了)"

echo "-- 尝试取 pstore/ramoops（需设备已回到系统；这一步与串口是否可用无关）"
if ! ssh_alive; then
	echo "    设备不可达 ⇒ 先恢复：让用户长按电源 10 s 关机再开，或音量- + 电源进 BL"
	echo "    恢复后单独跑： ssh $DEV 'mount -t pstore pstore /sys/fs/pstore; ls -la /sys/fs/pstore; cat /sys/fs/pstore/dmesg-ramoops-0'"
else
	SSH 'mount -t pstore pstore /sys/fs/pstore 2>/dev/null; ls /sys/fs/pstore 2>/dev/null' > "$RUNDIR/pstore-list.txt"
	sed 's/^/    /' "$RUNDIR/pstore-list.txt"
	if grep -q . "$RUNDIR/pstore-list.txt"; then
		for f in $(SSH 'ls /sys/fs/pstore' | tr -d '\r'); do
			SSH "cat /sys/fs/pstore/$f" > "$RUNDIR/$f" 2>/dev/null
			echo "    → $RUNDIR/$f ($(wc -l < "$RUNDIR/$f") 行)"
		done
		echo "== ramoops 摘要（panic 栈应在其中）=="
		grep -hE "Kernel panic|Internal error|Call trace|pc :|lr :|\[<" "$RUNDIR"/dmesg-ramoops-* 2>/dev/null | head -40 | sed 's/^/    /'
	else
		echo "    pstore 空 ⇒ 不是 panic（更可能是早期挂死/掉电），下一步：改 cmdline panic=0 保留现场 + 只用串口"
	fi
fi

# --- 4. 回滚 ---
rollback || true

echo
echo "### 结论记录"
echo "    arm=$ARM  verdict=$VERDICT"
echo "    log=$LOG"
echo "    serial=$SLOG"
echo "    pstore=$RUNDIR"
echo "  下一步判定："
echo "    · pstore 有栈      → 读栈定性（genpd/PM 路径 vs 别的），单变量二分该栈所在子系统"
echo "    · 串口有栈无 pstore → 同上，以串口为准"
echo "    · 两处都没有        → 不是 panic；改 panic=0 + 串口，或用 ramoops 加大到 256 KiB 重建一次"
exit 0
