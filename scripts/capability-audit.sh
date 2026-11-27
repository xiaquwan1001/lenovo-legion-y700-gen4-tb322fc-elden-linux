#!/bin/bash
# capability-audit.sh — 设备能力集合的**只读**现查（DEVICE/CAPABILITIES.md 的复现入口）
#
# 用途：把 CAPABILITIES 表里那些「桶② 有驱动未部署 / 桶③ 未模块化 / 固件面」的判定，
#       用一条命令在现场重新量一次（不 modprobe、不写 /sys、不重启、不装任何东西）。
#
# 用法：
#   scripts/capability-audit.sh            # 全部（需要 ssh elden 通）
#   scripts/capability-audit.sh config     # 只跑 CONFIG 面（=m/=y / 未开）
#   scripts/capability-audit.sh bind       # 只跑「设备 ↔ driver 绑定」面
#   scripts/capability-audit.sh fw         # 只跑固件面（清单/失败请求）
#   scripts/capability-audit.sh --tsv      # 机读（制表符分隔，供对账脚本吃）
#
# 退出码：0 = 采集成功；2 = 设备不可达；4 = 用法错。
# 判据出处：reports/hw-capability-drivers-20261127.md、reports/hw-capability-firmware-20261127.md、
#           DEVICE/CAPABILITIES.md §0/§1。
set -uo pipefail

HOST=${HOST:-elden}
SSH_OPTS=${SSH_OPTS:--o BatchMode=yes -o ConnectTimeout=8}
WHAT=${1:-all}
TSV=0
case "$WHAT" in
	--tsv) TSV=1; WHAT=all ;;
	all|config|bind|fw) ;;
	*) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 4 ;;
esac

run() { timeout -k 5 60 ssh $SSH_OPTS "$HOST" "$@" </dev/null 2>/dev/null; }

if ! run 'true'; then
	printf 'capability-audit: 设备不可达（ssh %s）\n' "$HOST" >&2
	exit 2
fi

out() { if [ "$TSV" = 1 ]; then printf '%s\t%s\t%s\n' "$1" "$2" "$3"; else printf '%-34s %-12s %s\n' "$1" "$2" "$3"; fi; }

