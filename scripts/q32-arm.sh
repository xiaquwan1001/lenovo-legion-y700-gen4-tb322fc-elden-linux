#!/bin/bash
# q32-arm.sh — Q32 三臂实验的单发执行器（暖起 vs 冷起）。
#
# 背景：reports/q32-warm-vs-cold-preresearch-20261023.md（§2 复位入口 / §3 ABL 交接 framebuffer / §5 三臂）
# 判据：同一臂内 ≥2 发**结果一致**才算证据；跨臂差异要按「固件有没有留活显示」(FW_LIVE_FB) 解释，
#       不接受「因为暖所以坏」。
#
# 用法：
#   scripts/q32-arm.sh w1 [n=2] [wait_s=900]   # 暖复位（PSCI SYSTEM_RESET2 vendor 0x80010001）
#   scripts/q32-arm.sh w2 [n=1] [wait_s=1500]  # 暖复位（架构 SYSTEM_RESET，rev -f）★可能落 STORM ~11 min 不可达
#   scripts/q32-arm.sh c1 [n=2] [wait_s=900]   # 真 POR：脚本喊话，**用户物理长按断电 10 s 再开机**
#
# 每发产出（与 Q28 同口径，可混用）：
#   reports/artifacts/q32-boot-<bootid8>.txt        ← Q32 判据（复位深度 / FW_LIVE_FB / simpledrm）
#   reports/artifacts/q28-clkdiag-q32-<arm>-<bid8>.txt
#   reports/trials/<UTC>-q32<arm>-r<N>/             ← env/dmesg/probe/q32/clkdiag
#   reports/trials/<UTC>-q32<arm>-r<N>.json         ← trial record（reset=warm|por）
#
# 纪律：w1/w2 是**复位操作**（不改分区），过 lib-boot-ready 就绪门；c1 是**物理动作**，脚本只等不按。
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
ARM=${1:?usage: $0 w1|w2|c1 [n] [wait_s]}
N=${2:-2}
WAIT=${3:-900}
case "$ARM" in w2) [ -n "${3:-}" ] || WAIT=1500 ;; esac
IMAGE=${IMAGE:-$ROOT/bootslot-b/boot_b-vk152.img}
# 复位深度证据：pstore 在本机实测**恒为空**（PITFALLS #197/#374）⇒ 串口 relay 才是唯一可靠通道。
# 该文件由 root 常驻服务（scripts/install-serial-logger.sh + serial-fanout.sh）以 0644 写入。
SERIAL_LOG=${SERIAL_LOG:-/var/log/elden-serial/ttyACM0.log}
SERIAL_OFF=0
SSH="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=6 root@192.168.7.1"
TDIR="$ROOT/reports/trials"
ARTS="$ROOT/reports/artifacts"
mkdir -p "$ARTS" "$TDIR"
S() { timeout "${2:-20}" $SSH "$1" 2>/dev/null; }   # lib-boot-ready.sh 需要
boot_id() { S 'cat /proc/sys/kernel/random/boot_id' 12 | tr -d '\r'; }
uptime_s() { S 'cut -d" " -f1 /proc/uptime' 12 | tr -d '\r'; }

pick_target() { $SSH true 2>/dev/null && { echo root@192.168.7.1; return 0; }; return 1; }

fastboot_wait() {  # 等 fastboot 出现（单条命令，不接管道，PITFALLS #199）
	local i
	for i in $(seq 1 30); do
		if fastboot devices 2>/dev/null | grep -q . ; then return 0; fi
		sleep 2
	done
	return 1
}

