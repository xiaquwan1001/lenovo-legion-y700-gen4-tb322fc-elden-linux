#!/bin/bash
# elden-ime-focusd.sh — 重建 /usr/local/bin/elden-ime-focusd（输入法焦点守护，动态链 glib/gio）
#
# 源   : patches-userland/zh-ime/elden-ime-focusd.c（+ build-elden-ime.sh，原本"在设备上编"）
# 产物 : out/ime-host/elden-ime-focusd（glibc，arm64 chroot 内编；设备现役件 sha256 7b8b0b46…）
# 取舍 : 设备上现役件是 glibc 动态件 ⇒ 用同一个 /opt/elden/arm64-sid chroot 编即可，
#        不需要 Alpine/musl 变体（Debian 根是当前与 Mobian 目标根）。
#
# 用法: bash packaging/elden-userland/build/elden-ime-focusd.sh [--dry-run]
#       sudo bash packaging/elden-userland/build/elden-ime-focusd.sh
set -euo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"
REPO=$(repo_root)
SRCDIR=patches-userland/zh-ime
CHROOT_DIR=${CHROOT_DIR:-/opt/elden/arm64-sid}
MIRROR=${MIRROR:-https://mirrors.ustc.edu.cn/debian}
OUT=$REPO/out/ime-host

need_file "$REPO/$SRCDIR/elden-ime-focusd.c"
need_file "$REPO/$SRCDIR/build-elden-ime.sh"
[ "$DRY_RUN" = 1 ] || need_root "$@"

note "产物 $OUT/elden-ime-focusd（arm64 glibc，动态链 glib/gio）"
run sh -c "test -x '$CHROOT_DIR/bin/sh' || debootstrap --arch=arm64 --variant=minbase --include=ca-certificates sid '$CHROOT_DIR' '$MIRROR'"
run chroot "$CHROOT_DIR" /bin/sh -c \
	"apt-get update -qq && apt-get install -y -qq --no-install-recommends build-essential pkgconf libglib2.0-dev"
run rm -rf "$CHROOT_DIR/root/zh-ime"
run mkdir -p "$CHROOT_DIR/root/zh-ime"
run cp -a "$REPO/$SRCDIR/." "$CHROOT_DIR/root/zh-ime/"
run chroot "$CHROOT_DIR" /bin/sh -c 'cd /root/zh-ime && sh build-elden-ime.sh'
run mkdir -p "$OUT"
run cp "$CHROOT_DIR/root/zh-ime/elden-ime-focusd" "$OUT/elden-ime-focusd"
if [ "$DRY_RUN" = 0 ]; then
	run sh -c "file '$OUT/elden-ime-focusd'; sha256sum '$OUT/elden-ime-focusd'"
fi
finish elden-ime-focusd
