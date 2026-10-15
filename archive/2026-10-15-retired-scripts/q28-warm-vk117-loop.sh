#!/bin/bash
# q28-warm-vk117-loop.sh — 从当前活台架自举：sysrq-b 回干净启动 → **等就绪** → reboot2 bootloader
# → fastboot boot <img> → 判读，循环 N 轮。用途：验证 vk117（干净恢复序列 + 复位前后寄存器转储）
# 在**坏发**时能否把 bonded DSI 链路拉回来。
#
# ★纪律（PITFALLS #225，2026-10-12 本机 2/2 复现）：reboot2 前必须**等**就绪（uptime>=120s + phoc/phosh 已起）；
#   uptime<25 s 就 reboot2 会把设备打进无任何 USB 通道态，只能人工长按关机。
#   暖启样本对 Q28 冷起 A/B 无效（PITFALLS #166），仅作机制取证。
set -uo pipefail
ROOT=/home/xuqianhui1001/y700-elden
cd "$ROOT"
IMG=${1:?usage: q28-warm-vk117-loop.sh <boot.img> [rounds]}
N=${2:-3}
TAB=root@192.168.7.1
MIN_UP=${MIN_UP:-120}
S() { timeout "${2:-25}" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=6 -b 0 "$TAB" "$1" 2>/dev/null; }

# 等就绪；成功回 0，超时回 1
wait_ready() {
	local U P H i
	for i in $(seq 1 60); do
		U=$(S 'cut -d" " -f1 /proc/uptime' 6); P=$(S 'ps -eo comm | grep -cx phoc' 6); H=$(S 'ps -eo comm | grep -cx phosh' 6)
		echo "[loop] ready? uptime=${U:-?} phoc=${P:-?} phosh=${H:-?}"
		if [ -n "$U" ] && [ "${U%%.*}" -ge "$MIN_UP" ] 2>/dev/null && { [ "${P:-0}" -ge 1 ] || [ "${H:-0}" -ge 1 ]; }; then
			echo "[loop] READY: uptime=$U phoc=$P phosh=$H"
			return 0
		fi
		sleep 5
	done
	return 1
}

ssh_up() { [ "$(S 'echo up' 6)" = up ]; }

for boot_try in 1 2; do
	echo "[loop] bootstrap #$boot_try：sysrq-b 回干净启动"
	if ssh_up; then
		S 'echo b > /proc/sysrq-trigger' 8 >/dev/null 2>&1 || true
	fi
	for i in $(seq 1 40); do ssh_up && break; sleep 5; done
	if wait_ready; then break; fi
	echo "[loop] bootstrap #$boot_try 未就绪"
done
wait_ready || { echo "[loop] FAIL=no-ready-boot —— 需要有人物理 POR"; exit 1; }

for r in $(seq 1 "$N"); do
	echo "=== round $r/$N $(date +%T) ==="
	# 上一轮 fastboot boot 后设备刚起，必须先等就绪再 reboot2（PITFALLS #225）
	wait_ready || { echo "[loop] round $r: 未就绪，停止（不冒险 reboot2）"; exit 1; }
	bash scripts/q28-boot-cycle.sh "$IMG" "vk117-r$r"
	rc=$?
	D=$(ls -t logs/q28-cycle-*/dmesg.txt 2>/dev/null | head -1)
	echo "[loop] round $r rc=$rc dmesg=$D"
	grep -nE 'Q28 link\[|resetting DSI link|unbalanced disables|Turning OFF PHY|panel init attempt|Failed to initialize panel|bonded command DMA failed' "$D" 2>/dev/null | head -20
	echo "[loop] --- round $r end ---"
done
echo "[loop] done"
