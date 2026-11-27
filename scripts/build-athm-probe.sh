#!/bin/bash
# build-athm-probe.sh — Q26 Step A probe: CONFIG_ATH12K=m single-shot build.
#
# Base = wt-athm worktree at bd114ca33 (= vk47clean source), config = wt-wifibmiss/.config
# with ATH12K flipped y->m.  LOCALVERSION matches the on-disk persistent modules dir
# 7.2.0-debug-vk47clean-gbd114ca335e1 so the .ko vermagic lines up for the probe.
#
# Runs under a hard deadline (timeout -k) per project long-run discipline.
#
# RETIRED 2026-11-27：Q26 Step A 一次性质询件（Q26 已于 2026-10-10 关闭）；基座 worktree
#   wt-athm / wt-wifibmiss 已不在本机，且路径硬编码换机前的 /home/xuqianhui1001 ⇒ 不可原地重建；
#   全仓 0 活调用点 ⇒ 保留文件不删（配方/判据仍可读）。
#   分类依据：reports/scripts-ref-audit-20261127.md（T14 / arch-audit A7）。
set -uo pipefail
ROOT=/home/xuqianhui1001/y700-elden
K=/home/xuqianhui1001/wt-athm
VER="${1:-athm}"
UTS_LV="${UTS_LV:--vk47clean-gbd114ca335e1}"
LOG="$ROOT/logs/build-$VER.log"
DEADLINE="${DEADLINE:-2700}"

mkdir -p "$ROOT/logs"
export ARCH=arm64
export CROSS_COMPILE="ccache aarch64-linux-gnu-"
export CC="ccache aarch64-linux-gnu-gcc"
export HOSTCC="ccache gcc"
export CCACHE_DIR="$HOME/.cache/ccache-elden"
export KBUILD_BUILD_USER=elden
export KBUILD_BUILD_HOST=y700

{
  echo "=== athm probe build start $(date -Is) pid=$$ ==="
  echo "HEAD=$(git -C "$K" rev-parse --short HEAD) dirty=$(git -C "$K" status --porcelain | wc -l)"
  grep -E '^CONFIG_ATH12K=' "$K/.config"
  echo "LOCALVERSION=$UTS_LV deadline=${DEADLINE}s"
  echo "=== make ==="
} >> "$LOG"

timeout -k 30 "$DEADLINE" make -C "$K" -j"$(nproc)" LOCALVERSION="$UTS_LV" \
    Image.gz dtbs modules >> "$LOG" 2>&1
rc=$?
echo "MAKE_EXIT=$rc at $(date -Is)" >> "$LOG"
exit $rc
