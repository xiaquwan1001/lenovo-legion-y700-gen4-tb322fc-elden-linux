#!/bin/bash
# build-phoc046-trixie.sh — 在 Debian trixie arm64 chroot 里编「设备在版 phoc 0.46 + edge-swipe 补丁」
#
# 目标：产一个与设备 ABI 一致的 arm64 件（动态链接系统 libwlroots-0.18.so、glibc 2.41）。
# 用法（需 root）：sudo bash scripts/build-phoc046-trixie.sh
# 产物：out/phoc-046-edge-swipe-arm64-<日期>/{phoc, build.log, meta.txt}
set -euo pipefail

REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SRC=${SRC:-$REPO/build/phoc046-edge-swipe}
CH=${CH:-/opt/elden/arm64-trixie}
DEST=$CH/build-phoc046-edge-swipe
STAMP=$(date +%Y%m%d)
OUT=${OUT:-$REPO/out/phoc-046-edge-swipe-arm64-$STAMP}

[ "$(id -u)" = 0 ] || { echo "需要 root：sudo bash $0" >&2; exit 1; }
[ -d "$SRC" ] || { echo "缺源码树：$SRC" >&2; exit 1; }
[ -x "$CH/bin/sh" ] || { echo "缺 chroot：$CH（先 debootstrap trixie arm64）" >&2; exit 1; }

mkdir -p "$OUT"

echo "=== 1/5 mirrors + deb-src（幂等）"
cat > "$CH/etc/apt/sources.list" <<'EOL'
deb https://mirrors.ustc.edu.cn/debian trixie main
deb https://mirrors.ustc.edu.cn/debian trixie-updates main
deb https://mirrors.ustc.edu.cn/debian-security trixie-security main
EOL

echo "=== 2/5 安装 phoc 构建依赖（trixie 版本，动态 wlroots 0.18）"
chroot "$CH" /bin/sh -c "export DEBIAN_FRONTEND=noninteractive; \
  apt-get update -qq && \
  apt-get install -y --no-install-recommends \
    build-essential pkg-config meson ninja-build \
    libglib2.0-dev libgles2-mesa-dev libgnome-desktop-3-dev gsettings-desktop-schemas \
    libinput-dev libudev-dev libdrm-dev libpixman-1-dev libwayland-dev wayland-protocols \
    libxkbcommon-dev libcairo2-dev liblcms2-dev libgudev-1.0-dev libjson-glib-dev \
    libwlroots-0.18-dev libgmobile-dev gobject-introspection libgirepository1.0-dev gettext libxcb1-dev" \
  2>&1 | tee "$OUT/apt.log" | tail -12

echo "=== 3/5 同步源码到 chroot"
rm -rf "$DEST"; mkdir -p "$DEST"
tar -C "$SRC" --exclude=./build-host --exclude=./.git -cf - . | tar -C "$DEST" -xf -

echo "=== 4/5 meson setup + ninja（release，链接系统 libwlroots-0.18）"
chroot "$CH" /bin/sh -c "cd /build-phoc046-edge-swipe && \
  meson setup build --buildtype=release -Dembed-wlroots=disabled -Dxwayland=enabled -Dtests=false \
    -Dgtk_doc=false" 2>&1 | tee "$OUT/build.log" | tail -25
chroot "$CH" /bin/sh -c "cd /build-phoc046-edge-swipe && ninja -C build src/phoc" \
  2>&1 | tee -a "$OUT/build.log" | tail -15

echo "=== 5/5 取产物 + 兼容性判据"
cp "$DEST/build/src/phoc" "$OUT/phoc"
{
  echo "src=$SRC"; echo "chroot=$CH"; echo "built_at=$(date -Is)"
  echo "patch=$(sha256sum "$REPO/patches/phoc-046-edge-swipe-20261128/0001-cursor-Add-an-edge-swipe-back-gesture.patch" | awk '{print $1}')"
  echo "sha256=$(sha256sum "$OUT/phoc" | awk '{print $1}')"
  file "$OUT/phoc"
  echo "--- NEEDED:"; objdump -p "$OUT/phoc" | awk '/NEEDED/{print $2}' | sort | tr '\n' ' '; echo
  echo "--- max GLIBC: $(objdump -T "$OUT/phoc" | grep -o 'GLIBC_[0-9.]*' | sort -Vu | tail -1)"
} > "$OUT/meta.txt" 2>&1
cat "$OUT/meta.txt"
echo "OK → $OUT"
