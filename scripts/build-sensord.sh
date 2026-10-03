#!/bin/bash
# 编译 eldroid-sensord（C4 数据源 daemon）：
#   native（主机冒烟测试）+ aarch64 static（部署到设备 rootfs，Alpine musl 兼容）
set -eu
cd "$(dirname "$0")/.."
CC=${CC:-}
[ -n "$CC" ] || CC=$(command -v aarch64-linux-gnu-gcc || echo "$HOME/bin/aarch64-linux-gnu-gcc")
if [ ! -x "$CC" ]; then echo "[build-sensord] aarch64 cross compiler not found: $CC"; exit 1; fi
mkdir -p out/sensord

echo "[build-sensord] aarch64 static -> out/sensord/eldroid-sensord"
$CC -static -O2 -Wall -Wextra -o out/sensord/eldroid-sensord scripts/eldroid-sensord.c -lm
STRIP=$(echo "$CC" | sed 's/gcc$/strip/')
[ -x "$STRIP" ] && "$STRIP" out/sensord/eldroid-sensord || true

if command -v gcc >/dev/null; then
  echo "[build-sensord] native -> out/sensord/eldroid-sensord-host"
  gcc -O2 -Wall -Wextra -o out/sensord/eldroid-sensord-host scripts/eldroid-sensord.c -lm
fi
echo "[build-sensord] done"
