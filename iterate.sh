#!/bin/bash
# 根目录兼容入口 —— 委托给 scripts/iterate.sh（四档环：mod / dtb / kernel / ram）。
#
# 旧用法 `iterate.sh [rootfs.cpio.gz]`（build→pack→cycle，无设备锁）已废弃。
# 新用法请优先：
#   scripts/iterate.sh mod <driver-dir>      # 模块快环 ~30s 不重启
#   scripts/iterate.sh dtb|kernel [--kexec|--boot|--flash]
#   scripts/iterate.sh ram  VERSION=vkNN-ram # 零写盘纯 RAM 变体
exec bash "$(dirname "$0")/scripts/iterate.sh" "$@"
