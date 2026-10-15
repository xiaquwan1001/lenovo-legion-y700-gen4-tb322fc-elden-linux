#!/bin/bash
# q24-rebuild-arms.sh — rebuild the Q24 test arms from the good `clean/base`
# baseline + the current (good) .config.
#
# Why (PITFALLS #162): vk81/82/83 were built with a .config whose ARCH_QCOM had
# been silently dropped by `make olddefconfig` -> dead kernels; their on-device
# verdicts ("sleeps to death / stuck on logo / broken boot") are void.  Rebuild
# on the restored good config and re-verify with the build/pack guards.
#
# Arms:
#   vk90-e4amxc : E4a  DT cambist power-domains MX -> MXC
#   vk91-fix3mx : FIX-3 driver lazy-on + suspend quiesce (MX DT kept)
#   vk92-fix2mx : FIX-2 driver hold runtime vote (MX DT kept)
#
# Each arm gets its own vermagic (LOCALVERSION=-<arm>), its own module staging
# and its own self-contained modular ramdisk (golden base + per-arm payload
# layer) so `fastboot boot` stays zero-write.
set -uo pipefail
ROOT=/home/xuqianhui1001/y700-elden
cd "$ROOT"
export PATH="$HOME/bin:$PATH"

TS=$(date +%Y%m%d-%H%M%S)
LOG=$ROOT/logs/q24-rebuild-$TS.log
mkdir -p "$ROOT/logs"
exec > >(tee -a "$LOG") 2>&1
echo "### q24-rebuild-arms start $(date '+%F %T')  log=$LOG"

BASE=$ROOT/out/rootfs-base-golden.cpio.gz
[ -f "$BASE" ] || { echo "missing golden base $BASE"; exit 1; }

ARMS="vk90-e4amxc:vk90-e4a vk91-fix3mx:vk91-fix3 vk92-fix2mx:vk92-fix2"

for spec in $ARMS; do
  V=${spec%%:*}; B=q24/${spec##*:}
  echo
  echo "================ $V  ($B) ================"
  git -C "$ROOT/linux" checkout -q "$B" || { echo "!! checkout $B failed"; continue; }
  echo "HEAD: $(git -C "$ROOT/linux" log -1 --oneline)"
  grep -qE '^CONFIG_ARCH_QCOM=y' "$ROOT/linux/.config" \
    || { echo "!! .config lost ARCH_QCOM -> restore from patches/config-before-fragment-*.bak"; continue; }

  export LOCALVERSION="-$V"
  STAGE=$ROOT/out/modstage-$V
  rm -rf "$STAGE"

  echo "--- [$V] build Image.gz dtbs modules"
  bash "$ROOT/scripts/build-kernel.sh" Image.gz dtbs modules || { echo "!! kernel build failed"; continue; }

  echo "--- [$V] modules_install -> $STAGE"
  ( cd "$ROOT/linux" && make -j"$(nproc)" ARCH=arm64 \
      CROSS_COMPILE="ccache aarch64-linux-gnu-" LOCALVERSION="$LOCALVERSION" \
      modules_install INSTALL_MOD_PATH="$STAGE" ) || { echo "!! modules_install failed"; continue; }

  KV=$(cd "$ROOT/linux" && make -s ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
        LOCALVERSION="$LOCALVERSION" kernelrelease | tr -d '\r')
  echo "--- [$V] KV=$KV"

  echo "--- [$V] modular ramdisk overlay"
  KV="$KV" STAGE="$STAGE" BASE="$BASE" bash "$ROOT/scripts/build-modular-overlay.sh" \
    || { echo "!! modular overlay failed"; continue; }
  cp -a "$ROOT/out/rootfs-overlaid-modular.cpio.gz" "$ROOT/out/rootfs-overlaid-modular-$V.cpio.gz"

  echo "--- [$V] package boot img"
  VERSION="$V" RAMDISK="$ROOT/out/rootfs-overlaid-modular-$V.cpio.gz" \
    bash "$ROOT/scripts/build-boot.sh" || { echo "!! packaging failed"; continue; }

  echo "--- [$V] DONE  $(ls -l "$ROOT/out/boot-elden-$V.img" 2>/dev/null)"
done

echo
echo "### q24-rebuild-arms done $(date '+%F %T')"
ls -l "$ROOT"/out/boot-elden-vk9*.img 2>/dev/null
