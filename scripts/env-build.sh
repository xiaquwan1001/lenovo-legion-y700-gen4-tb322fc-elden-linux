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

# Kernel tree to build: default = $ROOT/linux (the symlink), override with KDIR
# so mod-loop/build scripts can target a worktree (e.g. KDIR=build/vk151).
: "${KDIR:=$ROOT/linux}"
export KDIR

# Per-build uname label (e.g. LOCALVERSION=-vk50).  Export it and every ring —
# kernel/dtb builds, kexec fingerprint, and mod-loop's vermagic check — stays
# consistent, because they all go through kbuild().  Without this, a
# LOCALVERSION-tagged kernel makes mod-loop refuse its own modules.
: "${LOCALVERSION:=}"

kbuild() {
	# Run make in the kernel tree with the shared env.
	make -C "$KDIR" -j"${JOBS:-$(nproc)}" ${LOCALVERSION:+LOCALVERSION=$LOCALVERSION} "$@"
}
