#!/bin/sh
# q28-race-hunt.sh — Q28（显示 power-on 竞态：背光亮无画面 / vblank -110）密集复现 + 取证
#
# 为什么这么做：Q28 的近因假设 = DPU/DSI 上电路径走 runtime-PM，关键点 pm_runtime_get_sync
#   忽略返回值（dpu_kms.c:447 / dpu_crtc.c:1279 / dsi_host.c:3022），竞态下底层 resume
#   瞬时失败被吞 → 往没上电的硬件写 → 无 vblank -110。开机首条 modeset(~8.5 s) 撞一次，
#   概率 ~62%（且集中在温启）；而**熄屏→亮屏走的正是同一条 power-on 路径**，可以不开机
#   就把样本密度提高两个数量级。
#
# 为什么零构建：本机内核已编进 rpm tracepoints（/sys/kernel/debug/tracing/events/rpm/
#   {rpm_resume,rpm_return_int,rpm_status,rpm_suspend,rpm_idle,rpm_usage}）。
#   rpm_return_int 直接记录 pm_runtime_* 的返回值 ⇒ 被吞的错误会现形，无需诊断内核。
#   genpd 侧读 /sys/kernel/debug/pm_genpd/<dom>/current_state。
#
# 用法（设备上，root）：  q28-race-hunt.sh [cycles] [dwell_off_s] [dwell_on_s]
# 输出：/root/q28-hunt-<ts>/ 下 summary.txt + trace-hit.txt + dmesg.txt（命中时），
#       并打印 KEY=VALUE 供主机解析。默认 30 轮 / off 1.5 s / on 2.5 s。
#
# 退出码：0=跑完无命中；10=命中（已留现场）；2=环境不满足。
# 纪律：结束时一定关 tracing、恢复熄屏策略；主机侧务必套 timeout（见 AGENT-OPS §5）。
set -u

CYCLES=${1:-30}
DWELL_OFF=${2:-1.5}
DWELL_ON=${3:-2.5}
T=/sys/kernel/debug/tracing
CONN=$(for d in /sys/class/drm/card*-DSI-*; do [ -e "$d/dpms" ] && basename "$d" && break; done)
[ -n "${CONN:-}" ] || CONN=card0-DSI-1
CDIR=$(for d in /sys/class/drm/card*/$CONN; do [ -e "$d/dpms" ] && echo "$d" && break; done)
# ftrace filter 表达式（字段名 = name，见 include/trace/events/rpm.h 的 __string(name, dev_name)）
FILT='name ~ "ae01000*" || name ~ "ae00000*" || name ~ "ae94000*" || name ~ "ae96000*" || name ~ "*display*" || name ~ "*dsi*" || name ~ "*mdss*"'
TS=$(date +%Y%m%d-%H%M%S)
OUT=/root/q28-hunt-$TS

# ---- 环境检查 -------------------------------------------------------------
if [ ! -e "$T/events/rpm/rpm_return_int/enable" ] || [ ! -e "$CDIR/dpms" ]; then
	echo "FATAL=missing ftrace rpm events or dpms connector"
	echo "HAVE_TRACE=$([ -d $T/events/rpm ] && echo y || echo n) CONN=$CONN"
	exit 2
fi
mkdir -p "$OUT"
echo "OUT=$OUT"
echo "UNAME=$(uname -r)"
echo "UPTIME=$(cut -d' ' -f1 /proc/uptime)"
echo "CONN=$CONN DPMS_START=$(cat "$CDIR/dpms")"

