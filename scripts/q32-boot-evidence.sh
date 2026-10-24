#!/bin/sh
# q32-boot-evidence.sh — Q32（暖起 vs 冷起）**只读取证**：把「本次启动的复位深度」与
# 「本次启动固件有没有留活显示」两个自变量固定成可复核的字符串。
#
# 设计依据：reports/q32-warm-vs-cold-preresearch-20261023.md §2/§3
#   · 复位深度：`psci: SYSTEM_RESET2 vendor reset_type=…` 是**上一个**内核在复位前打的，
#     所以证据渠道是 **pstore/ramoops（上一个启动的 console 尾部）**，不是本次 dmesg。
#     架构 `SYSTEM_RESET` 与物理 POR 在内核侧不可区分 ⇒ 由调用方声明（RESET_DECLARED=por|cold|warm）。
#   · 固件活显示：DT `reserved-memory/*splash*` + msm 的 `boot framebuffer mapped before SID switch`
#     / `reserved boot framebuffer IOVA` + cmdline `silent_boot.mode`（nonsilent ⇒ ABL 点了屏）。
#   · simpledrm/efifb 是否参与：7.3 树无 `chosen/framebuffer` ⇒ 期望 0；非 0 说明交接路径变了。
#
# 用法：ssh root@192.168.7.1 'RESET_DECLARED=por sh -s' < scripts/q32-boot-evidence.sh
# 输出：/var/tmp/q32-boot-<bootid8>.txt（`===== summary` 机器可读，且回显 stdout）
#       /var/tmp/q32-pstore-<bootid8>.log（上一个启动的 console 尾部，**读完即删，必须在此归档**）
# 纪律：只读（唯一副作用 = 读取 pstore 条目，pstore 语义即「读后删除」，故先落 /var/tmp）。
set -u
BID=$(cut -c1-8 /proc/sys/kernel/random/boot_id 2>/dev/null)
OUT=${OUT:-/var/tmp/q32-boot-$BID.txt}
PST=/var/tmp/q32-pstore-$BID.log
: > "$OUT"
sec() { printf '\n===== %s =====\n' "$*" >> "$OUT"; }
q()  { "$@" >> "$OUT" 2>&1 || true; }
g()  { printf '%s\n' "--- dmesg /$1/" >> "$OUT"; dmesg 2>/dev/null | grep -cE -- "$1" >> "$OUT"; }
gl() { printf '%s\n' "--- dmesg /$1/ (head 6)" >> "$OUT"; dmesg 2>/dev/null | grep -E -- "$1" | head -6 >> "$OUT"; }

