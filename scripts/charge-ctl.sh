#!/bin/sh
# charge-ctl.sh — battery / charger control for TB322FC (elden), qcom-battmgr.
#
# On mainline the charger is managed by the ADSP via PMIC-GLINK; the OS only has
# two knobs:
#   * qcom-battmgr-usb/input_current_limit  -> how much the SoC may pull from USB
#     (this is the "charging power").  The ADSP defaults it to 100 mA (USB
#     suspend level), so with a PC/USB port the tablet NET DISCHARGES even while
#     plugged in.  Raising it to current_max makes it charge.
#   * qcom-battmgr-bat/charge_control_{start,end}_threshold -> "Battery Care"
#     charge limit (>=55%); charging stops at end%, resumes at start%.
#
# Usage:
#   charge-ctl.sh status
#   charge-ctl.sh power <uA|max>      # set input current limit (uA) or current_max
#   charge-ctl.sh limit <pct|off>     # battery-care end threshold (55..100) or off
#   charge-ctl.sh bypass              # run on adapter: cap charge at current SOC
#   charge-ctl.sh auto                # power = current_max (fix net discharge)
#
# Note: input_current_limit resets when the charger is re-detected, so `auto`
# should be re-applied on USB plug events (see /etc/udev/rules.d + charge-watch.sh).
set -u
BAT=/sys/class/power_supply/qcom-battmgr-bat
USB=/sys/class/power_supply/qcom-battmgr-usb

rd() { cat "$1" 2>/dev/null; }

status() {
	echo "battery : status=$(rd $BAT/status) type=$(rd $BAT/charge_type) cap=$(rd $BAT/capacity)% health=$(rd $BAT/health)"
	echo "          V=$(rd $BAT/voltage_now)uV I=$(rd $BAT/current_now)uA (I>0 charging) temp=$(rd $BAT/temp)"
	echo "          charge_limit=$(rd $BAT/charge_control_start_threshold)/$(rd $BAT/charge_control_end_threshold)%"
	echo "usb     : online=$(rd $USB/online) V=$(rd $USB/voltage_now)uV I=$(rd $USB/current_now)uA"
	echo "          input_current_limit=$(rd $USB/input_current_limit)uA current_max=$(rd $USB/current_max)uA"
	echo "          usb_type=$(rd $USB/usb_type)"
}

power() {
	case "${1:-}" in
	max) v=$(rd $USB/current_max) ;;
	''|*[!0-9]*) echo "usage: charge-ctl.sh power <uA|max>"; exit 1 ;;
	*) v=$1 ;;
	esac
	echo "$v" > $USB/input_current_limit && echo "input_current_limit = $v uA"
}

limit() {
	case "${1:-}" in
	off) echo 100 > $BAT/charge_control_end_threshold; echo "charge limit off (100%)"; return ;;
	''|*[!0-9]*) echo "usage: charge-ctl.sh limit <pct|off>"; exit 1 ;;
	esac
	p=$1
	[ "$p" -lt 55 ] && p=55          # kernel clamps to 55
	[ "$p" -gt 100 ] && p=100
	echo "$p" > $BAT/charge_control_end_threshold && \
		echo "charge limit = $(rd $BAT/charge_control_start_threshold)/$(rd $BAT/charge_control_end_threshold)%"
}

case "${1:-status}" in
	status) status ;;
	power) shift; power "$@" ;;
	limit) shift; limit "$@" ;;
	bypass) limit "$(rd $BAT/capacity)"; status ;;
	auto) power max; status ;;
	*) echo "usage: charge-ctl.sh {status|power <uA|max>|limit <pct|off>|bypass|auto}"; exit 1 ;;
esac
