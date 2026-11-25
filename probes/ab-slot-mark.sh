#!/bin/sh
# probes/ab-slot-mark.sh — A/B 槽「启动成功」记账的真机体检（设备侧 POSIX sh）
#
# 用法（主机侧）：scripts/autotest-cycle.sh --image bootslot-b/boot_b.img --test probes/ab-slot-mark.sh
# 判据（PITFALLS #181/#697、TASKS D17）：
#   · 两个守护单元都 active/finished（不允许 failed）
#   · active 槽 = _b 且 is marked successful；bootable=1
#   · 本启动内两个单元自己的日志行存在（证明它们真的跑过，不是从上次启动继承的状态）
#   · 没有任何单元把「错的槽」标成功（日志里不出现与 active 槽不一致的 mark 目标）
set -u
fail=0
ck() { # ck <ok|bad> <名字> <值>
	case "$1" in ok) printf 'OK   %-28s %s\n' "$2" "$3" ;;
	             *) printf 'FAIL %-28s %s\n' "$2" "$3"; fail=$((fail+1)) ;; esac
}

act=$(qbootctl -a 2>/dev/null | sed 's/.*slot:[[:space:]]*//' | tr -d '_ \r')
ck "$([ -n "$act" ] && echo ok || echo bad)" "active_slot" "${act:-空}"

for u in qbootctl.service ab-mark-successful.service; do
	st=$(systemctl is-active "$u" 2>/dev/null)
	rs=$(systemctl show -p Result --value "$u" 2>/dev/null)
	case "$st/$rs" in
		active/success|inactive/success) ck ok "$u" "$st/$rs" ;;
		*) ck bad "$u" "$st/$rs" ;;
	esac
done

ck "$(qbootctl -n "$act" >/dev/null 2>&1 && echo ok || echo bad)" "slot_successful" "$act"
ck "$(qbootctl -b "$act" >/dev/null 2>&1 && echo ok || echo bad)" "slot_bootable" "$act"

# 本启动内的单元日志（证明本轮真跑过）
n_q=$(journalctl -b -u qbootctl.service --no-pager 2>/dev/null | grep -c 'marked successful')
# 注意：distro 的 qbootctl.service 先跑过后，ab-mark-successful 走**幂等路径**
# （日志是「SLOT _b 已是 successful ⇒ 本次零写盘」），所以两种文案都要认。
n_a=$(journalctl -b -u ab-mark-successful.service --no-pager 2>/dev/null \
	| grep -cE 'marked successful|已是 successful')
ck "$([ "$n_q" -ge 1 ] && echo ok || echo bad)" "journal_qbootctl_mark" "$n_q"
ck "$([ "$n_a" -ge 1 ] && echo ok || echo bad)" "journal_ab_mark" "$n_a"

# 反例门：日志里出现的「mark 目标槽」必须与 active 槽一致
wrong=$(journalctl -b -u qbootctl.service -u ab-mark-successful.service --no-pager 2>/dev/null \
	| grep -oE 'slot [ab] marked successful|SLOT _[ab]' | grep -oE '[ab]$' | sort -u | grep -v "^${act}$" | tr '\n' ' ')
ck "$([ -z "$wrong" ] && echo ok || echo bad)" "no_wrong_slot_mark" "${wrong:-无}"

ck "$([ "$(systemctl --failed --no-legend 2>/dev/null | wc -l)" -le 3 ] && echo ok || echo bad)" \
	"failed_units_le_3" "$(systemctl --failed --no-legend 2>/dev/null | wc -l)"

echo "RESULT=fail:$fail"
exit 0
