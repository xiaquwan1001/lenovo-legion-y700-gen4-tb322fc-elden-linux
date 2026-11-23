#!/bin/sh
# elden-time-baseline.sh — 时间基线自愈（D1-④ / q28-DOSSIER §t T1，2026-11-23）
#
# 背景：TB322FC 硬件 RTC 断电归零且**不可写**（hwclock -w → RTC_SET_TIME 拒绝；
# q28-DOSSIER §t t-0 实测 RTC = 1970-01-08），冷启时钟停在假值 ⇒ TLS/HTTPS 全歪、
# journal 时间戳大面积失真（§t：watchdog 170 行里 162 行假钟）。设备 2026-11-16 已
# 手工装 fake-hwclock 兜底（§t t-2 T1），但**不在任何基线表** ⇒ 重建根回归。
#
# 本件 = systemd 原生自愈闭环（与在役 time-sync.sh 家族互补，不重复其 HTTP 兜底）：
#   网络 UP（After=network-online.target）
#   → 确保 NTP 开着：timedatectl set-ntp true（chrony 已在
#     /usr/lib/systemd/ntp-units.d/50-chrony.list 注册 chrony.service，systemd ≥252
#     的 timedated 由此发现第三方 NTP；失败兜底 systemctl enable --now chrony.service）
#   → 等 NTPSynchronized=yes（≤180 s）
#   → 超时 exit 1（单元进 systemctl --failed，失败可见；不静默吞）。
#
# 用法：
#   elden-time-baseline.sh                          # 运行（rootfs/debian/units-extra/elden-time-baseline.service 调用）
#   elden-time-baseline.sh --check [--root DIR]     # 只读巡检（设备本地 / 构建 chroot）
#   elden-time-baseline.sh --help
#
# 判据事实（2026-11-23 静态取证，见 reports/d1-host-side-20261123.md）：
#   * Debian chrony 4.9-2 提供 /usr/lib/systemd/ntp-units.d/50-chrony.list（内容 = chrony.service）
#     —— /opt/elden/mobian-rootfs（systemd 262.1-1 同版）实读；
#   * systemd-timedated 262 的 NTP 发现走 ntp-units.d（strings systemd-timedated 实读：
#     context_parse_ntp_services_from_disk + /usr/lib/systemd/ntp-units.d）；
#   * chrony.conf 默认 makestep 1 3（前 3 个 update 允许步进）——1970→now 属步进范围；
#   * NTPSynchronized=yes 在本机（systemd 259 + chrony 4.8 active、无 timesyncd）实测成立；
#     设备侧（systemd 262.1-1）同机制，需上机终证。
set -u

LOG=${LOG:-/run/elden-time-baseline.log}
MODE=run; ROOT=
# 注：参数解析用 while+shift（POSIX sh 无数组）。不能反向用 `for a in "$@"` + shift 的
# 老惯用法 —— for 词表已展开，shift 不改词表，`--root DIR`（空格形）的 DIR 会撞 `*)`
#（daily-baseline.sh 2026-11-23 修复的同型 bug）。
while [ $# -gt 0 ]; do
	case "$1" in
		--check) MODE=check ;;
		--root) [ $# -ge 2 ] || { echo "--root 缺目录参数" >&2; exit 2; }; ROOT="$2"; shift ;;
		--root=*) ROOT="${1#--root=}" ;;
		--help|-h) sed -n '2,34p' "$0"; exit 0 ;;
		*) echo "未知参数: $1" >&2; exit 2 ;;
	esac
	shift
done
R=${ROOT%/}
P() { printf '%s%s' "$R" "$1"; }

