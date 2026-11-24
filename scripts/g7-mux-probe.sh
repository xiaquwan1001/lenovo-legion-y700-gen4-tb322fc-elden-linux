#!/bin/bash
# g7-mux-probe.sh — 读「USB HS 数据 mux 的选择线（TLMM GPIO29）」，给 G7 的「换口 → mux 切换」判据用
#
# 为什么有这个脚本（2026-11-24 实机结论，见 reports/g7-routeA-dtfix-20261123.md §7）：
#   `/sys/class/mux/muxchip0` 在 7.4-rc3 上**没有** `mux_state`，`/sys/kernel/debug/mux/` 也是空的
#   ⇒ 判据 3 看似"没有观测面"。但选择线本身可读：`/sys/kernel/debug/gpio` 里 TLMM 的
#   `gpio29 : out low|out high` 就是 mux state 的物理代理：
#       out low  = mux state 0      out high = mux state 1
#   判法 = **插拔前/后各读一次**，电平翻转即"换口 → mux 切换"成立。
#
# 用法：
#   scripts/g7-mux-probe.sh                # 读一次（打印一行 TSV）
#   scripts/g7-mux-probe.sh --watch 60     # 采样 60 s，电平/角色变化才打印（插拔时用这个）
#   scripts/g7-mux-probe.sh --log f.tsv    # 追加到文件（默认只打 stdout）
#
# 环境：TAB=<ssh 目标>（默认 root@192.168.7.1）、INTERVAL=<采样间隔秒，默认 1>
#
# 纪律：
#   · **只读**。绝不要用 `echo … > /sys/class/typec/portX/data_role` 去模拟换口 —— 角色一换，
#     `usb0` 上的 ssh 就断，恢复要人工断电（2026-11-24 评估后放弃的做法）。
#   · 设备必须已在 Linux（ssh 可达）；不在 Linux 时脚本直接报错退出，不做任何复位动作。
set -uo pipefail

TAB=${TAB:-root@192.168.7.1}
INTERVAL=${INTERVAL:-1}
WATCH=0
LOG=""
while [ $# -gt 0 ]; do
	case "$1" in
		--watch) WATCH=${2:?--watch 需要秒数}; shift 2 ;;
		--log) LOG=${2:?--log 需要文件}; shift 2 ;;
		-h|--help) sed -n '2,24p' "$0"; exit 0 ;;
		*) echo "未知参数 $1（见 --help）" >&2; exit 2 ;;
	esac
done

SSH=(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=6 -o BatchMode=yes "$TAB")
probe() { # 打印一行 TSV：时间 \t gpio29 电平 \t port0 data_role \t port1 data_role \t port0 orientation
	local g r0 r1 o0
	g=$("${SSH[@]}" "grep -E ' gpio29 ' /sys/kernel/debug/gpio 2>/dev/null" 2>/dev/null | sed 's/.*: *//; s/  */ /g')
	r0=$("${SSH[@]}" 'cat /sys/class/typec/port0/data_role 2>/dev/null' 2>/dev/null)
	r1=$("${SSH[@]}" 'cat /sys/class/typec/port1/data_role 2>/dev/null' 2>/dev/null)
	o0=$("${SSH[@]}" 'cat /sys/class/typec/port0/orientation 2>/dev/null' 2>/dev/null)
	printf '%s\t%s\t%s\t%s\t%s\n' "$(date -Is)" "${g:-<no-gpio29>}" "${r0:-?}" "${r1:-?}" "${o0:-?}"
}

"${SSH[@]}" true 2>/dev/null || { echo "[mux-probe] ❌ 设备不在 Linux（ssh $TAB 不可达）⇒ 不探、不复位" >&2; exit 1; }

emit() { local line=$1; printf '%s\n' "$line"; [ -n "$LOG" ] && printf '%s\n' "$line" >> "$LOG"; }

if [ "$WATCH" = 0 ]; then
	emit "$(probe)"
	exit 0
fi

echo "# 采样 ${WATCH}s（间隔 ${INTERVAL}s）—— 现在可以插拔线缆；只打印变化行" >&2
prev=""
end=$(( $(date +%s) + WATCH ))
while [ "$(date +%s)" -lt "$end" ]; do
	cur=$(probe)
	key=$(printf '%s' "$cur" | cut -f2-)
	if [ "$key" != "$prev" ]; then
		emit "$cur"; prev=$key
	fi
	sleep "$INTERVAL"
done