collect() {  # collect <arm> <round> <boot_id> <reset_kind>
	local arm=$1 r=$2 BID=$3 reset=$4
	local B8; B8=$(printf '%s' "$BID" | cut -c1-8)
	local stamp logdir q32_rel cl_rel
	stamp=$(date -u +%Y%m%dT%H%M%SZ)
	logdir="$TDIR/${stamp}-q32${arm}-r$r"
	mkdir -p "$logdir"

	# ★Q32 证据必须**先**取：pstore（上个启动的 console 尾部）读后即删
	$SSH "RESET_DECLARED=$reset sh -s" < "$ROOT/scripts/q32-boot-evidence.sh" >/dev/null 2>&1
	q32_rel="reports/artifacts/q32-boot-$B8.txt"
	$SSH "cat /var/tmp/q32-boot-$B8.txt" > "$ROOT/$q32_rel" 2>/dev/null
	$SSH "cat /var/tmp/q32-pstore-$B8.log" > "$logdir/pstore-prev-boot.log" 2>/dev/null

	# ★串口：从复位前的偏移开始截取 → 上一个内核在复位路径上的打印（含 vendor reset_type）
	local SER_TOK=0 SER_BYTES=0
	if [ -r "$SERIAL_LOG" ]; then
		tail -c +$((SERIAL_OFF + 1)) "$SERIAL_LOG" > "$logdir/serial-delta.log" 2>/dev/null || true
		SER_BYTES=$(wc -c < "$logdir/serial-delta.log" 2>/dev/null | head -1); SER_BYTES=${SER_BYTES:-0}
		SER_TOK=$(grep -ac 'SYSTEM_RESET2 vendor reset_type' "$logdir/serial-delta.log" 2>/dev/null | head -1); SER_TOK=${SER_TOK:-0}
		grep -aE 'SYSTEM_RESET2 vendor reset_type|reboot: |Restarting system|Power down' "$logdir/serial-delta.log" 2>/dev/null | tail -6 > "$logdir/serial-reset.txt"
	fi

	# Q28 同口径（复位敏感：坏发即 NOCARD/STORM）
	cl_rel="reports/artifacts/q28-clkdiag-q32-$arm-$B8.txt"
	$SSH 'bash -s' < "$ROOT/scripts/q28-clkdiag.sh" >/dev/null 2>&1
	$SSH "cat /var/tmp/q28-clkdiag-$B8.txt" > "$ROOT/$cl_rel" 2>/dev/null

	$SSH 'uname -a; cat /proc/uptime; cat /proc/cmdline' > "$logdir/env.txt" 2>&1
	$SSH 'dmesg' > "$logdir/dmesg.txt" 2>&1
	$SSH 'sh -s' < "$ROOT/scripts/q28-devprobe.sh" > "$logdir/probe.txt" 2>&1
	cp -f "$ROOT/$q32_rel" "$logdir/" 2>/dev/null
	cp -f "$ROOT/$cl_rel" "$logdir/" 2>/dev/null
	local VERDICT FW RESET_D VPROOF
	VERDICT=$(grep -oE 'VERDICT=[A-Z]+' "$logdir/probe.txt" | head -1 | cut -d= -f2); VERDICT=${VERDICT:-UNKNOWN}
	FW=$(grep -oE 'FW_LIVE_FB=[a-z]+' "$ROOT/$q32_rel" | head -1 | cut -d= -f2); FW=${FW:-unknown}
	RESET_D=$(grep -oE 'RESET_DEPTH=[a-z_]+' "$ROOT/$q32_rel" | head -1 | cut -d= -f2); RESET_D=${RESET_D:-unknown}
	# vendor 复位路径的**结果级**证明：进得了 fastboot 只可能来自 reset_type=0x80010001（架构 SYSTEM_RESET 只会正常启动）
	if [ "$arm" = w1 ]; then VPROOF="yes(fastboot_reached)"; else VPROOF="n/a"; fi
	printf 'boot_id=%s\nimage=%s\narm=%s\nreset=%s\nverdict=%s\nfw_live_fb=%s\nreset_depth=%s\nvendor_path_proof=%s\nserial_vendor_reset=%s\nserial_delta_bytes=%s\n' \
		"$BID" "$(basename "$IMAGE")" "$arm" "$reset" "$VERDICT" "$FW" "$RESET_D" "$VPROOF" "$SER_TOK" "$SER_BYTES" > "$logdir/README.txt"

	TAB=root@192.168.7.1 bash "$ROOT/scripts/trial.sh" record --label "q32${arm}-r$r" --image "$IMAGE" \
		--reset "$reset" --deploy none --probe q28 --verdict "$VERDICT" --logdir "$logdir" \
		--note "Q32 arm=$arm 复位深度=$RESET_D FW_LIVE_FB=$FW serial_vendor_reset=$SER_TOK（boot_id=$B8）" >/dev/null 2>&1 \
		|| echo "  ⚠ trial 记录失败（继续）" >&2

	echo "  ARM=$arm r$r  VERDICT=$VERDICT  FW_LIVE_FB=$FW  RESET_DEPTH=$RESET_D  vendor_path_proof=$VPROOF  serial_vendor_reset=$SER_TOK (delta ${SER_BYTES}B)"
	if [ "$SER_TOK" -lt 1 ]; then
		# 已知：本机 console 是 USB gadget，复位前那个 pr_info 常在主机取走前就断链 ⇒ 串口缺行是常态
		echo "  ℹ 串口无 vendor reset 打印（gadget console 复位瞬间断链=已知现象）⇒ 复位深度以结果为准：$VPROOF"
	fi
	if [ "$SER_BYTES" -lt 200 ]; then
		echo "  ⚠ 串口增量仅 ${SER_BYTES}B ⇒ 采集可能没在工作（PITFALLS #359/#374 假阴性），复位深度不可判定" >&2
	fi
	echo "  → $q32_rel | $cl_rel | $logdir"
}

