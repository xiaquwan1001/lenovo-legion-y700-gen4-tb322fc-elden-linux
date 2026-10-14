#!/bin/bash
# arm-window-hunt.sh — 在坏发成簇的窗口里交替试多个显示臂，直到出现"健康发"。
# usage: scripts/arm-window-hunt.sh <wait_s> <label1:img1> [label2:img2 ...]
# 每发：确保在 fastboot（必要时单次 SSH reboot2 bootloader）→ fastboot boot → 串口抓 WAIT 秒
#        → 判 L1/L2 → 健康（L1=L2=0）则停在设备上并打印 HEALTHY。
# 判据只依赖串口（SSH 挂了也能跑）；SSH 只用于复位，单次、带退避。
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT"
WAIT=${1:?usage: arm-window-hunt.sh <wait_s> <label:img>...}; shift
SSH="ssh -o StrictHostKeyChecking=no -o ConnectionAttempts=1 -o ConnectTimeout=8 -o UserKnownHostsFile=/dev/null -o BatchMode=yes -b 0 root@192.168.7.1"

in_fastboot() { fastboot devices 2>/dev/null | grep -q .; }
to_fastboot() {
	in_fastboot && return 0
	echo "[hunt] 单次 SSH reboot2 bootloader"
	timeout 20 $SSH 'reboot2 bootloader' >/dev/null 2>&1
	for i in $(seq 1 10); do in_fastboot && return 0; sleep 4; done
	# 显示坏态下 reboot2 会挂 DRM cleanup（PITFALLS #253）⇒ 退回 SysRq-b → 日常 → 再进 fastboot
	echo "[hunt] reboot2 无效，改 SysRq-b（回日常）"
	timeout 20 $SSH 'echo b > /proc/sysrq-trigger' >/dev/null 2>&1
	for i in $(seq 1 30); do
		timeout 12 $SSH 'echo up' 2>/dev/null | grep -q up && break
		sleep 6
	done
	echo "[hunt] 日常已起，再 reboot2 bootloader"
	timeout 20 $SSH 'reboot2 bootloader' >/dev/null 2>&1
	for i in $(seq 1 15); do in_fastboot && return 0; sleep 4; done
	return 1
}
judge() { # $1 = console log
	local log=$1
	local l1 l2
	l1=$(grep -Ec 'command DMA timeout|bonded command DMA failed|Failed to initialize panel|sending dcs data .* failed' "$log")
	l2=$(grep -Ec 'ctl [0-9]+ reset failure|frame done timeout|vblank wait timed out|vblank timeout' "$log")
	echo "$l1 $l2"
}

for spec in "$@"; do
	label=${spec%%:*}; img=${spec#*:}
	echo "=================== $label ==================="
	if ! to_fastboot; then echo "[hunt] ❌ 无法进入 fastboot（SSH 不可用）——需要物理 POR"; exit 2; fi
	out=$(bash scripts/arm-console-run.sh "$img" "$label" "$WAIT" 2>&1 | tail -6)
	echo "$out"
	log=$(echo "$out" | sed -n 's/.*console=\([^ ]*\).*/\1/p')
	read l1 l2 <<< "$(judge "$log")"
	echo "[hunt] $label  L1=$l1 L2=$l2"
	if [ "$l1" -eq 0 ] && [ "$l2" -eq 0 ]; then
		echo "[hunt] ✅ HEALTHY: $label  (log=$log)  —— 设备停在该臂上，请目视面板"
		exit 0
	fi
done
echo "[hunt] ✖ 全部尝试均为坏发（窗口坏）"
exit 1
