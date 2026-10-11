#!/bin/bash
# c1-iprule-build.sh — build the vk95 kernel that enables policy routing
# (CONFIG_IP_ADVANCED_ROUTER / IP_MULTIPLE_TABLES) so Android netd can install
# the container default route natively (TASKS §5 Q2 / C1).
#
# Detached, timed self-contained build: kernel + modules + modular ramdisk +
# boot.img, using the current linux/.config (vk64 good config + c1 fragment).
set -uo pipefail
ROOT=/home/xuqianhui1001/y700-elden
cd "$ROOT"
export PATH="$HOME/bin:$PATH"

V=vk95
TS=$(date +%Y%m%d-%H%M%S)
LOG=$ROOT/logs/c1-iprule-build-$TS.log
mkdir -p "$ROOT/logs"
exec > >(tee -a "$LOG") 2>&1

echo "### c1-iprule-build start $(date '+%F %T')  log=$LOG"
echo "HEAD: $(git -C "$ROOT/linux" log -1 --oneline)"
grep -qE '^CONFIG_ARCH_QCOM=y' "$ROOT/linux/.config" || { echo "!! ARCH_QCOM missing"; exit 1; }
grep -qE '^CONFIG_IP_ADVANCED_ROUTER=y' "$ROOT/linux/.config" || { echo "!! IP_ADVANCED_ROUTER missing"; exit 1; }

BASE=$ROOT/out/rootfs-base-golden.cpio.gz
[ -f "$BASE" ] || { echo "!! missing golden base $BASE"; exit 1; }

export LOCALVERSION="-$V"
STAGE=$ROOT/out/modstage-$V
rm -rf "$STAGE"

echo "--- build Image.gz dtbs modules"
bash "$ROOT/scripts/build-kernel.sh" Image.gz dtbs modules || { echo "!! kernel build failed rc=$?"; exit 1; }

echo "--- modules_install -> $STAGE"
( cd "$ROOT/linux" && make -j"$(nproc)" ARCH=arm64 \
    CROSS_COMPILE="ccache aarch64-linux-gnu-" LOCALVERSION="$LOCALVERSION" \
    modules_install INSTALL_MOD_PATH="$STAGE" ) || { echo "!! modules_install failed"; exit 1; }

KV=$(cd "$ROOT/linux" && make -s ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
      LOCALVERSION="$LOCALVERSION" kernelrelease | tr -d '\r')
echo "--- KV=$KV"

echo "--- modular ramdisk overlay"
KV="$KV" STAGE="$STAGE" BASE="$BASE" bash "$ROOT/scripts/build-modular-overlay.sh" \
  || { echo "!! modular overlay failed"; exit 1; }
cp -a "$ROOT/out/rootfs-overlaid-modular.cpio.gz" "$ROOT/out/rootfs-overlaid-modular-$V.cpio.gz"

echo "--- package boot img"
VERSION="$V" RAMDISK="$ROOT/out/rootfs-overlaid-modular-$V.cpio.gz" \
  bash "$ROOT/scripts/build-boot.sh" || { echo "!! packaging failed"; exit 1; }

echo "--- DONE $(ls -l "$ROOT/out/boot-elden-$V.img" 2>/dev/null)"
echo "### c1-iprule-build done $(date '+%F %T')"
