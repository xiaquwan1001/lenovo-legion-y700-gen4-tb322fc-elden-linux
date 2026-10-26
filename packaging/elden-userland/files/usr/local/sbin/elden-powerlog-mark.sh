#!/bin/sh
# elden-powerlog-mark.sh — 干净关机标记（Q24/G1-22 的唯一可靠判别器）
#
# 从 /etc/init.d/elden-powerlog 的内联 start() 剥离出来（2026-10-25 固化），
# 目的：同一段逻辑既能被 OpenRC shutdown runlevel 调用，也能被 systemd
# shutdown.target 调用，不必在两种 init 里各写一遍。
#
# 判据：事件发生后 marker 存在 ⇒ 干净的、用户态发起的关机；marker 缺失 ⇒ 内核死了。
# 本机 USB VBUS 会自动开机，"它自己回来了"不构成任何证据。
{
	printf 'CLEAN-STOP %s uptime=%s boot_id=%s\n' \
		"$(date '+%F %T')" \
		"$(cut -d. -f1 /proc/uptime)" \
		"$(cat /proc/sys/kernel/random/boot_id 2>/dev/null)"
} >>/root/powerlog.txt 2>/dev/null
# 同时记下当时还活着的服务（OpenRC 有 rc-status，systemd 用 systemctl）
if command -v rc-status >/dev/null 2>&1; then
	rc-status default >>/root/powerlog.txt 2>/dev/null
elif command -v systemctl >/dev/null 2>&1; then
	systemctl list-units --type=service --state=running --no-pager --no-legend \
		>>/root/powerlog.txt 2>/dev/null
fi
sync
exit 0
