#!/bin/sh
# q28-boot-watchdog.sh — Q28（冷起「只有背光」）运营兜底：坏发自动重启一次。
#
# 为什么（2026-10-12）：Q28 冷起坏发率约 50% 且按时间成簇；根因（DYN pclk 域闩住）
# 未修。第二次启动独立地约 50% 成功 ⇒ 自动重启可把可用性从 ~50% 提到 ~75%。
# 这条**不改根因**，只是运营兜底。详见 PITFALLS #228。
#
# 判据：bad = (无图形会话 OR 无 /sys/class/drm/card0) AND (无 card0 或 命中 Q28 dmesg 特征)
#   特征 = command DMA timeout | Failed to initialize panel | vblank wait timed out
# 全部满足才重启；成功启动（有会话）⇒ 计数清零；重启次数跨启动计数、上限 MAX。
#
# 关闭： touch /etc/q28-watchdog.disable | cmdline 加 elden_q28_nowd | Q28_WD_MAX=0
# 调参： Q28_WD_WAIT（判活等待秒，默认 75）、Q28_WD_MAX（默认 2）
# 自检： Q28_WD_SELFTEST=nosession|nocard|sig|good   Q28_WD_DRYRUN=1（只判不动）
#
# ★实验纪律：任何可能留下坏发台架的 A/B / Q24 台架之前，先
#   /usr/local/sbin/q28-watchdog.sh off  （= touch /etc/q28-watchdog.disable）
set -u
DISABLE=/etc/q28-watchdog.disable
STATE=/var/lib/q28-watchdog
LOG=/var/log/q28-watchdog.log
MAX=${Q28_WD_MAX:-2}
WAIT=${Q28_WD_WAIT:-75}
SELFTEST=${Q28_WD_SELFTEST:-}
DRYRUN=${Q28_WD_DRYRUN:-0}

log() {
	echo "$(date +%Y-%m-%dT%H:%M:%S 2>/dev/null || echo t=)$(printf ' %s' "$*") [uptime=$(cut -d' ' -f1 /proc/uptime 2>/dev/null)s]" >>"$LOG" 2>/dev/null
	logger -t q28-wd "$*" 2>/dev/null
}

have_session() {
	case "$SELFTEST" in nosession) return 1 ;; session) return 0 ;; esac
	pgrep -x phoc  >/dev/null 2>&1 && return 0
	pgrep -x phosh >/dev/null 2>&1 && return 0
	return 1
}
have_card() {
	case "$SELFTEST" in nocard) return 1 ;; card) return 0 ;; esac
	[ -e /sys/class/drm/card0 ]
}
q28_sig() {
	[ "$SELFTEST" = sig ] && return 0
	dmesg 2>/dev/null | grep -qE 'command DMA timeout|Failed to initialize panel|vblank wait timed out'
}

mkdir -p "$STATE" 2>/dev/null || true
cnt=$(cat "$STATE/count" 2>/dev/null || echo 0)
case "$cnt" in ''|*[!0-9]*) cnt=0 ;; esac

# 成功启动是硬证据：清计数并退出（静默，避免每次开机都刷）。
# ★放在「停用检查」之前：停用期内也要把计数归零，否则再次启用时白丢一次重试额度。
if have_session && have_card; then
	echo 0 > "$STATE/count" 2>/dev/null || true
	[ "$SELFTEST" = good ] && log "selftest=good -> session+card present, count reset"
	exit 0
fi

[ -e "$DISABLE" ] && { log "disabled by $DISABLE"; exit 0; }
if grep -qw elden_q28_nowd /proc/cmdline 2>/dev/null; then log "disabled by cmdline"; exit 0; fi
case "$MAX" in ''|*[!0-9]*) MAX=2 ;; esac
[ "$MAX" -eq 0 ] && { log "disabled by Q28_WD_MAX=0"; exit 0; }

sleep "$WAIT"

if have_session && have_card; then
	echo 0 > "$STATE/count" 2>/dev/null || true
	exit 0
fi

sess=no; have_session && sess=yes
card=no; have_card && card=yes
sig=no;  q28_sig && sig=yes
if [ "$sess" = yes ] && [ "$card" = yes ]; then
	log "settled with session+card -> nothing to do"
	exit 0
fi
if [ "$card" = yes ] && [ "$sig" = no ]; then
	log "no session (card=$card sig=$sig selftest=${SELFTEST:-none}) but no Q28 signature -> NOT rebooting"
	exit 0
fi
if [ "$cnt" -ge "$MAX" ]; then
	log "Q28 bad boot (sess=$sess card=$card sig=$sig) but retry budget exhausted ($cnt>=$MAX) -> staying up for diagnosis"
	exit 0
fi

echo $((cnt + 1)) > "$STATE/count" 2>/dev/null || true
log "Q28 bad boot detected (attempt $((cnt + 1))/$MAX sess=$sess card=$card sig=$sig selftest=${SELFTEST:-none}) -> normal reboot"
if [ "$DRYRUN" = 1 ]; then log "DRYRUN=1 -> not rebooting"; exit 0; fi
sync
# 能力自检：老版 reboot2（2026-09-28 前）无参 = 进 fastboot（PITFALLS #229）⇒ 必须先确认
# 它自报支持「no argument = normal reboot」，否则退到 sysrq-b（硬复位，无 reason 串）。
if /usr/local/sbin/reboot2 -h 2>&1 | grep -q 'no argument = normal reboot'; then
	exec /usr/local/sbin/reboot2
fi
log "reboot2 lacks normal-reboot support -> falling back to sysrq-b"
echo b > /proc/sysrq-trigger
sleep 10
exit 1