# ---------- 0) pstore：上一个启动的尾部（复位深度的唯一内核侧证据） ----------
sec pstore-previous-boot
ls -l /sys/fs/pstore/ >> "$OUT" 2>&1 || true
: > "$PST"
for f in /sys/fs/pstore/*; do
	[ -f "$f" ] || continue
	case "$f" in
	*console*|*dmesg*)
		# 可能是压缩的（CONFIG_PSTORE_COMPRESS）⇒ 先试 zstd，再退回原样
		if command -v zstd >/dev/null 2>&1 && zstd -dc "$f" > "$PST.tmp" 2>/dev/null; then
			cat "$PST.tmp" >> "$PST"
		else
			cat "$f" >> "$PST" 2>/dev/null || true
		fi
		rm -f "$PST.tmp"
		;;
	esac
done
if [ -s "$PST" ]; then
	printf 'pstore_archived=%s bytes=%s\n' "$PST" "$(wc -c < "$PST")" >> "$OUT"
	printf '%s\n' '--- 上一个启动里的复位/关机痕迹（tail 10）' >> "$OUT"
	grep -aE 'SYSTEM_RESET2|vendor reset|reboot: |Restarting system|reboot_mode|psci_elden|Power down' "$PST" | tail -10 >> "$OUT"
	printf '%s\n' '--- 上一个启动的显示尾部（tail 6）' >> "$OUT"
	grep -aE 'msm_dpu|msm_dsi|drm|dsi|panel|mdss' "$PST" | tail -6 >> "$OUT"
else
	printf 'pstore_archived=none（ramoops 里没有上个启动的记录：多为真 POR/断电，或已被读过一次）\n' >> "$OUT"
fi

# ---------- 1) identity ----------
sec identity
q uname -a
printf 'boot_id=%s uptime=%ss\n' "$BID" "$(cut -d' ' -f1 /proc/uptime)" >> "$OUT"
printf 'reset_declared=%s\n' "${RESET_DECLARED:-unspecified}" >> "$OUT"
printf 'build_manifest=%s\n' "$(awk -F= '$1=="image"{sub(/^[^=]*=/,"");print;exit}' /etc/elden-build.manifest 2>/dev/null)" >> "$OUT"
printf 'cmdline=%s\n' "$(cat /proc/cmdline 2>/dev/null)" >> "$OUT"
printf 'bootargs=%s\n' "$(tr -d '\0' < /proc/device-tree/chosen/bootargs 2>/dev/null)" >> "$OUT"

# ---------- 2) 本次启动的复位深度旁证 ----------
sec reset-depth
g 'SYSTEM_RESET2 vendor reset_type'
gl 'SYSTEM_RESET2|psci_elden|vendor reset'
gl 'reboot: |Restarting system|reboot_mode'
gl 'reboot reason|reset reason|bootreason'
printf '--- qbootctl\n' >> "$OUT"
command -v qbootctl >/dev/null 2>&1 && qbootctl -m 2>&1 | head -4 >> "$OUT"

# ---------- 3) 固件是否留活显示 ----------
sec firmware-display
printf '%s\n' '--- reserved-memory / splash' >> "$OUT"
ls /proc/device-tree/reserved-memory/ 2>/dev/null | grep -i splash >> "$OUT"
# 节点名随树不同（linux/ 树 `splash-region@fc800000`、在机 DTB `splash_region`）⇒ 用通配，勿写死路径
SPLASH_DIR=""
for d in /proc/device-tree/reserved-memory/*splash*; do [ -d "$d" ] && { SPLASH_DIR=$d; break; }; done
if [ -n "$SPLASH_DIR" ]; then
	printf 'splash_node_path=%s\n' "$SPLASH_DIR" >> "$OUT"
	od -An -tx1 "$SPLASH_DIR/reg" 2>/dev/null | tr -s ' ' | head -2 >> "$OUT"
	[ -e "$SPLASH_DIR/no-map" ] && printf 'no_map=yes\n' >> "$OUT"
fi
gl 'reserved mem:.*splash'
gl 'boot framebuffer|bootloader frame|continuous-splash'
g 'simpledrm|simple-framebuffer|efifb'
printf '%s\n' '--- chosen/' >> "$OUT"
ls /proc/device-tree/chosen/ 2>/dev/null >> "$OUT"
printf '%s\n' '--- fb0' >> "$OUT"
for f in name virtual_size stride bits_per_pixel; do
	[ -e "/sys/class/graphics/fb0/$f" ] && printf 'fb0/%s=%s\n' "$f" "$(cat "/sys/class/graphics/fb0/$f")" >> "$OUT"
done
printf '%s\n' '--- silent_boot / panel' >> "$OUT"
tr ' ' '\n' < /proc/cmdline 2>/dev/null | grep -E 'silent_boot|dsi_display|bootreason' >> "$OUT"
for f in /sys/class/drm/card0-DSI-1/status /sys/class/drm/card0-DSI-1/enabled /sys/class/drm/card0-DSI-1/dpms \
         /sys/class/backlight/*/brightness; do
	[ -e "$f" ] && printf '%s=%s\n' "$f" "$(cat "$f" 2>/dev/null)" >> "$OUT"
done

# ---------- 4) 时间线 ----------
sec probe-timeline
printf '%s\n' '--- 关键时间戳（boot FB 记录 vs msm bind vs fbcon 切换）' >> "$OUT"
dmesg 2>/dev/null | grep -E 'boot framebuffer|reserved boot framebuffer|msm_dpu .*bound|Initialized msm|Console: switching to colour frame buffer|fb0: ' \
	| awk '{print $1, $2, substr($0, index($0,$3))}' | head -12 >> "$OUT"

# ---------- 5) 显示错误签名 ----------
sec display-errors
for p in "command DMA timeout" "peer command DMA timeout" "reset failure" "DSI_PLL_lockfail" \
         "failed to acquire mdss resets" "stale link configuration"; do
	printf '%-32s %s\n' "$p" "$(dmesg 2>/dev/null | grep -c -- "$p")" >> "$OUT"
done

# ---------- summary（机器可读） ----------
# ★抗噪匹配：ramoops 在 POR 后是**残留+新写交错**（同一地址被旧内容填过），实测会把
# `vendor reset_type=0x80010001` 写成 `vendor reret_type=0h8000001` 之类 ⇒ 不能用整串精确匹配。
# 只认不会被打乱的锚点 `SYSTEM_RESET2`（若它都花掉则记 unknown，不强推）。
PST_RESET=$(grep -ac 'SYSTEM_RESET2' "$PST" 2>/dev/null | head -1); PST_RESET=${PST_RESET:-0}
if [ -s "$PST" ]; then
	printf '%s\n' '--- pstore 抗噪匹配到的复位行（可能是残留/交错文本，需与上一发归档比对）' >> "$OUT"
	grep -aE 'SYSTEM_RESET2|Restarting system with command' "$PST" 2>/dev/null | tail -4 >> "$OUT"
