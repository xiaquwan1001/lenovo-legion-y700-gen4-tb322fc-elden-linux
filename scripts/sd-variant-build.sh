#!/bin/bash
# sd-variant-build.sh — build one sleep-death (熄屏→关机) candidate kernel + boot.img.
#
# Base = wt-sleepdeath worktree (checked out at vk47 / bd114ca33, = vk47clean source).
# Config = wt-wifibmiss/.config (same as the known-resetting on-device kernel;
#          audio/panel =y so a single C-file change only relinks the kernel Image).
# Ramdisk = out/initramfs-full-elden.cpio.gz (the standard full test vehicle).
#
# usage: scripts/sd-variant-build.sh <version>
#   e.g. scripts/sd-variant-build.sh sd-base
#        -> out/boot-elden-sd-base.img  (UTS ...-sd-base-g<sha>)
set -euo pipefail
ROOT=${ROOT:-/home/xuqianhui1001/y700-elden}
K=${K:-/home/xuqianhui1001/wt-sleepdeath}
VER=${1:?usage: sd-variant-build.sh <version>}
LOG="$ROOT/logs/build-$VER.log"

export ARCH=arm64
export CROSS_COMPILE="ccache aarch64-linux-gnu-"
export CC="ccache aarch64-linux-gnu-gcc"
export HOSTCC="ccache gcc"
export CCACHE_DIR="$HOME/.cache/ccache-elden"
export KBUILD_BUILD_USER=elden
export KBUILD_BUILD_HOST=y700

grep -q '^CONFIG_ARCH_QCOM=y' "$K/.config" || { echo "ERROR: ARCH_QCOM missing" >&2; exit 1; }

echo "[sd] HEAD=$(git -C "$K" rev-parse --short HEAD) dirty=$(git -C "$K" status --porcelain | wc -l)"
echo "[sd] building Image.gz + dtbs (LOCALVERSION=-$VER) ..."
make -C "$K" -j"$(nproc)" LOCALVERSION="-$VER" Image.gz dtbs 2>&1 | tee "$LOG"

KDIR="$K" LOCALVERSION="-$VER" RAMDISK_KIND=full VERSION="$VER" \
	bash "$ROOT/scripts/build-boot.sh" 2>&1 | tee -a "$LOG"

echo "[sd] done: $ROOT/out/boot-elden-$VER.img"
