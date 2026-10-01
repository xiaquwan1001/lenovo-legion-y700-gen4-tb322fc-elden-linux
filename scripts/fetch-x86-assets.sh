#!/usr/bin/env bash
# fetch-x86-assets.sh — 主机侧下载 Win-x86 转译 PoC 所需离线资产到 pkgs-x86/
# 用法: bash scripts/fetch-x86-assets.sh [rootfs|hangover|box64|all]
# 教训: github 直连/代理会时间反转且静默卡死 → 双路径 + precheck + 超时。
set -u
DIR="$HOME/y700-elden/pkgs-x86"
mkdir -p "$DIR"
cd "$DIR"

PROXY=http://127.0.0.1:7897
# precheck: 代理 vs 直连哪个能通 github
probe() {
  local u="$1"
  curl -sS --max-time 8 --noproxy '*' -o /dev/null -w '%{http_code}' "$u" 2>/dev/null
  local direct=$?
  curl -sS --max-time 8 -x "$PROXY" -o /dev/null -w '%{http_code}' "$u" 2>/dev/null
  local prox=$?
  if [ "$direct" = "0" ] || [ "$prox" = "0" ]; then echo ok; else echo fail; fi
}

get() {  # get <url> <out> <sha256(optional)>
  local u="$1" o="$2" s="${3:-}"
  echo "== $o"
  # 先直连，失败再代理
  curl -L --http1.1 --retry 2 --retry-delay 2 -C - --connect-timeout 12 --max-time 600 --noproxy '*' -o "$o" "$u" \
    || curl -L --http1.1 --retry 2 --retry-delay 2 -C - --connect-timeout 12 --max-time 600 -x "$PROXY" -o "$o" "$u"
  if [ -n "$s" ]; then echo "$s  $o" | sha256sum -c - && echo "  sha256 OK"; fi
  ls -lh "$o"
}

ROOTFS_URL="https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.5-base-arm64.tar.gz"
HANGOVER_URL="https://github.com/AndreRH/hangover/releases/download/hangover-11.16/hangover_11.16_ubuntu2404_noble_arm64.tar"
HANGOVER_DEB13="https://github.com/AndreRH/hangover/releases/download/hangover-11.16/hangover_11.16_debian13_trixie_arm64.tar"
BOX64_PKGS="https://pi-apps-coders.github.io/box64-debs/debian/Packages"

case "${1:-all}" in
  rootfs) get "$ROOTFS_URL" "ubuntu-base-24.04.5-base-arm64.tar.gz";;
  hangover) get "$HANGOVER_URL" "hangover_11.16_ubuntu2404_noble_arm64.tar";;
  box64)
    curl -sS --http1.1 --max-time 30 -x "$PROXY" -o Packages "$BOX64_PKGS" \
      || curl -sS --http1.1 --max-time 30 --noproxy '*' -o Packages "$BOX64_PKGS"
    grep -A1 '^Package: box64-generic-arm$' Packages | grep '^Filename:' | awk '{print $2}' | while read f; do
      get "https://pi-apps-coders.github.io/box64-debs/debian/$f" "$(basename "$f")"
    done;;
  all) get "$ROOTFS_URL" "ubuntu-base-24.04.5-base-arm64.tar.gz"; get "$HANGOVER_URL" "hangover_11.16_ubuntu2404_noble_arm64.tar";;
  *) echo "unknown"; exit 2;;
esac
