#!/bin/bash
# extract-mesa-libs.sh — 从 Waydroid AOSP 构建产物里抽出 Mesa/gralloc 动态库（方案 B 用）
#
# 用法：
#   bash extract-mesa-libs.sh                 # 默认产品 waydroid_arm64_only
#   PRODUCT=waydroid_arm64_only TREE=/mnt/Samsung/waydroid-build bash extract-mesa-libs.sh
#   OUTDIR=~/mesa-out bash extract-mesa-libs.sh
#
# 产出：
#   $OUTDIR/lib64/...                          # 按 vendor 层次排好的库
#   $OUTDIR/mesa-vendor-<版本>_<产品>.tar.gz    # 供 scp 到设备
#   $OUTDIR/manifest.txt                       # 每个文件的 sha256
set -uo pipefail

TREE="${TREE:-${AOSP_TREE:-/mnt/Samsung/waydroid-build}}"   # 2026-10-02 迁到 1T Samsung 盘
PRODUCT="${PRODUCT:-waydroid_arm64_only}"
JOBS="${JOBS:-16}"
OUTDIR="${OUTDIR:-$HOME/mesa-out}"
OUT="$TREE/out/target/product/$PRODUCT"
VENDOR_LIB="$OUT/vendor/lib64"

log()  { echo -e "\033[1;36m[extract]\033[0m $*"; }
warn() { echo -e "\033[1;33m[extract] ⚠️  $*\033[0m"; }
die()  { echo -e "\033[1;31m[extract] ❌ $*\033[0m" >&2; exit 1; }

# 与 device/waydroid 的 Android.mk 安装路径一一对应（LOCAL_VENDOR_MODULE=true）
FILES=(
  libgallium_dri.so
  libgbm_mesa.so
  dri_gbm.so
  libgbm_mesa_wrapper.so
  egl/libEGL_mesa.so
  egl/libGLESv1_CM_mesa.so
  egl/libGLESv2_mesa.so
  egl/libGLES_mesa.so
  hw/vulkan.freedreno.so
  hw/gralloc.minigbm_gbm_mesa.so
  hw/gralloc.gbm.so
)

[ -d "$TREE/external/mesa" ] || die "找不到 $TREE/external/mesa（树没同步完？）"

MESA_VER="$(cat "$TREE/external/mesa/VERSION" 2>/dev/null | tr -d '[:space:]')"
MESA_VER="${MESA_VER:-unknown}"

if [ ! -d "$VENDOR_LIB" ]; then
  warn "还没构建：$VENDOR_LIB 不存在"
  warn "先跑： bash $(dirname "$0")/mesa-build.sh"
  die "或确认 PRODUCT/TREE 是否正确"
fi

rm -rf "$OUTDIR"
mkdir -p "$OUTDIR/lib64"

miss=0
for f in "${FILES[@]}"; do
  src="$VENDOR_LIB/$f"
  if [ -e "$src" ]; then
    mkdir -p "$OUTDIR/lib64/$(dirname "$f")"
    cp -a "$src" "$OUTDIR/lib64/$f"
    log "✅ $f  ($(stat -c%s "$src") B)"
  else
    warn "缺失: $f（若本产品不构建该模块可忽略）"
    miss=$((miss + 1))
  fi
done
[ "$miss" -lt ${#FILES[@]} ] || die "一个都没抽到，构建产物路径可能不对"

# 记录版本，构建完可核对 Mesa 是否 26.1.8
echo "mesa_version=$MESA_VER" > "$OUTDIR/VERSION.txt"
echo "product=$PRODUCT"      >> "$OUTDIR/VERSION.txt"
echo "built_at=$(date -Is)"  >> "$OUTDIR/VERSION.txt"

# 校验：容器里那份 Mesa 26.0.8 的 A830 只有 KGSL chip-id；26.1 应含 DRM 的 0xffff44050000
if [ -e "$OUTDIR/lib64/libgallium_dri.so" ]; then
  if grep -qa $'\x00\x00\x05\x44\xff\xff\x00\x00' "$OUTDIR/lib64/libgallium_dri.so"; then
    log "✅ 关键修复已确认：libgallium_dri.so 含 chip_id 0xffff44050000（DRM / Adreno 830）"
  else
    warn "⚠️ 在 libgallium_dri.so 里没找到 0xffff44050000，确认 Mesa 版本 ≥26.1"
  fi
fi

( cd "$OUTDIR" && find lib64 -type f -exec sha256sum {} \; > manifest.txt )

TARBALL="$OUTDIR/mesa-vendor-${MESA_VER}_${PRODUCT}.tar.gz"
tar czf "$TARBALL" -C "$OUTDIR" lib64 VERSION.txt manifest.txt
log "打包完成: $TARBALL ($(du -h "$TARBALL" | cut -f1))"
log "下一步： bash $(dirname "$0")/mesa-deploy.sh"
