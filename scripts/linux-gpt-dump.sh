#!/bin/bash
# linux-gpt-dump.sh — EDL 只读 dump 六 LUN 的 GPT 主表 + 备表（零写盘），并更新 SHA256SUMS。
#
# 用法：
#   scripts/linux-gpt-dump.sh                 # 输出到 backup/<SN>-16+512/edl-<ts>/
#   scripts/linux-gpt-dump.sh --enter-edl     # 设备在 Android/fastboot 时先自动切 9008
#   scripts/linux-gpt-dump.sh --out DIR       # 指定输出目录
#
# 纪律（GPT-MINIMAL-DESIGN.md §5-6）：任何写表动作前先跑本脚本；表按 **4096 B 扇区** 口径：
#   主表 = LUN LBA0..5（24576 B）；备表 = LBA (alt_lba-4)..alt_lba（20480 B，末扇区是备份头）。
#   备表 LBA 从主表头 alt_lba 现算，不写死（不同 LUN 的 alt_lba 分别是 123871231/5119/5119/8191/1048575/8191）。
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SN=${SN:-HA2EXB0E}
LOADER=${LOADER:-$HOME/下载/tb322fc/xbl_s_devprg_ns.melf}
QDL=${QDL:-$HOME/edl/qdl/build/qdl}
OUT=""; ENTER_EDL=0
while [ $# -gt 0 ]; do
	case "$1" in
		--out) OUT=$2; shift 2 ;;
		--enter-edl) ENTER_EDL=1; shift ;;
		-h|--help) sed -n '2,14p' "$0"; exit 0 ;;
		*) echo "未知参数 $1" >&2; exit 2 ;;
	esac
done
OUT=${OUT:-$ROOT/backup/$SN-16+512/edl-$(date +%Y%m%d-%H%M)}
mkdir -p "$OUT"

if [ "$ENTER_EDL" -eq 1 ]; then
	if timeout -k 5 6 adb devices | awk '{print $1}' | grep -qx "$SN"; then
		timeout -k 5 20 adb -s "$SN" reboot edl || true
	elif timeout -k 5 8 fastboot devices | awk '{print $1}' | grep -qx "$SN"; then
		timeout -k 5 20 fastboot -s "$SN" oem edl || true
	fi
	sleep 8
fi
timeout -k 5 10 lsusb | grep -q '05c6:9008' || { echo "!! 未枚举到 05c6:9008（EDL）" >&2; exit 1; }

echo "[1/3] 读六 LUN 主表"
timeout -k 10 300 "$QDL" -s ufs "$LOADER" \
	read 0/0+6 "$OUT/gpt0-primary.bin" read 1/0+6 "$OUT/gpt1-primary.bin" \
	read 2/0+6 "$OUT/gpt2-primary.bin" read 3/0+6 "$OUT/gpt3-primary.bin" \
	read 4/0+6 "$OUT/gpt4-primary.bin" read 5/0+6 "$OUT/gpt5-primary.bin" \
	2>&1 | grep -E 'read .* successfully|ERR' | tail -8

echo "[2/3] 由 alt_lba 现算备表位置并读备表（同一会话，-R 收尾 reset）"
args=()
for lun in 0 1 2 3 4 5; do
	alt=$(python3 - "$OUT/gpt${lun}-primary.bin" <<'PY'
import struct,sys
b=open(sys.argv[1],'rb').read(); h=b[4096:4096+92]
if h[:8]!=b'EFI PART': sys.exit(1)
print(struct.unpack_from('<Q',h,32)[0])
PY
) || { echo "!! LUN$lun 主表无 EFI PART" >&2; exit 1; }
	args+=(read "$lun/$((alt-4))+5" "$OUT/gpt${lun}-backup.bin")
	echo "   LUN$lun 备表 LBA $((alt-4))..$alt"
done
timeout -k 10 300 "$QDL" -s ufs -R "$LOADER" "${args[@]}" 2>&1 | grep -E 'read .* successfully|ERR|reset' | tail -8

echo "[3/3] 校验 + 清单"
for lun in 0 1 2 3 4 5; do
	p="$OUT/gpt${lun}-primary.bin"; b="$OUT/gpt${lun}-backup.bin"
	[ -s "$p" ] && [ -s "$b" ] || { echo "!! LUN$lun 文件不齐" >&2; exit 1; }
	eq=$(python3 - "$p" "$b" <<'PY'
import sys
p=open(sys.argv[1],'rb').read(); b=open(sys.argv[2],'rb').read()
# 主表 LBA2 起是条目数组；备表前段同结构 ⇒ 比较前 4096 B（32 项）或按需更长
print('entries_equal' if p[8192:8192+4096]==b[:4096] else 'entries_DIFF')
PY
)
	echo "   LUN$lun  $(stat -c%s "$p")B/$(stat -c%s "$b")B  $eq"
done
( cd "$OUT" && sha256sum *.bin > SHA256SUMS.txt )
echo "OK  输出目录: $OUT（12 件 + SHA256SUMS.txt）"
echo "下一步：python3 scripts/gpt-audit-tb322fc.py --dev $OUT --stock ~/文档/TB322FC_15.10.259"
