#!/bin/sh
# Rebuild patched phoc + phosh on the device (Alpine 3.24, aarch64 native).
# Usage: sh build-phoc-phosh.sh [work-dir] [patch-dir]
#   work-dir  : where to unpack/build (default /root/build)
#   patch-dir : directory holding the 0001/0002 patches (default: this script's dir)
#
# Build-time deps must already be installed (see README.md). Nothing is deleted.
set -e

WORK="${1:-/root/build}"
SELF="$(cd "$(dirname "$0")" && pwd)"
PATCHES="${2:-$SELF}"

PHOC_VER=0.55.1
PHOSH_VER=0.55.0
PHOC_URL="https://sources.phosh.mobi/releases/phoc/phoc-$PHOC_VER.tar.xz"
PHOSH_URL="https://sources.phosh.mobi/releases/phosh/phosh-$PHOSH_VER.tar.xz"

mkdir -p "$WORK"
cd "$WORK"

fetch() {
	[ -f "$2" ] || curl -fSL -o "$2" "$1"
}

fetch "$PHOC_URL"  "phoc-$PHOC_VER.tar.xz"
fetch "$PHOSH_URL" "phosh-$PHOSH_VER.tar.xz"

# ---- phoc ------------------------------------------------------------------
rm -rf "phoc-$PHOC_VER"
tar xJf "phoc-$PHOC_VER.tar.xz"
cd "phoc-$PHOC_VER"
# Alpine aports applies this wlroots revert for phosh
patch -Np1 -f -d subprojects/wlroots-0.20.x \
	< subprojects/packagefiles/wlroots/0001-Revert-layer-shell-error-on-0-dimension-without-anch.patch
patch -Np1 -f < "$PATCHES/0001-phoc-honor-any-mode.patch"
meson setup output --prefix=/usr --default-library=static --buildtype=release \
	-Dembed-wlroots=enabled -Dman=false -Dtests=false -Db_lto=false
ninja -C output
ldd output/src/phoc | grep -i wlroots && { echo "ERROR: phoc linked wlroots dynamically" >&2; exit 1; }
cd "$WORK"

# ---- phosh -----------------------------------------------------------------
rm -rf "phosh-$PHOSH_VER"
tar xJf "phosh-$PHOSH_VER.tar.xz"
cd "phosh-$PHOSH_VER"
# Alpine aports patches (keep parity with the distro package)
patch -Np1 -f < "$PATCHES/alpine-phosh-use-after-free-fix.patch"
patch -Np1 -f < "$PATCHES/alpine-phosh-extend-timeout-with-pid.patch"
# our patches
patch -Np1 -f < "$PATCHES/0002-phosh-report-supported-scale.patch"
sed -i 's/\.rc/_rc/' meson.build
meson setup output --prefix=/usr --buildtype=release -Dphoc_tests=disabled \
	-Dman=false -Dtests=false -Db_lto=false -Dbindings-lib=false \
	-Dintrospection=false -Dvapi=false
ninja -C output

echo "== built:"
echo "   $WORK/phoc-$PHOC_VER/output/src/phoc"
echo "   $WORK/phosh-$PHOSH_VER/output/src/phosh"
