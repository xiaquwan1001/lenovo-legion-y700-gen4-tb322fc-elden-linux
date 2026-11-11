#!/bin/sh
# charge-icl-fix.sh — 事件驱动地把 input_current_limit 顶回 current_max
#
# 由 /etc/udev/rules.d/90-elden-charge.rules 在 power_supply 的 add/change
# 事件里调用（reports/t18-charging-timing-20261111.md）。
# 与 charge-watch.sh 的区别：本脚本**只做一次**，不循环；两者互补
# （udev 事件窗口趋零，charge-watch 兜住没有事件的情况）。
#
# 判据：插拔 USB 后 1 s 内 input_current_limit == current_max。
# 回退：删掉 udev 规则即可，本脚本不常驻。
set -u
USB=/sys/class/power_supply/qcom-battmgr-usb

[ -e "$USB/online" ] || exit 0
[ "$(cat "$USB/online" 2>/dev/null)" = 1 ] || exit 0

cur=$(cat "$USB/input_current_limit" 2>/dev/null) || exit 0
max=$(cat "$USB/current_max" 2>/dev/null) || exit 0
[ -n "$cur" ] && [ -n "$max" ] || exit 0

if [ "$cur" -lt "$max" ]; then
	echo "$max" >"$USB/input_current_limit" 2>/dev/null && \
		logger -t charge-icl-fix "input_current_limit $cur -> $max uA (udev)"
fi