if [ "$MODE" = check ]; then
	MISS=0; WARN=0
	ok()   { printf '  ok    %s\n' "$*"; }
	warnf(){ WARN=$((WARN+1)); printf '  warn  %s\n' "$*"; }
	miss() { MISS=$((MISS+1)); printf '  MISS  %s\n' "$*"; }

	# 1 chrony 在
	if [ -x "$(P /usr/sbin/chronyd)" ]; then ok "chrony 已安装（/usr/sbin/chronyd）"
	else miss "chrony 未安装（pkgmap.tsv map chrony）"; fi
	# 2 NTP 入口已 enable（包别名 chronyd.service 或 wants 链接）
	if [ -e "$(P /etc/systemd/system/multi-user.target.wants/chrony.service)" ] \
	   || [ -e "$(P /etc/systemd/system/chronyd.service)" ]; then
		ok "chrony NTP 入口已 enable（chronyd.service 别名 / multi-user.target.wants）"
	else
		miss "chrony NTP 未 enable（冷启不会自动校时）"
	fi
	# 3 fake-hwclock 在（RTC 不可写 ⇒ 冷启兜底，q28-DOSSIER §t T1）
	FHBIN=""
	for b in /usr/sbin/fake-hwclock /sbin/fake-hwclock /usr/bin/fake-hwclock; do
		[ -x "$(P "$b")" ] && { FHBIN=$b; break; }
	done
	if [ -n "$FHBIN" ]; then ok "fake-hwclock 已安装（$FHBIN）"
	else miss "fake-hwclock 未安装（daily-baseline.tsv P0 行；设备 2026-11-16 手工装过，重建根回归）"
	fi
	# 4 fake-hwclock 启动入口 enabled（Debian 0.15 单元名 = fake-hwclock.service；设备 11-16
	#   形态为 load.service + save.timer ⇒ 用 fake-hwclock* 宽匹配，不把包内单元名写死）
	FHW=""
	if [ -d "$(P /etc/systemd/system)" ]; then
		FHW=$(find "$(P /etc/systemd/system)" -maxdepth 2 -name 'fake-hwclock*' 2>/dev/null | head -1)
	fi
	if [ -n "$FHW" ]; then ok "fake-hwclock 启动入口在位（${FHW#"$R"}）"
	else miss "fake-hwclock 无启动入口（/etc/systemd/system 下无 fake-hwclock* 链接）"; fi
	# 5 保存机制（cron.hourly 或 save.timer；缺 cron 时只 warn 不 MISS）
	if [ -f "$(P /etc/cron.hourly/fake-hwclock)" ] \
	   || [ -n "$(find "$(P /etc/systemd/system)" -maxdepth 2 -name 'fake-hwclock-save.timer' 2>/dev/null | head -1)" ]; then
		ok "fake-hwclock 保存机制在位（cron.hourly / save.timer）"
	else
		warnf "未发现保存机制（cron.hourly/fake-hwclock 或 save.timer）；若单元带关机 ExecStop 兜底则可接受，上机核对"
	fi
	# 6 自愈单元在位 + enabled
	UB=""
	for u in /etc/systemd/system/elden-time-baseline.service /usr/lib/systemd/system/elden-time-baseline.service; do
		[ -f "$(P "$u")" ] && { UB=$u; break; }
	done
	if [ -z "$UB" ]; then
		warnf "elden-time-baseline.service 未部署（配方：scp rootfs/debian/units-extra/elden-time-baseline.service → /etc/systemd/system/；scp scripts/elden-time-baseline.sh → /usr/local/sbin/ 并 chmod 755；ln -sfn ../elden-time-baseline.service /etc/systemd/system/multi-user.target.wants/）"
	else
		ok "elden-time-baseline.service 在位（$UB）"
		if [ -e "$(P /etc/systemd/system/multi-user.target.wants/elden-time-baseline.service)" ]; then
			ok "elden-time-baseline.service 已 enable（multi-user.target.wants）"
		else
			miss "elden-time-baseline.service 未 enable（网络 UP 后不会自愈）"
		fi
	fi
	# 7 实跑态（仅本地 root + timedatectl 可用时；--root/chroot 或离线巡检跳过）
	if [ -z "$R" ] && command -v timedatectl >/dev/null 2>&1 && [ "$(id -u)" = 0 ]; then
		synced=$(timedatectl show -p NTPSynchronized --value 2>/dev/null || echo unknown)
		case "$synced" in
			yes) ok "NTPSynchronized=yes（当前已同步）" ;;
			no)  warnf "NTPSynchronized=no（可能离线巡检；联网后应转 yes，日志 = /run/elden-time-baseline.log）" ;;
			*)   warnf "NTPSynchronized=$synced（timedatectl 不可用或无 dbus）" ;;
		esac
	fi
	printf '结果: MISS=%d WARN=%d\n' "$MISS" "$WARN"
	[ "$MISS" -gt 0 ] && exit 1
	exit 0
fi

# ---------------------------------------------------------------- run（unit 调用）
: > "$LOG" 2>/dev/null || LOG=/dev/null
log() { printf '%s [time-baseline] %s\n' "$(date -u +%FT%TZ)" "$*" >>"$LOG"; }
if ! command -v systemctl >/dev/null 2>&1; then
	log "无 systemctl（非 systemd 根）→ 交给 openrc 期 time-sync.sh 家族，退出 0"
	exit 0
fi
# 1) 确保 NTP 开着：首选 timedatectl set-ntp true（chrony 已经 ntp-units.d 注册），
#    失败（无 dbus / 单元未注册）退回 systemctl enable --now chrony.service。
if command -v timedatectl >/dev/null 2>&1 && timedatectl set-ntp true >>"$LOG" 2>&1; then
	log "set-ntp true ok（timedated → chrony.service，经 ntp-units.d 发现）"
else
	log "set-ntp true 失败/不可用 → 兜底 systemctl enable --now chrony.service"
	systemctl enable --now chrony.service >>"$LOG" 2>&1 \
		|| log "兜底 enable --now chrony.service 也失败（继续等同步判据）"
fi
# 2) 等 NTPSynchronized=yes（≤180 s；单元 TimeoutStartSec=300 留余量）
i=0; s=no
while [ "$i" -lt 60 ]; do
	s=$(timedatectl show -p NTPSynchronized --value 2>/dev/null || echo no)
	[ "$s" = yes ] && { log "NTPSynchronized=yes（等待约 $((i * 3)) s）"; exit 0; }
	sleep 3; i=$((i + 1))
done
log "超时 180 s 仍未同步（NTPSynchronized=$s）→ exit 1（单元进 --failed，失败可见）"
exit 1
