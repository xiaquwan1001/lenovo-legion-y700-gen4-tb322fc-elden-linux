#!/bin/sh
# uinput-touch-build.sh — 构建 tools/uinput-touch.c（虚拟触摸屏注入器）。
#   usage: tools/uinput-touch-build.sh [--host]
# 默认交叉编 aarch64（设备用），--host 编本机 x86_64（仅 --help/自检用）。
# 产物：out/tools/uinput-touch（或 uinput-touch-host）。与 uinput-back-build.sh 同约定。
set -eu
cd "$(dirname "$0")/.."
mkdir -p out/tools
CC=${CC:-aarch64-linux-gnu-gcc}
OUT=out/tools/uinput-touch
if [ "${1:-}" = "--host" ]; then CC=${HOSTCC:-gcc}; OUT=out/tools/uinput-touch-host; fi
command -v "$CC" >/dev/null 2>&1 || { echo "缺交叉编译器 $CC（或加 --host 用本机 gcc）" >&2; exit 1; }
$CC -O2 -Wall -Wextra -static -o "$OUT" tools/uinput-touch.c -lm
echo "built: $OUT"; file "$OUT" | sed 's/^/  /'
