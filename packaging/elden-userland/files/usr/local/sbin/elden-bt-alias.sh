#!/bin/sh
# elden-bt-alias.sh — 开机后设蓝牙适配器名字/上电
#
# hci0 要等 btqca 固件下载完（~30 s）才 UP；本脚本**必须立即返回**：
# 它在 OpenRC default runlevel 里是 oneshot，同步 sleep 会把 elogind/greetd 一起堵住
# （2026-10-26 实测：冷起多等 30 s，桌面迟迟不来）。等待逻辑放后台子 shell。
ALIAS=${BT_ALIAS:-elden}
(
	i=0
	while [ "$i" -lt 60 ]; do
		hciconfig hci0 2>/dev/null | grep -q "UP RUNNING" && break
		i=$((i + 1))
		sleep 1
	done
	command -v bluetoothctl >/dev/null 2>&1 || exit 0
	bluetoothctl system-alias "$ALIAS" >/dev/null 2>&1
	bluetoothctl power on >/dev/null 2>&1
) >/dev/null 2>&1 &
exit 0
