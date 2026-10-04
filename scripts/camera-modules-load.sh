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
#
# modprobe resolves the ordering from modules.dep (built by depmod); the list
# below is only the non-media roots that must be probed explicitly.
set -u

KV=$(uname -r)
MODDIR=/lib/modules/$KV
[ -d "$MODDIR/kernel" ] || { echo "[camera] no modules for $KV" >&2; exit 0; }

# Always (re)generate the module index with the device's depmod.  This is
# REQUIRED: the device uses kmod, whose modules.dep uses full relative paths
# (and a modules.dep.bin index); a hand-written "bare name" modules.dep makes
# modprobe report "Module qcom-camss not found" for any module with deps.
# 20 modules regenerate in well under a second.
depmod -a "$KV" 2>/dev/null || depmod -a 2>/dev/null || true

load() {
	if lsmod 2>/dev/null | grep -q "^$1 "; then
		return 0
	fi
	if modprobe "$1" 2>/dev/null; then
		echo "[camera] loaded $1"
	else
		echo "[camera] WARN: modprobe $1 failed" >&2
	fi
}

# Clocks/regulators/control bus first, then the platform + sensors.
for m in camcc-sm8750 cambistmclkcc-sm8750 i2c-qcom-cci wl2868c-regulator; do
	load "$m"
done
load qcom-camss
# Sensors are async; they bind when their supplies/clocks are ready.
for m in leds-qcom-flash gt9764 s5kjns gc08a8; do
	load "$m"
done

echo "[camera] done: $(ls /dev/media* 2>/dev/null | wc -l) media, $(ls /dev/video* 2>/dev/null | wc -l) video nodes"
