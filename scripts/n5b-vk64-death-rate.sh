#!/bin/bash
# n5b-vk64-death-rate.sh — N5b：在 vk64（7.2 血统）RAM 内核上重复
#   「完整相机栈 + 真实 dpms On->Off 熄屏」配方，测量致死率。
#
# 背景：reports/q24-n5-vk64-death-reproduced-20261015.md（第 2 发致死，n=2）
#   对照：reports/q24-n2prime-both-arms-survive-20261015.md（M1-7.3 上 12 发全存活）
#
# ★ 判据纪律（PITFALLS #288）：
#   - 死活唯一可信判据 = /proc/sys/kernel/random/boot_id 是否变化
#   - 硬复位（Q24）签名 = powerlog 里【没有】本次 boot_id + pstore 空
#   - 每次必须确认 dpms 真的发生 On->Off 跃迁（否则 SetActive 是 no-op = 假阴性）
#
# 每次死亡的恢复：RAM 内核死 -> 系统回落 boot_b（M1）-> 需重新 `fastboot boot` vk64。
#
# 用法：bash scripts/n5b-vk64-death-rate.sh [轮数] [图像]
set -u
ROOT=${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
N=${1:-5}
IMG=${2:-$ROOT/out/boot-elden-vk64.img}
# --check：零副作用预检（不 boot/不刷），放在参数位置解释，避免被当成轮数
if [ "$N" = "--check" ]; then CHECK_ONLY=1; N=0; IMG=${2:-$ROOT/out/boot-elden-vk64.img}; fi
DEV=root@192.168.7.1
LOG=${LOG:-$ROOT/logs/n5b-vk64-$(date +%Y%m%d-%H%M%S).log}
SLOG=$LOG.serial
mkdir -p "$(dirname "$LOG")"
exec > >(tee -a "$LOG") 2>&1

# 串口采集统一走 lib（relay 常驻日志 优先；#359）。死亡瞬间 dmesg 是 T5 唯一的完整记录。
. "$(dirname "$0")/lib-serial-source.sh"

# 串口常驻记录：Q24 是 SoC 级硬复位 + pstore 空（#197），死亡瞬间的 dmesg 事后拿不到，
# 只能在死亡发生时由串口抓（console=ttyGS0 -> 宿主 /dev/ttyACM0）。T5 要交的「完整 dmesg」全靠这条。
start_serial() {
	# 串口是 T5「完整 dmesg」的唯一来源（硬复位时 pstore 常空，#197）。
	# 旧实现把「无权限」吞成空日志 ⇒ 假阴性，现已由 lib 硬失败（#359）。
	if ! serial_start "$SLOG"; then
		if [ "${ALLOW_NOSERIAL:-0}" = 1 ]; then
			echo "  ⚠️ ALLOW_NOSERIAL=1 ⇒ 继续，但本轮数据不含死亡瞬间 dmesg（T5 不可用）"
			return 0
		fi
		echo "  ❌ 拒绝无串口采样（空日志会被误读成「没有 panic」）"
		echo "  确实要无串口采样：ALLOW_NOSERIAL=1 bash $0 $*"
		exit 3
	fi
	serial_probe "$SLOG" || echo "  ⚠️ 串口探针未通：死亡瞬间内容可能缺失（结论里标注）"
}
stop_serial() { serial_stop; }
trap stop_serial EXIT

SSH() { timeout 25 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 -o BatchMode=yes "$DEV" "$@" 2>/dev/null; }
FB()  { timeout 20 fastboot devices > /tmp/n5b-fbdev.txt 2>/dev/null; grep -q HA2EXB0E /tmp/n5b-fbdev.txt; }

echo "### N5b start $(date '+%F %T')  rounds=$N  img=$IMG"
[ -f "$IMG" ] || {
	echo "missing image: $IMG"
	echo "  换机后 out/*.img 未随迁；先重建："
	echo "    scripts/rebuild-vk64-image.sh --check-only   # 前置检查（零编译）"
	echo "    scripts/rebuild-vk64-image.sh                # 编内核+打包+manifest"
	exit 1
}

# 前置：设备侧 vk64 模块树与 cambist 原件（#177：FIX-3 版会让任何自动加载相机的启动挂死）
preflight_device() {
	local kv_dir cambist md5
	kv_dir=$(SSH 'ls -d /lib/modules/7.2.0-debug-vk64-* 2>/dev/null | head -1' | tr -d '\r')
	[ -n "$kv_dir" ] || { echo "❌ 设备上没有 /lib/modules/7.2.0-debug-vk64-*：vk64 的 .ko 全缺，相机栈起不来"; return 1; }
	echo "  模块树: $kv_dir ($(SSH "ls $kv_dir | wc -l" | tr -d '\r') 项)"
	cambist="$kv_dir/drivers/clk/qcom/cambistmclkcc-sm8750.ko"
	md5=$(SSH "md5sum $cambist 2>/dev/null" | awk '{print $1}' | tr -d '\r')
	echo "  cambist ko md5=${md5:-<缺>}（原件应为 88a45177…, 备份 /root/q24bak/）"
	case "$md5" in
		88a45177*) : ;;
		*) echo "  ⚠️ cambist 不是原件（可能是 FIX-3 实验版）。还原命令："
		   echo "     ssh $DEV 'cp /root/q24bak/cambistmclkcc-sm8750.ko $cambist'"
		   return 1;;
	esac
	SSH 'test -x /usr/local/sbin/camera-modules-load.sh' || { echo "❌ 设备缺 camera-modules-load.sh"; return 1; }
	return 0
}

