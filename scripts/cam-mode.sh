#!/bin/sh
# cam-mode.sh — elden 上「相机 ⇄ 熄屏」互斥的操作口径（在设备上当 root 跑）
#
# 为什么需要它（2026-10-09 深夜，用户实机确认）：**相机模块在位时熄屏掉电是常态**，
# 不是低概率间歇（Q24/H2 亦未根治）。所以两者必须显式二选一，不能靠"应该不会碰到"。
#
# 用法：
#   sh cam-mode.sh status              # 只读：当前处于哪一态 + 风险提示
#   sh cam-mode.sh on                  # 相机态：先禁熄屏/挂起/锁屏，再加载相机栈并校验
#   sh cam-mode.sh off                 # 日常态：卸载相机栈（熄屏恢复安全），并恢复熄屏设置
#   sh cam-mode.sh blank disable|restore|show   # 单独动熄屏设置（disable 会把原值存档）
#
# 原则：守卫不静默（PITFALLS #157）、状态必须被读回来证明（不只看 rc）、一切有截止时间盒。
set -u
STATE=/var/lib/elden-cam/blank.env
CAM=/usr/local/sbin/camera-modules-load.sh
PAT='camss|cci|camcc|bist|wl2868c|s5kjns|gc08a8|gt9764|leds_qcom|system_heap'
# 卸载顺序 = 加载顺序的逆序（sensor/flash 先走，时钟最后）
UNLOAD='gc08a8 s5kjns gt9764 leds-qcom-flash qcom-camss wl2868c-regulator i2c-qcom-cci cambistmclkcc-sm8750 camcc-sm8750'

# 注意：`timeout` 只能 exec **真二进制**，不能跑 shell 函数（写成 `timeout 10 su_run …`
# 会报 “failed to run command ‘su_run’: No such file or directory”，整段 gsettings 当场空转）。
# ⇒ 把“以会话用户跑”拼成命令前缀字符串，让 timeout 去 exec sudo。
CAMAS='sudo -u xuqianhui1001 HOME=/home/xuqianhui1001 XDG_RUNTIME_DIR=/run/user/1000'
find_bus(){
	for p in $(pgrep -u 1000 | head -40); do
		tr '\0' '\n' < /proc/$p/environ 2>/dev/null | grep -m1 '^DBUS_SESSION_BUS_ADDRESS='
	done | head -1 | cut -d= -f2-
}
GS(){ # GS get|set <schema> <key> [value]；拿不到会话总线就明确报错（不静默）
	SBU=$(find_bus)
	if [ -z "$SBU" ]; then echo "[cam-mode] FAIL: 找不到会话总线（会话用户未登录？gsettings 读不到真值）" >&2; return 1; fi
	if [ "$1" = get ]; then
		timeout 10 $CAMAS DBUS_SESSION_BUS_ADDRESS="$SBU" gsettings get "$2" "$3" 2>/dev/null | tail -1
	else
		timeout 10 $CAMAS DBUS_SESSION_BUS_ADDRESS="$SBU" gsettings set "$2" "$3" "$4" 2>&1 | tail -1
	fi
}
DPMS(){ cat /sys/class/drm/card0/card0-DSI-1/dpms 2>/dev/null || cat /sys/class/drm/card0-DSI-1/dpms 2>/dev/null; }

cam_n(){ lsmod | grep -icE "$PAT"; }
status(){
	echo "camera modules = $(cam_n)   media = $(ls /dev/media* 2>/dev/null | wc -l)   video = $(ls /dev/video* 2>/dev/null | wc -l)"
	echo "dpms = $(DPMS)   idle-delay = $(GS get org.gnome.desktop.session idle-delay)"
	if [ "$(cam_n)" -gt 0 ]; then
		echo "==> 状态 = CAM-ON：**不要熄屏**（相机在位时熄屏掉电是常态）"
	else
		echo "==> 状态 = CAM-OFF：熄屏安全（相机栈不在位）"
	fi
}
blank_disable(){
	mkdir -p "$(dirname "$STATE")"
	if [ ! -f "$STATE" ]; then
		{ echo "IDLE=$(GS get org.gnome.desktop.session idle-delay)"
		  echo "AC=$(GS get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout)"
		  echo "BATT=$(GS get org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout)"
		  echo "LOCK=$(GS get org.gnome.desktop.screensaver lock-enabled)"; } > "$STATE"
		echo "[blank] 原值已存档：$(tr '\n' ' ' < "$STATE")"
	else
		echo "[blank] 已有存档（不覆盖）：$(tr '\n' ' ' < "$STATE")"
	fi
	GS set org.gnome.desktop.session idle-delay "uint32 0"
	GS set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout "0"
	GS set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout "0"
	GS set org.gnome.desktop.screensaver lock-enabled "false"
	echo "[blank] 现状：idle=$(GS get org.gnome.desktop.session idle-delay) ac=$(GS get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout) lock=$(GS get org.gnome.desktop.screensaver lock-enabled)"
}
blank_restore(){
	if [ -f "$STATE" ]; then
		. "$STATE"
		GS set org.gnome.desktop.session idle-delay "${IDLE:-uint32 300}"
		GS set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout "${AC:-900}"
		GS set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout "${BATT:-900}"
		GS set org.gnome.desktop.screensaver lock-enabled "${LOCK:-true}"
		rm -f "$STATE"; echo "[blank] 已恢复存档值"
	else
		echo "[blank] 没有存档 ⇒ 写回项目默认（idle=300 / ac=900 / lock=true）"
		GS set org.gnome.desktop.session idle-delay "uint32 300"
		GS set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout "900"
		GS set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout "900"
		GS set org.gnome.desktop.screensaver lock-enabled "true"
	fi
	echo "[blank] 现状：idle=$(GS get org.gnome.desktop.session idle-delay) ac=$(GS get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout) lock=$(GS get org.gnome.desktop.screensaver lock-enabled)"
}
do_on(){
	blank_disable				# 顺序不能反：先禁熄屏，再加载（#158 的教训）
	timeout -k 10 180 env CAM_FORCE=1 sh "$CAM"; echo "[cam-mode] loader rc=$?"
	echo "[cam-mode] 读回：$(cam_n) 个模块 / $(ls /dev/media* 2>/dev/null | wc -l) media / $(ls /dev/video* 2>/dev/null | wc -l) video"
	[ "$(cam_n)" -gt 0 ] || { echo "[cam-mode] FAIL: 模块没进来，看上面 loader 的点名信息" >&2; return 1; }
}
do_off(){
	for m in $UNLOAD; do
		if lsmod | grep -q "^$(echo "$m" | tr '-' '_') "; then
			timeout 20 rmmod "$m" 2>&1 | head -1 | sed "s/^/[cam-mode] rmmod $m: /"
		fi
	done
	echo "[cam-mode] 读回：$(cam_n) 个模块 / $(ls /dev/media* 2>/dev/null | wc -l) media / $(ls /dev/video* 2>/dev/null | wc -l) video"
	blank_restore
}

case "${1:-status}" in
	status)  status ;;
	on)      do_on; status ;;
	off)     do_off; status ;;
	blank)   case "${2:-}" in disable) blank_disable ;; restore) blank_restore ;; show) status ;; (*) echo "usage: $0 blank disable|restore|show" >&2; exit 2 ;; esac ;;
	*) echo "usage: $0 {status|on|off|blank disable|blank restore|blank show}" >&2; exit 2 ;;
esac
