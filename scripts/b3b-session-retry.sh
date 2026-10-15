#!/bin/sh
# b3b-session-retry.sh — 零构建实验：在坏发台上重走一次 modeset，看面板是否点亮。
#
# 动机：B1 首样本证明「让失败非致命」不够，缺的是「谁发起重试」
# （reports/q28-b1-firstsample-20261015.md）。本脚本测最廉价的候选形态 B3-b：
# 由用户态重启会话（= 触发一次新的 atomic commit），而非整机复位。
#
# 用法：sh b3b-session-retry.sh before|retry
#   before → 记录当前坏发态
#   retry  → 停 greetd + kill phoc → 等 → 重启 greetd → 等 15 s → 记录结果
#
# 判据：l1 / dsi_isr / reset_failure 计数 + ★用户目视（唯一可信，PITFALLS #275）。
set -eu

s() { busybox timeout 20 "$@" 2>/dev/null; }

snap() {
	echo "uptime=$(cut -d' ' -f1 /proc/uptime)"
	echo "dsi_isr=$(grep dsi_isr /proc/interrupts | head -1 | awk '{print $2}')"
	echo "l1=$(dmesg | grep -cE 'command DMA timeout|bonded command DMA failed|Failed to initialize panel')"
	echo "reset_failure=$(dmesg | grep -c 'reset failure')"
	echo "hw_recovery=$(dmesg | grep -c 'hw recovery is not complete')"
	echo "panel_prepared=$(dmesg | grep -c 'panel prepared')"
	echo "phoc=$(pgrep -xc phoc 2>/dev/null || echo 0)"
	echo "phosh=$(pgrep -xc phosh 2>/dev/null || echo 0)"
	echo "backlight=$(cat /sys/class/backlight/*/brightness 2>/dev/null | head -1)"
	echo "dpms=$(cat /sys/class/drm/card0-DSI-1/dpms 2>/dev/null)"
	echo "connector=$(cat /sys/class/drm/card0-DSI-1/status 2>/dev/null)"
}

case "${1:-}" in
before)
	echo "=== BEFORE (bad boot) ==="
	snap
	;;
retry)
	echo "=== BEFORE ==="
	snap
	echo
	echo "=== stopping greetd + phoc (release DRM master) ==="
	rc-service greetd stop 2>&1 | tail -1 || true
	sleep 2
	pkill -x phoc 2>/dev/null || true
	sleep 3
	echo "phoc after stop: $(pgrep -xc phoc 2>/dev/null || echo 0)"
	echo
	echo "=== restarting greetd (=> new atomic commit / modeset) ==="
	rc-service greetd start 2>&1 | tail -1 || true
	sleep 20
	echo
	echo "=== AFTER ==="
	snap
	;;
*)
	echo "usage: $0 before|retry" >&2
	exit 2
	;;
esac
