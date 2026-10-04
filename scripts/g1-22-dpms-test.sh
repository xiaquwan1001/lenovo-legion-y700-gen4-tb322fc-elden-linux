#!/bin/sh
# g1-22-dpms-test.sh — 在设备上定量测试「熄屏（DPMS off）→ 回归」。
#
# 背景（G1-22 / GAPS Q21-Q22）：post-vk34 增量使 vk40+ 在显示 on/off 提交后出现
#   - DPU `vblank timeout`（`wait for commit done returned -110`）
#   - `UCSI PPM init failed`
#   - 间歇性整机静默硬复位（无 panic）
# vk34recon 基线为 0/0。本脚本用可控的 DPMS off/on 循环做定量计数，供 A/B 对比。
#
# 用法（设备上）：g1-22-dpms-test.sh [cycles]
# 输出：KEY=VALUE 行，便于主机侧解析。
set -u
CYCLES=${1:-5}
OUT=$(uname -r)
echo "UNAME=$OUT"
echo "UPTIME_BEFORE=$(cut -d' ' -f1 /proc/uptime)"

# DSI 连接器：优先 DRM 连接器名，退化用 DSI-1
CONN=""
for d in /sys/class/drm/card*-DSI-*; do
	[ -e "$d/status" ] || continue
	b=$(basename "$d"); CONN=${b#card*-}
done
[ -n "$CONN" ] || CONN=DSI-1
echo "CONN=$CONN"
echo "DPMS_BEFORE=$(cat /sys/class/drm/card*-"$CONN"/dpms 2>/dev/null | head -1)"

# 会话环境（wlr-randr 需连到 phoc 的 wayland/session bus）
export XDG_RUNTIME_DIR=/run/phosh
PID=$(pidof phosh 2>/dev/null || pidof phoc 2>/dev/null || true)
if [ -n "$PID" ]; then
	export DBUS_SESSION_BUS_ADDRESS=$(tr '\0' '\n' < /proc/"$PID"/environ | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p')
fi
echo "PHOSH_PID=${PID:-none}"
echo "WAYLAND_DISPLAY=$(basename /run/phosh/wayland-* 2>/dev/null | head -1)"

cnt() { dmesg 2>/dev/null | grep -cE "$1"; }
echo "BASE_VBLANK=$(cnt 'vblank timeout')"
echo "BASE_PPM=$(cnt 'PPM init failed')"
echo "BASE_DPU_WAIT=$(cnt 'wait for commit done returned -110')"

# 触发循环：真实合成器提交 on/off
i=1
while [ "$i" -le "$CYCLES" ]; do
	wlr-randr --output "$CONN" --off >/dev/null 2>&1
	echo "CYCLE_${i}_OFF_RC=$?"
	sleep 5
	wlr-randr --output "$CONN" --on >/dev/null 2>&1
	echo "CYCLE_${i}_ON_RC=$?"
	sleep 3
	i=$((i + 1))
done

echo "AFTER_VBLANK=$(cnt 'vblank timeout')"
echo "AFTER_PPM=$(cnt 'PPM init failed')"
echo "AFTER_DPU_WAIT=$(cnt 'wait for commit done returned -110')"
echo "UPTIME_AFTER=$(cut -d' ' -f1 /proc/uptime)"
echo "DONE"
