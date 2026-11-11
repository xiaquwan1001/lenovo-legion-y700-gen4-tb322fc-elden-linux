#!/bin/bash
# build-phoc-arm64.sh — 产出「广告 wp_linux_drm_syncobj_manager_v1」的 aarch64 phoc（C12 L2）
#
# 背景：phoc（0.55.1 / 0.58 / 0.59.rc1 全树）都不调用
#   wlr_linux_drm_syncobj_manager_v1_create() ⇒ droidloom 的 presenter（硬绑定该全局）起不来。
#   补丁 = patches/phoc-syncobj-20261111/0001-desktop-advertise-linux-drm-syncobj-v1.patch
#
# **设备在版 = phoc 0.58.0 + phosh 0.59~alpha1**（2026-11-11 实测），所以本脚本按 Debian 打包方式
# 用 **内嵌 wlroots 静态**（`-Dembed-wlroots=enabled -Dwlroots:default_library=static`）构建：
#   · 0.58 的 desktop.c 用 wlroots 新 text-input API（`show_input_panel` 等），系统 libwlroots-0.20.2 没有
#     ⇒ 必须内嵌 **并且** 先套 Debian 的 `debian/patches/Apply-upstream-patches.patch`（给内嵌树加该 API）；
#   · 内嵌静态后 phoc 自包含（NEEDED 里没有 libwlroots），与设备在版二进制形态一致。
#
# 用法：sudo bash scripts/build-phoc-arm64.sh
# 产物：out/phoc-syncobj-arm64-<日期>/phoc-0.58.0-syncobj（替换设备 /usr/bin/phoc）
set -euo pipefail

