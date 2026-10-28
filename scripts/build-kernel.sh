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
  # DSI 锚点用「或」：B5 重构（2026-10-27，patches/local/b5-resoc-20261027）把
  # msm_dsi_host_bonded_cmd_trigger 降成 file-static 的 dsi_bonded_cmd_trigger，
  # 并把对外面收成 msm_dsi_host_bonded_cmd_xfer ⇒ 只认旧名会把好内核判死。
  # 语义与旧版一致：普通符号仍是**子串**匹配（gcc_sm8750 实际符号是 gcc_sm8750_probe）；
  # 只有 DSI 那一条是「或」，用 ERE 且两侧锁到空白，避免误命中更长的名字。
  for sym in gcc_sm8750 'msm_dsi_host_bonded_cmd_trigger|msm_dsi_host_bonded_cmd_xfer|dsi_bonded_cmd_trigger' rpmh; do
    if ! grep -qF "$sym" "$SMP" && ! grep -qE "[[:space:]]($sym)\$" "$SMP"; then
      echo "ERROR: '$sym' MISSING in System.map -> .config lost ARCH_QCOM/DRM_MSM (olddefconfig?). This Image is DEAD (no QCOM drivers). Restore .config from $ROOT/patches/config-before-fragment-*.bak and rebuild." >&2
      exit 1
    fi
  done
  echo "[build] symbol guard OK: gcc_sm8750 / DSI bonded（旧名或 B5 重构后名） / rpmh present in System.map"
fi

command -v ccache >/dev/null 2>&1 && ccache -s 2>/dev/null | sed -n '1,6p' || true
