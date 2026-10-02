#!/bin/bash
# mesa-build.sh — 只构建 Waydroid vendor 需要的 Mesa/gralloc 模块（比 make vendorimage 快得多）
#
# 用法： bash mesa-build.sh
# 完成后自动调用 extract-mesa-libs.sh 抽库。
#
# 说明：
#   * 产品 lineage_waydroid_arm64_only，Mesa 走 meson（BOARD_MESA3D_USES_MESON_BUILD=true），
#     arm64 驱动表含 freedreno（见 device/waydroid/waydroid/waydroid_arm64_only/BoardConfig.mk）。
#   * 只 make 必要模块，避免整包 vendorimage（1~3 小时 → 通常十几分钟）。
set -eo pipefail

# 2026-10-02: AOSP 树已迁到 1T Samsung 盘（旧 /mnt/data、~/waydroid-build 均已不存在）
TREE="${TREE:-${AOSP_TREE:-/mnt/Samsung/waydroid-build}}"
# ~/bin holds repo + the aarch64 cross toolchain; repo is required by
# vendor/extra/waydroid-patches/apply-patches.sh (used for `repo info`).
export PATH="$HOME/bin:$PATH"
JOBS="${JOBS:-16}"
PRODUCT="${PRODUCT:-waydroid_arm64_only}"
CCACHE_DIR="${CCACHE_DIR:-/mnt/Samsung/ccache}"
export CCACHE_DIR USE_CCACHE=1
export CCACHE_EXEC="$(command -v ccache || true)"

log() { echo -e "\033[1;36m[build]\033[0m $*"; }

[ -d "$TREE" ] || { echo "❌ 树不存在: $TREE"; exit 1; }
[ -n "$CCACHE_EXEC" ] || log "⚠️ 没装 ccache，构建会慢一些"

mkdir -p "$CCACHE_DIR" 2>/dev/null || true
if [ -n "$CCACHE_EXEC" ]; then
  ccache -M 100G >/dev/null 2>&1 || true
  log "ccache: $(ccache -s 2>/dev/null | awk '/max cache size|Cache size/{print}' | tr '\n' ' ')"
fi

cd "$TREE"

# build/envsetup.sh is not `set -u` safe (references TOP / ZSH_VERSION unbound).
set +u
# shellcheck disable=SC1091
. build/envsetup.sh

# Waydroid 的补丁钩子（存在才调用）
if command -v apply-waydroid-patches >/dev/null 2>&1; then
  log "apply-waydroid-patches"
  # 补丁脚本对"已应用的补丁"会误报 Conflicts 并返回 1；这些 framework/hidl 补丁
  # 与本目标（Mesa/gralloc）无关，已在树内为一组提交，故非致命，继续构建。
  apply-waydroid-patches || log "⚠️ 补丁脚本返回非零（多为已应用导致的假冲突），继续"
fi

lunch "lineage_${PRODUCT}-userdebug" || lunch "${PRODUCT}-userdebug"

MODULES=(
  libgallium_dri
  libEGL_mesa
  libGLESv1_CM_mesa
  libGLESv2_mesa
  libGLES_mesa
  libgbm_mesa
  dri_gbm
  libgbm_mesa_wrapper
  gralloc.minigbm_gbm_mesa
  gralloc.gbm
  vulkan.freedreno
)

log "make -j$JOBS ${MODULES[*]}"
make -j"$JOBS" "${MODULES[@]}"

log "构建完成，抽库…"
bash "$(dirname "$0")/extract-mesa-libs.sh"
