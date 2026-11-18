#!/bin/bash
# linux-gpt-dump.sh — EDL 只读 dump 六 LUN 的 GPT 主表 + 备表（零写盘），并更新 SHA256SUMS。
#
# 用法：
#   scripts/linux-gpt-dump.sh                 # 输出到 backup/<SN>-16+512/edl-<ts>/
#   scripts/linux-gpt-dump.sh --enter-edl     # 设备在 Android/fastboot 时先自动切 9008
#   scripts/linux-gpt-dump.sh --out DIR       # 指定输出目录
#   scripts/linux-gpt-dump.sh --reset-after   # 收尾显式 `qdl reset` 把设备踢出 9008（默认留 EDL）
#
# qdl 语义（PITFALLS #674/#675）：`-R` = `--skip-reset`（**跳过**会话末尾的 reset），
# 不是「执行 reset」；本脚本每一条 qdl 都带 -R ⇒ 设备在两条命令之间留在 9008，
# 不会再出现「第一发结束即 reset、第二发 SAHARA: failed to read request」。
#
# 纪律（GPT-MINIMAL-DESIGN.md §5-6）：任何写表动作前先跑本脚本；表按 **4096 B 扇区** 口径：
#   主表 = LUN LBA0..5（24576 B）；备表 = LBA (alt_lba-4)..alt_lba（20480 B，末扇区是备份头）。
#   备表 LBA 从主表头 alt_lba 现算，不写死（不同 LUN 的 alt_lba 分别是 123871231/5119/5119/8191/1048575/8191）。
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SN=${SN:-HA2EXB0E}
LOADER=${LOADER:-$HOME/下载/tb322fc/xbl_s_devprg_ns.melf}
QDL=${QDL:-$HOME/edl/qdl/build/qdl}
OUT=""; ENTER_EDL=0; RESET_AFTER=0
while [ $# -gt 0 ]; do
	case "$1" in
		--out) OUT=$2; shift 2 ;;
		--enter-edl) ENTER_EDL=1; shift ;;
		--reset-after) RESET_AFTER=1; shift ;;
		-h|--help) sed -n '2,22p' "$0"; exit 0 ;;
		*) echo "未知参数 $1" >&2; exit 2 ;;
	esac
done
OUT=${OUT:-$ROOT/backup/$SN-16+512/edl-$(date +%Y%m%d-%H%M)}
mkdir -p "$OUT"

# 串行化：dump 与别的 agent 的写盘动作不能交错（scripts/lib-device-lock.sh 单一真源）
. "$ROOT/scripts/lib-device-lock.sh"
device_lock_acquire

if [ "$ENTER_EDL" -eq 1 ]; then
	if timeout -k 5 6 adb devices | awk '{print $1}' | grep -qx "$SN"; then
		timeout -k 5 20 adb -s "$SN" reboot edl || true
	elif timeout -k 5 8 fastboot devices | awk '{print $1}' | grep -qx "$SN"; then
		timeout -k 5 20 fastboot -s "$SN" oem edl || true
	fi
	sleep 8
fi
timeout -k 5 10 lsusb | grep -q '05c6:9008' || { echo "!! 未枚举到 05c6:9008（EDL）" >&2; exit 1; }

echo "[1/3] 读六 LUN 主表（-R：会话结束不 reset，设备留在 9008 供第 2 步用）"
timeout -k 10 300 "$QDL" -s ufs -R "$LOADER" \
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
timeout -k 10 300 "$QDL" -s ufs -R "$LOADER" "${args[@]}" 2>&1 | grep -E 'read .* successfully|ERR' | tail -8

echo "[3/3] 校验 + 清单"
for lun in 0 1 2 3 4 5; do
	p="$OUT/gpt${lun}-primary.bin"; b="$OUT/gpt${lun}-backup.bin"
	[ -s "$p" ] && [ -s "$b" ] || { echo "!! LUN$lun 文件不齐" >&2; exit 1; }
	eq=$(python3 - "$p" "$b" <<'PY'
import struct,sys,zlib
p=open(sys.argv[1],'rb').read(); b=open(sys.argv[2],'rb').read()
# 条目数组可能 >1 扇区（LUN4 = 96x128 = 12288 B），长度必须从表头现读，不能写死 4096
h=p[4096:4096+92]
if h[:8]!=b'EFI PART': print('primary_no_header'); sys.exit(0)
ent_lba,=struct.unpack_from('<Q',h,72); nent,esz=struct.unpack_from('<II',h,80)
blk=p[ent_lba*4096:ent_lba*4096+nent*esz]
bh=b[-4096:-4096+92]
if bh[:8]!=b'EFI PART': print('backup_no_header'); sys.exit(0)
b_ent,=struct.unpack_from('<Q',bh,72)
bb=b[(b_ent-ent_lba)*4096:(b_ent-ent_lba)*4096+nent*esz] if b_ent>=ent_lba else b[:nent*esz]
ok = blk==bb and (zlib.crc32(blk)&0xffffffff)==struct.unpack_from('<I',h,88)[0]
print(('entries_equal' if blk==bb else 'entries_DIFF') + ('/crc_ok' if ok else '/crc_BAD'))
PY
)
	echo "   LUN$lun  $(stat -c%s "$p")B/$(stat -c%s "$b")B  $eq"
done
( cd "$OUT" && sha256sum *.bin > SHA256SUMS.txt )
echo "OK  输出目录: $OUT（12 件 + SHA256SUMS.txt）"
if [ "$RESET_AFTER" -eq 1 ]; then
	echo "[reset] 显式踢出 9008"
	timeout -k 10 120 "$QDL" -s ufs "$LOADER" reset 2>&1 | tail -2 || echo "WARN qdl reset 失败（设备可能已自行离开 9008）" >&2
else
	echo "设备仍在 EDL(9008)（每条 qdl 都带 -R）。要回正常启动加 --reset-after 或手工 qdl reset"
fi
echo "下一步：python3 scripts/gpt-audit-tb322fc.py --dev $OUT --stock ~/文档/TB322FC_15.10.259"
