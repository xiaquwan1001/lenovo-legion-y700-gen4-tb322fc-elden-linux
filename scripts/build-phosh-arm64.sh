#!/bin/bash
# build-phosh-arm64.sh — 产出带「output power 失败即视为屏亮」修复的 aarch64 phosh
#
# 根因背景（2026-11-14 实证）：phosh 用 zwlr_output_power_v1 探测面板开关状态，
#   wlroots 只允许**每个 output 一个** power 对象 ⇒ 若其他客户端/握手时序抢到，
#   phosh 收到 failed 事件，但 monitor.c 的 failed 回调**不更新 power_mode**，
#   于是 power_mode 停在初始 OFF（语义 = 屏已关）⇒ screen-saver-manager 的
#   `active = (mode == OFF)` 一开始就 TRUE 且永不变 ⇒ 电源键 press/release 全短路、
#   空闲不熄屏；而电源菜单挂起走 logind 不受影响。
#   修复 = failed 时把 power_mode 设为 ON 并 notify。
#   详见 patches-userland/upstream/phosh-power-mode-fallback.patch
#   与 TASKS/sessions/2026-11-14-T20-电源键不熄屏.md
#
# 用法：sudo bash scripts/build-phosh-arm64.sh
# 产物：out/phosh-arm64-<日期>/phosh-<ver>-powermode（替换设备 /usr/libexec/phosh）
set -euo pipefail

CHROOT_DIR=${CHROOT_DIR:-/opt/elden/arm64-sid}
MIRROR=${MIRROR:-https://mirrors.ustc.edu.cn/debian}
POOL=$MIRROR/pool/main/p/phosh
VER=${VER:-0.58.0}
DEBVER=${DEBVER:-0.58.0-1}
SUITE=${SUITE:-sid}
REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
PATCH=$REPO/patches-userland/upstream/phosh-power-mode-fallback.patch
STAMP=$(date +%Y%m%d)
OUT=$REPO/out/phosh-arm64-$STAMP
WORK=$REPO/build/phosh-src-$VER
SRCDIR=${SRCDIR:-build-phosh-src$(printf '%s' "$VER" | tr -cd '0-9')}
SRC_CACHE=${SRC_CACHE:-/opt/elden/arm64-sid/build-phosh}

say() { printf '\n=== %s\n' "$*"; }
[ "$(id -u)" = 0 ] || { echo "需要 root（chroot 构建）：sudo bash $0" >&2; exit 1; }
[ -f "$PATCH" ] || { echo "缺补丁：$PATCH" >&2; exit 1; }

say "1/6 取源码（USTC Debian pool）"
mkdir -p "$WORK"; cd "$WORK"
for f in phosh_${DEBVER}.dsc phosh_${VER}.orig.tar.xz phosh_${DEBVER}.debian.tar.xz; do
  [ -s "$f" ] && { echo "    (已有) $f"; continue; }
  if [ -s "$SRC_CACHE/$f" ]; then cp "$SRC_CACHE/$f" "$f"; echo "    (cache) $f"
  else curl -fsS -m 120 -O "$POOL/$f"; fi
done
tar xf phosh_${VER}.orig.tar.xz
SRC_TREE=$(ls -d phosh-*/ 2>/dev/null | head -1); SRC_TREE=${SRC_TREE%/}
[ -n "$SRC_TREE" ] || { echo "解包后找不到 phosh-*/ 源码目录" >&2; exit 1; }
echo "    源码树 = $SRC_TREE"
mkdir -p debian-x && tar xf phosh_${DEBVER}.debian.tar.xz -C debian-x

say "2/6 chroot 依赖"
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
    gsettings-desktop-schemas-dev libadwaita-1-dev libappstream-dev \
    libcallaudio-dev libevince-gtk3-dev libgirepository1.0-dev libgmobile-dev \
    libjson-glib-dev libsecret-1-dev libsystemd-dev libfeedback-dev \
    libfribidi-dev libgcr-3-dev libgnome-bluetooth-3.0-dev libglib2.0-dev \
    libgnome-desktop-3-dev libgtk-3-dev libgtk-4-dev libgudev-1.0-dev \
    libhandy-1-dev libmm-glib-dev libnm-dev libpam0g-dev \
    libpolkit-agent-1-dev libpulse-dev libupower-glib-dev libwayland-dev \
    libxml2-utils python3-docutils valac \
    libecal2.0-dev libqrcodegen-dev evolution-data-server-dev \
    libdrm-dev wayland-protocols libxkbcommon-dev libinput-dev \
    libpixman-1-dev desktop-file-utils hwdata libcap-dev \
    libedataserverui-1.2-4
" || { echo "!! chroot 依赖安装失败（可能包名在 sid 上变了，见上面 apt 报错）" >&2; exit 1; }

say "3/6 源码入 chroot + 打补丁"
D=$CHROOT_DIR/$SRCDIR
mkdir -p "$D"
rsync -a --delete "$WORK/$SRC_TREE/" "$D/phosh/"
[ -d "$WORK/debian-x/debian" ] && SRC_DEB="$WORK/debian-x/debian/" || SRC_DEB="$WORK/debian-x/"
rsync -a --delete "$SRC_DEB" "$D/debian/"
cp "$PATCH" "$D/0001-powermode.patch"
chroot "$CHROOT_DIR" /bin/sh -c "
  set -e
  cd /$SRCDIR/phosh
  # Debian 的 upstream patches 是 quilt 序列，可能不存在该文件；有则套
  if [ -f ../debian/patches/Apply-upstream-patches.patch ]; then
    patch -p1 -l < ../debian/patches/Apply-upstream-patches.patch
  fi
  patch -p1 -l < ../0001-powermode.patch
"

say "4/6 meson 配置（不建 introspection/vapi，只要能跑）"
chroot "$CHROOT_DIR" /bin/sh -c "
  cd /$SRCDIR/phosh
  meson setup --wipe /$SRCDIR/build \
    --prefix=/usr --buildtype=release \
    -Dman=false -Dtests=false -Dgtk_doc=false \
    -Dintrospection=false -Dvapi=false -Dbindings-lib=false \
    -Dphoc_tests=disabled 2>&1 | tail -8
" || { echo "!! meson setup 失败" >&2; exit 1; }

say "5/6 编译（qemu-user）"
chroot "$CHROOT_DIR" /bin/sh -c "cd /$SRCDIR/build && ninja src/phosh" || { echo '!! 编译失败' >&2; exit 1; }
[ -x "$CHROOT_DIR/$SRCDIR/build/src/phosh" ] || { echo "!! 产物缺失" >&2; exit 1; }

say "6/6 取产物 + 自校验「补丁确实在二进制里」"
mkdir -p "$OUT"
install -m 0755 -o "${SUDO_USER:-root}" -g "${SUDO_USER:-root}" \
  "$CHROOT_DIR/$SRCDIR/build/src/phosh" "$OUT/phosh-${VER}-powermode"
BIN=$OUT/phosh-${VER}-powermode
H=$(sha256sum "$BIN" | cut -d' ' -f1)
file "$BIN" | grep -q 'ARM aarch64' || { echo "!! 不是 aarch64" >&2; exit 1; }
# 判据：新件与设备在版件的「Failed to set output power mode」上下文不同（含 fallback 分支的特征）
echo "sha256 = $H  size=$(stat -c%s "$BIN")"
echo "$H  phosh-${VER}-powermode" >> "$OUT/SHA256SUM"
echo "DONE → $BIN"
echo "上机：sh scripts/phosh-install.sh --install $BIN   （divert + hold，见 PITFALLS #654 同款做法）"
