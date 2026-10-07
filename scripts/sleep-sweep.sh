#!/bin/bash
# sleep-sweep.sh — 主机侧自动扫掠：设 camera.conf → 反复重启 → 每次真实熄屏 → 记 存活/掉电。
# 依赖：boot_b = 可启动的 camdp-nocam；掉电后落在 fastboot 时用 `fastboot reboot` 兜底。
# 用法：bash scripts/sleep-sweep.sh "<模块名，空格分隔>" [轮数]
set -u
DEV=root@192.168.7.1
S() { timeout 20 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=6 -o BatchMode=yes "$DEV" "$@" 2>/dev/null; }
FB() { timeout 20 fastboot devices 2>/dev/null | grep -q HA2EXB0E; }
CONF="${1:?conf}"
[ "$CONF" = NONE ] && CONF=""
N="${2:-3}"

# 实时落盘：用户可能中途取消命令，agent 看不到被中断的输出；统一 tee 到文件。
LOG="${LOG:-/tmp/sleep-sweep.log}"
exec > >(tee -a "$LOG") 2>&1
echo "### sleep-sweep start $(date '+%F %T') conf=[$CONF] N=$N log=$LOG"

boot_ok() {
	S 'true' && [ -n "$(S 'pidof phoc' | tr -d "\r")" ]
}

# 每次成功启动后置槽位成功标志：否则 boot_b retry 递减/耗尽 → ABL 抛到 fastboot
mark_slot() { S 'qbootctl -m b' >/dev/null 2>&1 || true; }

wait_booted() {
	local t kicked=0
	for t in $(seq 1 30); do
		if boot_ok; then mark_slot; return 0; fi
		if [ "$kicked" = 0 ] && [ "$t" -ge 4 ] && FB; then
			echo "    (device in fastboot -> fastboot reboot)"
			timeout 20 fastboot reboot >/dev/null 2>&1
			kicked=1
		fi
		sleep 5
	done
	return 1
}

printf '%s\n' $CONF > /tmp/sleepsweep.conf
S 'cat > /etc/modules-load.d/camera.conf' < /tmp/sleepsweep.conf

for i in $(seq 1 "$N"); do
	wait_booted || { echo "CONF[$CONF] run$i NOBOOT"; continue; }
	S '(sleep 1; reboot) >/dev/null 2>&1 &' >/dev/null 2>&1
	sleep 6
	wait_booted || { echo "CONF[$CONF] run$i NOBOOT-after-reboot"; continue; }
	sleep 3
	r=$(S 'P=$(pidof phoc); export DBUS_SESSION_BUS_ADDRESS=$(tr "\0" "\n" < /proc/$P/environ | sed -n "s/^DBUS_SESSION_BUS_ADDRESS=//p"); export XDG_RUNTIME_DIR=/run/user/0; timeout 10 gdbus call --session --dest org.gnome.ScreenSaver --object-path /org/gnome/ScreenSaver --method org.gnome.ScreenSaver.SetActive true >/dev/null 2>&1; sleep 12; echo ALIVE')
	if [ "${r//$'\r'/}" = "ALIVE" ]; then
		echo "CONF[$CONF] run$i ALIVE"
		S 'P=$(pidof phoc); export DBUS_SESSION_BUS_ADDRESS=$(tr "\0" "\n" < /proc/$P/environ | sed -n "s/^DBUS_SESSION_BUS_ADDRESS=//p"); export XDG_RUNTIME_DIR=/run/user/0; timeout 10 gdbus call --session --dest org.gnome.ScreenSaver --object-path /org/gnome/ScreenSaver --method org.gnome.ScreenSaver.SetActive false >/dev/null 2>&1' >/dev/null 2>&1
	else
		echo "CONF[$CONF] run$i DEAD"
	fi
done
