#!/bin/bash
# sysroot-add-debs.sh — 通用：把 trixie arm64 的 deb 解进 sysroot（供交叉编）
#
# 用法（需 root）：sudo bash scripts/sysroot-add-debs.sh <pkg> [pkg...]
#   SYSROOT=（默认 out/sysroot-trixie-arm64） CH=（默认 /opt/elden/arm64-trixie）
# 幂等：dpkg -x 覆盖同名文件即可；不动 chroot 已安装状态（只 `apt-get download`）。
# 末尾自动补 /lib/aarch64-linux-gnu 的 libc/libm/libmvec/ld 链接（trixie 的 ld script 用绝对路径）。
set -euo pipefail

REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
CH=${CH:-/opt/elden/arm64-trixie}
SYSROOT=${SYSROOT:-$REPO/out/sysroot-trixie-arm64}
WORK=/var/tmp/sysroot-debs
[ $# -ge 1 ] || { echo "用法: sudo bash $0 <deb 包名> [...]" >&2; exit 2; }
[ "$(id -u)" = 0 ] || { echo "需要 root" >&2; exit 1; }

echo "=== 下载 $* （trixie arm64）"
rm -rf "$WORK"
chroot "$CH" /bin/sh -c "mkdir -p $WORK && cd $WORK && apt-get download $*" 2>&1 | tail -5

echo "=== 解包到 $SYSROOT"
n=0
for d in "$CH$WORK"/*.deb; do dpkg -x "$d" "$SYSROOT"; n=$((n+1)); done
echo "  解入 $n 个包"

SYSLIB="$SYSROOT/lib/aarch64-linux-gnu"; USRLIB="$SYSROOT/usr/lib/aarch64-linux-gnu"
mkdir -p "$SYSLIB"
for f in libc.so.6 libm.so.6 libmvec.so.1 ld-linux-aarch64.so.1; do
  [ -e "$USRLIB/$f" ] || continue
  [ -e "$SYSLIB/$f" ] || ln -s ../../usr/lib/aarch64-linux-gnu/"$f" "$SYSLIB/$f"
done
echo "=== 完成（$n 包）"
