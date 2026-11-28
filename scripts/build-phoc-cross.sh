#!/bin/bash
# build-phoc-cross.sh — 交叉编 phoc（0.46 设备版或上游 main）到 Debian-13 arm64，**不需要 root/chroot**
#
# 前置（一次性，需 root）：
#   sudo bash scripts/sysroot-add-debs.sh <phoc 依赖包...>   # 或直接复用已有 out/sysroot-trixie-arm64
#   sudo rsync -a /opt/elden/arm64-trixie/usr/{bin,lib/aarch64-linux-gnu,include,share} out/sysroot-trixie-arm64/usr/
#
# 用法：
#   bash scripts/build-phoc-cross.sh [源码树] [构建目录名]
#     默认源码树 = build/phoc046-edge-swipe（设备在版 0.46 + edge-swipe 补丁）
#     产物 → out/phoc-cross-<date>/{phoc,meta.txt}
# 判据：NEEDED 必须含 libwlroots-0.18.so；max GLIBC ≤ 2.41；与 chroot 版对照 NEEDED 一致。
set -euo pipefail

REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SYSROOT=${SYSROOT:-$REPO/out/sysroot-trixie-arm64}
SRC=${1:-$REPO/build/phoc046-edge-swipe}
BUILDDIR=${2:-build-cross}
OUT=${OUT:-$REPO/out/phoc-cross-$(date +%Y%m%d)}
REF=${REF:-$REPO/out/phoc-046-edge-swipe-arm64-20261128/phoc}

[ -d "$SYSROOT/usr/lib/aarch64-linux-gnu" ] || { echo "缺 sysroot：$SYSROOT" >&2; exit 1; }
[ -d "$SRC" ] || { echo "缺源码树：$SRC" >&2; exit 1; }
mkdir -p "$OUT"

export ELDEN_AARCH64_SYSROOT="$SYSROOT"
export PKG_CONFIG_ALLOW_CROSS=1
export PKG_CONFIG_LIBDIR="$SYSROOT/usr/lib/aarch64-linux-gnu/pkgconfig:$SYSROOT/usr/share/pkgconfig"
export PKG_CONFIG_SYSROOT_DIR="$SYSROOT"   # 让 .pc 里的 /usr 前缀落进 sysroot（构建工具也跟着走 sysroot/usr/bin）

cd "$SRC"
if [ ! -d "$BUILDDIR" ]; then
  echo "=== meson setup ($BUILDDIR)"
  meson setup "$BUILDDIR" --cross-file "$REPO/rootfs/cross-aarch64-phoc.ini" \
    --buildtype=release -Dembed-wlroots=disabled -Dxwayland=enabled -Dtests=false -Dgtk_doc=false
fi
echo "=== ninja"
ninja -C "$BUILDDIR" src/phoc

cp "$BUILDDIR/src/phoc" "$OUT/phoc"
{
  echo "src=$SRC"; echo "builddir=$BUILDDIR"; echo "built_at=$(date -Is)"
  echo "sha256=$(sha256sum "$OUT/phoc" | awk '{print $1}')"
  echo "size=$(stat -c%s "$OUT/phoc")"
  echo "--- NEEDED:"; objdump -p "$OUT/phoc" | awk '/NEEDED/{print $2}' | sort | tr '\n' ' '; echo
  echo "--- max GLIBC: $(objdump -T "$OUT/phoc" | grep -o 'GLIBC_[0-9.]*' | sort -Vu | tail -1)"
} > "$OUT/meta.txt"
cat "$OUT/meta.txt"

fail=0
objdump -p "$OUT/phoc" | awk '/NEEDED/{print $2}' | grep -qx libwlroots-0.18.so || { echo "FAIL: 未链接 libwlroots-0.18.so" >&2; fail=1; }
g=$(objdump -T "$OUT/phoc" | grep -o 'GLIBC_[0-9.]*' | sort -Vu | tail -1)
case "$g" in GLIBC_2.4[1-9]*) echo "FAIL: glibc $g > 设备 2.41" >&2; fail=1;; esac
if [ -f "$REF" ]; then
  if diff <(objdump -p "$OUT/phoc" | awk '/NEEDED/{print $2}' | sort) \
          <(objdump -p "$REF" | awk '/NEEDED/{print $2}' | sort) >/dev/null; then
    echo "OK: NEEDED 与 chroot 版（$REF）一致"
  else
    echo "WARN: NEEDED 与 chroot 版不同（逐项 diff 见上）" >&2
  fi
fi
[ $fail -eq 0 ] && echo "PASS → $OUT" || exit 1