# ---------------- 前置门 ----------------
. "$ROOT/scripts/lib-boot-ready.sh"
case "$ARM" in w1|w2) boot_ready_or_die ;; esac
T=$(pick_target) || { echo "❌ 设备不可达（先 elden-net.sh）" >&2; exit 1; }
PREV=$(boot_id); [ -n "$PREV" ] || { echo "❌ 读不到 boot_id" >&2; exit 1; }
echo "[Q32/$ARM] 起点 boot_id=${PREV:0:8} uptime=$(uptime_s)s 镜像=$(basename "$IMAGE") 计划 $N 发"

await_new_boot() {  # await_new_boot <round>
	local r=$1 deadline bid up
	deadline=$(( $(date +%s) + WAIT ))
	while [ "$(date +%s)" -lt "$deadline" ]; do
		bid=$(boot_id)
		if [ -n "$bid" ] && [ "$bid" != "$PREV" ]; then
			up=$(uptime_s)
			while [ "${up%.*}" -lt 12 ] 2>/dev/null; do sleep 2; up=$(uptime_s); done
			PREV=$bid
			collect "$ARM" "$r" "$bid" "$RESET_KIND"
			return 0
		fi
		sleep 4
	done
	echo "❌ Round $r 超时：${WAIT}s 内无新 boot_id" >&2
	return 1
}

for k in $(seq 1 "$N"); do
	echo
	echo "=============== Q32/$ARM  Round $k / $N ==============="
	# 复位前锚定串口偏移（复位路径上的打印从这里往后找）
	if [ -r "$SERIAL_LOG" ]; then SERIAL_OFF=$(stat -c%s "$SERIAL_LOG" 2>/dev/null || echo 0); fi
	echo "  serial_off=$SERIAL_OFF ($(basename "$SERIAL_LOG"))"
	case "$ARM" in
	w1)
		echo "→ 暖复位 W1：eldroid-bootctl reboot bootloader → fastboot reboot"
		RESET_KIND=warm
		S 'sync' 30 || true
		S 'eldroid-bootctl reboot bootloader 2>/dev/null || reboot bootloader' 15 || true
		if ! fastboot_wait; then echo "❌ fastboot 没出现（PITFALLS #143 / 通道丢失）" >&2; exit 1; fi
		echo "  fastboot 在；发 fastboot reboot（单条，不接管道）"
		fastboot reboot >/dev/null 2>&1 || true
		;;
	w2)
		echo "→ 暖复位 W2：reboot -f（架构 SYSTEM_RESET）。★若落 STORM 可能 ~11 min 不可达（PITFALLS #215）"
		RESET_KIND=warm
		S 'sync' 30 || true
		S 'reboot -f' 8 || true
		;;
	c1)
		echo "→ 真 POR C1：请**现在**物理长按电源键 ~10 s 关机，再短按开机（不要用 reboot！）"
		RESET_KIND=por
		;;
	esac
	await_new_boot "$k" || exit 1
done

echo
echo "[Q32/$ARM] 完成 $N 发。汇总："
for d in $(ls -dt "$TDIR"/*-q32${ARM}-r* 2>/dev/null | head -"$N"); do
	printf '  %s  %s\n' "$(basename "$d")" "$(grep -E 'verdict=|fw_live_fb=|reset_depth=' "$d/README.txt" 2>/dev/null | tr '\n' ' ')"
done
echo "★ 判据：同臂内 ≥2 发一致才算证据；跨臂差异按 FW_LIVE_FB 解释（reports/q32-warm-vs-cold-preresearch-20261023.md §5）"
