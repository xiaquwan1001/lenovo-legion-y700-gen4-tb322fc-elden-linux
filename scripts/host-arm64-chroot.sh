#!/bin/bash
# host-arm64-chroot.sh — 在主机上建一个 **arm64 Debian(sid) 构建 chroot**，并可选在里面编 sensord
#
# 为什么需要（两个目的，同一份成本）：
#   1. `waydroid-sensord(-udp)` 是**动态 musl** 二进制，换 glibc 发行版必须重编，
#      而仓库里只有设备侧 `make`（`patches-userland/waydroid-sensord-udp/Makefile`），
#      没有「不依赖设备」的构建路径 ⇒ 本脚本给出这条路径。
#   2. 这个 chroot 就是 Mobian 迁移的 **S1（arm64 rootfs 构建）** 同一件东西，
#      `debootstrap` 起来之后 S2–S5 都能在里面离线做。
#
# 前置：需要 root（本机 AppArmor 限制非特权 userns：`kernel.apparmor_restrict_unprivileged_userns=1`
#       ⇒ `unshare -r chroot` 不可用，`mmdebstrap --mode=unshare` 也不行）。
#       用法：`sudo bash scripts/host-arm64-chroot.sh [--build-sensord]`
#
# 产物：$CHROOT_DIR（默认 /opt/elden/arm64-sid）、out/sensord-host/（--build-sensord 时）
set -euo pipefail

CHROOT_DIR=${CHROOT_DIR:-/opt/elden/arm64-sid}
SUITE=${SUITE:-sid}
MIRROR=${MIRROR:-https://mirrors.ustc.edu.cn/debian}
REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
DO_SENSORD=0
for a in "$@"; do [ "$a" = "--build-sensord" ] && DO_SENSORD=1; done

[ "$(id -u)" = 0 ] || { echo "需要 root（本机限制非特权 userns）：sudo bash $0" >&2; exit 1; }

say() { printf '\n=== %s\n' "$*"; }

say "0/5 依赖：debootstrap / qemu-user-static（binfmt 已注册：$(ls /proc/sys/fs/binfmt_misc 2>/dev/null | grep -c qemu-aarch64)）"
if ! command -v debootstrap >/dev/null; then
	apt-get update -qq
	DEBIAN_FRONTEND=noninteractive apt-get install -y -qq debootstrap
fi
command -v debootstrap >/dev/null || { echo "debootstrap 安装失败" >&2; exit 1; }
# arm64 二进制要靠 binfmt 才能在 x86 主机上执行（本机已注册；缺则装 qemu-user-static）
if [ ! -e /proc/sys/fs/binfmt_misc/qemu-aarch64 ]; then
	DEBIAN_FRONTEND=noninteractive apt-get install -y -qq qemu-user-static
fi

say "1/5 debootstrap $SUITE arm64 → $CHROOT_DIR（minbase，可重入）"
if [ ! -x "$CHROOT_DIR/bin/sh" ]; then
	debootstrap --arch=arm64 --variant=minbase --include=ca-certificates \
		"$SUITE" "$CHROOT_DIR" "$MIRROR"
else
	echo "已存在，跳过 debootstrap"
fi

say "2/5 基础构建工具 + gbinder/glibutil 开发包"
chroot "$CHROOT_DIR" /bin/sh -c "
	set -e
	export DEBIAN_FRONTEND=noninteractive
	printf 'deb $MIRROR $SUITE main contrib non-free\n' > /etc/apt/sources.list
	apt-get update -qq
	apt-get install -y -qq --no-install-recommends \
		build-essential pkgconf make g++ git ca-certificates \
		libgbinder-dev libglibutil-dev libglib2.0-dev 2>&1 | tail -5
"

say "3/5 自检：chroot 内 arch / 编译器 / gbinder 头文件"
chroot "$CHROOT_DIR" /bin/sh -c 'dpkg --print-architecture; g++ --version | head -1; pkg-config --modversion glib-2.0 gbinder-1.0 glibutil 2>/dev/null || true; ls /usr/include/gbinder/gbinder.h'

if [ "$DO_SENSORD" = 1 ]; then
	say "4/5 构建 waydroid-sensord-udp（仓库源 → chroot 内 make）"
	rm -rf "$CHROOT_DIR/root/sensord-build"
	mkdir -p "$CHROOT_DIR/root/sensord-build"
	cp -a "$REPO/patches-userland/waydroid-sensord-udp/." "$CHROOT_DIR/root/sensord-build/"
	chroot "$CHROOT_DIR" /bin/sh -c 'cd /root/sensord-build && make clean >/dev/null 2>&1; make 2>&1 | tail -8; ls -l waydroid-sensord-udp; file waydroid-sensord-udp; sha256sum waydroid-sensord-udp'
	mkdir -p "$REPO/out/sensord-host"
	cp "$CHROOT_DIR/root/sensord-build/waydroid-sensord-udp" "$REPO/out/sensord-host/waydroid-sensord-udp"
	cp "$CHROOT_DIR/root/sensord-build/waydroid-sensord-udp" "$REPO/out/sensord-host/waydroid-sensord"
	( cd "$REPO/out/sensord-host" && sha256sum waydroid-sensord* > SHA256SUMS && cat SHA256SUMS )
else
	say "4/5 跳过 sensord 构建（加 --build-sensord）"
fi

say "5/5 完成"
cat <<EOF
chroot : $CHROOT_DIR   (suite=$SUITE, arch=arm64, mirror=$MIRROR)
用法   : sudo chroot $CHROOT_DIR /bin/bash
注意   : 换 glibc 后 **动态 musl** 的 elden-ime-focusd 也要在这里重编：
         cp -a patches-userland/zh-ime $CHROOT_DIR/root/ && chroot ... sh -c 'cd /root/zh-ime && sh build-elden-ime.sh'
EOF
