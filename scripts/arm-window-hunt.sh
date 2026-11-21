#!/bin/bash
# arm-window-hunt.sh — 在坏发成簇的窗口里交替试多个显示臂，直到出现"健康发"。
# usage: scripts/arm-window-hunt.sh <wait_s> <label1:img1> [label2:img2 ...]
# 每发：确认设备已在 fastboot（★#701 后不做软重启：Linux→BL 三条软路径全灭）→
#        fastboot boot → 串口抓 WAIT 秒 → 判 L1/L2 → 健康（L1=L2=0）则停在设备上并打印 HEALTHY。
# 判据只依赖串口；SSH 只用于**探活**（判断设备到底在 Linux 还是断线），不再用于复位。
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT"
WAIT=${1:?usage: arm-window-hunt.sh <wait_s> <label:img>...}; shift
SSH="ssh -o StrictHostKeyChecking=no -o ConnectionAttempts=1 -o ConnectTimeout=8 -o UserKnownHostsFile=/dev/null -o BatchMode=yes -b 0 ${TAB:-root@192.168.7.1}"

# PITFALLS #584：`fastboot devices | grep -q` 会 SIGPIPE 打断 bulk 通道 ⇒ 只能物理 POR。
# 必须先取完整输出再在 shell 里判（不要接管道给 grep）。
in_fastboot() { d=$(timeout 6 fastboot devices 2>/dev/null); case "$d" in *fastboot*) return 0 ;; *) return 1 ;; esac; }
# ★ #701 fail-closed 门（2026-11-21，reports/linux-to-fastboot-20261121.md）：Linux→fastboot 的
#   三条软路径（sz reboot2 bootloader / systemctl reboot bootloader / SysRq-b→reboot2）实测全灭。
#   旧实现在这里"重启一下再继续采样"，实际每发都停在 Linux ⇒ 静默产无效样本。现在只探活、不软重启。
BL_NEED_PHYS='需物理键进 BL，见 reports/linux-to-fastboot-20261121.md'
to_fastboot() {
	in_fastboot && return 0
	if timeout 15 $SSH 'echo up' 2>/dev/null | grep -q up; then
		echo "[hunt] 设备在 Linux（SSH 可达）但不在 fastboot —— #701：软重启路径已实测全灭，本节不尝试。"
	else
		echo "[hunt] 设备既不在 fastboot，SSH 探活也失败（卡片/正在重启/线缆？）。"
	fi
	echo "[hunt] $BL_NEED_PHYS（音量下 + 电源），进 BL 后重跑本脚本。"
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
	if ! to_fastboot; then echo "[hunt] ❌ 无法进入 fastboot ⇒ 停手（不产无效样本）：$BL_NEED_PHYS"; exit 2; fi
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
