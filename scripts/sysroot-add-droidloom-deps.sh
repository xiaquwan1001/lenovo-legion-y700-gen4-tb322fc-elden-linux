#!/bin/bash
# sysroot-add-droidloom-deps.sh — 给 trixie arm64 sysroot 补 droidloom 4 个 C 依赖件的 -dev 包
#
# 背景：T44 评估（reports/t44-ubuntu-build-scoping-20261128.md）实证 = 真 C 依赖只有
#   wayland-client / gbm / libpipewire-0.3（+ 构建期 glslangValidator，宿主已有 16.2.0）。
#   本脚本从 trixie chroot 里 apt-get download 对应 arm64 -dev 包，dpkg -x 进 sysroot，
#   让主机交叉编 `droidloom-{wayland,audio,devices,gpu-server}` 成为可能（不走 Arch）。
#
# 用法（需 root）：sudo bash scripts/sysroot-add-droidloom-deps.sh
# 幂等：已存在的 .pc/.so 会跳过；只往 out/sysroot-trixie-arm64/ 里加文件。
set -euo pipefail

REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
CH=${CH:-/opt/elden/arm64-trixie}
SYSROOT=${SYSROOT:-$REPO/out/sysroot-trixie-arm64}
WORK=/var/tmp/droidloom-dev-debs
PKGS="libwayland-dev libgbm-dev libpipewire-0.3-dev libspa-0.2-dev libdrm-dev libxkbcommon-dev libwayland-client0 libwayland-server0 libgbm1 libpipewire-0.3-0t64 libdrm2 libxkbcommon0"

[ "$(id -u)" = 0 ] || { echo "需要 root：sudo bash $0" >&2; exit 1; }
[ -d "$SYSROOT/usr/lib/aarch64-linux-gnu" ] || { echo "缺 sysroot：$SYSROOT" >&2; exit 1; }

echo "=== 1/3 在 chroot 里下载 arm64 -dev 包（trixie 版本，与 sysroot 基线一致）"
rm -rf "$WORK"; mkdir -p "$WORK"
chroot "$CH" /bin/sh -c "cd /var/tmp 2>/dev/null || cd /tmp; rm -rf droidloom-dev-debs; mkdir -p droidloom-dev-debs; \
  cd droidloom-dev-debs && apt-get download $PKGS" 2>&1 | tail -8
cp "$CH"/var/tmp/droidloom-dev-debs/*.deb "$WORK"/ 2>/dev/null || cp "$CH"/tmp/droidloom-dev-debs/*.deb "$WORK"/

echo "=== 2/3 解到 sysroot（dpkg -x，不跑 maintainer scripts）"
for d in "$WORK"/*.deb; do
  echo "  + $(basename "$d")"
  dpkg -x "$d" "$SYSROOT"
done

echo "=== 3/3 判据：三个必需 .pc 必须可被 pkg-config 找到"
export PKG_CONFIG_LIBDIR="$SYSROOT/usr/lib/aarch64-linux-gnu/pkgconfig:$SYSROOT/usr/share/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_LIBDIR"
fail=0
for f in wayland-client gbm libpipewire-0.3; do
  v=$(pkg-config --modversion "$f" 2>/dev/null || true)
  if [ -n "$v" ]; then echo "  [ok]   $f = $v"; else echo "  [FAIL] $f 找不到"; fail=1; fi
done
[ $fail -eq 0 ] || { echo "有 FAIL：检查 sysroot 路径" >&2; exit 1; }
echo "OK — sysroot 现可编 droidloom-wayland/audio/devices/gpu-server"

# --- 追加（2026-11-28 实测踩到）：sysroot 的 libm.so/libc.so 是 GNU ld script，
# 引用绝对路径 /lib/aarch64-linux-gnu/lib{m,mvec,c}.so.6，而真实 .so.6 落在 usr/lib/...
# 交叉链接会报 "cannot find /lib/aarch64-linux-gnu/libm.so.6"。补符号链接即可（幂等）。
SYSLIB="$SYSROOT/lib/aarch64-linux-gnu"
USRLIB="$SYSROOT/usr/lib/aarch64-linux-gnu"
mkdir -p "$SYSLIB"
for n in libc.so.6 libm.so.6 libmvec.so.1; do
  [ -e "$USRLIB/$n" ] || continue
  [ -e "$SYSLIB/$n" ] || ln -s ../../usr/lib/aarch64-linux-gnu/"$n" "$SYSLIB/$n"
done
[ -e "$SYSLIB/ld-linux-aarch64.so.1" ] || ln -s ../../usr/lib/aarch64-linux-gnu/ld-linux-aarch64.so.1 "$SYSLIB/ld-linux-aarch64.so.1" 2>/dev/null || true
echo "=== 4/4 动态链接器路径自检"
for n in libc.so.6 libm.so.6 libmvec.so.1; do
  [ -e "$SYSLIB/$n" ] && echo "  [ok] /lib/aarch64-linux-gnu/$n" || echo "  [FAIL] 缺 /lib/aarch64-linux-gnu/$n"
done
