#!/bin/sh
# probes/g7-dwc3.sh — dwc3 双连接器（G7）真机判据采集（设备侧 POSIX sh，只读）
#
# 用法（主机侧）：
#   scripts/autotest-cycle.sh --image <件>.img --test probes/g7-dwc3.sh --label g7
# 基线对照：同一脚本跑在 bootslot-b/boot_b.img（日常核）上，逐行 diff 才有效。
#
# 判据（reports/g7-routeA-dtfix-20261123.md §3 + 2026-11-25 更正）：
#   · `Failed to create device link` 的判据是 **≤ 日常基线**，不是 =0 —— 实测基线本身
#     就有 8 条（qcom_pmic_glink → 5-0042/5-0043/88e8000.phy/a600000.usb），是既有状态。
#   · role switch 两个都注册且 waiting_for_supplier=0。
#   · gadget 活着（/sys/class/udc 有 a600000.usb）—— 说明 HS 数据总线确实被选中。
#   · 换口→mux 翻转需要人插拔，本脚本只采「可观测面在不在」（不判 pass/fail）。
set -u
echo "UTS=$(uname -r)"
echo "BUILD=$(uname -v)"
echo "ROOT=$(findmnt -no SOURCE,FSTYPE / | tr ' ' ':')"
echo "--- devlink ---"
echo "DEVLINK_FAIL=$(dmesg | grep -c 'Failed to create device link')"
dmesg | grep 'Failed to create device link' | sed 's/^/  dl: /' | head -12
echo "DEVLINK_CYCLE=$(dmesg | grep -c 'Fixed dependency cycle')"
echo "--- usb role ---"
echo "ROLE_SWITCHES=$(ls /sys/class/usb_role 2>/dev/null | tr '\n' ' ')"
for r in /sys/class/usb_role/*/; do
	[ -d "$r" ] || continue
	n=$(basename "$r")
	[ -e "$r/waiting_for_supplier" ] && echo "  $n waiting_for_supplier=$(cat "$r/waiting_for_supplier" 2>/dev/null)"
	[ -e "$r/role" ] && echo "  $n role=$(cat "$r/role" 2>/dev/null)"
done
echo "--- gadget / udc ---"
echo "UDC=$(ls /sys/class/udc 2>/dev/null | tr '\n' ' ')"
echo "--- typec ---"
for p in /sys/class/typec/port*; do
	[ -e "$p" ] || continue
	echo "  $(basename "$p") data_role=$(cat "$p/data_role" 2>/dev/null) power_role=$(cat "$p/power_role" 2>/dev/null) orientation=$(cat "$p/orientation" 2>/dev/null)"
done
echo "PARTNERS=$(ls -d /sys/class/typec/port*-partner 2>/dev/null | wc -l)"
echo "--- mux 可观测面 ---"
echo "MUXCLASS=$(ls /sys/class/mux 2>/dev/null | tr '\n' ' ')"
echo "MUXDEBUGFS=$(ls /sys/kernel/debug/mux 2>/dev/null | tr '\n' ' ')"
grep -H . /sys/class/mux/*/mux_state 2>/dev/null | sed 's/^/  mux: /' || echo "  mux_state: 无（本核不暴露）"
echo "--- dmesg 关键词 ---"
echo "MUX_LINES=$(dmesg | grep -ciE 'fsa4480|typec|mux|role switch')"
dmesg | grep -iE 'fsa4480|role switch|mux' | tail -8 | sed 's/^/  m: /'
echo "--- 告警面 ---"
echo "WARN=$(dmesg | grep -c 'WARNING:')"
echo "TRACE=$(dmesg | grep -ciE 'call trace')"
echo "PANIC_OOP=$(dmesg | grep -ciE 'BUG:|Oops')"
echo "FAILED_UNITS=$(systemctl --failed --no-legend 2>/dev/null | wc -l)"
exit 0
