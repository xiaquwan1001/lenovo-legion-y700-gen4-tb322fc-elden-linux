#!/bin/sh
# bench-install.sh — 设备侧：安装可选基准工具（需要网络）
#
# 只装 Alpine 源里有的（已核实 USTC/aliyun latest-stable 均有 aarch64）：
#   sysbench stress-ng vkmark fio 7zip iperf3
# 注意：glmark2 / vkcube / tinymembench Alpine 无；GLES 用 rootfs 自带
#   es2gears_wayland，Vulkan 用 vkmark（+ vulkan-tools 已在 rootfs）。
#
# 用法（设备上 root）： sh bench-install.sh
set -eu
command -v apk >/dev/null 2>&1 || { echo "not Alpine (no apk)" >&2; exit 1; }
apk update
apk add --no-cache sysbench stress-ng vkmark fio 7zip iperf3
echo "[bench-install] done; now run: sh bench-run.sh"
