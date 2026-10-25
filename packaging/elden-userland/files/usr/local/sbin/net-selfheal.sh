#!/bin/sh
# net-selfheal.sh — 设备侧网络自愈（HTTPS 信任链 + PMTU 黑洞缓解）
#
# 背景（2026-10-18 定位，见 reports/net-https-mtu-rootcause-20261018.md）：
#   1) 设备上 8 个 /etc 配置文件是 **0 字节**，而包内原版内容躺在同名
#      `.apk-new` 旁边。其中 `/etc/ca-certificates.conf` 空 =>  `update-ca-certificates`
#      永远生成 0 字节 `/etc/ssl/certs/ca-certificates.crt` => **全站 HTTPS 失效**
#      （curl/git/apk 报 "error adding trust anchors"）。
#      **`apk fix <pkg>` 修不了**：apk 把它当"用户已修改的配置文件"，
#      只再写一份 `.apk-new`，0 字节活文件原封不动（实测两次）。
#   2) 手机热点广播 MTU 1500，其上游实际 MTU 1400 且不下发 ICMP frag-needed
#      => PMTU 黑洞；TLS ClientHello 用后量子混合曲线时达 1423 字节，
#      被拆成「满 MSS 首段 + 213 字节尾段」，首段丢弃后连接卡死。
#
# 本脚本幂等，可反复跑。默认由 OpenRC `local` 载荷在 boot 时调用。
#   usage: net-selfheal.sh [--check]   # --check 只报告不修改，退出码=问题数
set -u

CHECK_ONLY=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1

problems=0
log() { printf '[net-selfheal] %s\n' "$*"; }
report() { problems=$((problems + 1)); log "PROBLEM: $*"; }

# ---------------------------------------------------------------- 1. 0 字节配置自愈
# 只处理「活文件 0 字节 / 缺失 且 存在 .apk-new」的情形，绝不动有内容的文件。
heal_zero_configs() {
	for new in $(find /etc -name '*.apk-new' -type f 2>/dev/null); do
		live="${new%.apk-new}"
		[ -s "$new" ] || continue          # 包内原版也得有内容才可信
		if [ -s "$live" ]; then
			# 两边都有内容 = 真正的用户改动，不碰（留给人工/apk 决策）
			continue
		fi
		report "$live 是 0 字节/缺失，而包内原版存在（$(stat -c %s "$new") 字节）"
		[ "$CHECK_ONLY" = 1 ] && continue
		mv -f "$new" "$live"
		case "$live" in
		*/update.d/*) chmod 755 "$live" ;;
		*)            chmod 644 "$live" ;;
		esac
		log "restored: $live ($(stat -c %s "$live") bytes)"
	done
}

# ---------------------------------------------------------------- 2. 信任链
ensure_ca_bundle() {
	conf=/etc/ca-certificates.conf
	bundle=/etc/ssl/certs/ca-certificates.crt

	if [ ! -s "$conf" ]; then
		report "$conf 为空 => update-ca-certificates 必产出空 bundle"
		[ "$CHECK_ONLY" = 1 ] && return
		# 没有 .apk-new 可用时的兜底：按 mozilla 目录重建（Alpine 包内
		# post-install 就是这么生成的：一行一个 mozilla/<name>.crt）
		if [ -d /usr/share/ca-certificates/mozilla ]; then
			{
				printf '# rebuilt by net-selfheal.sh on %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
				( cd /usr/share/ca-certificates && \
				  ls mozilla/*.crt 2>/dev/null | LC_ALL=C sort )
			} > "$conf"
			log "rebuilt $conf ($(wc -l < "$conf") lines) from mozilla/"
		else
			log "no /usr/share/ca-certificates/mozilla, cannot rebuild $conf"
			return
		fi
	fi

	need=0
	[ -s "$bundle" ] || need=1
	if [ "$need" = 0 ] && [ -s "$conf" ]; then
		# bundle 比 conf 旧 => 需要重建
		[ "$conf" -nt "$bundle" ] && need=1
	fi

	if [ "$need" = 1 ]; then
		report "证书 bundle 缺失/过期（$(stat -c %s "$bundle" 2>/dev/null || echo 0) 字节）"
		[ "$CHECK_ONLY" = 1 ] && return
		/usr/sbin/update-ca-certificates >/dev/null 2>&1 || \
			log "update-ca-certificates failed"
	fi

	n=$(grep -c '^-----BEGIN CERTIFICATE-----' "$bundle" 2>/dev/null || echo 0)
	if [ "$n" -lt 100 ]; then
		report "bundle 里只有 $n 张证书（预期 >100）"
	else
		log "ca bundle OK: $n certs, $(stat -c %s "$bundle") bytes"
	fi
}

# ---------------------------------------------------------------- 3. PMTU 黑洞缓解
# 只对 wifi 生效（有线/网桥不受手机热点影响）。1400 = 实测上游 MTU。
WIFI_MTU=${WIFI_MTU:-1400}
ensure_pmtu() {
	iface=$(ip -br link 2>/dev/null | awk '$1 ~ /^wlan/ && $2 == "UP" {print $1; exit}')
	[ -n "${iface:-}" ] || return 0
	cur=$(cat "/sys/class/net/$iface/mtu" 2>/dev/null || echo 0)
	if [ "$cur" -gt "$WIFI_MTU" ]; then
		report "$iface MTU=$cur > $WIFI_MTU（热点上游黑洞风险）"
		[ "$CHECK_ONLY" = 1 ] && return 0
		ip link set "$iface" mtu "$WIFI_MTU" && log "$iface MTU -> $WIFI_MTU"
	fi
	# 省电模式对 ath12k 表现为突发丢包，关掉更稳
	if command -v iw >/dev/null 2>&1; then
		if iw dev "$iface" get power_save 2>/dev/null | grep -q 'on'; then
			if [ "$CHECK_ONLY" = 1 ]; then
				report "$iface power_save=on（ath12k 突发丢包源）"
			else
				iw dev "$iface" set power_save off
				log "$iface power_save -> off"
			fi
		fi
	fi
}

heal_zero_configs
ensure_ca_bundle
ensure_pmtu

log "done, problems=$problems"
[ "$CHECK_ONLY" = 1 ] && exit "$problems"
exit 0
