#!/bin/bash
# eldroid-sensord.sh — 重建 /usr/local/bin/eldroid-sensord（C4 传感器 UDP 数据源 daemon）
#
# 源   : scripts/eldroid-sensord.c
# 产物 : out/sensord/eldroid-sensord（aarch64 static）
# 可复现性：功能等价；sha 与清单 a1a457b2… **不同**（设备原件为 musl 静态件，
#          宿主编译器是 glibc 静态 ⇒ 体积/字节不同）。判据是"源在 + 能编 + 静态 aarch64"。
#
# 用法: bash packaging/elden-userland/build/eldroid-sensord.sh [--dry-run]
set -euo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"
REPO=$(repo_root)

need_file "$REPO/scripts/eldroid-sensord.c"
need_file "$REPO/scripts/build-sensord.sh"
need aarch64-linux-gnu-gcc gcc-aarch64-linux-gnu

note "产物 out/sensord/eldroid-sensord（aarch64 static）+ -host（本机）"
run bash "$REPO/scripts/build-sensord.sh"
finish eldroid-sensord
