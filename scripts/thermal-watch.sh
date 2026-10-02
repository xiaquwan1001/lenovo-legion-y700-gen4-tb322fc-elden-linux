#!/bin/sh
# thermal-watch.sh — 用户态温控监控守护 (SM8750 / TB322FC "elden")
#
# 周期采样所有 thermal_zone 温度 + CPU/GPU 当前频点与限频状态，落日志；
# 超阈值时告警，可选自动写 scaling_max_freq 兜底（AUTO_FALLBACK=1）。
#
# 用法：
#   scripts/thermal-watch.sh                     # 前台运行，默认 5s 采样
#   INTERVAL=2 WARN=78 ALERT=90 thermal-watch.sh # 调阈值/周期
#   thermal-watch.sh --duration 600              # 跑 600s 后自动退出（配合压测）
#   nohup thermal-watch.sh >/dev/null 2>&1 &     # 后台
#
# 环境变量：
#   INTERVAL   采样间隔秒 (默认 5)
#   LOG        日志文件 (默认 /var/log/thermal-watch.log；设 LOG=- 只打印)
#   WARN/ALERT 告警阈值 °C (默认 80 / 92)
#   AUTO_FALLBACK  1=超 ALERT 时自动写 CPU scaling_max_freq 兜底 (默认 0)
#   FALLBACK_CPU0_KHZ / FALLBACK_CPU6_KHZ  兜底上限 kHz
#   ZONE_FILTER 只监控包含该子串的热区 (默认全部)
# 退出码：0 正常结束；1 参数错误。
set -u

INTERVAL=${INTERVAL:-5}
LOG=${LOG:-/var/log/thermal-watch.log}
WARN=${WARN:-80}
ALERT=${ALERT:-92}
AUTO_FALLBACK=${AUTO_FALLBACK:-0}
FALLBACK_CPU0_KHZ=${FALLBACK_CPU0_KHZ:-1363200}
FALLBACK_CPU6_KHZ=${FALLBACK_CPU6_KHZ:-1401600}
ZONE_FILTER=${ZONE_FILTER:-}
DURATION=0

while [ $# -gt 0 ]; do
	case "$1" in
		--duration) DURATION=$2; shift 2 ;;
		--interval) INTERVAL=$2; shift 2 ;;
		-h|--help) sed -n '2,22p' "$0"; exit 0 ;;
		*) echo "unknown arg: $1" >&2; exit 1 ;;
	esac
done

log() {
	line="$(date '+%Y-%m-%d %H:%M:%S') $*"
	echo "$line"
	[ "$LOG" != "-" ] && echo "$line" >> "$LOG" 2>/dev/null
}

# ---- helpers ---------------------------------------------------------------
zone_list() {
	for z in /sys/class/thermal/thermal_zone*; do
		[ -e "$z/temp" ] || continue
		t=$(cat "$z/type" 2>/dev/null)
		[ -n "$ZONE_FILTER" ] && case "$t" in *"$ZONE_FILTER"*) ;; *) continue ;; esac
		echo "$z"
	done
}

# 返回 "temp zone_type" 的最大值（temp 为毫摄氏度）
max_of() {
	# $1 = grep -E pattern
	awk -v pat="$1" '
		$0 ~ pat {
			t=$1+0; if (t>m) { m=t; z=$2 }
		}
		END { if (m=="") m=0; print m, z }'
}

collect() {
	# 输出每行: temp zone_type
	for z in $(zone_list); do
		t=$(cat "$z/temp" 2>/dev/null) || continue
		ty=$(cat "$z/type" 2>/dev/null)
		echo "$t $ty"
	done
}

policies() {
	for p in /sys/devices/system/cpu/cpufreq/policy*; do
		[ -d "$p" ] && echo "$p"
	done
}

