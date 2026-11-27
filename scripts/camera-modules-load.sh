#!/bin/sh
# camera-modules-load.sh — bring up the mainline camera stack on TB322FC.
#
# Idempotent, quiet, safe to run at every boot (from /init) or by hand.  It
# expects the camera .ko bundle to already be installed under
# /lib/modules/$(uname -r)/ (see deploy-camera-modules.sh / the boot ramdisk).
#
# Loads, in dependency order:
#   clk:   camcc-sm8750, cambistmclkcc-sm8750   (CAM_CC GDSC + MCLK3/4)
#   i2c:   i2c-qcom-cci                          (CCI0/CCI1 control buses)
#   pmic:  wl2868c-regulator                     (camera LDO1-7)
#   media: qcom-camss                            (CSIPHY/CSID/VFE)
#   i2c:   s5kjns (rear), gc08a8 (front), gt9764 (rear AF VCM)
#   led:   leds-qcom-flash                       (flash subdev, sensor async dep)
#   dma:   system_heap                           (/dev/dma_heap/system provider)
#
# modprobe resolves the ordering from modules.dep (built by depmod); the list
# below is only the non-media roots that must be probed explicitly.
#
# dma-buf heap (libcamera software ISP): the simple pipeline + soft ISP needs a
# dma-buf provider; without one it aborts with
#   "DmaBufAllocator ... Could not open any dma-buf provider"
# and never debayers.  `system_heap` gives /dev/dma_heap/system, which works.
# Do NOT load `cma_heap`: it also creates /dev/dma_heap/reserved (a 32 MiB CMA
# area from DT), and libcamera's DmaHeap probes linux,cma -> reserved -> system
# in that order, so `reserved` wins and then fails the ~30 MiB frame alloc with
# ENOMEM.  Keep cma_heap unloaded so libcamera falls through to `system`.
set -u

# elden_nocamera=1 (kernel cmdline) suppresses auto-load.  Used for the
# camera-module-set ⇄ screen-blank power-off bisection (Q24) — a clean boot
# with zero camera modules lets us add groups cumulatively.
# 不能静默退：静默 rc=0 会把「配置态」读成「驱动坏」（2026-10-09 深夜在 payload loader
# 上已经栽过一次，这是同型）。手动测试用 CAM_FORCE=1 显式绕过。
if grep -q "elden_nocamera=1" /proc/cmdline; then
	if [ "${CAM_FORCE:-0}" = 1 ]; then
		echo "[camera] cmdline says elden_nocamera=1 but CAM_FORCE=1 -> loading anyway"
	else
		echo "[camera] SKIPPED: cmdline has elden_nocamera=1 (override with CAM_FORCE=1)"
		exit 0
	fi
fi

KV=$(uname -r)
MODDIR=/lib/modules/$KV
MODDIR=$(readlink -f "$MODDIR")
# 判“有没有模块”不能要求 kernel/ 前缀：`M=<dir> modules_install` 装出来的布局就是没有
# kernel/（2026-10-09 深夜 mod-loop 的 tar 刚栽在同一件事上，今天相机线又被它误挡一次）。
# 按目录下实际存在 .ko 判。
if ! find "$MODDIR" -name '*.ko*' -print -quit 2>/dev/null | grep -q .; then
	echo "[camera] no modules for $KV (nothing under $MODDIR)" >&2
	exit 0
fi

# Always (re)generate the module index with the device's depmod.  This is
# REQUIRED: the device uses kmod, whose modules.dep uses full relative paths
# (and a modules.dep.bin index); a hand-written "bare name" modules.dep makes
# modprobe report "Module qcom-camss not found" for any module with deps.
# 20 modules regenerate in well under a second.
depmod -a "$KV" 2>/dev/null || depmod -a 2>/dev/null || true

load() {
	# lsmod 里模块名是**下划线**，传进来的是连字符 —— 不转换就永远匹配不上，
	# 幂等检查形同虚设（已加载也会重新 modprobe 并谎报 “loaded”）。
	if lsmod 2>/dev/null | grep -q "^$(echo "$1" | tr '-' '_') "; then
		echo "[camera] already loaded $1"
		return 0
	fi
	if modprobe "$1" 2>/dev/null; then
		echo "[camera] loaded $1"
	else
		echo "[camera] WARN: modprobe $1 failed" >&2
	fi
}

# dma-buf provider first (libcamera soft ISP), then clocks/regulators/bus.
load system_heap
for m in camcc-sm8750 cambistmclkcc-sm8750 i2c-qcom-cci wl2868c-regulator; do
	load "$m"
done
load qcom-camss
# Sensors are async; they bind when their supplies/clocks are ready.
for m in leds-qcom-flash gt9764 s5kjns gc08a8; do
	load "$m"
done

echo "[camera] done: $(ls /dev/media* 2>/dev/null | wc -l) media, $(ls /dev/video* 2>/dev/null | wc -l) video nodes"
