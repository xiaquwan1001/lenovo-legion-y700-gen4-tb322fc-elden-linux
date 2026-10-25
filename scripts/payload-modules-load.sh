#!/bin/sh
# payload-modules-load.sh — load the modularized payload drivers (ATH12K, QDSP6
# audio, haptics, touch, backlight) for TB322FC when they are built as modules.
#
# Idempotent, quiet, safe to run at every boot (from /init right after
# camera-modules-load.sh) or by hand.  Expects the module bundle for the
# running kernel under /lib/modules/$(uname -r)/ (built by
# scripts/build-modular-overlay.sh from a `make modules_install` staging dir).
#
# Loads, in dependency order:
#   audio:  snd-q6apm (pulls the whole qdsp6 stack: q6core/q6prm/q6adm/q6asm/
#           q6afe/routing/dais), then snd-soc-sc8280xp (eldren card driver,
#           pulls wcd939x codec) — wcd939x-sdw binds via SoundWire modalias
#   wifi:   ath12k (+ ath12k_wifi7)
#   input:  aw86927 (haptics), novatek-nvt36xxx-spi (touchscreen)
#   video:  aw99706 (backlight)
#
# modprobe resolves ordering from modules.dep (device depmod regenerates it,
# same as camera-modules-load.sh — kmod needs full-path deps + .bin index).
set -u

KV=$(uname -r)
MODDIR=/lib/modules/$KV
[ -d "$MODDIR/kernel" ] || { echo "[payload] no modules for $KV" >&2; exit 0; }

depmod -a "$KV" 2>/dev/null || depmod -a 2>/dev/null || true

load() {
	# lsmod 打印下划线名（snd-q6apm → snd_q6apm），两种写法都要能命中
	local m=${1//-/_}
	if lsmod 2>/dev/null | grep -q "^$m "; then
		return 0
	fi
	if ! modprobe "$1" 2>/dev/null; then
		echo "[payload] WARN: modprobe $1 failed" >&2
		return 1
	fi
	# 内核把该驱动编成 =y 时 modprobe 也会 rc=0（modules.builtin 命中），
	# 但 lsmod 里永远不会出现 —— 不能把「builtin」记成「loaded」（2026-10-26 实测：
	# vk152 非模块化内核上本脚本把 ath12k/q6apm 全报成 loaded，是假证据）。
	if lsmod 2>/dev/null | grep -q "^$m "; then
		echo "[payload] loaded $1"
	else
		echo "[payload] $1 is builtin in this kernel (no-op)"
	fi
}

# Audio first: QDSP6 services are needed before the card driver can probe.
load snd-q6apm
load snd-soc-sc8280xp
load ath12k
load ath12k_wifi7
load aw86927
load novatek-nvt36xxx-spi
load aw99706

# net: Waydroid container networking (PITFALLS #184). bridge pulls llc/stp via
# modules.dep; veth is the container end of the bridge. On a RAM boot these MUST
# load before switch_root or the initramfs module files are gone afterwards.
load bridge
load veth
load fuse

# NOTE 2026-10-09: lsmod prints names with '_' (dashes become underscores), so the
# counter below must use underscore spellings -- the original pattern used dashes for
# snd-soc-sc8280xp/novatek-nvt36xxx-spi and under-reported 4 of 7.
echo "[payload] done: $(lsmod 2>/dev/null | grep -cE '^(ath12k|ath12k_wifi7|snd_soc_sc8280xp|snd_q6apm|aw86927|novatek_nvt36xxx_spi|aw99706|bridge|veth|fuse) ') payload modules loaded"
