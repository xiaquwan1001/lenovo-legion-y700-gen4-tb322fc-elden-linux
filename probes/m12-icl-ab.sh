#!/bin/sh
# probes/m12-icl-ab.sh — ICL 档位 → 充电电流的交替 A/B（设备侧，只读+写 ICL 一个属性）
#
# 用法：scripts/autotest-cycle.sh --image <件>.img --test probes/m12-icl-ab.sh
# 判据：交替 500000 / 900000 各两轮，每轮 40 s 采 `qcom-battmgr-bat/current_now` 均值；
#       900 mA 档的 |电流| 应稳定大于 500 mA 档（同一 USB 主机端口、同一次启动内对照）。
set -u
PSY=/sys/class/power_supply/qcom-battmgr-usb
BAT=/sys/class/power_supply/qcom-battmgr-bat
echo "UTS=$(uname -r)"
echo "BUILD=$(uname -v)"
echo "usb_type=$(cat $PSY/usb_type 2>/dev/null)"
echo "current_max=$(cat $PSY/current_max 2>/dev/null) limit_boot=$(cat $PSY/input_current_limit 2>/dev/null)"
echo "epp=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null) load1=$(cut -d' ' -f1 /proc/loadavg)"
n=0; sum=0
avg() { # avg <秒>
	n=0; sum=0; i=0
	while [ "$i" -lt "$1" ]; do
		v=$(cat "$BAT/current_now" 2>/dev/null || echo 0)
		sum=$((sum + v)); n=$((n + 1)); sleep 2; i=$((i + 2))
	done
	echo $((sum / n))
}
for r in 1 2; do
	for lvl in 500000 900000; do
		printf %s "$lvl" > "$PSY/input_current_limit" 2>/dev/null
		rb=$(cat "$PSY/input_current_limit")
		# 先等 10 s 让固件/充电器稳定，再采 40 s
		sleep 10
		a=$(avg 40)
		printf 'round=%s set=%s readback=%s current_now_avg=%s |avg|=%s\n' \
			"$r" "$lvl" "$rb" "$a" "$( [ "$a" -lt 0 ] && echo $(( -a )) || echo "$a" )"
	done
done
echo "unknown_message=$(dmesg | grep -c 'unknown message')"
echo "RESULT=done"
exit 0
