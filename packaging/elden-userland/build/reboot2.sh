#!/bin/bash
# reboot2.sh — 重建 /usr/local/sbin/reboot2（PSCI vendor reset → fastboot 的可靠入口）
#
# 源   : rootfs/reboot2.c
# 产物 : out/reboot2/reboot2（aarch64 static）
# 说明 : sources.tsv 里原先只是一行裸命令（`aarch64-linux-gnu-gcc -static -Os -o /tmp/reboot2 …`），
#        产物落在 /tmp 且没 strip ⇒ 无法与 MANIFEST 对齐。本配方把它固化下来：
#        写仓库内 out/reboot2/ 并 strip（与 MANIFEST 的 709 368 B 同级体量）。
#        注意 sha 仍与清单 0c68ee5f… **不同**（清单件是设备上那一版；重建=功能等价）。
#
# 用法: bash packaging/elden-userland/build/reboot2.sh [--dry-run]
set -euo pipefail
. "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"
REPO=$(repo_root)
CC=${CC:-aarch64-linux-gnu-gcc}

need_file "$REPO/rootfs/reboot2.c"
need aarch64-linux-gnu-gcc gcc-aarch64-linux-gnu

note "产物 out/reboot2/reboot2（aarch64 static，-Os，已 strip）"
run mkdir -p "$REPO/out/reboot2"
run "$CC" -static -Os -o "$REPO/out/reboot2/reboot2" "$REPO/rootfs/reboot2.c"
run aarch64-linux-gnu-strip "$REPO/out/reboot2/reboot2"
if [ "$DRY_RUN" = 0 ]; then
	run sh -c "file '$REPO/out/reboot2/reboot2'; sha256sum '$REPO/out/reboot2/reboot2'"
fi
finish reboot2
