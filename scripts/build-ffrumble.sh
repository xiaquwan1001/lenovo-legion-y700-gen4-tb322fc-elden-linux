#!/bin/bash
# build-ffrumble.sh — 交叉编译 ffrumble（aw86927 FF_RUMBLE 宿主侧阳性对照工具）
#   产物：out/ffrumble/ffrumble（aarch64 static，Alpine/Debian 通吃）+ 主机自测版
set -eu
cd "$(dirname "$0")/.."
CC=${CC:-}
[ -n "$CC" ] || CC=$(command -v aarch64-linux-gnu-gcc || echo "$HOME/bin/aarch64-linux-gnu-gcc")
[ -x "$CC" ] || { echo "[build-ffrumble] aarch64 cross compiler not found: $CC"; exit 1; }
mkdir -p out/ffrumble
echo "[build-ffrumble] $CC -static -O2 -> out/ffrumble/ffrumble"
$CC -static -O2 -Wall -Wextra -o out/ffrumble/ffrumble scripts/ffrumble.c
STRIP=$(echo "$CC" | sed 's/gcc$/strip/')
[ -x "$STRIP" ] && "$STRIP" out/ffrumble/ffrumble || true
if command -v gcc >/dev/null; then
  gcc -O2 -Wall -Wextra -o out/ffrumble/ffrumble-host scripts/ffrumble.c
fi
file out/ffrumble/ffrumble
echo "[build-ffrumble] done"
