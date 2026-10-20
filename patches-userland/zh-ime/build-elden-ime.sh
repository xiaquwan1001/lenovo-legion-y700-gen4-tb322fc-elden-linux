#!/bin/sh
# 构建 elden-ime 用户态组件（在设备上跑；需要 gcc + glib/gio 开发文件）
set -e
cd "$(dirname "$0")"
CC=${CC:-gcc}
PKGS="gio-2.0 glib-2.0"
$CC -O2 -Wall -o elden-ime-focusd elden-ime-focusd.c $(pkg-config --cflags --libs $PKGS)
echo "built: $(pwd)/elden-ime-focusd"