wait_ssh() { # $1=timeout secs
	local t=0
	while [ "$t" -lt "${1:-90}" ]; do SSH true && return 0; sleep 5; t=$((t+5)); done
	return 1
}

# 等待 vk64 RAM 内核起来（要等到 uname 含 vk64，避免误判成 boot_b）
wait_vk64() {
	local t=0
	while [ "$t" -lt 240 ]; do
		local u; u=$(SSH 'uname -r' | tr -d '\r')
		case "$u" in *vk64*) return 0;; esac
		# 若掉进 fastboot，踢一脚回 boot_b（否则卡死）
		FB && { echo "    (in fastboot -> reboot to boot_b)"; timeout 20 fastboot reboot >/dev/null 2>&1; }
		sleep 5; t=$((t+5))
	done
	return 1
}

boot_vk64() {
	echo "-- fastboot boot vk64 --"
	timeout 120 fastboot boot "$IMG" >/dev/null 2>&1 || { echo "  fastboot boot FAILED"; return 1; }
	wait_ssh 90 || { echo "  SSH never came up"; return 1; }
	wait_vk64 || { echo "  kernel is not vk64 (fell back?)"; return 1; }
	return 0
}

# 从 boot 镜像里抽 UTS（不用 strings：gzip 压过的 kernel 里 strings 看不到明文）
img_uts() {
	timeout 60 python3 - "$1" <<'EOF'
import gzip, re, struct, sys
d = open(sys.argv[1], 'rb').read()
ks, ka, rs, ra, ss, sa, ts, ta, ps = struct.unpack_from('<9I', d, 8)
k = d[ps * 2048:ps * 2048 + ks]
try:
    k = gzip.decompress(k)
except Exception:
    pass
m = re.search(rb'Linux version [^\x00\n]{0,100}', k)
print(m.group(0).decode() if m else '(not found)')
EOF
}

start_serial
ssh_alive_probe() { SSH true; }

# 零副作用预检（--check）：不 boot、不刷、不改设备状态。
# 重点是把「每次死亡后的恢复通道」先验清楚——本脚本靠 `fastboot boot` 重进 vk64，
# 而 2026-10-18 实测过它在本机可能报 OKAY 却不真正生效（#293），死得快时会卡住。
if [ "${CHECK_ONLY:-0}" = 1 ]; then
	echo "== 预检（不写盘）=="
	printf '  串口采集    : '; if serial_source_probe; then :; else echo "❌ 不可用 ⇒ 死亡瞬间 dmesg 拿不到（T5 数据不完整）"; fi
	printf '  设备可达    : '; if ssh_alive_probe; then echo "SSH ok ($(SSH 'uname -r' | tr -d '\r'))"; else echo "不可达（需先进 Linux）"; fi
	printf '  fastboot    : '; if FB; then echo "ok"; else echo '不在 fastboot（fastboot boot 需要它）'; fi
	printf '  镜像        : '; if [ -f "$IMG" ]; then echo "$IMG ($(stat -c %s "$IMG") B, sha256 $(sha256sum "$IMG" | cut -c1-16)…)"; else echo "❌ 缺 $IMG"; fi
	printf '  镜像 UTS    : '; img_uts "$IMG"; echo
	preflight_device || true
	echo "== 结束。真跑：bash $0 [轮数] [图像] =="
	serial_stop
	exit 0
fi

if ssh_alive_probe; then
	preflight_device || { echo "### 前置未通过：修好再跑（本次不采样，避免污染 n）"; exit 1; }
else
	echo "  （设备当前不可达，跳过设备侧前置检查；每轮 boot 后仍会校验模块数）"
fi

