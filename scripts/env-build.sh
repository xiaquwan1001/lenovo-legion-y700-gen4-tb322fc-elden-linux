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

# Kernel tree to build.  Resolution order:
#   1. KDIR=... (explicit override, e.g. KDIR=build/vk151 or an experiment worktree)
#   2. $ROOT/patches/current-tree  (一行指针 = 日常线树；2026-10-27 起）
#   3. $ROOT/linux                 （历史：GEEKiDoS v7.2-elden 血统符号链接）
# 为什么要有第 2 条：日常线载荷是 7.3-rc7（build/vk151），而 `linux` 符号链接停在
# 7.2 血统且无 .config —— 裸跑 iterate/mod-loop/build-kernel 会静默编错树。
if [ -z "${KDIR:-}" ]; then
	if [ -r "$ROOT/patches/current-tree" ]; then
		_t=$(sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$ROOT/patches/current-tree" | grep -v '^$' | head -1)
		[ -n "$_t" ] && KDIR="$ROOT/$_t"
	fi
	: "${KDIR:=$ROOT/linux}"
fi
# 相对路径按仓库根解析（文档里的写法是 KDIR=build/vk151），随后统一成绝对路径，
# 否则调用方一旦 cd 到别处 $KDIR 就失效。
case "$KDIR" in /*) ;; *) KDIR="$ROOT/$KDIR" ;; esac
export KDIR
[ -d "$KDIR" ] || echo "[env] WARNING: KDIR 不存在: $KDIR（用 KDIR=<tree> 覆盖）" >&2
[ -f "$KDIR/.config" ] || echo "[env] WARNING: $KDIR/.config 不存在（先 make defconfig，或用 KDIR=<tree>）" >&2

# Per-build uname label (e.g. LOCALVERSION=-vk50).  Export it and every ring —
# kernel/dtb builds, kexec fingerprint, and mod-loop's vermagic check — stays
# consistent, because they all go through kbuild().  Without this, a
# LOCALVERSION-tagged kernel makes mod-loop refuse its own modules.
: "${LOCALVERSION:=}"

kbuild() {
	# Run make in the kernel tree with the shared env.
	make -C "$KDIR" -j"${JOBS:-$(nproc)}" ${LOCALVERSION:+LOCALVERSION=$LOCALVERSION} "$@"
}
