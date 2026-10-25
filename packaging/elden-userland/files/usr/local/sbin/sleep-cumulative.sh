#!/bin/sh
# sleep-cumulative.sh — 累积式加载相机模块组，每加一组就真实熄屏一次。
# 第一个致死的组 = 元凶（或最小致死集合）。配合 camdp-nocam 载具
# （cmdline elden_nocamera=1，/init 不自动加载相机模块）使用。
# 用法（设备上）：sh /usr/local/sbin/sleep-cumulative.sh
set -u

G1="system_heap"
G2="camcc-sm8750 cambistmclkcc-sm8750 i2c-qcom-cci"
G3="wl2868c-regulator"
G4="qcom-camss"
G5="leds-qcom-flash gt9764 s5kjns gc08a8"

CAMRE='qcom_camss|system_heap|s5kjns|gc08a8|wl2868c_regulator|gt9764|leds_qcom_flash|camcc_sm8750|cambistmclkcc_sm8750'

camn() { lsmod | awk 'NR>1{print $1}' | grep -cE "$CAMRE"; }

# DP/DRM 必需（与本次结论无关）
lsmod | grep -q "^fsa4480 " || modprobe fsa4480 2>/dev/null

sess_env() {
	P=$(pidof phoc 2>/dev/null || true)
	if [ -n "$P" ]; then
		export DBUS_SESSION_BUS_ADDRESS=$(tr '\0' '\n' < /proc/"$P"/environ | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p')
		export XDG_RUNTIME_DIR=/run/user/0
		gsettings set org.gnome.desktop.session idle-delay 0 2>/dev/null
	fi
}

trigger() {
	label="$1"
	setsid /usr/local/sbin/blankspy.sh >/dev/null 2>&1 &
	sleep 2
	echo "### $label | cam_mods=$(camn) up=$(cut -d. -f1 /proc/uptime) dpms_pre=$(cat /sys/class/drm/card0-DSI-1/dpms 2>/dev/null)"
	timeout 10 gdbus call --session --dest org.gnome.ScreenSaver \
		--object-path /org/gnome/ScreenSaver --method org.gnome.ScreenSaver.SetActive true \
		>/dev/null 2>&1
	sleep 3
	echo "    dpms_post=$(cat /sys/class/drm/card0-DSI-1/dpms 2>/dev/null)"
	sleep 8
	echo "    ALIVE up=$(cut -d. -f1 /proc/uptime) boot=$(cat /proc/sys/kernel/random/boot_id)"
	# 唤醒，准备下一轮
	timeout 10 gdbus call --session --dest org.gnome.ScreenSaver \
		--object-path /org/gnome/ScreenSaver --method org.gnome.ScreenSaver.SetActive false \
		>/dev/null 2>&1
	sleep 3
}

sess_env
echo "=== start: cam_mods=$(camn)"
trigger "G0-none"

for g in "$G1" "$G2" "$G3" "$G4" "$G5"; do
	echo "=== load [$g]"
	for m in $g; do
		modprobe "$m" 2>/dev/null && echo "    + $m" || echo "    ! $m failed"
	done
	trigger "after[$g]"
done
echo "ALL_DONE cam_mods=$(camn)"
