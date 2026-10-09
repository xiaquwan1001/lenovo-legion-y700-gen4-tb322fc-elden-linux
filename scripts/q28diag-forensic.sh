#!/bin/sh
# q28diag-forensic.sh — run ON the device (root) over SSH after vk73-q28diag boot.
# Covers BOTH Q28 signatures in one shot:
#   (A) bonded command-DMA -ETIMEDOUT  -> regdump lines (Q28 ...) from the diag kernel
#   (B) panel-init-ok / vblank-fail    -> DSI VCO prepare_count (warm-boot skip-prepare hypothesis)
# Zero-write, read-only.
echo "=== uname ==="; uname -r
echo
echo "=== [A] Q28 regdump + display init signatures ==="
dmesg | grep -E "Q28|bonded|dcs data|timing 1904|Failed to init|PLL.*lock failed|command DMA|orphan reparent|vblank|wait_for_commit" | head -80
echo
echo "=== [B] DSI VCO clock state — FULL columns (prepare_count is the key datum) ==="
# clk_summary columns: clk  ready  enable_cnt  protect_cnt  duty_cycle  rate  parent
# under debugfs; some trees also show prepare via enable vs rate. Grab whole tree lines.
CLK=/sys/kernel/debug/clk/clk_summary
[ -d /sys/kernel/debug ] || mount -t debugfs none /sys/kernel/debug 2>/dev/null
if [ -f "$CLK" ]; then
  echo "-- header --"; head -1 "$CLK"
  echo "-- dsi*vco / dsi_pll / mdss pclk/byte --"
  grep -E "dsi.*vco|dsi.*pll|disp_cc_mdss_(pclk|byte)" "$CLK"
else
  echo "NO clk_summary (debugfs missing)"
fi
echo
echo "=== genpd summary (mdss_gdsc/gfx state) ==="
[ -f /sys/kernel/debug/pm_genpd/pm_genpd_summary ] && grep -E "mdss|gfx" /sys/kernel/debug/pm_genpd/pm_genpd_summary || echo "no pm_genpd_summary"
echo
echo "=== DSI / mdss interrupts (dsi1_isr==0 => DSI1 never fired) ==="
grep -E "msm_mdss|dsi" /proc/interrupts
echo
echo "=== DSI1 PLL reg via ioremem not possible (STRICT_DEVMEM); rely on dmesg regdump ==="
echo "=== done ==="
