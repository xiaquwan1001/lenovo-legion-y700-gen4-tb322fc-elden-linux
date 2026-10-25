#!/bin/sh
# elden-bootlog.sh — 每次启动一份证据快照（文件名带 boot_id）
#
# 从 /etc/local.d/elden-bootlog.start 剥离（2026-10-25 固化）。为什么要带 boot_id：
# kexec 目标内核的日志会与回退启动的日志混在同一文件里，带 id 才能分开。

id=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null)
[ -n "$id" ] || exit 0
mkdir -p /var/log
{
	date
	echo "boot_id=$id"
	echo "cmdline=$(cat /proc/cmdline)"
	echo "uptime=$(cut -d' ' -f1 /proc/uptime)"
	echo '--- /sys/class/drm ---'; ls /sys/class/drm 2>/dev/null
	echo '--- card0-DSI-1 ---'; cat /sys/class/drm/card0-DSI-1/status 2>/dev/null
	echo '--- dmesg ---'; dmesg 2>/dev/null
} > "/var/log/dmesg-$id.txt" 2>&1
sync
exit 0
