#!/bin/sh
# charge-watch.sh — keep the qcom-battmgr charger settings applied.
#
# Three things must be (re)applied at runtime on mainline:
#   1. input_current_limit: the ADSP defaults it to 100 mA, which makes the
#      tablet net-discharge even while plugged in.  Set it to current_max.
#      ★2026-11-26 实测（reports/usb-charging-dualport-20261126.md、PITFALLS #734）：
#      系统负载 ≈0.8 A ⇒ **500 mA 档仍净放电**（-270 mA），只有顶到 900 mA 才 +130 mA。
#      但 900 mA 是**超 SDP 规范取电**，v_bus 会洼到 4.52 V（< 4.75 V 下限、PC 端口超载）
#      ⇒ 2. 洼地保护。
#   2. sag guard: 连续 SAG_SAMPLES 次 v_bus < SAG_UV 就把目标降到 ICL_FLOOR，
#      并在 v_bus 恢复（> RECOVER_UV 持续 RECOVER_SAMPLES 次）后最多再试 MAX_TRIES 次抬高。
#      目的 = 宁可慢充，也不把对端端口拖进 OCP（断了就彻底不充）。
#   3. optional battery-care limit from /etc/charge.conf (LIMIT=off|55..100).
#
# The charger is re-detected on every (re)plug and the limit resets, so poll and
# re-apply.  Started by systemd `charge-watch.service`（sources
# packaging/elden-userland/services.tsv；deploy gate = deploy-desktop-shell.sh §17）.
#
# 用法：charge-watch.sh            # 常驻（unit 用）
#       charge-watch.sh --check    # 一次性报告；online 但 ICL<500 mA ⇒ rc=1
set -u
USB=${USB:-/sys/class/power_supply/qcom-battmgr-usb}
BAT=${BAT:-/sys/class/power_supply/qcom-battmgr-bat}
CONF=${CONF:-/etc/charge.conf}
LOG=${LOG:-/run/charge-watch.log}
CCTL=/usr/local/sbin/charge-ctl.sh

# 可从 /etc/conf.d/charge-watch 覆盖（systemd EnvironmentFile；见 services.tsv）
# 阈值口径（2026-11-26 上机定，reports/usb-charging-dualport-20261126.md §2/§5）：
#   本机实测「900 mA 稳定取电」时 v_bus 就停在 4.47–4.52 V（PC 端口自身 droop，持续 3 min 未被 OCP 掐断）
#   ⇒ 4.60 V 阈值会把正常充电判成超载、降到 500–700 mA 后反而**净放电**（实测 -284 mA）。
#   因此阈值取「真正的塌陷」= < 4.40 V，且降档目标取 USB 规范 SDP 上限 500 mA（保住端口优先）。
SAG_UV=${SAG_UV:-4400000}		# 低于它才算真塌陷（本机正常充电 ~4.5 V，不能拿 4.6 当门）
SAG_SAMPLES=${SAG_SAMPLES:-3}		# 连续 3 次（≈6 s）才降档，避免负载瞬变误判
RECOVER_UV=${RECOVER_UV:-4600000}	# 高于它才考虑抬回
RECOVER_SAMPLES=${RECOVER_SAMPLES:-15}	# 连续 15 次（≈30 s）稳定才算恢复
MAX_TRIES=${MAX_TRIES:-2}		# 抬回最多试 2 次，之后整段插着期不再试
ICL_FLOOR=${ICL_FLOOR:-500000}		# 降档目标 = SDP 规范上限（端口优先；此档可能仍净放电，属已知代价）

log() { echo "$(date '+%H:%M:%S') $*" >>"$LOG"; }
rd() { cat "$1" 2>/dev/null; }

# ---- 启动顺序竞态（2026-11-11 实测，reports/t18-charging-timing-20261111.md）----
# /init 在 boot 后 9.0 s 就拉起本脚本，而 `qcom-battmgr-usb` 的 power_supply 节点
# 要 12.84 s 才被 healthd 发现 ⇒ 首轮空转。插电后这段时间里 ADSP 默认给 100 mA，
# 没有人顶回 ⇒ 净放电。所以：先阻塞等节点出现，再进主循环。
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

