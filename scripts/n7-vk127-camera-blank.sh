#!/bin/bash
# n7-vk127-camera-blank.sh — N7：在 vk127（7.3-rc7 重放线）上跑 Q24 配方
#
# 背景：N5 在 vk64（7.2 血统）上第 2 发致死；M1-7.3 同配方 12/12 存活。
#   本轮把台架换成 **vk127**（= M1-7.3 重放镜像，可编可二分），理由：
#     ① 决策相关（日常策略针对 7.3 线）；② 死亡可在同一棵树内二分（N6'）；
#     ③ 设备当前就活在这颗内核上（RAM boot，零重启成本）。
#
# 臂：
#   A = 完整相机栈 + **不熄屏** 长时窗对照（证明"栈本身不致死"，防 #212 型假阴性）
#   B = 完整栈 + 真实 dpms On->Off（org.gnome.ScreenSaver.SetActive）+ 保持 30 s，N 发
#
# 判据纪律（PITFALLS #288/#209）：
#   - 死活唯一可信判据 = /proc/sys/kernel/random/boot_id 是否变化
#   - 硬复位(Q24)签名 = powerlog 里【没有】本次 boot_id + pstore 空 + uname 回落 boot_b
#   - 每发必须确认 dpms 真的 On->Off（否则 SetActive 是 no-op = 假阴性）
#
#   K = 同 B，但用**内核 DPMS**（写 /sys/class/drm/card0-DSI-1/dpms）而非 ScreenSaver。
#       用于 Q28 坏发 boot：那种 boot 上 phoc/phosh 会 crash-loop，会话总线不可靠，
#       但内核路径仍能产生真实的 CRTC/dispcc 断电-上电转换（这是 Q24 关心的那一跳）。
#
# 用法：bash scripts/n7-vk127-camera-blank.sh A|B|K|all [发数] [A臂秒数]
set -u
ROOT=${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
MODE=${1:-all}
N=${2:-6}
IDLE=${3:-600}
DEV=root@192.168.7.1
LOG=${LOG:-$ROOT/logs/n7-vk127-$(date +%Y%m%d-%H%M%S).log}
mkdir -p "$(dirname "$LOG")"
exec > >(tee -a "$LOG") 2>&1

SSH() { timeout 30 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 -o BatchMode=yes "$DEV" "$@" 2>/dev/null; }
SESS() { SSH "su - xuqianhui1001 -c 'DBUS_SESSION_BUS_ADDRESS=$SBU XDG_RUNTIME_DIR=/run/user/1000 $1'"; }

echo "### N7 start $(date '+%F %T') mode=$MODE N=$N idle=$IDLE log=$LOG"

U=$(SSH 'uname -r' | tr -d '\r')
BID=$(SSH 'cat /proc/sys/kernel/random/boot_id' | tr -d '\r')
[ -n "$U" ] && [ -n "$BID" ] || { echo "FATAL: no ssh/kernel"; exit 1; }
echo "kernel=$U  boot_id=$BID"
case "$U" in *vk127*) : ;; *) echo "WARN: not vk127 (台架不一致，仍继续但标注)";; esac

Q28() { SSH 'dmesg | grep -cE "command DMA timeout|Failed to initialize panel"' | tr -d '\r'; }
ISR() { SSH 'dmesg | grep -c dsi_isr' | tr -d '\r'; }
DPMS() { SSH 'cat /sys/class/drm/card0/card0-DSI-1/dpms' | tr -d '\r'; }

QS=$(Q28); IS=$(ISR); echo "Q28sig=$QS dsi_isr_cnt=$IS dpms=$(DPMS)"

# ---- 会话总线（phoc）+ 关自动熄屏，确保熄屏只由我们触发 --------------------
# K 臂不需要会话（Q28 坏发上 phoc 会 crash-loop）
SBU=""
if [ "$MODE" != K ]; then
	SBU=$(SSH 'for p in $(pidof phoc); do tr "\0" "\n" < /proc/$p/environ 2>/dev/null | sed -n "s/^DBUS_SESSION_BUS_ADDRESS=//p"; done | head -1' | tr -d '\r')
	[ -n "$SBU" ] || { echo "FATAL: no phoc session bus (桌面没起来？)"; exit 1; }
	SESS 'gsettings set org.gnome.desktop.session idle-delay "uint32 0"' >/dev/null
	SESS 'gsettings set org.gnome.desktop.screensaver lock-enabled false' >/dev/null
	echo "idle-delay=$(SESS 'gsettings get org.gnome.desktop.session idle-delay' | tr -d '\r')  bus=${SBU:0:30}…"