# 保存原始 scaling_max_freq（兜底用）
save_orig() {
	for p in $(policies); do
		echo "$(cat "$p/scaling_max_freq" 2>/dev/null)" > "/tmp/.tw_orig_$(basename "$p")"
	done
}
restore_orig() {
	for p in $(policies); do
		f="/tmp/.tw_orig_$(basename "$p")"
		[ -f "$f" ] && cat "$f" > "$p/scaling_max_freq" 2>/dev/null
	done
}

# ---- main loop -------------------------------------------------------------
log "== thermal-watch start interval=${INTERVAL}s warn=${WARN}C alert=${ALERT}C fallback=${AUTO_FALLBACK} log=${LOG} =="
save_orig
fallback_on=0
i=0
elapsed=0
while :; do
	all="$(collect)"
	cpu="$(echo "$all" | max_of 'cpu-[01]-[0-9]-[0-9]-thermal')"
	gpu="$(echo "$all" | max_of 'gpuss[0-9]-thermal')"
	ddr="$(echo "$all" | max_of 'ddr-thermal')"
	batt="$(echo "$all" | max_of 'battmgr')"
	zmax="$(echo "$all" | max_of '.')"
	cmax=${cpu%% *}; cx=${cpu#* }; ctype=${cx:-na}
	gmax=${gpu%% *}; gtype=${gpu#* }
	dmax=${ddr%% *}; bmax=${batt%% *}
	zmt=${zmax%% *}; ztype=${zmax#* }

	# 每 policy 频点
	fr=""
	for p in $(policies); do
		c=$(cat "$p/scaling_cur_freq" 2>/dev/null)
		cl=$(cat "$p/scaling_max_freq" 2>/dev/null)
		fr="$fr $(basename "$p")=${c:-?}/${cl:-?}kHz"
	done

	lvl=INFO
	[ "$zmt" -ge $((WARN*1000)) ] && lvl=WARN
	[ "$zmt" -ge $((ALERT*1000)) ] && lvl=ALERT
	# 限频状态（cdev cur_state）
	cdevs=""
	for c in /sys/class/thermal/cooling_device*; do
		s=$(cat "$c/cur_state" 2>/dev/null)
		[ "${s:-0}" != "0" ] && cdevs="$cdevs $(basename "$c")=$(cat "$c/type")@$s"
	done

	log "[$lvl] zmax=${ztype}:$((zmt/1000))C cpu=${ctype}:$((cmax/1000))C gpu=${gtype}:$((gmax/1000))C ddr=$((dmax/1000))C batt=$((bmax/1000))C freq:${fr}${cdevs:+ cdev:${cdevs}}"

	# 兜底：超 ALERT 限制 CPU 上限；回落到 WARN-5 以下恢复
	if [ "$AUTO_FALLBACK" = 1 ]; then
		if [ "$zmt" -ge $((ALERT*1000)) ] && [ "$fallback_on" = 0 ]; then
			for p in $(policies); do
				case "$(basename "$p")" in
					policy0) echo "$FALLBACK_CPU0_KHZ" > "$p/scaling_max_freq" 2>/dev/null ;;
					policy6) echo "$FALLBACK_CPU6_KHZ" > "$p/scaling_max_freq" 2>/dev/null ;;
				esac
			done
			fallback_on=1
			log "[FALLBACK] zmax=$((zmt/1000))C>=ALERT -> cap cpu0=${FALLBACK_CPU0_KHZ}kHz cpu6=${FALLBACK_CPU6_KHZ}kHz"
		elif [ "$fallback_on" = 1 ] && [ "$zmt" -lt $(((WARN-5)*1000)) ]; then
			restore_orig
			fallback_on=0
			log "[FALLBACK] cooldown -> restored original scaling_max_freq"
		fi
	fi

	i=$((i+1)); elapsed=$((elapsed+INTERVAL))
	[ "$DURATION" -gt 0 ] && [ "$elapsed" -ge "$DURATION" ] && break
	sleep "$INTERVAL"
done

[ "$fallback_on" = 1 ] && restore_orig
log "== thermal-watch stop after ${elapsed}s ($i samples) =="
