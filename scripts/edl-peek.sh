#!/usr/bin/env bash
# edl-peek.sh — 经 bkerler python edl 的 Firehose peek 读物理内存（只读工具，无 poke）
# 用法: scripts/edl-peek.sh <hex-addr> <length-bytes> [outfile]
# 前置: 设备处于 9008 (05c6:9008)；udev 规则 99-edl.rules 已放行。
# 注意: 命令逐条执行（PITFALLS #3）；peek 可能被 loader secboot 门控拒绝（见
#       reports/uefi-ddr-fallback-plan-20261101.md §1.1），拒绝时勿重试超过一发。
#
# ⚠ 2026-11-01 实测定案（PITFALLS #486）：本机 loader `xbl_s_devprg_ns.melf` 的
#   Supported Functions 里根本没有 peek ⇒ 本脚本在本机**必然失败**（rawxml 手发同样被拒）。
#   保留仅为记录；不要再拿它试错。DDR 回读请走 reports/uefi-ddr-fallback-plan-20261101.md §1.4 的
#   「切断回落 + fastboot boot Linux + probes/blackbox」。
set -euo pipefail
ADDR="${1:?usage: edl-peek.sh <hex-addr> <length-bytes> [outfile]}"
LEN="${2:?}"
OUT="${3:-/tmp/edl-peek-${ADDR}.bin}"
EDL_DIR="${EDL_DIR:-$HOME/edl-tool/bkerler-edl-1cda1a6}"
LOADER="${EDL_LOADER:-$HOME/下载/tb322fc/xbl_s_devprg_ns.melf}"
cd "$EDL_DIR"
exec python3 edl.py --loader="$LOADER" --memory=Ufs --skipstorageinit peek "$ADDR" "$LEN" "$OUT"
