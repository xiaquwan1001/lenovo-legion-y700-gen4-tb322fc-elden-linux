#!/bin/sh
# ★★★ RETIRED（2026-11-22 脚本审计批 1，reports/scripts-audit-20261122.md §3）★★★
# 此脚本已退役，勿再装机/调用。理由：
#   1. 下方把**设备路径**写进 driver/bind，而 sysfs bind 只吃设备名
#      （ath12k-retry.sh:50-51 NOTE 明写）⇒ 被调用必静默失效；
#   2. 全仓零调用点；真源 = scripts/ath12k-retry.sh。
# 已同步移出 packaging/elden-userland/MANIFEST.tsv 与 rootfs/build-rootfs.sh 拷贝名单。
# 确要强行运行（只读调试）：ATH12K_LOAD_ALLOW=1 sh $0
if [ "${ATH12K_LOAD_ALLOW:-0}" != 1 ]; then
	echo "ath12k-load: RETIRED —— bind 写设备路径必静默失效，真源=scripts/ath12k-retry.sh" >&2
	echo "  强行运行：ATH12K_LOAD_ALLOW=1 sh $0" >&2
	exit 2
fi
# Load the ath12k (WCN7861 "Peach") driver as a *module* after boot.
#
# Why a module:
#   As a built-in (CONFIG_ATH12K=y) the PCI probe runs synchronously inside the
#   kernel initcall phase. When the Peach WCN was not ready yet, MHI POWER_ON
#   waited for its 90s timeout, which blocked /init for ~90s; if MHI ever failed
#   to return at all, /init never ran (no USB/serial/network, backlight only).
#   Loading from userspace after boot avoids blocking entirely.
#
# Retry policy: if the first probe leaves the PCI device unbound, re-probe via
#   the driver's sysfs `bind`. NEVER unbind/remove a live ath12k device -- that
#   has been observed to hang the kernel.
#
# Firmware (all in /lib/firmware/ath12k/PEACH/hw2.0/):
#   amss.bin m3.bin aux_ucode.bin tmel.bin board-2.bin regdb.bin
#   qdss_trace_config.bin   (PEACH-only; missing => no wlan0)

DEV=/sys/bus/pci/devices/0000:01:00.0
DRV=/sys/bus/pci/drivers/ath12k_wifi7_pci
PHY=/sys/class/ieee80211/phy0

log() { echo "ath12k-load: $*"; }

sleep "${ATH12K_LOAD_DELAY:-8}"

if ! modprobe ath12k_pci 2>/dev/null; then
	log "modprobe ath12k_pci failed"
fi

for i in $(seq 1 60); do
	[ -e "$PHY" ] && { log "phy0 up"; exit 0; }
	[ -e "$DEV" ] || { sleep 5; continue; }
	# still being probed or already successfully bound -> leave it alone
	if [ ! -e "$DEV/driver" ]; then
		echo "$DEV" > "$DRV/bind" 2>/dev/null && log "re-bound $DEV (try $i)"
	fi
	sleep 5
done

log "gave up (no phy0)"
exit 1
