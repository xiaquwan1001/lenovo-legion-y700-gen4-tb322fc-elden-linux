#!/bin/bash
# build-phosh-upstream-fix.sh — 用「上游 main 源树 + 本地补丁」编 aarch64 phosh（验证上游补丁用）
#
# 与 build-phosh-arm64.sh 的区别：不下载 Debian 源包、不套 Debian quilt（上游树自带 subprojects），
# 直接把 $SRC 目录 rsync 进 chroot 编译。用于把 patches-userland/upstream/*.patch 做成可上机验证的件。
#
# 用法：sudo bash scripts/build-phosh-upstream-fix.sh [源树目录]
#   默认源树 = /tmp/phosh-up（`git clone https://gitlab.gnome.org/World/Phosh/phosh.git`）
# 产物：out/phosh-upstream-<日期>/phosh-<version>-<tag>
set -euo pipefail

CHROOT_DIR=${CHROOT_DIR:-/opt/elden/arm64-sid}
SRC=${1:-/tmp/phosh-up}
REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
STAMP=$(date +%Y%m%d)
TAG=${TAG:-outputpower}
VER=$(sed -n "s/^  version: '\(.*\)',/\1/p" "$SRC/meson.build" | head -1)
[ -n "$VER" ] || { echo "读不到 $SRC/meson.build 的 version" >&2; exit 1; }
OUT=$REPO/out/phosh-upstream-$STAMP
D=$CHROOT_DIR/build-phosh-upstream
say() { printf '\n=== %s\n' "$*"; }
[ "$(id -u)" = 0 ] || { echo "需要 root（chroot 构建）" >&2; exit 1; }
[ -f "$SRC/meson.build" ] || { echo "$SRC 不像 phosh 源树" >&2; exit 1; }

say "1/4 同步源树到 chroot（$SRC → $D；subprojects 从本地 Debian 源树补，chroot 无网）"
mkdir -p "$D"
rsync -a --delete --exclude .git "$SRC/" "$D/phosh/"
# 缺的 subprojects（libcall-ui/gvc 等）从已解包的 Debian 源树拷进来
SUBSRC=$(ls -d "$CHROOT_DIR"/build-phosh-src*/phosh 2>/dev/null | head -1)
if [ -n "$SUBSRC" ]; then
  for d in "$SUBSRC"/subprojects/*/; do
    b=$(basename "$d")
    [ -e "$D/phosh/subprojects/$b" ] || { echo "    补 subproject: $b"; cp -a "$d" "$D/phosh/subprojects/"; }
  done
fi

say "2/4 chroot 依赖（与 build-phosh-arm64.sh 同一组）"
if [ ! -x "$CHROOT_DIR/bin/sh" ]; then
  echo "缺 chroot：先跑 scripts/build-phosh-arm64.sh 一次" >&2; exit 1
fi
chroot "$CHROOT_DIR" /bin/sh -c "
  export DEBIAN_FRONTEND=noninteractive
  apt-get install -y -qq --no-install-recommends \
    build-essential pkgconf meson ninja-build gettext ca-certificates \
    gsettings-desktop-schemas-dev libadwaita-1-dev libappstream-dev \
    libcallaudio-dev libevince-gtk3-dev libgirepository1.0-dev libgmobile-dev \
    libjson-glib-dev libsecret-1-dev libsystemd-dev libfeedback-dev \
    libfribidi-dev libgcr-3-dev libgnome-bluetooth-3.0-dev libglib2.0-dev \
    libgnome-desktop-3-dev libgtk-3-dev libgtk-4-dev libgudev-1.0-dev \
    libhandy-1-dev libmm-glib-dev libnm-dev libpam0g-dev \
    libpolkit-agent-1-dev libpulse-dev libupower-glib-dev libwayland-dev \
    libxml2-utils python3-docutils valac libecal2.0-dev libqrcodegen-dev \
    evolution-data-server-dev libdrm-dev wayland-protocols libxkbcommon-dev \
    libinput-dev libpixman-1-dev desktop-file-utils hwdata libcap-dev \
    libedataserverui-1.2-4 libdconf-dev libpipewire-0.3-dev > /tmp/deps.log 2>&1 || { tail -5 /tmp/deps.log; exit 1; }
"

say "3/4 meson + ninja"
chroot "$CHROOT_DIR" /bin/sh -c "
  cd $D/phosh
  rm -rf $D/build
  meson setup $D/build --prefix=/usr --buildtype=release \
    -Dman=false -Dtests=false -Dgtk_doc=false -Dintrospection=false \
    -Dvapi=false -Dbindings-lib=false -Dphoc_tests=disabled > /tmp/meson-up.log 2>&1 \
    || { tail -20 /tmp/meson-up.log; exit 1; }
  ninja -C $D/build -j8 src/phosh > /tmp/ninja-up.log 2>&1 || { tail -20 /tmp/ninja-up.log; exit 1; }
"
[ -x "$CHROOT_DIR/$D/build/src/phosh" ] || { echo "!! 产物缺失" >&2; exit 1; }

say "4/4 取产物"
mkdir -p "$OUT"
BIN=$OUT/phosh-$VER-$TAG
install -m 0755 -o "${SUDO_USER:-root}" -g "${SUDO_USER:-root}" "$CHROOT_DIR/$D/build/src/phosh" "$BIN"
file "$BIN" | grep -q 'ARM aarch64' || { echo "!! 不是 aarch64" >&2; exit 1; }
H=$(sha256sum "$BIN" | cut -d' ' -f1)
echo "sha256 = $H  size=$(stat -c%s "$BIN")  version=$VER"
echo "$H  $(basename "$BIN")" >> "$OUT/SHA256SUM"
echo "DONE → $BIN"
echo "上机：sh scripts/phosh-install.sh --install $BIN"
