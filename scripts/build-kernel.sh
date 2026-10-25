#!/bin/bash
# build-kernel.sh — rebuild kernel/DTB for TB322FC (elden), with ccache.
#
# usage:
#   scripts/build-kernel.sh                 # Image.gz + dtbs  (default)
#   scripts/build-kernel.sh Image.gz        # kernel only (skip DT)
#   scripts/build-kernel.sh dtbs            # DTB only (seconds)
#   scripts/build-kernel.sh modules         # build all =m modules
#   TARGETS="Image.gz dtbs" scripts/build-kernel.sh
#
# Env: JOBS=<n> (default nproc), CCACHE_DIR, CCACHE_MAXSIZE.
set -euo pipefail
ROOT=${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
. "$ROOT/scripts/env-build.sh"

# Guard: olddefconfig can silently drop CONFIG_ARCH_QCOM and brick the image.
grep -q '^CONFIG_ARCH_QCOM=y' "$KDIR/.config" || {
	echo "ERROR: CONFIG_ARCH_QCOM missing in .config (corrupted by olddefconfig?)" >&2
	exit 1
}

TARGETS=("${@:-Image.gz dtbs}")
[ $# -eq 0 ] && TARGETS=(Image.gz dtbs)

echo "[build] CROSS_COMPILE=$CROSS_COMPILE"
echo "[build] targets: ${TARGETS[*]}"
kbuild "${TARGETS[@]}"

ls -la "$KDIR/arch/arm64/boot/Image.gz" \
       "$KDIR/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb" 2>/dev/null || true

# Post-build symbol guard (FAILURE 2026-10-10): a config stripped of ARCH_QCOM
# builds fine but yields a kernel with ZERO qcom platform symbols -> dead image
# (vk81/82/83). Assert the platform actually linked in before shipping.
SMP="$KDIR/System.map"
if [ -f "$SMP" ]; then
  for sym in gcc_sm8750 msm_dsi_host_bonded_cmd_trigger rpmh; do
    if ! grep -q "$sym" "$SMP"; then
      echo "ERROR: '$sym' MISSING in System.map -> .config lost ARCH_QCOM/DRM_MSM (olddefconfig?). This Image is DEAD (no QCOM drivers). Restore .config from $ROOT/patches/config-before-fragment-*.bak and rebuild." >&2
      exit 1
    fi
  done
  echo "[build] symbol guard OK: gcc_sm8750 / msm_dsi_host_bonded_cmd_trigger / rpmh present in System.map"
fi

command -v ccache >/dev/null 2>&1 && ccache -s 2>/dev/null | sed -n '1,6p' || true
