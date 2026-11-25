#!/bin/sh
# wifi-scan-refresh.sh — 连通态周期扫描：让「可用 WiFi 候选榜」不掉成只剩已连接那一项
#
# 背景（2026-10-19 U2 实测，PITFALLS #354，报告 reports/wifi-scan-stale-20261019.md）：
#   1) NM **不在「已连接」时做周期扫描**：nm-device-wifi.c: _scan_notify_allowed() 里
#      ACTIVATED 分支写死 `periodic_allowed = FALSE`，注释原文「we ask the supplicant to
#      background scan for us」。
#   2) 它交给 supplicant 的 bgscan 是**写死**的，连接级 `802-11-wireless.bgscan` 在
#      NM 1.52 里根本不被读取：nm-supplicant-config.c: nm_supplicant_config_add_bgscan()
#      → bgscan = "simple:30:-70:86400"（单 BSS、信号良好档）
#      ⇒ 信号好于 -70 dBm 时 long 档 = **86400 s**，等于连通态不再扫描。
#      多 BSS ESS 才用 "simple:30:-65:300"。
#   3) 不再扫描 ⇒ wpa_supplicant 的 BSS 缓存按 age 过期被清（默认 bss_expiration_age=180 s）
#      ⇒ NM 的 AP 对象被逐个移除 ⇒ 候选榜塌成只剩当前连接项。
#      实测（手机热点，RSSI -30 dBm，单 BSS）：NM 重启后只做 1 次连接期扫描，
#      之后 300 s 内 **0 次**扫描事件；AP 数 35 → 1（150 s 内）。
#      显式 RequestScan 立刻恢复：1 → 24 项（12 s）。
#
# 因此本脚本用 NM 的**显式**扫描路径补周期复扫。只在 wifi 已连接时扫，
# 未连接/连接中 NM 自己每 ≤120 s 扫一次（SCAN_INTERVAL_SEC_MAX），不叠加。
#
# 间隔必须 < 180 s（supplicant 的 bss_expiration_age），否则过期清缓存仍会发生；
# 默认 150 s。全信道扫描本机约 5.6–8.4 s（110 信道），≈4–6% 占空比。
#
# usage:
#   wifi-scan-refresh.sh            # 常驻循环（OpenRC 服务用法）
#   wifi-scan-refresh.sh --once     # 只做一轮（装完/调试用）
#   wifi-scan-refresh.sh --check    # 只报状态，不扫描；退出码 = 0
#   wifi-scan-refresh.sh --quiet    # 循环时不打日志
# 环境变量：WIFI_SCAN_INTERVAL（秒，默认 150），通常来自 /etc/conf.d/wifi-scan-refresh
set -u

INTERVAL="${WIFI_SCAN_INTERVAL:-150}"
MODE=loop
QUIET=0

for arg in "$@"; do
	case "$arg" in
	--once) MODE=once ;;
	--loop) MODE=loop ;;
	--check) MODE=check ;;
	--quiet) QUIET=1 ;;
	-h | --help)
		sed -n '2,30p' "$0"
		exit 0
		;;
	*)
		printf '[wifi-scan] unknown arg: %s\n' "$arg" >&2
		exit 2
		;;
	esac
done

log() { [ "$QUIET" = 1 ] || printf '[wifi-scan] %s\n' "$*"; }

# 取第一个 wifi 设备名（nmcli terse: DEVICE:TYPE:STATE）
wifi_dev() {
	nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null |
		awk -F: '$2=="wifi"{print $1; exit}'
}

dev_state() {
	nmcli -t -f DEVICE,STATE device status 2>/dev/null |
		awk -F: -v d="$1" '$1==d{print $2; exit}'
}

ap_count() {
	nmcli -f BSSID dev wifi list --rescan no 2>/dev/null |
		grep -cE '^[0-9A-F]{2}:'
}

# do_pass 返回值：0 = 已提交扫描 / 2 = 跳过（未连接或设备未就绪）/ 1 = 其它错误

# 一次扫描请求。返回 0 = 已提交（含"正在扫描"这种可接受状态）
request_scan() {
	dev="$1"
	out=$(nmcli dev wifi rescan ifname "$dev" 2>&1)
	rc=$?
	if [ "$rc" = 0 ]; then
		return 0
	fi
	case "$out" in
	*"Scanning already"* | *"scanning"* | *"Scan in progress"*)
		return 0
		;;
	esac
	log "rescan failed rc=$rc: $out"
	return 1
}

do_pass() {
	dev=$(wifi_dev)
	if [ -z "$dev" ]; then
		log "no wifi device (driver not up?) — skip"
		return 2
	fi
	state=$(dev_state "$dev")
	if [ "$state" != "connected" ]; then
		# 未连接 / 连接中：NM 自己按 SCAN_INTERVAL_SEC_MAX=120 s 复扫，无需叠加
		log "$dev state=$state — skip (NM self-scans)"
		return 2
	fi
	before=$(ap_count)
	request_scan "$dev" || return 1
	log "$dev connected: requested scan (aps before=$before, interval=${INTERVAL}s)"
	return 0
}

case "$MODE" in
check)
	dev=$(wifi_dev)
	if [ -z "$dev" ]; then
		printf 'wifi_device=none\n'
		exit 0
	fi
	printf 'wifi_device=%s\nstate=%s\naps=%s\ninterval=%s\n' \
		"$dev" "$(dev_state "$dev")" "$(ap_count)" "$INTERVAL"
	;;
once)
	do_pass
	;;
loop)
	log "start: interval=${INTERVAL}s (must be < 180 s to beat supplicant bss_expiration_age)"
	while :; do
		do_pass
		# 未连接 / 设备未就绪时短睡（不耗射频），别白等一整个间隔
		[ $? = 2 ] && sleep 15 || sleep "$INTERVAL"
	done
	;;
esac