else
	echo "mode=K：不依赖会话总线（内核 DPMS 路径）"
fi

# ---- 载入完整相机栈 ---------------------------------------------------------
echo "-- load full camera stack (CAM_FORCE=1) --"
SSH 'CAM_FORCE=1 /usr/local/sbin/camera-modules-load.sh' | tail -5
MODS=$(SSH 'lsmod | grep -cE "camss|cci|camcc|cambist|s5kjns|gc08a8|gt9764|wl2868c|leds_qcom_flash"' | tr -d '\r')
VID=$(SSH 'ls /dev/video* 2>/dev/null | wc -l' | tr -d '\r')
MEDIA=$(SSH 'ls /dev/media* 2>/dev/null | wc -l' | tr -d '\r')
echo "camera modules=$MODS /dev/video*=$VID /dev/media*=$MEDIA"
[ "${MODS:-0}" -ge 15 ] || { echo "FATAL: camera stack incomplete ($MODS)"; exit 1; }
[ "${VID:-0}" -ge 8 ] || { echo "FATAL: no video nodes ($VID)"; exit 1; }

record() { # label verdict note
	bash "$ROOT/scripts/trial.sh" record --label "n7-vk127-$1" --image "device:vk127" \
		--reset warm --verdict "$2" --logdir "$LOG" --note "$3" >/dev/null 2>&1 || true
}

# ---- Arm A：不熄屏长时窗 ---------------------------------------------------
armA() {
	local t=0 beat=0
	echo
	echo "================ ARM A: full stack, NO blank, window=${IDLE}s ================"
	while [ "$t" -lt "$IDLE" ]; do
		sleep 30; t=$((t+30))
		local c; c=$(SSH 'cat /proc/sys/kernel/random/boot_id' | tr -d '\r')
		if [ -z "$c" ] || [ "$c" != "$BID" ]; then
			echo "ARM-A DIED at t=${t}s (boot_id ${BID} -> ${c:-<unreachable>})"
			record "armA-noblank" DEAD "N7 ArmA full-stack no-blank died at t=${t}s kernel=$U"
			return 1
		fi
		if [ $((t % 120)) -eq 0 ]; then
			beat=$((beat+1))
			echo "  t=${t}s alive uptime=$(SSH 'cut -d" " -f1 /proc/uptime' | tr -d '\r') dpms=$(DPMS) q28=$(Q28)"
		fi
	done
	echo "ARM-A ALIVE (${IDLE}s, full stack in place, no blank, boot_id unchanged)"
	record "armA-noblank" ALIVE "N7 ArmA full-stack no-blank survived ${IDLE}s kernel=$U"
	return 0
}

# ---- Arm B：真实熄屏 -------------------------------------------------------
armB() {
	local i A B C
	echo
	echo "================ ARM B: full stack + real dpms On->Off x$N ================"
	for i in $(seq 1 "$N"); do
		echo "-- round $i --"
		SESS 'gdbus call --session --dest org.gnome.ScreenSaver --object-path /org/gnome/ScreenSaver --method org.gnome.ScreenSaver.SetActive false' >/dev/null
		sleep 4
		A=$(DPMS)
		local q0; q0=$(Q28)
		SESS 'gdbus call --session --dest org.gnome.ScreenSaver --object-path /org/gnome/ScreenSaver --method org.gnome.ScreenSaver.SetActive true' >/dev/null
		sleep 4
		B=$(DPMS)
		echo "  dpms $A -> $B  (Q28sig=$q0)"
		if [ "$B" != "Off" ]; then
			echo "  ROUND$i INVALID-NO-BLANK ($A->$B)"
			record "armB-round$i" INVALID "no dpms Off transition A=$A B=$B"
			continue
		fi
		sleep 30
		C=$(SSH 'cat /proc/sys/kernel/random/boot_id' | tr -d '\r')
		if [ -n "$C" ] && [ "$C" = "$BID" ]; then
			echo "  ROUND$i ALIVE (boot_id unchanged, Q28sig=$q0 dpms=$B)"
			record "armB-round$i" ALIVE "N7 vk127 full-stack+blank round$i Q28sig=$q0 dpms=$A->$B"
			SESS 'gdbus call --session --dest org.gnome.ScreenSaver --object-path /org/gnome/ScreenSaver --method org.gnome.ScreenSaver.SetActive false' >/dev/null
			sleep 4
			echo "  woke: dpms=$(DPMS)"
		else
			echo "  ROUND$i DEAD (boot_id ${BID} -> ${C:-<unreachable>})"
			local t=0
			while [ "$t" -lt 120 ]; do SSH true && break; sleep 5; t=$((t+5)); done
			local P S2 U2
			P=$(SSH 'grep -c "$(cat /proc/sys/kernel/random/boot_id)" /root/powerlog.txt' | tr -d '\r')
			S2=$(SSH 'ls /sys/fs/pstore/ 2>/dev/null | wc -l' | tr -d '\r')
			U2=$(SSH 'uname -r' | tr -d '\r')
			echo "  signature: powerlog_hits=${P:-?} pstore_entries=${S2:-?} uname=${U2:-?}"
			[ "${P:-1}" = "0" ] && echo "  => HARD RESET (Q24 signature)"
			record "armB-round$i" DEAD "N7 vk127 full-stack+blank round$i Q28sig=$q0 dpms=$A->$B powerlog=$P pstore=$S2 uname=$U2"
			return 1
		fi
	done
	echo "ARM-B ALL ALIVE ($N/$N)"
	return 0
}

