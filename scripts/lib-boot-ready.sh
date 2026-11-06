#!/usr/bin/env bash
# lib-boot-ready.sh — 「复位/进 fastboot 前的系统就绪门」（host 侧，经 SSH 判定当前运行的系统）
#
# 动机（见 reports/audit-early-reboot-20261012.md）：
#   系统尚未起来（桌面未起、DSI/DRM 仍在 bring-up）时就发 reboot2 bootloader，
#   偶发把设备打进「无任何 USB 通道」态（fastboot/NCM 全无、ping 不通），只能长按断电恢复
#   （PITFALLS #143）。2026-10-12 实测：uptime≈20s 发 reboot2 → 全通道丢失；
#   uptime=138s、桌面已起时执行 → 正常进 fastboot。
#   旧脚本只把「SSH 可达」当就绪，而 SSH 在 uptime≈6.7s 即可用、比桌面早得多（PITFALLS #67），
#   门太松，可在上电 <60s 触发。
#
# 用法（在被 patch 的脚本里）：
#   . "$(dirname "$0")/lib-boot-ready.sh"
#   boot_ready_or_die            # 不就绪即 die；就绪返回 0
#
# 就绪判据（全部通过才放行，fail-closed）：
#   1) SSH 现问现答（fire 前复核一次）
#   2) uptime >= BOOT_READY_MIN_UPTIME（默认 90 s）
#   3) 桌面已起：phoc 或 phosh 在跑（现场证据里真正区分好坏的信号）
#      非图形/RAM 诊断变体确无判据时显式 BOOT_READY_ALLOW_NODESKTOP=1 跳过 3)
#   4) 可选：BOOT_READY_REJECT_STORM=1 时，dmesg 有 vblank/power-up-failed 风暴即拒绝
#      （坏发态软复位路径本身不可靠，PITFALLS #150/#170）
#
# 逃生阀：ELDEN_FORCE_REBOOT=1 跳过本门（打印醒目告警），供确知安全的场景。
# 依赖：调用方提供 ssh 包装 $S（形如: S '<cmd>' [timeout] -> 走 timeout+ssh）。
: "${BOOT_READY_MIN_UPTIME:=90}"
: "${BOOT_READY_ALLOW_NODESKTOP:=0}"
: "${BOOT_READY_REJECT_STORM:=0}"

boot_ready_or_die() {
	# $S 缺省时自动加载同目录 lib-ssh.sh（拿统一的 BatchMode/超时口径），而不是留一个
	# 名叫 "S" 的不存在命令等它失败（2026-11-05 脚本审计顺手修掉的老坑）。
	if [ -z "${S:-}" ]; then
		if ! declare -F S >/dev/null 2>&1 && [ -f "$(dirname "${BASH_SOURCE[0]}")/lib-ssh.sh" ]; then
			# shellcheck disable=SC1091
			. "$(dirname "${BASH_SOURCE[0]}")/lib-ssh.sh"
		fi
		S=S
	fi
	local up phoc phosh storm reason=""
	if [ "${ELDEN_FORCE_REBOOT:-0}" = 1 ]; then
		echo "[boot-ready] WARN ELDEN_FORCE_REBOOT=1 -- skip readiness gate (self-inflicted hang risk)" >&2
		return 0
	fi

	# ★ 2026-11-05（脚本审计 P2）：就绪判定的 4–5 项**合成一条远端命令**。
	#   旧版顺序发 4 条 ssh（ssh 活 + uptime + phoc + phosh，可选第 5 条 dmesg），
	#   每条 timeout 10–15 s ⇒ 弱链路/忙设备最坏 ~40 s 才得出「能不能重启」；而且分开发的
	#   4 次探测彼此跨秒，不是同一时刻的快照。合成一条后：1 个往返、1 个时刻、输出可解析。
	#   解析用 bash 内建，不依赖 awk/tr 的多次拉取。
	# ★ 单引号是**必须**的：这些 $( ) 要在远端求值，双引号会在主机上就地展开
	#   （试过：双引号版把主机 uptime 当设备 uptime，判据静默失效——自检用例抓到的正是这条）。
	local probe
	probe='echo alive=yes; echo up=$(cut -d. -f1 /proc/uptime 2>/dev/null); '
	probe="$probe"'echo phoc=$(ps -eo comm | grep -cx phoc); echo phosh=$(ps -eo comm | grep -cx phosh); '
	if [ "$BOOT_READY_REJECT_STORM" = 1 ]; then
		probe="$probe"'echo storm=$(dmesg 2>/dev/null | grep -cE "vblank wait timed out|power-up failed|command DMA timeout"); '
	fi
	local out alive="" up="" phoc="" phosh="" storm="" line
	out="$($S "$probe" 20)"
	while IFS= read -r line; do
		line="${line%$'\r'}"
		case "$line" in
			alive=*) alive="${line#alive=}" ;;
			up=*)    up=$(printf '%s' "${line#up=}" | tr -dc '0-9') ;;
			phoc=*)  phoc=$(printf '%s' "${line#phoc=}" | tr -dc '0-9') ;;
			phosh=*) phosh=$(printf '%s' "${line#phosh=}" | tr -dc '0-9') ;;
			storm=*) storm=$(printf '%s' "${line#storm=}" | tr -dc '0-9') ;;
		esac
	done <<< "$out"

	# 1) SSH 活（同一趟里拿到的第一个信号；整趟空 = 不可达）
	if [ "$alive" != yes ]; then
		echo "[boot-ready] FAIL: SSH 未答（设备不在 Linux 或通道未起）-- 拒绝 reboot" >&2
		echo "[boot-ready]   若目标是物理 POR 冷起样本，见 archive/2026-10-15-retired-scripts/q28-cold-run.sh，别在此强发复位。" >&2
		exit 3
	fi

	# 2) uptime（busybox 上 pgrep -x 不可靠，桌面用 ps|grep -cx，见 PITFALLS #68）
	up="${up:-0}"; phoc="${phoc:-0}"; phosh="${phosh:-0}"
	[ "$up" -lt "$BOOT_READY_MIN_UPTIME" ] && reason="$reason uptime=${up}s<${BOOT_READY_MIN_UPTIME}s;"
	if [ "$BOOT_READY_ALLOW_NODESKTOP" != 1 ] && [ "$((phoc + phosh))" -lt 1 ]; then
		reason="$reason desktop-not-up(phoc+phosh=0);"
	fi

	# 3) 可选风暴拒绝（坏发态软复位不可靠，PITFALLS #150/#170）
	if [ "$BOOT_READY_REJECT_STORM" = 1 ]; then
		storm="${storm:-0}"
		[ "$storm" -gt 0 ] && reason="$reason storm-sig=${storm};"
	fi

	if [ -n "$reason" ]; then
		echo "[boot-ready] FAIL: 系统未就绪，拒绝进 fastboot/reboot。原因:${reason}" >&2
		echo "[boot-ready]   等系统完全起来（桌面可见、uptime>=${BOOT_READY_MIN_UPTIME}s）后重跑；" >&2
		echo "[boot-ready]   确无桌面的非图形变体：BOOT_READY_ALLOW_NODESKTOP=1；确知安全强发：ELDEN_FORCE_REBOOT=1" >&2
		exit 4
	fi
	echo "[boot-ready] OK: uptime=${up}s phoc=${phoc} phosh=${phosh} -- 放行进 fastboot"
	return 0
}
