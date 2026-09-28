#!/bin/bash
# List shared libraries the built Mesa needs that the target root does not
# already provide, and copy them next to it.
#
# The sysroot is assembled from the full archive, so Mesa can end up linking
# against libraries the tablet's desktop install never pulled in
# (libxcb-keysyms is one). Ship those alongside instead of requiring apt.
set -euo pipefail

STAGE=${STAGE:-/home/xuqianhui1001/y700-elden/out/mesa-build/stage/opt/mesa-a830}
SYSROOT=${SYSROOT:-/home/xuqianhui1001/y700-elden/out/sysroot-arm64}
TARGET=${1:-/mnt/rootfs}
LIB=lib/aarch64-linux-gnu

need=$(for so in "$STAGE/$LIB"/*.so* "$STAGE/$LIB"/dri/*.so "$STAGE/$LIB"/gbm/*.so; do
	[ -f "$so" ] || continue
	aarch64-linux-gnu-objdump -p "$so" 2>/dev/null | awk '/NEEDED/{print $2}'
done | sort -u)

echo "== libraries Mesa needs but the target lacks"
missing=()
for lib in $need; do
	# Mesa's own libraries resolve through the rpath inside /opt/mesa-a830.
	if ls "$STAGE/$LIB/$lib" >/dev/null 2>&1; then
		continue
	fi
	if ! ls "$TARGET/usr/$LIB/$lib" "$TARGET/$LIB/$lib" >/dev/null 2>&1; then
		missing+=("$lib")
		echo "  $lib"
	fi
done
[ ${#missing[@]} -eq 0 ] && { echo "  (none)"; exit 0; }

echo "== copying from sysroot into /opt/mesa-a830/runtime"
for lib in "${missing[@]}"; do
	src=$(find "$SYSROOT/usr/$LIB" "$SYSROOT/$LIB" -maxdepth 1 -name "$lib" 2>/dev/null | head -1)
	if [ -z "$src" ]; then
		echo "  WARNING: $lib not in sysroot either"
		continue
	fi
	real=$(readlink -f "$src")
	cp -a "$real" "$TARGET/opt/mesa-a830/runtime/$(basename "$real")"
	ln -sfn "$(basename "$real")" "$TARGET/opt/mesa-a830/runtime/$lib"
	echo "  $lib <- $(basename "$real")"
done

ls -l "$TARGET/opt/mesa-a830/runtime/"
