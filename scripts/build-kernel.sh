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
grep -q '^CONFIG_ARCH_QCOM=y' "$ROOT/linux/.config" || {
	echo "ERROR: CONFIG_ARCH_QCOM missing in .config (corrupted by olddefconfig?)" >&2
	exit 1
}

TARGETS=("${@:-Image.gz dtbs}")
[ $# -eq 0 ] && TARGETS=(Image.gz dtbs)

echo "[build] CROSS_COMPILE=$CROSS_COMPILE"
echo "[build] targets: ${TARGETS[*]}"
kbuild "${TARGETS[@]}"

ls -la "$ROOT/linux/arch/arm64/boot/Image.gz" \
       "$ROOT/linux/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb" 2>/dev/null || true
command -v ccache >/dev/null 2>&1 && ccache -s 2>/dev/null | sed -n '1,6p' || true
