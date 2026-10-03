#!/bin/bash
# Cross-compile Mesa 26.1.6 (freedreno GL + turnip Vulkan) for the TB322FC.
#
# Stock Ubuntu ships Mesa 26.0.8, whose A830 support is incomplete enough that
# gnome-shell wedges the GPU ("hangcheck detected gpu lockup"). 26.1.6 carries
# the mainline-DRM A830 work, so it goes into /opt/mesa-a830 and the desktop is
# pointed at it through environment variables.
set -euo pipefail

SRC=${SRC:-/home/xuqianhui1001/y700-elden/out/mesa-26.1.6-src}
SYSROOT=${SYSROOT:-/home/xuqianhui1001/y700-elden/out/sysroot-arm64}
BUILD=${BUILD:-/home/xuqianhui1001/y700-elden/out/mesa-build}
PREFIX=/opt/mesa-a830
CROSS=/home/xuqianhui1001/y700-elden/out/cross-aarch64.ini
MESON=${MESON:-$(command -v meson)}

# pkg-config for the target comes from the cross file's pkg_config_libdir;
# exporting it here as well would also redirect native tool lookups.
unset PKG_CONFIG_SYSROOT_DIR PKG_CONFIG_LIBDIR PKG_CONFIG_PATH

rm -rf "$BUILD"
"$MESON" setup "$BUILD" "$SRC" \
	--cross-file "$CROSS" \
	--prefix "$PREFIX" \
	--libdir lib/aarch64-linux-gnu \
	--buildtype release \
	-Dstrip=true \
	-Dgallium-drivers=freedreno \
	-Dvulkan-drivers=freedreno \
	-Dplatforms=x11,wayland \
	-Dglx=dri \
	-Degl=enabled \
	-Dgbm=enabled \
	-Dgles1=disabled \
	-Dgles2=enabled \
	-Dopengl=true \
	-Dllvm=disabled \
	-Dshared-llvm=disabled \
	-Dvideo-codecs= \
	-Dgallium-va=disabled \
	-Dvulkan-layers= \
	-Dtools= \
	-Dvalgrind=disabled \
	-Dlibunwind=disabled \
	-Dzstd=enabled \
	-Dxmlconfig=disabled \
	2>&1 | tail -40

echo "== building"
ninja -C "$BUILD" -j"$(nproc)" 2>&1 | tail -15

echo "== installing to staging"
rm -rf "$BUILD/stage"
DESTDIR="$BUILD/stage" ninja -C "$BUILD" install >/dev/null

echo "== result"
find "$BUILD/stage$PREFIX" -name '*.so*' -o -name '*.json' | head -20
du -sh "$BUILD/stage$PREFIX"