fi
PST_PRESENT=no; [ -s "$PST" ] && PST_PRESENT=yes
VENDOR_RESET=$(dmesg 2>/dev/null | grep -c 'SYSTEM_RESET2 vendor reset_type')
SPLASH_NODE=no
for d in /proc/device-tree/reserved-memory/*splash*; do [ -d "$d" ] && SPLASH_NODE=yes; done
SPLASH_MEM=$(dmesg 2>/dev/null | grep -c 'reserved mem:.*splash')
BOOTFB=$(dmesg 2>/dev/null | grep -c 'reserved boot framebuffer IOVA')
BOOTFB_MAP=$(dmesg 2>/dev/null | grep -c 'boot framebuffer mapped before SID switch')
SDRM=$(dmesg 2>/dev/null | grep -icE 'simpledrm|simple-framebuffer|efifb')
CHOSEN_FB=no; [ -d /proc/device-tree/chosen/framebuffer ] && CHOSEN_FB=yes
SILENT=$(tr ' ' '\n' < /proc/cmdline 2>/dev/null | sed -n 's/^silent_boot\.mode=//p')
FBNAME=$(cat /sys/class/graphics/fb0/name 2>/dev/null)
DSI=$(cat /sys/class/drm/card0-DSI-1/status 2>/dev/null)
DSIEN=$(cat /sys/class/drm/card0-DSI-1/enabled 2>/dev/null)
STORM=$(dmesg 2>/dev/null | grep -Ec 'command DMA timeout|peer command DMA timeout|ctl [0-9]+ reset failure')

if [ "${PST_RESET:-0}" -gt 0 ]; then
	RESET_DEPTH=vendor_bootloader          # 上个启动经 PSCI SYSTEM_RESET2 vendor 复位
elif [ "$VENDOR_RESET" -gt 0 ]; then
	RESET_DEPTH=vendor_bootloader_same_boot
elif [ -n "${RESET_DECLARED:-}" ] && [ "${RESET_DECLARED}" != unspecified ]; then
	RESET_DEPTH="${RESET_DECLARED}_declared"
else
	RESET_DEPTH=unknown
fi

if [ "$BOOTFB" -gt 0 ] && [ "$SPLASH_NODE" = yes ]; then
	FW_LIVE_FB=yes
elif [ "$BOOTFB" -gt 0 ] || [ "$SPLASH_NODE" = yes ]; then
	FW_LIVE_FB=partial
else
	FW_LIVE_FB=no
fi

{
	printf '\n===== summary =====\n'
	printf 'boot_id=%s uptime=%ss\n' "$BID" "$(cut -d' ' -f1 /proc/uptime)"
	printf 'RESET_DECLARED=%s\n' "${RESET_DECLARED:-unspecified}"
	printf 'PSTORE_PRESENT=%s\n' "$PST_PRESENT"
	printf 'PSTORE_RESET_PRINT=%s\n' "${PST_RESET:-0}"
	printf 'RESET_DEPTH=%s\n' "$RESET_DEPTH"
	printf 'SPLASH_NODE=%s\n' "$SPLASH_NODE"
	printf 'SPLASH_RESERVED_MEM=%s\n' "$SPLASH_MEM"
	printf 'BOOTFB_RECORDED=%s\n' "$BOOTFB"
	printf 'BOOTFB_MAPPED_PRE_SID=%s\n' "$BOOTFB_MAP"
	printf 'FW_LIVE_FB=%s\n' "$FW_LIVE_FB"
	printf 'SILENT_BOOT=%s\n' "${SILENT:-unset}"
	printf 'SIMPLEDRM=%s\n' "$SDRM"
	printf 'CHOSEN_FB=%s\n' "$CHOSEN_FB"
	printf 'FB0_NAME=%s\n' "${FBNAME:-none}"
	printf 'DSI_STATUS=%s/%s\n' "${DSI:-none}" "${DSIEN:-none}"
	printf 'STORM_SIG=%s\n' "$STORM"
} >> "$OUT"

tr -d '\0' < "$OUT" > "$OUT.clean" 2>/dev/null && mv -f "$OUT.clean" "$OUT" 2>/dev/null || true

sed -n '/^===== summary =====/,$p' "$OUT"
echo "OUT=$OUT"
[ -s "$PST" ] && echo "PSTORE=$PST"
exit 0
