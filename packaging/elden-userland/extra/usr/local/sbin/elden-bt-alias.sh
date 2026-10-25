#!/bin/sh
# elden-bt-alias.sh — 开机后设蓝牙适配器名字/上电
#
# 从 /etc/local.d/elden-bringup.start 的 inline 子 shell 剥离（2026-10-25 固化）。
# hci0 要等 btqca 加载固件后 ~30 s 才出现，所以先等再设；bluetoothd 由 bluetooth 服务拉起。

ALIAS=${BT_ALIAS:-elden}
WAIT=${BT_WAIT:-30}

sleep "$WAIT"
command -v bluetoothctl >/dev/null 2>&1 || exit 0
bluetoothctl system-alias "$ALIAS" >/dev/null 2>&1
bluetoothctl power on >/dev/null 2>&1
exit 0