# ---- 1. CONFIG 面（桶②③ 的根因多半在这里）----------------------------------
cfg_section() {
	# 判据来源 = **在机内核**的 config（不是构建树）；换核后重跑才有意义
	printf '%-34s %-12s %s\n' '（在机内核实测）' "$(run 'uname -r')" 'config 取自 /proc/config.gz'
	run 'zcat /proc/config.gz 2>/dev/null || cat /boot/config-$(uname -r) 2>/dev/null' > /tmp/cap-cfg.$$ || true
	[ -s /tmp/cap-cfg.$$ ] || { echo "（取不到内核 config）" >&2; return; }
	# 符号=期望（y/m/-）：- 表示「不要求」
	while IFS=$'\t' read -r sym want blk; do
		[ -n "${sym:-}" ] || continue
		line=$(grep -E "^(${sym}=|# ${sym} is not set)" /tmp/cap-cfg.$$ | head -1)
		if [ -z "$line" ]; then cur='(absent)'
		elif printf '%s' "$line" | grep -q 'is not set'; then cur='n'
		else cur=${line#*=}; fi
		if [ "$want" = '-' ]; then verdict='info'
		elif [ "$cur" = "$want" ]; then verdict='OK'
		elif [ "$cur" = 'n' ] || [ "$cur" = '(absent)' ]; then verdict='MISSING'
		else verdict='MISMATCH'; fi
		out "$sym" "${cur}" "$verdict  [$blk]"
	done <<-'EOF'
		CONFIG_VIDEO_QCOM_IRIS	m	iris 视频解码
		CONFIG_NFC_ST21NFCA_I2C	-	NFC：本机无硬件（G1-10 ❌），不投入
		CONFIG_HW_RANDOM_QCOM	m	硬件 TRNG
		CONFIG_CRYPTO_DEV_QCE	-	QCE：上游 BROKEN 开不出（drivers/crypto/Kconfig:529）
		CONFIG_CORESIGHT_CTCU	m	CTCU 相机测试单元
		CONFIG_CORESIGHT_TPDM	m	Coresight TPDM
		CONFIG_CORESIGHT_TNOC	m	Coresight TNOC
		CONFIG_ATH12K	-	WiFi 裁决保持 =y（开机即起，见 CAPABILITIES §3 C8）
		CONFIG_GUNYAH	-	Gunyah 已裁决不投入
EOF
	# 说明：`(absent)` = 该符号**根本没出现在 .config** 里，两种成因要分开看 ——
	#   ① 树里确实没有该驱动（`ls build/<tree>/drivers/...` 一次就知道）
	#   ② 树里有、但 .config 生成得比树内容早（真例：st21nfca 文件 2026-11-25 才进树，
	#      而在机的 build/daily/.config 是 11-16 的）⇒ `make olddefconfig` 后才会出现
	#      `# CONFIG_NFC_ST21NFCA_I2C is not set`。别把②当成①。
	[ "$TSV" = 1 ] || printf '%-34s %-12s %s\n' '（说明）' '(absent)' '符号不在 .config：要么树里没这驱动，要么 config 早于树内容（olddefconfig 再判）'
	rm -f /tmp/cap-cfg.$$
}

# ---- 2. 设备 ↔ driver 绑定面（桶②/⑤）-------------------------------------
bind_section() {
	while IFS=$'\t' read -r dev label; do
		[ -n "${dev:-}" ] || continue
		drv=$(run "readlink /sys/bus/platform/devices/${dev}/driver 2>/dev/null | xargs -r basename")
		[ -n "$drv" ] || drv='NODRIVER'
		out "$label" "$dev" "${drv:-NODRIVER}"
	done <<-EOF
	10c3000.rng	硬件 TRNG
1dfa000.crypto	QCE
10001000.ctcu	CTCU
3d37000.gmu	GPU GMU（子节点，无 driver 属正常）
ad27000.isp	相机 ISP
ac7b000.cci	相机 CCI#0
EOF
	# 相机是否常驻（2026-11-27 起：cam-mode-off 已 disabled）
	cam=$(run 'lsmod | grep -cE "qcom_camss|i2c_qcom_cci|wl2868c|leds_qcom_flash"')
	vid=$(run 'ls /dev/video* 2>/dev/null | wc -l')
	med=$(run 'ls /dev/media* 2>/dev/null | wc -l')
	svc=$(run 'systemctl is-enabled cam-mode-off.service 2>&1')
	out '相机栈（模块/视频节点/media）' "cam=${cam:-0}" "video=${vid:-0} media=${med:-0} cam-mode-off=${svc:-?}"
	# 未绑定的 amba 设备数（Coresight 大洞）
	unb=$(run 'for d in /sys/bus/amba/devices/*; do [ -e "$d/driver" ] || echo x; done | wc -l')
	out 'amba 未绑定设备数' "${unb:-?}" '（TPDM/TNOC 未开 CONFIG 时的形态）'
}

# ---- 3. 固件面 --------------------------------------------------------------
fw_section() {
	total=$(run 'find /lib/firmware -type f | wc -l')
	out '/lib/firmware 文件数' "${total:-?}" '基线 121（2026-11-27）'
	fails=$(run 'dmesg 2>/dev/null | grep -c "Direct firmware load .* failed"')
	reg=$(run 'dmesg 2>/dev/null | grep -c "failed to load regulatory.db"')
	out 'Direct firmware load 失败数' "${fails:-?}" "（regulatory.db 若为 1 属符号链/时序，不是缺件：${reg:-?}）"
	run 'dmesg 2>/dev/null | grep "Direct firmware load .* failed" | sed "s/^/    /"' || true
	for f in qcom/vpu/vpu35_p4.mbn qca/tmel_peach_20.elf novatek_ts_csot_3k_fw.bin \
	         awinic/y700-gen4-haptic.bin awinic/y700-gen4-speakers.bin \
	         qcom/sm8750/Lenovo-Y700-Gen4-tplg.bin; do
		s=$(run "[ -f /lib/firmware/$f ] && stat -c %s /lib/firmware/$f || echo MISSING")
		out "$f" "${s:-?}" "$([ "${s:-}" = MISSING ] && echo MISSING || echo present)"
	done
}

case "$WHAT" in
	config) cfg_section ;;
	bind)   bind_section ;;
	fw)     fw_section ;;
	all)
		echo "== 1. CONFIG 面 =="; cfg_section
		echo "== 2. 绑定面 =="; bind_section
		echo "== 3. 固件面 =="; fw_section
		;;
esac
echo "（只读采集；改动请回到 DEVICE/CAPABILITIES.md §2 的下一步）"
