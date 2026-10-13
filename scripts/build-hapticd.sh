#!/bin/bash
# build-hapticd.sh — 交叉编译 elden-hapticd（Waydroid 马达透传宿主 daemon）
#   产物：out/hapticd/elden-hapticd（aarch64 static，Alpine musl 可直接跑）
set -eu
cd "$(dirname "$0")/.."
CC=${CC:-}
[ -n "$CC" ] || CC=$(command -v aarch64-linux-gnu-gcc || echo "$HOME/bin/aarch64-linux-gnu-gcc")
[ -x "$CC" ] || { echo "[build-hapticd] aarch64 cross compiler not found: $CC"; exit 1; }
mkdir -p out/hapticd
echo "[build-hapticd] $CC -static -O2 -> out/hapticd/elden-hapticd"
$CC -static -O2 -Wall -Wextra -o out/hapticd/elden-hapticd scripts/elden-hapticd.c
STRIP=$(echo "$CC" | sed 's/gcc$/strip/')
[ -x "$STRIP" ] && "$STRIP" out/hapticd/elden-hapticd || true
if command -v gcc >/dev/null; then
  echo "[build-hapticd] native -> out/hapticd/elden-hapticd-host"
  gcc -O2 -Wall -Wextra -o out/hapticd/elden-hapticd-host scripts/elden-hapticd.c
fi
file out/hapticd/elden-hapticd
echo "[build-hapticd] done"
