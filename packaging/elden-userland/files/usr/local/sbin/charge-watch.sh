#!/bin/sh
# charge-watch.sh — keep the qcom-battmgr charger settings applied.
#
# Two things must be (re)applied at runtime on mainline:
#   1. input_current_limit: the ADSP defaults it to 100 mA, which makes the
#      tablet net-discharge even while plugged in.  Set it to current_max.
#   2. optional battery-care limit from /etc/charge.conf (LIMIT=off|55..100).
#
# The charger is re-detected on every (re)plug and the limit resets, so poll and
# re-apply.  Started by /init (see patch-init-charge.sh) or manually.
set -u
USB=/sys/class/power_supply/qcom-battmgr-usb
BAT=/sys/class/power_supply/qcom-battmgr-bat
CONF=/etc/charge.conf
LOG=/run/charge-watch.log
CCTL=/usr/local/sbin/charge-ctl.sh

log() { echo "$(date '+%H:%M:%S') $*" >>"$LOG"; }
: >"$LOG"
log "started"

# ---- 启动顺序竞态（2026-11-11 实测，reports/t18-charging-timing-20261111.md）----
# /init 在 boot 后 9.0 s 就拉起本脚本，而 `qcom-battmgr-usb` 的 power_supply 节点
# 要 12.84 s 才被 healthd 发现 ⇒ 首轮空转，下一轮在 ~19 s（旧的 sleep 10）。
# 插电后这段时间里 ADSP 默认给 100 mA（见文件头），没有人顶回 ⇒ 净放电。
# 所以：先阻塞等节点出现，再进主循环。
wait_for_usb() {
	i=0
	while [ ! -e "$USB/online" ] && [ "$i" -lt 600 ]; do	# 最长等 120 s
		i=$((i + 1)); sleep 0.2
	done
	if [ -e "$USB/online" ]; then
		log "usb node appeared after $((i / 5)) s"
	else
		log "usb node never appeared (120 s) - continuing anyway"
	fi
}
wait_for_usb

while true; do
	# 1. charging power: pull the ADSP-negotiated maximum
	if [ -e "$USB/online" ] && [ "$(cat "$USB/online")" = 1 ]; then
		cur=$(cat "$USB/input_current_limit" 2>/dev/null)
		max=$(cat "$USB/current_max" 2>/dev/null)
		if [ -n "$cur" ] && [ -n "$max" ] && [ "$cur" -lt "$max" ]; then
			echo "$max" >"$USB/input_current_limit" 2>/dev/null && \
				log "input_current_limit $cur -> $max uA"
		fi
	fi

	# 2. optional battery-care limit
	if [ -f "$CONF" ]; then
		. "$CONF" 2>/dev/null
		if [ -n "${LIMIT:-}" ] && [ "$LIMIT" != off ] && [ -x "$CCTL" ]; then
			end=$(cat "$BAT/charge_control_end_threshold" 2>/dev/null)
			[ -n "$end" ] && [ "$end" != "$LIMIT" ] && "$CCTL" limit "$LIMIT" >/dev/null 2>&1
		fi
	fi

	# 轮询周期 2 s（原 10 s）：ADSP 会在每次重插时把 ICL 拉回 100 mA，
	# 10 s 的窗口太长，用户能看出「插着不充电」。
	sleep 2
done