check_once() {
	online=$(rd "$USB/online"); cur=$(rd "$USB/input_current_limit")
	max=$(rd "$USB/current_max"); v=$(rd "$USB/voltage_now")
	e=$("$CDIR/charge-ctl.sh" status 2>/dev/null || true)
	echo "online=${online:-?} icl=${cur:-?} max=${max:-?} v_bus=${v:-?}uV usb_type=$(rd "$USB/usb_type")"
	echo "battery: $(rd "$BAT/capacity")% i=$(rd "$BAT/current_now")uA status=$(rd "$BAT/status")"
	[ -n "$e" ] && printf '%s\n' "$e" | head -2
	[ "${online:-0}" = 1 ] || { echo "verdict: USB 未接（不判 ICL）"; exit 0; }
	if [ -n "${cur:-}" ] && [ "${cur:-0}" -ge 500000 ]; then
		echo "verdict: OK（ICL=${cur} ≥500 mA；900 mA 档才是净充电档，500 mA 档仍可能净放电）"
		exit 0
	fi
	echo "verdict: FAIL（online 但 ICL=${cur:-?} ⇒ 净放电，见 PITFALLS #734）"
	exit 1
}

CDIR=$(cd "$(dirname "$0")" && pwd)
[ "${1:-}" = "--check" ] && check_once

# tick() = 一次迭代（读 → 顶回 → 洼地判定 → battery-care）。不带 sleep，便于自测。
tick() {
	online=$(rd "$USB/online")
	if [ "${online:-0}" != 1 ]; then
		# 未接电：状态机复位（下次插上重新从 max 起试）
		[ -n "${target:-}" ] && log "usb offline - state reset"
		target=; tries=0; sag=0; good=0
		return 0
	fi

	max=$(rd "$USB/current_max")
	cur=$(rd "$USB/input_current_limit")
	v=$(rd "$USB/voltage_now")

	if [ -n "$max" ]; then
		[ -n "${target:-}" ] || target=$max
		[ "${target:-0}" -gt "$max" ] 2>/dev/null && target=$max
		# 1a. 顶回目标档
		if [ -n "$cur" ] && [ "$cur" -ne "$target" ]; then
			if echo "$target" >"$USB/input_current_limit" 2>/dev/null; then
				log "input_current_limit $cur -> $target uA"
				cur=$target
			fi
		fi
	fi

	# 2. 洼地保护
	case "${v:-0}" in ''|*[!0-9]*) v=0 ;; esac
	if [ "$v" -gt 0 ] && [ "$v" -lt "$SAG_UV" ]; then
		sag=$((sag + 1)); good=0
	elif [ "$v" -gt "$RECOVER_UV" ]; then
		good=$((good + 1)); sag=0
	else
		sag=0
	fi

	if [ -n "${max:-}" ] && [ "${target:-0}" -gt "$ICL_FLOOR" ] && [ "$sag" -ge "$SAG_SAMPLES" ]; then
		if echo "$ICL_FLOOR" >"$USB/input_current_limit" 2>/dev/null; then
			log "SAG v_bus=$v uV < $SAG_UV x$sag -> drop ICL to $ICL_FLOOR uA (protect host port)"
			target=$ICL_FLOOR; sag=0; good=0
		fi
	elif [ -n "${max:-}" ] && [ "${target:-0}" -le "$ICL_FLOOR" ] && [ "$good" -ge "$RECOVER_SAMPLES" ] && [ "$tries" -lt "$MAX_TRIES" ]; then
		if echo "$max" >"$USB/input_current_limit" 2>/dev/null; then
			tries=$((tries + 1))
			log "RECOVER v_bus=$v uV > $RECOVER_UV x$good -> retry ICL $max uA (attempt $tries/$MAX_TRIES)"
			target=$max; good=0
		fi
	fi

	# 3. optional battery-care limit
	if [ -f "$CONF" ]; then
		. "$CONF" 2>/dev/null
		if [ -n "${LIMIT:-}" ] && [ "$LIMIT" != off ] && [ -x "$CCTL" ]; then
			end=$(rd "$BAT/charge_control_end_threshold")
			[ -n "$end" ] && [ "$end" != "$LIMIT" ] && "$CCTL" limit "$LIMIT" >/dev/null 2>&1
		fi
	fi
	return 0
}

