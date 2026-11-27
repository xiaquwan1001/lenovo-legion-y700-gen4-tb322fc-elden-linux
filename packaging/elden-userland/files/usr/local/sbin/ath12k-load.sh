#!/bin/sh
# ★★★ RETIRED（2026-11-22 脚本审计批 1，reports/scripts-audit-20261122.md §3）★★★
# 此脚本已退役，勿再装机/调用。理由：
#   1. 【2026-11-23 批 3 已就地修掉】原把**设备路径**写进 driver/bind，而 sysfs bind 只吃
#      设备名（ath12k-retry.sh:50-51 NOTE 明写）⇒ 被调用必静默失效。现改为写设备名 +
#      去掉 `2>/dev/null` 吞错 + 写失败即带判据退出（退役决定不变）；
#   2. 全仓零调用点；真源 = scripts/ath12k-retry.sh。
# 已同步移出 packaging/elden-userland/MANIFEST.tsv 与 rootfs/build-rootfs.sh 拷贝名单。
# 确要强行运行（只读调试）：ATH12K_LOAD_ALLOW=1 sh $0
if [ "${ATH12K_LOAD_ALLOW:-0}" != 1 ]; then
	echo "ath12k-load: RETIRED —— 已由 scripts/ath12k-retry.sh 取代（bind 写设备名的修法见下方正文）" >&2
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
# sysfs `bind` 收的是**设备名**（PCI 地址），不是设备路径 —— 旧代码写 "$DEV" 会 EINVAL 且恒不生效。
DEVNAME=$(basename "$DEV")
DRV=/sys/bus/pci/drivers/ath12k_wifi7_pci
PHY=/sys/class/ieee80211/phy0

log() { echo "ath12k-load: $*"; }

sleep "${ATH12K_LOAD_DELAY:-8}"

# 不再吞 modprobe 的 stderr：失败时把真实原因打出来（模块内置 / 固件缺失 是两种不同处置）
if ! out=$(modprobe ath12k_pci 2>&1); then
	log "modprobe ath12k_pci failed（stderr：${out:-<空>}）"
fi

for i in $(seq 1 60); do
	[ -e "$PHY" ] && { log "phy0 up"; exit 0; }
	[ -e "$DEV" ] || { sleep 5; continue; }
	# still being probed or already successfully bound -> leave it alone
	if [ ! -e "$DEV/driver" ]; then
		# bind 只吃设备名（对齐 ath12k-retry.sh:50-51 NOTE）。
		# 旧写法 `echo "$DEV" > bind 2>/dev/null && log ...` = 内容写错 + 吞错
		# ⇒ 60 轮空转 5 分钟、日志里只看到「绑定成功」的假象。
		if err=$(printf '%s' "$DEVNAME" > "$DRV/bind" 2>&1); then
			log "re-bound $DEVNAME (try $i)"
		else
			log "bind 写入失败：$DRV/bind <= \"$DEVNAME\"（stderr：${err:-<空>}）"
			log "判据：ls -l $DRV 应见 $DEVNAME 软链；ls $DEV/driver 应存在；dmesg | grep -i ath12k 应无 probe 失败"
			log "常见原因：设备名写成路径（旧 bug）/ 已被其它驱动占用 / 固件缺失（/lib/firmware/ath12k/PEACH/hw2.0/）"
			exit 1
		fi
	fi
	sleep 5
done

log "gave up (no phy0)"
exit 1
