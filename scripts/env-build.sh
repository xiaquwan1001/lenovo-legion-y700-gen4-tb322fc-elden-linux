#!/bin/bash
# env-build.sh — shared host build environment for the elden kernel tree.
#
# Source it (do not execute):
#     . "$(dirname "$0")/scripts/env-build.sh"
#
# Why: every build script used to set CROSS_COMPILE by hand, so ccache (installed
# but unused, 0 GiB cache) never ran.  Sourcing this file routes all aarch64
# compiles through ccache, giving a warm cache across config churn and clean
# builds.  Override any variable by exporting it before sourcing.

export PATH="$HOME/bin:$PATH"

: "${ROOT:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
: "${ARCH:=arm64}"
: "${CCACHE_DIR:=$HOME/.cache/ccache-elden}"
: "${CCACHE_MAXSIZE:=20G}"

# Reproducibility metadata baked into `uname -v`.
: "${KBUILD_BUILD_USER:=elden}"
: "${KBUILD_BUILD_HOST:=y700}"

if command -v ccache >/dev/null 2>&1; then
	export CCACHE_DIR
	mkdir -p "$CCACHE_DIR" 2>/dev/null || true
	ccache -M "$CCACHE_MAXSIZE" >/dev/null 2>&1 || true
	export CROSS_COMPILE="ccache aarch64-linux-gnu-"
	export CC="ccache aarch64-linux-gnu-gcc"
	export HOSTCC="ccache gcc"
else
	echo "[env] WARNING: ccache not found — building without cache" >&2
	export CROSS_COMPILE="aarch64-linux-gnu-"
fi
export ARCH KBUILD_BUILD_USER KBUILD_BUILD_HOST

kbuild() {
	# Run make in the kernel tree with the shared env.
	make -C "$ROOT/linux" -j"${JOBS:-$(nproc)}" "$@"
}
