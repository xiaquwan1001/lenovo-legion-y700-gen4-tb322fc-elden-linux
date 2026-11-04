#!/bin/bash
# elden-hapticd.sh — 重建 /usr/local/bin/elden-hapticd（Waydroid 马达透传宿主 daemon）
#
# 源   : scripts/elden-hapticd.c
# 产物 : out/hapticd/elden-hapticd（aarch64 static）
# 可复现性：2026-11-04 实测重建产物 sha256 == MANIFEST 清单值 aca55cb1…（逐字一致）
#
# 用法: bash packaging/elden-userland/build/elden-hapticd.sh [--dry-run]
set -euo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"
REPO=$(repo_root)

need_file "$REPO/scripts/elden-hapticd.c"
need_file "$REPO/scripts/build-hapticd.sh"
need aarch64-linux-gnu-gcc gcc-aarch64-linux-gnu

note "产物 out/hapticd/elden-hapticd（aarch64 static，Alpine/Debian 通吃）"
run bash "$REPO/scripts/build-hapticd.sh"
finish elden-hapticd
