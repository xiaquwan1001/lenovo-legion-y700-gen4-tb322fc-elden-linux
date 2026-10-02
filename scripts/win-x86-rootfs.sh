#!/bin/bash
# win-x86-rootfs.sh — 构建/部署 glibc aarch64 rootfs（Win-x86 转译 PoC 阶段A）
#
# 主机侧（本机 x86_64，交叉构建）：下载 Ubuntu base arm64 并解包成可 chroot 目录；
# 或用 --debootstrap 走 debootstrap+qemu-user-static 交叉构建 Debian/Ubuntu rootfs。
# 设备侧（--deploy）：scp 到设备并 bind-mount /dev /proc /sys /dev/shm /dev/pts /run。
#
# 用法：
#   scripts/win-x86-rootfs.sh build [distro]     # 下载并解包到 out/glibc-rootfs
#   scripts/win-x86-rootfs.sh deploy <host>      # scp 到 <host>:/root/glibc-rootfs 并挂载验证
#   scripts/win-x86-rootfs.sh debootstrap        # debootstrap 交叉构建（需 root + qemu）
#
# 本机既有教训：github/镜像直连/代理会反转且静默卡死 → 双路径 + precheck。
set -eu
HERE="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$HERE/out"
ASSETS="$HERE/pkgs-x86"
PROXY="${HTTP_PROXY:-http://127.0.0.1:7897}"
ROOTFS="${ROOTFS:-$DIR/glibc-rootfs}"
UBUNTU_URL="https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.5-base-arm64.tar.gz"
UBUNTU_SHA="a91d5a93010193712d346d761372b7c9db6dfcf093893161c64ca107f05914f2"

fetch() { # fetch <url> <out> [sha256]
  local u="$1" o="$2" s="${3:-}" rc
  mkdir -p "$(dirname "$o")"
  [ -s "$o" ] && { echo "exists: $o"; }
  if [ ! -s "$o" ]; then
    curl -L --http1.1 --retry 2 --retry-delay 2 -C - --connect-timeout 12 --max-time 900 --noproxy '*' -o "$o" "$u" \
      || curl -L --http1.1 --retry 2 --retry-delay 2 -C - --connect-timeout 12 --max-time 900 -x "$PROXY" -o "$o" "$u"
  fi
  if [ -n "$s" ]; then echo "$s  $o" | sha256sum -c -; fi
}

build() {
  local distro="${1:-ubuntu2404}"
  case "$distro" in
    ubuntu2404|ubuntu) fetch "$UBUNTU_URL" "$ASSETS/ubuntu-base-24.04.5-base-arm64.tar.gz" "$UBUNTU_SHA";;
    *) echo "unsupported distro: $distro" >&2; exit 2;;
  esac
  echo "== unpack -> $ROOTFS"
  rm -rf "$ROOTFS"; mkdir -p "$ROOTFS"
  tar -xzf "$ASSETS/ubuntu-base-24.04.5-base-arm64.tar.gz" -C "$ROOTFS"
  # 基本可用性：apt 源 + resolv
  cp -f /etc/resolv.conf "$ROOTFS/etc/resolv.conf" 2>/dev/null || true
  echo "== verify (本机 x86 无法 chroot aarch64，仅显示文件结构；真机验证用 deploy)"
  ls "$ROOTFS" | head
  du -sh "$ROOTFS"
}

debootstrap_build() {
  # 交叉构建：主机需 apt install debootstrap qemu-user-static
  command -v debootstrap >/dev/null || { echo "need: apt install debootstrap qemu-user-static" >&2; exit 2; }
  [ "$(id -u)" = 0 ] || { echo "need root" >&2; exit 2; }
  local mirror="${DEBOOTSTRAP_MIRROR:-http://ports.ubuntu.com/ubuntu-ports}"
  rm -rf "$ROOTFS"; mkdir -p "$ROOTFS"
  debootstrap --arch=arm64 --foreign --variant=minbase "$1" "$ROOTFS" "$mirror"
  cp -f /usr/bin/qemu-aarch64-static "$ROOTFS/usr/bin/" 2>/dev/null || true
  chroot "$ROOTFS" /debootstrap/debootstrap --second-stage
  chroot "$ROOTFS" bash -c "apt-get update && apt-get install -y ca-certificates wget"
  echo "== done: $ROOTFS"
}

deploy() {
  local host="${1:?usage: $0 deploy <root@host>}"
  [ -d "$ROOTFS" ] || { echo "no rootfs at $ROOTFS (run build first)" >&2; exit 2; }
  echo "== tar | ssh -> $host:/root"
  tar -C "$(dirname "$ROOTFS")" -czf - "$(basename "$ROOTFS")" | \
    ssh -o ConnectTimeout=10 "$host" 'mkdir -p /root && tar -C /root -xzf - && echo deployed'
  ssh -o ConnectTimeout=10 "$host" '
    R=/root/glibc-rootfs
    for m in /dev /proc /sys /dev/shm /dev/pts /run; do
      [ -d "$R$m" ] || mkdir -p "$R$m"
      mountpoint -q "$R$m" || mount --bind "$m" "$R$m"
    done
    cp -f /etc/resolv.conf "$R/etc/resolv.conf" 2>/dev/null || true
    chroot "$R" /usr/bin/ldd --version | head -1
    chroot "$R" uname -m
  '
}

case "${1:-}" in
  build) shift; build "${1:-ubuntu2404}";;
  debootstrap) shift; debootstrap_build "${1:-noble}";;
  deploy) shift; deploy "${1:-}";;
  *) echo "usage: $0 {build|debootstrap|deploy} ..." >&2; exit 2;;
esac
