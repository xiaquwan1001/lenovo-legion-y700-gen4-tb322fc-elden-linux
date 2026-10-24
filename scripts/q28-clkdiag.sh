#!/bin/bash
# q28-clkdiag.sh — 设备侧**只读**取证：一次冷起后立刻跑，用来区分
# 「peer(第二路) pclk/INTF 没起来」与「DSI 侧问题」（Q28 下一个单变量）。
#
# 判据（见 reports/q28-dpu-intf-next-20261023.md）：
#   · disp_cc_mdss_pclk1_clk_src 的 parent/rate 是否与 pclk0 一致
#   · dsi1(ae96000.dsi) 的 byte_src / pixel_src parent 是否指向自己的 PLL
#   · 坏发的特征：`ctl 1 reset failure: -22` + `peer command DMA timeout` + DSI 中断 0
#
# 用法：ssh root@192.168.7.1 'bash -s' < scripts/q28-clkdiag.sh   （或拷到设备上跑）
# 输出：/var/tmp/q28-clkdiag-<bootid前8>.txt（好/坏各收一份做对照）
set -uo pipefail
BID=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null | cut -c1-8)
OUT=${OUT:-/var/tmp/q28-clkdiag-$BID.txt}
: > "$OUT"
sec() { printf '\n===== %s =====\n' "$*" >> "$OUT"; }
run() { printf '%s\n' "--- $*" >> "$OUT"; "$@" >> "$OUT" 2>&1 || true; }

sec identity
run uname -a
printf 'boot_id=%s uptime=%ss\n' "$BID" "$(cut -d' ' -f1 /proc/uptime)" >> "$OUT"
run cat /proc/cmdline

sec display-status
for f in /sys/class/drm/card0-DSI-1/status /sys/class/drm/card0-DSI-1/enabled \
         /sys/class/drm/card0-DSI-1/dpms /sys/class/backlight/*/brightness; do
	[ -e "$f" ] && printf '%s=%s\n' "$(basename "$(dirname "$f")")/$(basename "$f")" "$(cat "$f")" >> "$OUT"
done
ls /sys/class/drm/ >> "$OUT" 2>&1

sec dmesg-signatures
for p in "command DMA timeout" "peer command DMA timeout" "DSI_PLL_lockfail" \
         "recovery is not complete" "reset failure" "STORM" "failed to acquire mdss resets" \
         "failed to prime mdss resets" "stale link configuration" "Unbalanced enable"; do
	printf '%-34s %s\n' "$p" "$(dmesg 2>/dev/null | grep -c -- "$p")" >> "$OUT"
done
dmesg 2>/dev/null | grep -E "command DMA timeout|peer command DMA timeout|reset failure|DSI_PLL_lockfail" | tail -8 >> "$OUT"

sec q32-reset-and-handoff
# Q32 三判据（reports/q32-warm-vs-cold-preresearch-20261023.md §2/§3）：
# ① 本次复位深度：vendor reset 打印是否出现（架构 SYSTEM_RESET 与 POR 内核侧不可区分）
printf 'vendor_reset_print=%s\n' "$(dmesg 2>/dev/null | grep -c 'SYSTEM_RESET2 vendor reset_type')" >> "$OUT"
dmesg 2>/dev/null | grep -E 'SYSTEM_RESET2|reset reason|reboot: ' | tail -4 >> "$OUT"
# ② 固件是否留活显示：DT splash 区 + msm 记录的 boot framebuffer + silent_boot 模式
_sp=no; for _d in /proc/device-tree/reserved-memory/*splash*; do [ -d "$_d" ] && _sp=yes; done
printf 'splash_node=%s\n' "$_sp" >> "$OUT"
printf 'bootfb_recorded=%s\n' "$(dmesg 2>/dev/null | grep -c 'reserved boot framebuffer IOVA')" >> "$OUT"
printf 'silent_boot=%s\n' "$(tr ' ' '\n' < /proc/cmdline | sed -n 's/^silent_boot.mode=//p')" >> "$OUT"
# ③ simpledrm/efifb 是否参与（7.3 树期望 0；非 0 = 交接路径变了）
printf 'simpledrm_or_efifb=%s\n' "$(dmesg 2>/dev/null | grep -icE 'simpledrm|simple-framebuffer|efifb')" >> "$OUT"
printf 'chosen_fb=%s\n' "$([ -d /proc/device-tree/chosen/framebuffer ] && echo yes || echo no)" >> "$OUT"

sec ctl-clock-rates
# DPU/INTF 侧的关键量：pclk0/1 的 parent 与 rate
for c in disp_cc_mdss_pclk0_clk_src disp_cc_mdss_pclk1_clk_src \
         disp_cc_mdss_mdp_clk_src disp_cc_mdss_byte0_clk_src disp_cc_mdss_byte1_clk_src; do
	[ -d "/sys/kernel/debug/clk/$c" ] || continue
	printf '%-32s rate=%-12s parent=%s\n' "$c" \
		"$(cat /sys/kernel/debug/clk/$c/clk_rate 2>/dev/null)" \
		"$(cat /sys/kernel/debug/clk/$c/clk_parent 2>/dev/null)" >> "$OUT"
done

sec dsi-phy-clocks
# byte_src / pixel_src 的 parent 名（能直接看出是否指向自己的 PLL）
grep -E "dsi[01]_pll|byte_src|pixel_src|mdss_pclk" /sys/kernel/debug/clk/clk_summary 2>/dev/null \
	| sed -E 's/^ +//' | head -60 >> "$OUT"

sec drm-summary
[ -r /sys/kernel/debug/dri/0/summary ] && cat /sys/kernel/debug/dri/0/summary >> "$OUT"
for crtc in /sys/kernel/debug/dri/0/crtc-*; do
	[ -d "$crtc" ] || continue
	printf '%s: %s\n' "$(basename "$crtc")" "$(cat "$crtc"/name 2>/dev/null)" >> "$OUT"
done

sec i2c-panel
ls /sys/bus/i2c/devices/ 2>/dev/null | grep -iE "nt36536|pp8807|0-00" >> "$OUT"

echo "$OUT"
