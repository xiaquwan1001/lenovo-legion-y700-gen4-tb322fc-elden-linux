#!/usr/bin/env bash
# RETIRED 2026-11-27：本机 loader 无 peek 支持必然失败（PITFALLS #486 定案，脚本头已注明），DDR 回读走 reports/uefi-ddr-fallback-plan-20261101.md §1.4 路径；替代：fastboot boot Linux + probes/blackbox；可复核：reports/ltbox-evaluation-20261118.md
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
# 硬门（#486 定案后加）：本机 loader 不实现 peek，默认直接拒绝执行，避免第 N 次无效试错。
# 真的换了 loader/新机型要复测时：FORCE=1 scripts/edl-peek.sh ...
if [ "${FORCE:-0}" != 1 ]; then
	echo "REFUSE: 本机 loader xbl_s_devprg_ns.melf 不放行 peek（PITFALLS #486，一发定案）。" >&2
	echo "        复测请显式 FORCE=1；DDR 回读请走 reports/uefi-ddr-fallback-plan-20261101.md §1.4。" >&2
	exit 3
fi
ADDR="${1:?usage: edl-peek.sh <hex-addr> <length-bytes> [outfile]}"
LEN="${2:?}"
OUT="${3:-/tmp/edl-peek-${ADDR}.bin}"
EDL_DIR="${EDL_DIR:-$HOME/edl-tool/bkerler-edl-1cda1a6}"
LOADER="${EDL_LOADER:-$HOME/下载/tb322fc/xbl_s_devprg_ns.melf}"
cd "$EDL_DIR"
# 外部命令一律套 timeout -k（仓规）；edl.py 的 peek 可能无限等待回包
exec timeout -k 10 180 python3 edl.py --loader="$LOADER" --memory=Ufs --skipstorageinit peek "$ADDR" "$LEN" "$OUT"