CHROOT_DIR=${CHROOT_DIR:-/opt/elden/arm64-sid}
MIRROR=${MIRROR:-https://mirrors.ustc.edu.cn/debian}
POOL=$MIRROR/pool/main/p/phoc
VER=${VER:-0.58.0}
DEBVER=${DEBVER:-0.58.0-1}
SUITE=${SUITE:-sid}
REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
PATCH=$REPO/patches/phoc-syncobj-20261111/0001-desktop-advertise-linux-drm-syncobj-v1.patch
STAMP=$(date +%Y%m%d)
OUT=$REPO/out/phoc-syncobj-arm64-$STAMP
WORK=$REPO/build/phoc-src-$VER

say() { printf '\n=== %s\n' "$*"; }
[ "$(id -u)" = 0 ] || { echo "需要 root（chroot 构建）：sudo bash $0" >&2; exit 1; }
[ -f "$PATCH" ] || { echo "缺补丁：$PATCH" >&2; exit 1; }

say "1/6 取源码（校园网 USTC Debian pool；sid 只有 0.59~rc1 的 Sources 索引，故直接抓 pool 文件）"
mkdir -p "$WORK"; cd "$WORK"
for f in phoc_${DEBVER}.dsc phoc_${VER}.orig.tar.xz phoc_${DEBVER}.debian.tar.xz; do
  [ -s "$f" ] || curl -fsS -m 60 -O "$POOL/$f"
done
tar xf phoc_${VER}.orig.tar.xz
mkdir -p debian-x && tar xf phoc_${DEBVER}.debian.tar.xz -C debian-x

say "2/6 chroot（$CHROOT_DIR）依赖"
if [ ! -x "$CHROOT_DIR/bin/sh" ]; then
  debootstrap --arch=arm64 --variant=minbase --include=ca-certificates "$SUITE" "$CHROOT_DIR" "$MIRROR"
fi
chroot "$CHROOT_DIR" /bin/sh -c "
  set -e
  export DEBIAN_FRONTEND=noninteractive
  printf 'deb $MIRROR $SUITE main contrib non-free\n' > /etc/apt/sources.list
  apt-get update -qq
  apt-get install -y -qq --no-install-recommends \
    build-essential pkgconf meson ninja-build gettext ca-certificates \
    libglib2.0-dev libgles-dev libegl-dev libgbm-dev libdrm-dev \
    libgnome-desktop-3-dev gsettings-desktop-schemas-dev \
    libinput-dev libudev-dev libpixman-1-dev libwayland-dev wayland-protocols \
    libxkbcommon-dev libxcb1-dev libxcb-ewmh-dev libxcb-icccm4-dev \
    libxcb-xinput-dev libxcb-xfixes0-dev libxcb-render0-dev libxcb-shm0-dev \
    libxcb-composite0-dev libxcb-errors-dev libxcb-util-dev libxcb-image0-dev \
    libxcb-xkb-dev libxcb-present-dev libxcb-dri3-dev libxcb-randr0-dev \
    libjson-glib-dev libseat-dev libdisplay-info-dev libliftoff-dev libgtk-4-dev hwdata | tail -2
"

say "3/6 源码入 chroot + 打两层补丁（Debian upstream patches → 我们的 syncobj 补丁）"
D=$CHROOT_DIR/build-phoc-src58
mkdir -p "$D"
rsync -a --delete "$WORK/phoc-$VER/" "$D/phoc/"
# debian.tar.xz 的顶层目录是 `debian/`；两种解包形态都兼容（2026-11-11 实测：解到 debian-x/debian/）
if [ -d "$WORK/debian-x/debian" ]; then SRC_DEB="$WORK/debian-x/debian/"; else SRC_DEB="$WORK/debian-x/"; fi
rsync -a --delete "$SRC_DEB" "$D/debian/"
cp "$PATCH" "$D/0001-syncobj.patch"
# 额外补丁（可选）：patches/phoc-osk-versiongate-20261111/*.patch —— 让 enable 重新触发 OSK
# （2026-11-11：phoc advertise text-input v3 version 2 ⇒ 版本门把所有客户端都挡掉，PITFALLS #615）
EXTRA_DIR=${EXTRA_DIR:-$REPO/patches/phoc-osk-versiongate-20261111}
EXTRA_N=0
mkdir -p "$D/extra"; rm -f "$D/extra"/*.patch
if [ -d "$EXTRA_DIR" ]; then
  for p in "$EXTRA_DIR"/*.patch; do
    [ -e "$p" ] || continue
    EXTRA_N=$((EXTRA_N+1))
    cp "$p" "$D/extra/$(printf '%02d' "$EXTRA_N")-$(basename "$p")"
  done
fi
chroot "$CHROOT_DIR" /bin/sh -c "
  set -e
  cd /build-phoc-src58/phoc
  patch -p1 -l < ../debian/patches/Apply-upstream-patches.patch
  patch -p1 -l < ../0001-syncobj.patch
"
# 额外补丁按文件名顺序应用（上面已拷进 chroot 的 /build-phoc-src58/extra/）
for ep in "$CHROOT_DIR"/build-phoc-src58/extra/*.patch; do
  [ -e "$ep" ] || continue
  inner=/build-phoc-src58/extra/$(basename "$ep")
  say "3b/6 额外补丁 $(basename "$ep")"
  chroot "$CHROOT_DIR" /bin/sh -c "cd /build-phoc-src58/phoc && patch -p1 -l < $inner"
done


say "4/6 meson 配置（内嵌 wlroots 静态、gles2、无 vulkan/glslang 依赖）"
chroot "$CHROOT_DIR" /bin/sh -c "
  cd /build-phoc-src58/phoc
  meson setup --wipe /build-phoc-src58/build \
    -Dembed-wlroots=enabled -Dwlroots:default_library=static -Dwlroots:renderers=gles2 \
    -Dxwayland=disabled -Dtests=false | tail -5
"

say "5/6 编译（qemu-user，约 15–25 min）"
chroot "$CHROOT_DIR" /bin/sh -c 'cd /build-phoc-src58/build && ninja src/phoc | tail -2'

say "6/6 取产物 + 自校验（必须无 libwlroots 依赖）"
mkdir -p "$OUT"
TAG=${OUTTAG:-$([ "${EXTRA_N:-0}" -gt 0 ] && echo syncobj-osk || echo syncobj)}
install -m 0755 -o "${SUDO_USER:-root}" -g "${SUDO_USER:-root}" \
  "$CHROOT_DIR/build-phoc-src58/build/src/phoc" "$OUT/phoc-${VER}-${TAG}"
H=$(sha256sum "$OUT/phoc-${VER}-${TAG}" | cut -d' ' -f1)
NEEDED=$(readelf -d "$OUT/phoc-${VER}-${TAG}" | grep -c NEEDED)
WR=$(readelf -d "$OUT/phoc-${VER}-${TAG}" | grep -ci wlroots || true)
[ "$WR" = 0 ] || { echo "!! 产物仍依赖 libwlroots（$WR 处）⇒ 未静态内嵌" >&2; exit 1; }
echo "sha256 = $H（NEEDED=$NEEDED，wlroots 依赖=$WR）"
echo "$H  phoc-${VER}-${TAG}" >> "$OUT/SHA256SUM"
echo "DONE → $OUT/phoc-${VER}-${TAG}"
echo "上机：cp -a /usr/bin/phoc /usr/bin/phoc.orig && install -m0755 <件> /usr/bin/phoc && systemctl restart greetd"
