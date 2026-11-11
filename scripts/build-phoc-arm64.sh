#!/bin/bash
# build-phoc-arm64.sh — 在主机上产出「广告 wp_linux_drm_syncobj_manager_v1」的 aarch64 phoc（C12 L2）
#
# 背景：phoc 0.55.1 / 0.58 / 0.59.rc1 全树都不调用
#   wlr_linux_drm_syncobj_manager_v1_create() ⇒ droidloom 的 presenter（硬绑定该全局）起不来。
#   补丁 = patches/phoc-syncobj-20261111/0001-desktop-advertise-linux-drm-syncobj-v1.patch
#
# 本机（x86_64）用 arm64 Debian sid chroot（qemu-user binfmt，编译在本机跑）构建，
# 目标是 **对系统 libwlroots-0.20.2** 编（与设备 Debian sid 同版），不内嵌 wlroots。
#
# 用法：sudo bash scripts/build-phoc-arm64.sh [--regen-chroot]
# 产物：out/phoc-syncobj-arm64-<日期>/phoc（ELF aarch64，替换设备 /usr/bin/phoc）
#
# 判据（主机侧已实测，见 reports/droidloom-l2-phoc-syncobj-20261111.md）：
#   WAYLAND_DISPLAY=<patched phoc> wayland-info | grep syncobj  → 有 wp_linux_drm_syncobj_manager_v1 v1
set -euo pipefail

CHROOT_DIR=${CHROOT_DIR:-/opt/elden/arm64-sid}
MIRROR=${MIRROR:-https://mirrors.ustc.edu.cn/debian}
SUITE=${SUITE:-sid}
REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SRC=$REPO/external/phoc-work/phoc
PATCH=$REPO/patches/phoc-syncobj-20261111/0001-desktop-advertise-linux-drm-syncobj-v1.patch
STAMP=$(date +%Y%m%d)
OUT=$REPO/out/phoc-syncobj-arm64-$STAMP

say() { printf '\n=== %s\n' "$*"; }
[ "$(id -u)" = 0 ] || { echo "需要 root（chroot 构建）：sudo bash $0" >&2; exit 1; }
[ -f "$PATCH" ] || { echo "缺补丁：$PATCH" >&2; exit 1; }

say "1/5 chroot（$CHROOT_DIR）"
if [ ! -x "$CHROOT_DIR/bin/sh" ] || [ "${1:-}" = "--regen-chroot" ]; then
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
    libjson-glib-dev libseat-dev libdisplay-info-dev libliftoff-dev \
    libgtk-4-dev libwlroots-0.20-dev hwdata | tail -2
"

say "2/5 源码入 chroot（补丁已含在 external/phoc-work/phoc 工作区；这里用干净副本+打补丁）"
mkdir -p "$CHROOT_DIR/build-phoc"
rsync -a --delete --exclude build --exclude .git --exclude subprojects/wlroots "$SRC/" "$CHROOT_DIR/build-phoc/phoc/"
cp "$PATCH" "$CHROOT_DIR/build-phoc/phoc/0001-syncobj.patch"
chroot "$CHROOT_DIR" /bin/sh -c 'cd /build-phoc/phoc && patch -p1 -s < 0001-syncobj.patch'

say "3/5 meson 配置（系统 wlroots-0.20.2，与设备同版）"
chroot "$CHROOT_DIR" /bin/sh -c '
  cd /build-phoc/phoc
  meson setup --wipe /build-phoc/build -Dembed-wlroots=disabled -Dxwayland=disabled -Dtests=false | tail -6
'

say "4/5 编译（qemu-user，约 10–20 min）"
chroot "$CHROOT_DIR" /bin/sh -c 'cd /build-phoc/build && ninja src/phoc | tail -3'

say "5/5 取产物"
mkdir -p "$OUT"
cp "$CHROOT_DIR/build-phoc/build/src/phoc" "$OUT/phoc"
chown -R "$(logname 2>/dev/null || echo root)" "$OUT" 2>/dev/null || true
( cd "$OUT" && sha256sum phoc > SHA256SUM && file phoc >> SHA256SUM )
cat "$OUT/SHA256SUM"
echo "DONE → $OUT/phoc"
echo "上机判据（待设备）：wayland-info | grep wp_linux_drm_syncobj_manager_v1；"
echo "  回退：dpkg -i /var/cache/apt/archives/phoc_*.deb 或还原备份的 /usr/bin/phoc"
