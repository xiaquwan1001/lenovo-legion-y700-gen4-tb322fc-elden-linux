#!/bin/sh
# suspend-resource-sample.sh — 待机/唤醒的「间接资源测量」采样器（设备侧，POSIX sh）
#
# 为什么不是电流表：本项目口径（用户 2026-11-13 定）= **不追精密电流数值**，
#   改用「同一设备、同一软件、跨 suspend 周期」的**资源占用趋势**间接判断有没有退化：
#     · 进程/线程数与关键服务 RSS（后台有没有偷偷长起来）
#     · slab/avail 内存、zram 用量
#     · 电池侧 V/I/charge_counter 作为**同口径相对量**（不做功耗换算结论）
#     · suspend_stats + wakeup_count（唤醒源次数）
#   判据纪律：单点无意义，必须**同一 boot 内 ≥3 周期**看趋势；跨 boot 比较要先对齐 UTS 与负载。
#
# 用法（设备上）：
#   sh suspend-resource-sample.sh probe                 # 只打一行当前快照（TSV 到 stdout）
#   sh suspend-resource-sample.sh cycles 3 45 /tmp/s.tsv # 3 周期，每周期 rtcwake 45 s，追加到 TSV
#
# 取数：设备上默认由 systemd timer（elden-resource-sample.timer，30 min）追加到
#   /var/lib/elden/suspend-resource.tsv；主机侧 `scp elden-root:/var/lib/elden/suspend-resource.tsv .` 后自行 awk/画图。

set -u
TS=$(date +%s)
UP=$(cut -d. -f1 /proc/uptime)
LOAD=$(cut -d' ' -f1 /proc/loadavg)
PROCS=$(ls -d /proc/[0-9]* 2>/dev/null | wc -l)
THREADS=$(ls -d /proc/[0-9]*/task/[0-9]* 2>/dev/null | wc -l)
mem() { awk -v k="$1" '$1==k":"{print $2}' /proc/meminfo; }
MA=$(mem MemAvailable); MF=$(mem MemFree); CA=$(mem Cached); SW=$(mem SwapTotal); SF=$(mem SwapFree)
SWU=$(( ${SW:-0} - ${SF:-0} ))
B=/sys/class/power_supply/qcom-battmgr-bat
rd() { [ -f "$B/$1" ] && cat "$B/$1" 2>/dev/null || echo ""; }
CUR=$(rd current_now); VOLT=$(rd voltage_now); CC=$(rd charge_counter); BT=$(rd temp); CAP=$(rd capacity); ST=$(rd status)
# 本机 /sys/power/suspend_stats 是**目录**（每项一个文件），不是单个文件（2026-11-13 现查）
SS="$(cat /sys/power/suspend_stats/success 2>/dev/null || echo '')/$(cat /sys/power/suspend_stats/fail 2>/dev/null || echo '')"
# /sys/power/wakeup_count **读会阻塞**（内核语义：要等 wakeup 计数可报告）⇒ 必须套 timeout，
# 否则采样器会永久挂在 systemd 服务里（2026-11-13 实测踩到，服务卡在 cat 上）。
WC=$(timeout 2 cat /sys/power/wakeup_count 2>/dev/null || echo "")
# 前 5 个最大 RSS 进程（name:rss_kb，按 RSS 降序；同一 comm 取最大那个）
TOP=$(ps -eo rss=,comm= 2>/dev/null | awk '{r[$2]=($1>r[$2]?$1:r[$2])} END{for(k in r) printf "%s:%d ", k, r[k]}' \
      | tr ' ' '\n' | sort -t: -k2 -nr | grep -v '^$' | head -5 | tr '\n' ',' | sed 's/,$//')
# 关键服务 RSS（只取在跑的）
SVC=""
for s in waydroid-container phoc phosh sshd; do
	r=$(systemctl show -p MainPID --value "$s" 2>/dev/null || echo 0)
	[ "${r:-0}" -gt 0 ] 2>/dev/null && SVC="$SVC$s:$(awk '/VmRSS/{print $2}' /proc/$r/status 2>/dev/null),"
done
SVC=$(echo "$SVC" | sed 's/,$//')

printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
	"$TS" "$UP" "$LOAD" "$PROCS" "$THREADS" "${MA:-}" "${MF:-}" "${CA:-}" "$SWU" \
	"${CUR:-}" "${VOLT:-}" "${CC:-}" "${BT:-}" "${CAP:-}" "${ST:-}" "${SS:-}" "${WC:-}" "$TOP" "$SVC" "$(uname -r)"

case "${1:-probe}" in
probe) : ;;
cycles)
	n=${2:-3}; sl=${3:-45}; out=${4:-/tmp/suspend-resource.tsv}
	[ -f "$out" ] || printf 'ts\tup\tload\tprocs\tthreads\tmem_avail\tmem_free\tcached\tswap_used\tbat_uA\tbat_uV\tcharge_counter\tbat_temp_mc\tcapacity\tstatus\tsuspend_success/fail\twakeup_count\ttop5_rss\tkey_services\tuts\n' > "$out"
	i=0
	while [ "$i" -lt "$n" ]; do
		i=$((i+1))
		sh "$0" probe >> "$out"
		rtcwake -m mem -s "$sl" >/dev/null 2>&1
		echo "cycle $i rc=$?" >&2
		sh "$0" probe >> "$out"
	done
	echo "$out" ;;
*) echo "用法: $0 [probe|cycles N SECS OUT]" >&2; exit 2 ;;
esac
