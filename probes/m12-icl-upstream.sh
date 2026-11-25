#!/bin/sh
# probes/m12-icl-upstream.sh — 用**上游已合入实现**（be5e7367bceb）测 USB 输入限流是否真能写
#
# 用法：scripts/autotest-cycle.sh --image out/m12-upstream-20261125/boot-m12-upstream.img \
#            --test probes/m12-icl-upstream.sh
# 判据（对映 commit be5e7367bceb 的声明；本机 = SM8750 / Lenovo Legion Y700 Gen4）：
#   · 该 psy 的 input_current_limit 是 writeable
#   · 写 900000 后读回 = 写值（firmware 接受，且不再出现 "unknown message"）
#   · dmesg 里 `unknown message` 计数 = 0
#   · 电流方向/幅度随档位变化（500 mA 档 vs 900 mA 档各采一段）
set -u
PSY=/sys/class/power_supply/qcom-battmgr-usb
fail=0
ck() { case "$1" in ok) printf 'OK   %-30s %s\n' "$2" "$3" ;;
                      *) printf 'FAIL %-30s %s\n' "$2" "$3"; fail=$((fail+1)) ;; esac; }

echo "UTS=$(uname -r)"
echo "BUILD=$(uname -v)"
[ -d "$PSY" ] || { echo "FAIL psy 不存在：$PSY"; echo "RESULT=fail:1"; exit 0; }

cked=$(dmesg | grep -c 'unknown message')
before=$(cat "$PSY/input_current_limit" 2>/dev/null)
cmax=$(cat "$PSY/current_max" 2>/dev/null)
echo "current_limit_before=$before current_max=$cmax usb_type=$(cat "$PSY/usb_type" 2>/dev/null)"

printf 900000 > "$PSY/input_current_limit" 2>/tmp/icl.err; rc=$?
after=$(cat "$PSY/input_current_limit" 2>/dev/null)
echo "write900000_rc=$rc readback=$after err=$(cat /tmp/icl.err 2>/dev/null)"

ck "$([ "$rc" = 0 ] && echo ok || echo bad)" "write_accepted" "rc=$rc"
ck "$([ "$after" = 900000 ] && echo ok || echo bad)" "readback_900000" "${after:-空}"

# 电流采样：每档 20 s，取 BATTERY 侧 current_now 的中位数近似（busybox/Procps 均可）
sample() { # sample <标签> <秒>
	i=0; n=0; sum=0
	while [ "$i" -lt "$2" ]; do
		v=$(cat /sys/class/power_supply/qcom-battmgr-bat/current_now 2>/dev/null || echo 0)
		sum=$((sum + v)); n=$((n + 1)); i=$((i + 2)); sleep 2
	done
	[ "$n" -gt 0 ] && echo "$1 current_now_avg=$((sum / n)) uA (n=$n)" || echo "$1 no-sample"
}
sample "icl=${after:-?}" 20

printf 500000 > "$PSY/input_current_limit" 2>/dev/null
rb500=$(cat "$PSY/input_current_limit" 2>/dev/null)
echo "write500000 readback=$rb500"
ck "$([ "$rb500" = 500000 ] && echo ok || echo bad)" "readback_500000" "${rb500:-空}"
sample "icl=${rb500:-?}" 20

cked2=$(dmesg | grep -c 'unknown message')
echo "unknown_message_before=$cked after=$cked2"
ck "$([ "$cked2" = 0 ] && echo ok || echo bad)" "no_unknown_message" "$cked2"
echo "RESULT=fail:$fail"
exit 0