# ---- 会话总线（真实熄屏路径 = org.gnome.ScreenSaver.SetActive）------------
# ★ 踩坑（2026-10-09 实测）：greetd 起的桌面会话现在跑在 **UID 1000**，其临时 session bus
#   （dbus-run-session 的 /tmp/dbus-XXXX）**拒绝 root 连接**：“Error connecting: The
#   connection is closed”。所以熄屏/唤屏必须用 setpriv 降到会话属主 UID 执行；
#   而 root 写 /sys/class/drm/.../dpms 会被 DRM 拒（Permission denied）⇒ 没有 sysfs 退路。
PID=$(pidof phoc 2>/dev/null | awk '{print $1}')
[ -n "${PID:-}" ] || PID=$(pidof phosh 2>/dev/null | awk '{print $1}')
if [ -n "${PID:-}" ]; then
	DBUS_SESSION_BUS_ADDRESS=$(tr '\0' '\n' < /proc/"$PID"/environ |
		sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p')
	SESSUID=$(sed -n 's/^Uid:[[:space:]]*\([0-9]*\).*/\1/p' /proc/"$PID"/status | head -1)
	SESSGID=$(sed -n 's/^Gid:[[:space:]]*\([0-9]*\).*/\1/p' /proc/"$PID"/status | head -1)
	export DBUS_SESSION_BUS_ADDRESS
fi
[ -n "${SESSUID:-}" ] || { echo "FATAL=no desktop session (phoc/phosh not running?)"; exit 2; }
echo "PHOC_PID=${PID:-none} SESSUID=$SESSUID SESSIONBUS=${DBUS_SESSION_BUS_ADDRESS:+set}"

ss() {
	setpriv --reuid="$SESSUID" --regid="$SESSGID" --clear-groups \
		env DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
		XDG_RUNTIME_DIR="/run/user/$SESSUID" \
		timeout 10 gdbus call --session --dest org.gnome.ScreenSaver \
		--object-path /org/gnome/ScreenSaver \
		--method org.gnome.ScreenSaver.SetActive "$1" >/dev/null 2>&1
}
wake() { ss false; }
blank() { ss true; }

# ---- 记录 tracing 前的 dmesg 游标（按行数差判新增）------------------------
DM_BASE=$(dmesg | wc -l)
dmesg >"$OUT/dmesg-before.txt"
DMBASE_VB=$(dmesg | grep -c "vblank timeout")

# ---- 布防 ftrace ----------------------------------------------------------
arm() {
	echo 0 >"$T/tracing_on"
	echo >"$T/trace"
	echo 8192 >"$T/buffer_size_kb" 2>/dev/null || echo 4096 >"$T/buffer_size_kb"
	echo 0 >/sys/kernel/tracing/events/enable 2>/dev/null || echo 0 >"$T/events/enable"
	for e in rpm_resume rpm_return_int rpm_status rpm_suspend rpm_idle; do
		[ -e "$T/events/rpm/$e/enable" ] || continue
		echo 1 >"$T/events/rpm/$e/enable"
		# 只看显示链上的设备，省缓冲
		echo "$FILT" >"$T/events/rpm/$e/filter" 2>/dev/null || true
		echo "  $e filter=$(cat $T/events/rpm/$e/filter 2>/dev/null)"
	done
	echo 1 >"$T/tracing_on"
	echo "TRACE_ARMED=1 BUF=$(cat $T/buffer_size_kb)KB/CPU"
}
disarm() {
	echo 0 >"$T/tracing_on" 2>/dev/null
	for e in rpm_resume rpm_return_int rpm_status rpm_suspend rpm_idle; do
		[ -e "$T/events/rpm/$e/enable" ] && echo 0 >"$T/events/rpm/$e/enable"
	done
	cp "$T/trace" "$OUT/trace-tail.txt" 2>/dev/null || true
}
trap 'disarm; echo "TRACING_DISABLED=1"' EXIT INT TERM

# ---- 现场快照（命中或收尾都存）-------------------------------------------
snapshot() {
	local tag=$1
	{
		echo "### $tag @ uptime=$(cut -d' ' -f1 /proc/uptime)"
		echo "-- dpms/brightness --"
		echo "dpms=$(cat "$CDIR/dpms") brightness=$(cat /sys/class/backlight/*/brightness 2>/dev/null)"
		echo "-- runtime_status --"
		for d in ae01000.display-controller ae00000.display-subsystem ae94000.dsi ae96000.dsi; do
			p=/sys/bus/platform/devices/$d/power
			[ -d "$p" ] && echo "$d $(cat $p/runtime_status)"
		done
		echo "-- genpd --"
		for g in mdss_gdsc gfx mdss_int2_gdsc; do
			[ -e /sys/kernel/debug/pm_genpd/$g/current_state ] &&
				echo "$g=$(cat /sys/kernel/debug/pm_genpd/$g/current_state) active=$(cat /sys/kernel/debug/pm_genpd/$g/active_time 2>/dev/null)"
		done
		echo "-- dmesg delta (since arm) --"
		dmesg | tail -n +"$((DM_BASE + 1))" |
			grep -iE "vblank timeout|reset failure|wait for commit done|Q28|bonded|panel|dsi|mdss|dpu" | tail -40
	} >"$OUT/$tag.txt" 2>&1
}

# ---- 主循环 ---------------------------------------------------------------
# ---- 先验证熄屏/唤屏链路真的生效（否则一切样本都是假的）----------------
check_path() {
	blank; sleep 1.2
	off1=$(cat "$CDIR/dpms")
	wake; sleep 2
	on1=$(cat "$CDIR/dpms")
	echo "PATHCHECK blank->$off1 wake->$on1"
	[ "$off1" = "Off" ] && [ "$on1" = "On" ]
}
if ! check_path; then
	echo "FATAL=dpms 熄屏/唤屏链路未生效（dpms 现在=$(cat "$CDIR/dpms")）——先修会话总线再跑"
	echo "HINTS=『setpriv 到会话 UID』是否够 / 桌面是否在跑 / phosh screensaver 插件是否加载"
	exit 2
fi

arm
HITS=0
EFFECTIVE=0
FIRST_HIT=0
i=0
while [ "$i" -lt "$CYCLES" ]; do
	i=$((i + 1))
	blank
	sleep "$DWELL_OFF"
	off_seen=$(cat "$CDIR/dpms")
	wake
	sleep "$DWELL_ON"
	on_seen=$(cat "$CDIR/dpms")
	[ "$off_seen" = "Off" ] && [ "$on_seen" = "On" ] && EFFECTIVE=$((EFFECTIVE + 1))

	new=$(dmesg | wc -l)
	vb_now=$(dmesg | grep -c "vblank timeout")
	new_vb=$((vb_now - DMBASE_VB))
	if [ "$on_seen" != "On" ] || [ "$new_vb" -gt 0 ]; then
		HITS=$((HITS + 1))
		[ "$FIRST_HIT" = "0" ] && FIRST_HIT=$i
		echo "HIT cycle=$i dpms_after_wake=$on_seen new_vblank_timeout=$new_vb"
		cp "$T/trace" "$OUT/trace-hit-$i.txt" 2>/dev/null || true
		snapshot "hit-$i"
		dmesg >"$OUT/dmesg-hit.txt"
		# 命中即停：现场比多样本更值钱（且继续打温复位会加剧，见 Q28b 纪律）
		break
	fi
	printf "."
done
echo
disarm
wake 2>/dev/null || true   # 不要把设备留在熄屏态

DMBASE_VB=$vb_now
dmesg >"$OUT/dmesg-after.txt"
{
	echo "CYCLES=$CYCLES EFFECTIVE=$EFFECTIVE HITS=$HITS FIRST_HIT=$FIRST_HIT"
	echo "VBLANK_TIMEOUT_TOTAL=$vb_now NEW_SINCE_ARM=$((vb_now - DMBASE_VB))"
	echo "DWELL_OFF=$DWELL_OFF DWELL_ON=$DWELL_ON"
} | tee "$OUT/summary.txt"
[ "$HITS" -gt 0 ] && exit 10
exit 0