# ---- Arm K：内核 DPMS 路径（Q28 坏发 boot 用） ------------------------------
DPMS_SET() { SSH "echo $1 > /sys/class/drm/card0-DSI-1/dpms; cat /sys/class/drm/card0-DSI-1/dpms" | tr -d '\r'; }
armK() {
	local i A B C
	echo
	echo "================ ARM K: kernel DPMS Off/On x$N (kernel=$U) ================"
	for i in $(seq 1 "$N"); do
		echo "-- round $i --"
		A=$(DPMS_SET On)
		sleep 3
		local q0; q0=$(Q28)
		B=$(DPMS_SET Off)
		sleep 3
		echo "  dpms $A -> $B  (Q28sig=$q0)"
		if [ "$B" != "Off" ]; then
			echo "  ROUND$i INVALID-NO-BLANK ($A->$B)"
			record "armK-round$i" INVALID "kernel-dpms no Off A=$A B=$B"
			continue
		fi
		sleep 30
		C=$(SSH 'cat /proc/sys/kernel/random/boot_id' | tr -d '\r')
		if [ -n "$C" ] && [ "$C" = "$BID" ]; then
			echo "  ROUND$i ALIVE (boot_id unchanged, Q28sig=$q0)"
			record "armK-round$i" ALIVE "N7-K vk127 full-stack kernel-dpms round$i Q28sig=$q0"
			echo "  wake: dpms=$(DPMS_SET On)"
			sleep 3
		else
			echo "  ROUND$i DEAD (boot_id ${BID} -> ${C:-<unreachable>})"
			local t=0
			while [ "$t" -lt 120 ]; do SSH true && break; sleep 5; t=$((t+5)); done
			local P S2 U2
			P=$(SSH 'grep -c "$(cat /proc/sys/kernel/random/boot_id)" /root/powerlog.txt' | tr -d '\r')
			S2=$(SSH 'ls /sys/fs/pstore/ 2>/dev/null | wc -l' | tr -d '\r')
			U2=$(SSH 'uname -r' | tr -d '\r')
			echo "  signature: powerlog_hits=${P:-?} pstore_entries=${S2:-?} uname=${U2:-?}"
			[ "${P:-1}" = "0" ] && echo "  => HARD RESET (Q24 signature)"
			record "armK-round$i" DEAD "N7-K vk127 full-stack kernel-dpms round$i Q28sig=$q0 powerlog=$P pstore=$S2 uname=$U2"
			return 1
		fi
	done
	echo "ARM-K ALL ALIVE ($N/$N)"
	return 0
}

RC=0
case "$MODE" in
	A) armA || RC=1 ;;
	B) armB || RC=1 ;;
	K) armK || RC=1 ;;
	all) armA || RC=1; [ "$RC" = 0 ] && { armB || RC=1; } ;;
	*) echo "usage: $0 A|B|K|all [N] [idle_secs]"; exit 2 ;;
esac

echo
echo "### N7 done $(date '+%F %T') rc=$RC kernel=$U boot_id_at_start=$BID log=$LOG"
echo "### 收尾提醒：测试后请执行 cam-mode.sh off 退回零相机安全态"
exit "$RC"
