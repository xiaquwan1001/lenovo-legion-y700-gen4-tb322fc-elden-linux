#!/bin/bash
# pack.sh — DEPRECATED 兼容入口（2026-10-07，见 .pi/plans/2026-10-07-造轮子审计.md §1.1）。
#
# 唯一实现 = scripts/build-boot.sh（本文件曾复刻一份 mkbootimg 调用，已删除以免漂移）。
# 保留仅为兼容旧文档/肌肉记忆（与根目录 build.sh / iterate.sh 同一做法）。
#
# 旧用法 : pack.sh [rootfs.cpio.gz] [out.img]
# 新用法 : VERSION=vkN [RAMDISK=...] [ROOTARGS=] scripts/build-boot.sh
#   RAM-only 调试镜像：ROOTARGS= VERSION=vkN-ram scripts/build-boot.sh
set -eu
if [ -n "${1:-}" ]; then
	export RAMDISK=$1
fi
if [ -n "${2:-}" ]; then
	echo "[pack] 注意：旧参数 out.img 已忽略；输出 = out/boot-elden-\${VERSION}.img" >&2
fi
exec bash "$(dirname "$0")/scripts/build-boot.sh"
