#!/bin/sh
# sleep-bisect.sh — 在设备上做「相机模块 ⇄ 熄屏掉电」最小模块集二分。
#
# 用法（设备上）：sleep-bisect.sh "system_heap"
#                 sleep-bisect.sh "camcc-sm8750 cambistmclkcc-sm8750 i2c-qcom-cci qcom-camss"
#                 sleep-bisect.sh ""            # 对照组：不加载任何相机模块
#
# 行为：先把全部相机模块卸载干净 → 只加载参数里的集合 → 真实熄屏
#       （org.gnome.ScreenSaver.SetActive(true)）→ 观察是否掉电。
#       设备活着会打印 ALIVE=1；掉电则 SSH 直接断（外部判死）。
#
# 前提：运行内核的 /lib/modules 里有相机模块（即 camdp 载具）。
set -u
WANT="${1:-}"

CAMS="gc08a8 s5kjns gt9764 leds-qcom-flash qcom-camss wl2868c-regulator i2c-qcom-cci cambistmclkcc-sm8750 camcc-sm8750 system_heap"

echo "== unload all camera modules =="
i=0
while [ "$i" -lt 3 ]; do
	for m in $CAMS; do rmmod "$m" 2>/dev/null; done
	i=$((i + 1))
done
left=$(lsmod | awk 'NR>1{print $1}' | grep -cE '^gc08a8$|^s5kjns$|^gt9764$|^leds_qcom_flash$|^qcom_camss$|^wl2868c_regulator$|^i2c_qcom_cci$|^cambistmclkcc_sm8750$|^camcc_sm8750$|^system_heap$')
echo "CAM_LOADED_AFTER_UNLOAD=$left"

echo "== load subset: [$WANT] =="
for m in $WANT; do
	if modprobe "$m" 2>/dev/null; then echo "loaded $m"; else echo "WARN modprobe $m failed"; fi
done
echo "LOADED=$(lsmod | awk 'NR>1{print $1}' | tr '\n' ' ')"

# DP/DRM 需要 fsa4480 常驻，且它不影响本次结论
lsmod | grep -q "^fsa4480 " || modprobe fsa4480 2>/dev/null

# idle-delay=0：测试期间禁用自动熄屏，只用脚本内受控触发
P=$(pidof phoc 2>/dev/null || true)
if [ -n "$P" ]; then
	export DBUS_SESSION_BUS_ADDRESS=$(tr '\0' '\n' < /proc/"$P"/environ | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p')
	export XDG_RUNTIME_DIR=/run/user/0
	gsettings set org.gnome.desktop.session idle-delay 0 2>/dev/null
fi

setsid /usr/local/sbin/blankspy.sh >/dev/null 2>&1 &
sleep 2

echo "BOOT_ID_BEFORE=$(cat /proc/sys/kernel/random/boot_id)"
echo "UP_BEFORE=$(cut -d. -f1 /proc/uptime)"
echo "DPMS_PRE=$(cat /sys/class/drm/card0-DSI-1/dpms 2>/dev/null)"

timeout 10 gdbus call --session --dest org.gnome.ScreenSaver \
	--object-path /org/gnome/ScreenSaver --method org.gnome.ScreenSaver.SetActive true 2>&1
echo "TRIGGER_RC=$?"

sleep 3
echo "DPMS_POST=$(cat /sys/class/drm/card0-DSI-1/dpms 2>/dev/null)"
sleep 10
echo "ALIVE=1 UP_AFTER=$(cut -d. -f1 /proc/uptime)"
echo "BOOT_ID_AFTER=$(cat /proc/sys/kernel/random/boot_id)"
tail -3 /root/blankspy.log 2>/dev/null