for i in $(seq 1 "$N"); do	echo
	echo "================ ROUND $i ================"
	printf "\n===== N5b ROUND %s %s =====\n" "$i" "$(date '+%F %T')" >> "$SLOG" 2>/dev/null || true
	boot_vk64 || { echo "ROUND$i SETUP-FAIL"; continue; }

	# 等会话起来（phoc 在 = 桌面活）
	t=0; while [ $t -lt 180 ]; do SSH 'pidof phoc' | grep -q . && break; sleep 5; t=$((t+5)); done
	SSH 'pidof phoc' | grep -q . || { echo "ROUND$i NO-SESSION"; continue; }

	BID=$(SSH 'cat /proc/sys/kernel/random/boot_id' | tr -d '\r')
	Q28=$(SSH 'dmesg | grep -cE "command DMA timeout|Failed to initialize panel"' | tr -d '\r')
	echo "  boot_id=$BID  Q28sig=$Q28"

	# 载入完整相机栈
	SSH 'CAM_FORCE=1 /usr/local/sbin/camera-modules-load.sh >/dev/null 2>&1'
	MODS=$(SSH 'lsmod | grep -cE "camss|cci|camcc|cambist|s5kjns|gc08a8|gt9764|wl2868c|leds_qcom_flash"' | tr -d '\r')
	echo "  camera modules=$MODS"
	[ "${MODS:-0}" -ge 15 ] || { echo "ROUND$i STACK-INCOMPLETE($MODS)"; continue; }

	# 取会话总线 + 禁自动熄屏（确保熄屏是我们主动触发）
	SBU=$(SSH 'for p in $(pidof phoc); do tr "\0" "\n" < /proc/$p/environ 2>/dev/null | sed -n "s/^DBUS_SESSION_BUS_ADDRESS=//p"; done | head -1' | tr -d '\r')
	[ -n "$SBU" ] || { echo "ROUND$i NO-BUS"; continue; }
	SSH "su - xuqianhui1001 -c 'DBUS_SESSION_BUS_ADDRESS=$SBU XDG_RUNTIME_DIR=/run/user/1000 gsettings set org.gnome.desktop.session idle-delay \"uint32 0\"'" >/dev/null

	# WAKE -> 确认 On；BLANK -> 确认 Off
	SSH "su - xuqianhui1001 -c 'DBUS_SESSION_BUS_ADDRESS=$SBU XDG_RUNTIME_DIR=/run/user/1000 gdbus call --session --dest org.gnome.ScreenSaver --object-path /org/gnome/ScreenSaver --method org.gnome.ScreenSaver.SetActive false'" >/dev/null
	sleep 4
	A=$(SSH 'cat /sys/class/drm/card0/card0-DSI-1/dpms' | tr -d '\r')
	SSH "su - xuqianhui1001 -c 'DBUS_SESSION_BUS_ADDRESS=$SBU XDG_RUNTIME_DIR=/run/user/1000 gdbus call --session --dest org.gnome.ScreenSaver --object-path /org/gnome/ScreenSaver --method org.gnome.ScreenSaver.SetActive true'" >/dev/null
	sleep 4
	B=$(SSH 'cat /sys/class/drm/card0/card0-DSI-1/dpms' | tr -d '\r')
	echo "  dpms $A -> $B"
	if [ "$B" != "Off" ]; then echo "ROUND$i INVALID-NO-BLANK($A->$B)"; continue; fi

	# 保持 30 s，然后判活
	sleep 30
	C=$(SSH 'cat /proc/sys/kernel/random/boot_id' | tr -d '\r')
	if [ -n "$C" ] && [ "$C" = "$BID" ]; then
		echo "ROUND$i ALIVE (boot_id unchanged, Q28sig=$Q28)"
		V=ALIVE
	else
		# 死了：等回落 + 取硬复位签名
		echo "ROUND$i DEAD (boot_id $BID -> ${C:-<unreachable>})"
		wait_ssh 120 || true
		PLOG=$(SSH 'grep -c "$(cat /proc/sys/kernel/random/boot_id)" /root/powerlog.txt' | tr -d '\r')
		PSTORE=$(SSH 'ls /sys/fs/pstore/ 2>/dev/null | wc -l' | tr -d '\r')
		UNAME=$(SSH 'uname -r' | tr -d '\r')
		echo "  signature: powerlog_hits=${PLOG:-?} pstore_entries=${PSTORE:-?} uname=${UNAME:-?}"
		[ "${PLOG:-1}" = "0" ] && echo "  => HARD RESET (Q24 signature: userland powerlog has no record)"
		# 死后立即固化死亡瞬间的证据（串口切片 + pstore），供 T5 与 N6 二分使用
		if [ -s "$SLOG" ]; then
			awk -v n="$i" 'index($0,"N5b ROUND " n " "){buf=""} {buf=buf $0 "\n"} END{printf "%s", buf}' "$SLOG" > "$LOG.round$i.serial"
			echo "  death-window serial -> $LOG.round$i.serial ($(wc -l < "$LOG.round$i.serial") 行)"
		fi
		PST=$(SSH 'mount -t pstore pstore /sys/fs/pstore 2>/dev/null; ls /sys/fs/pstore 2>/dev/null' | tr -d '\r')
		if [ -n "$PST" ]; then
			for f in $PST; do SSH "cat /sys/fs/pstore/$f" > "$LOG.round$i.$f" 2>/dev/null; done
			echo "  ramoops 已留档：$LOG.round$i.dmesg-ramoops*"
		else
			echo "  pstore 空（Q24 常规：无痕硬复位 #197）"
		fi
		V=DEAD
	fi
	bash "$ROOT/scripts/trial.sh" record --label "n5b-vk64-round$i" --image "device:vk64" \
		--reset cold --verdict "$V" --logdir "$LOG" \
		--note "N5b vk64 7.2-lineage full-stack+blank round$i Q28sig=$Q28 mods=$MODS" >/dev/null 2>&1 || true
done
echo
echo "### N5b done $(date '+%F %T')  log=$LOG"
