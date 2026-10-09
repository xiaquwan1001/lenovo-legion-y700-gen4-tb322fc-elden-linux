#!/usr/bin/env bash
# q28-boot-cycle.sh — 跑一轮「温启 → 零写盘 fastboot boot 诊断内核 → 取证」，判定 Q28 是否复现。
#
# 为什么每轮要温启：Q28 只在**开机后第一次 modeset**出问题（80 轮 DPMS 上电循环 0 命中已排除稳态
# 竞态，见 .pi/plans/2026-10-09-Q28-密集复现与vk74.md）。所以样本只能从 boot 里取。
# 通道：SSH over USB-NCM（**adb 恒无效**，本机没有 adbd）；进 fastboot 用 G1-24 的
# reboot2 bootloader（PSCI SYSTEM_RESET2 vendor reason），不需要按键。
#
# 用法： scripts/q28-boot-cycle.sh <boot.img> [tag]
# 退出：0=本轮 Q28 未复现（好发）；10=复现（坏发，证据已落 logs/）；1=环境/超时问题。
# 纪律：fastboot 命令拆单条（PITFALLS #3）；主机侧一律带 timeout（AGENT-OPS §5）；
#       连续温启会**累积**面板失败（PITFALLS #140 系列/Q28b）⇒ 跑几轮后要请用户做一次物理冷启。
set -uo pipefail
cd "$(dirname "$0")/.."
IMG=${1:?usage: q28-boot-cycle.sh <boot.img> [tag]}
TAG=${2:-$(basename "$IMG" .img)}
TAB=${TAB:-root@192.168.7.1}
OUT=logs/q28-cycle-$(date +%Y%m%d-%H%M%S)
mkdir -p "$OUT"
[ -e "$IMG" ] || { echo "missing $IMG"; exit 1; }
S() { timeout "${2:-25}" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=6 "$TAB" "$1" 2>/dev/null; }

echo "IMG=$IMG TAG=$TAG OUT=$OUT"
echo "before: $(S 'echo uptime=$(cut -d" " -f1 /proc/uptime) uname=$(uname -r)')"

echo "== 1) reboot2 bootloader（进 fastboot，无需按键）=="
S '(sleep 2; reboot2 bootloader) >/dev/null 2>&1 &' || true

echo "== 2) 等 fastboot（最多 90 s）=="
i=0; while [ $i -lt 18 ]; do
	if fastboot devices 2>/dev/null | grep -q .; then echo "fastboot: $(fastboot devices | head -1)"; break; fi
	sleep 5; i=$((i + 1))
done
fastboot devices 2>/dev/null | grep -q . || { echo "FAIL=no-fastboot-device（90 s 内没进 fastboot；可能需物理干预）"; exit 1; }

echo "== 3) fastboot boot（零写盘，单条命令）=="
timeout 180 fastboot boot "$IMG" 2>&1 | tail -3 | tee "$OUT/fastboot.log"

echo "== 4) 等 SSH（最多 150 s）=="
i=0; while [ $i -lt 30 ]; do
	if S 'echo up' | grep -q up; then echo "ssh up after $((i * 5))s"; break; fi
	sleep 5; i=$((i + 1))
done
S 'echo up' | grep -q up || { echo "FAIL=no-ssh（150 s；可能停在无桌面/引导失败）"; exit 1; }

echo "== 5) 取证 =="
S 'cat /proc/cmdline; echo "--- uname ---"; uname -a' >"$OUT/cmdline-uname.txt" 2>&1
S 'dmesg' >"$OUT/dmesg.txt" 2>&1
S 'for d in /sys/class/drm/card*-DSI-*; do [ -e "$d/dpms" ] && echo "$(basename $d) status=$(cat $d/status) dpms=$(cat $d/dpms)"; done; echo "bright=$(cat /sys/class/backlight/*/brightness 2>/dev/null)"; echo "phosh=$(ps -eo comm | grep -cx phosh)"' >"$OUT/drm.txt" 2>&1
S 'grep -E "^(mdss_gdsc|gfx|mdss_int2_gdsc)" /sys/kernel/debug/pm_genpd/pm_genpd_summary; echo "-- runtime --"; for d in ae01000.display-controller ae00000.display-subsystem ae94000.dsi ae96000.dsi; do p=/sys/bus/platform/devices/$d/power; [ -d "$p" ] && echo "$d $(cat $p/runtime_status)"; done' >"$OUT/power.txt" 2>&1

# 2026-10-09 vk74-1 实测：坏发时 dsi1vco_clk enable=0 rate=0（而 dsi0vco 有频率）、两 host 的
# dsi_isr 计数全 0 ⇒ 怀疑 slave host 的 DSI PLL 从未锁定。这两项是好/坏对照的关键，必须每轮采。
S 'echo "== vco/clk now =="; grep -E "dsi0vco_clk|dsi1vco_clk|dsi0_byte|dsi1_byte" /sys/kernel/debug/clk/clk_summary | awk "{print \$1, \$3, \$4, \$5}"; echo "== dsi_isr counts =="; awk "/dsi_isr|mdss/ {print \$1, \$2, \$3, \$NF}" /proc/interrupts | head -6' >"$OUT/vco-irq.txt" 2>&1

VB=$(grep -c "vblank timeout" "$OUT/dmesg.txt")
PU=$(grep -cE "power-up failed|failed to resume dsi host" "$OUT/dmesg.txt")
PI=$(grep -cE "Failed to initialize panel|dcs data .* failed" "$OUT/dmesg.txt")
DPMS=$(grep -oE "dpms=[A-Za-z]+" "$OUT/drm.txt" | head -1)
PMON=$(grep -c "mdss_gdsc *on" "$OUT/power.txt")
{
	echo "TAG=$TAG UTS=$(sed -n 's/^Linux version \([^ ]*\).*/\1/p' "$OUT/dmesg.txt" | head -1)"
	echo "VBLANK_TIMEOUT=$VB POWERUP_FAIL=$PU PANEL_INIT_FAIL=$PI $DPMS MDSS_GDSC_ON=$PMON"
	if [ "$((VB + PU + PI))" -gt 0 ] || echo "$DPMS" | grep -qi "off"; then V=BAD; else V=GOOD; fi
	echo "VERDICT=$V"
} | tee "$OUT/summary.txt"
grep -E "power-up failed|resume dsi host|dpu pm:|vblank timeout|Failed to initialize|bonded|PLL.*lock fail" "$OUT/dmesg.txt" | head -20
[ "$((VB + PU + PI))" -gt 0 ] && exit 10
echo "$DPMS" | grep -qi "off" && exit 10
exit 0
