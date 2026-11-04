#!/bin/bash
# waydroid-sensord-udp.sh — 与 waydroid-sensord.sh 同源同构建（MANIFEST 里是两个文件名指向同一产物）
# 保留独立入口只是为了让 `verify.sh --rebuildable` 能按 ELF 名一一映射。
#
# 用法: bash packaging/elden-userland/build/waydroid-sensord-udp.sh [--dry-run] [--target=glibc|musl]
set -euo pipefail
exec bash "$(dirname -- "${BASH_SOURCE[0]}")/waydroid-sensord.sh" "$@"
