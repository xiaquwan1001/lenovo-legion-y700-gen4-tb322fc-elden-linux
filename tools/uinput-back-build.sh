#!/bin/sh
# uinput-back-build.sh — 构建 tools/uinput-back.c（D13 边缘侧滑返回 PoC 注入器）
#   默认交叉编 aarch64（与 scripts/build-ffrumble.sh 的约定一致），
#   --host 用本机 gcc；产物落 out/tools/。
#   用法: tools/uinput-back-build.sh [--host]
set -eu
cd "$(dirname "$0")/.."
SRC=tools/uinput-back.c
mkdir -p out/tools

if [ "${1:-}" = "--host" ]; then
	command -v gcc >/dev/null || { echo "host gcc not found" >&2; exit 1; }
	echo "[uinput-back-build] gcc -O2 -Wall -Wextra -> out/tools/uinput-back-host"
	gcc -O2 -Wall -Wextra -o out/tools/uinput-back-host "$SRC"
	STRIP=strip
	[ -x "$STRIP" ] && "$STRIP" out/tools/uinput-back-host || true
	echo "[uinput-back-build] host build done"
	exit 0
fi

CC=${CC:-}
[ -n "$CC" ] || CC=$(command -v aarch64-linux-gnu-gcc || echo "$HOME/bin/aarch64-linux-gnu-gcc")
[ -x "$CC" ] || { echo "[uinput-back-build] aarch64 cross compiler not found: $CC" >&2; exit 1; }
echo "[uinput-back-build] $CC -static -O2 -Wall -Wextra -> out/tools/uinput-back"
"$CC" -static -O2 -Wall -Wextra -o out/tools/uinput-back "$SRC"
STRIP=$(echo "$CC" | sed 's/gcc$/strip/')
[ -x "$STRIP" ] && "$STRIP" out/tools/uinput-back || true
if command -v file >/dev/null; then
	file out/tools/uinput-back
fi
echo "[uinput-back-build] aarch64 build done"