# ---- 判据自证：假 sysfs 驱动 tick()，不走真硬件（criterion-self-proof 口径）----
selftest() {
	ST=$(mktemp -d) || exit 1
	mkdir -p "$ST/usb" "$ST/bat"
	USB=$ST/usb BAT=$ST/bat LOG=$ST/log CONF=$ST/no-such-conf
	: >"$LOG"
	set_rt() { echo "$1" >"$USB/online"; echo 900000 >"$USB/current_max"; echo "$2" >"$USB/voltage_now"; echo 100000 >"$USB/input_current_limit"; }
	fail=0
	chk() { # chk <名字> <期望> <实得>
		if [ "$2" = "$3" ]; then echo "  PASS  $1 = $3"; else echo "  FAIL  $1 期望 $2 实得 $3"; fail=$((fail + 1)); fi
	}
	target=; tries=0; sag=0; good=0
	# 1) online + 端口健康 ⇒ 顶到 max
	set_rt 1 5000000; tick; chk "首次顶档" 900000 "$(rd "$USB/input_current_limit")"
	# 2) 连续 3 次洼地 ⇒ 降到 floor
	for i in 1 2 3; do echo 4300000 >"$USB/voltage_now"; tick; done
	chk "洼地 3 次后降档" "$ICL_FLOOR" "$(rd "$USB/input_current_limit")"
	# 3) 再连续洼地不重复降（幂等）
	tick; chk "降档幂等" "$ICL_FLOOR" "$(rd "$USB/input_current_limit")"
	# 4) 恢复 15 次 ⇒ 抬回 max（第 1 次尝试）
	for i in $(seq 1 "$RECOVER_SAMPLES"); do echo 5000000 >"$USB/voltage_now"; tick; done
	chk "恢复后抬回 max" 900000 "$(rd "$USB/input_current_limit")"
	chk "尝试计数" 1 "$tries"
	# 5) 再次洼地 ⇒ 再降；恢复 ⇒ 第 2 次抬回
	for i in 1 2 3; do echo 4300000 >"$USB/voltage_now"; tick; done
	chk "二次降档" "$ICL_FLOOR" "$(rd "$USB/input_current_limit")"
	for i in $(seq 1 "$RECOVER_SAMPLES"); do echo 5000000 >"$USB/voltage_now"; tick; done
	chk "第二次抬回" 900000 "$(rd "$USB/input_current_limit")"
	# 6) 超过 MAX_TRIES 后不再抬（本次插着期封顶）
	for i in 1 2 3; do echo 4300000 >"$USB/voltage_now"; tick; done
	for i in $(seq 1 $((RECOVER_SAMPLES * 2))); do echo 5000000 >"$USB/voltage_now"; tick; done
	chk "MAX_TRIES 用尽后保持 floor" "$ICL_FLOOR" "$(rd "$USB/input_current_limit")"
	# 7) 拔线复位 ⇒ 再插回从 max 起
	echo 0 >"$USB/online"; tick
	echo 1 >"$USB/online"; echo 5000000 >"$USB/voltage_now"; tick
	chk "重插复位后顶档" 900000 "$(rd "$USB/input_current_limit")"
	chk "重插后 tries 归零" 0 "$tries"
	rm -rf "$ST"
	[ "$fail" = 0 ] && echo "selftest: PASS (7/7)" || { echo "selftest: FAIL ($fail)"; return 1; }
}

CDIR=$(cd "$(dirname "$0")" && pwd)
case "${1:-}" in
	--check) check_once ;;
	--selftest) selftest; exit $? ;;
	"") ;;
	*) echo "用法: $0 [--check|--selftest]" >&2; exit 2 ;;
esac

log "started"
wait_for_usb

target=
tries=0
sag=0
good=0

while true; do
	tick
	# 轮询周期 2 s：ADSP 会在每次重插时把 ICL 拉回 100 mA，窗口太长用户能看出「插着不充电」
	sleep 2
done
