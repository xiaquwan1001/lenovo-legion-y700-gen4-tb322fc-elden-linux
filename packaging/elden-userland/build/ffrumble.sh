#!/bin/bash
# ffrumble.sh — 重建 /usr/local/bin/ffrumble（EV_FF 阳性对照工具）
#
# 源   : scripts/ffrumble.c（117 行，2026-10-25 按用法重写；原件源码从未入库）
# 规格 : packaging/elden-userland/sources/ffrumble/README.md（行为规格 + 反汇编要点）
# 验收 : bash packaging/elden-userland/sources/ffrumble/check-abi.sh out/ffrumble/ffrumble
# 真跑 : bash scripts/build-ffrumble.sh   （本配方 = 同一命令的 dry-run 包装）
#
# 用法: bash packaging/elden-userland/build/ffrumble.sh [--dry-run]
set -euo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"
REPO=$(repo_root)

need_file "$REPO/scripts/ffrumble.c"
need_file "$REPO/scripts/build-ffrumble.sh"
need aarch64-linux-gnu-gcc gcc-aarch64-linux-gnu

note "产物 out/ffrumble/ffrumble（aarch64 static）+ out/ffrumble/ffrumble-host（本机自测）"
run bash "$REPO/scripts/build-ffrumble.sh"
[ "$DRY_RUN" = 1 ] || run bash "$REPO/packaging/elden-userland/sources/ffrumble/check-abi.sh" "$REPO/out/ffrumble/ffrumble"
finish ffrumble
