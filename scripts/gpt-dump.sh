#!/bin/sh
# gpt-dump.sh — 在设备（mainline Linux）上 dump LUN0 GPT 主/备表
#
# 为什么不用 sgdisk/gdisk：本机 UFS 逻辑扇区 = 4096 B，sgdisk 按 512 解析会读错。
# 布局（4096 B 扇区，同型号通用；234 GiB 档首次实测）：LBA0 MBR / LBA1 主头 / LBA2 主条目(32×128B)=1 扇区；
#   主表取 LBA0..5（6 扇区，LBA3..5 落在 first_usable 前，安全）；
#   备表 = [backup_lba-4 .. backup_lba]（5 扇区：条目区 4 + 头 1）——与
#   scripts/gpt-surgery-tb322fc.py 的 --backup 期望完全一致。
#
# 用法（设备上 root）：
#   DEV=/dev/sda PREFIX=/tmp/gpt-new sh gpt-dump.sh
# 产出：$PREFIX-primary.bin（24576 B）、$PREFIX-backup.bin（20480 B）
# 主机侧取回：
#   BAK=backup/<SN>-<容量档>   (例 backup/HA2ABH62-12+256  —— 按 ../DEVICE/README.md §2.2 命名，勿用 new-tablet)
#   scp root@192.168.7.1:/tmp/gpt-new-primary.bin "$BAK"/gpt_main0.bin
#   scp root@192.168.7.1:/tmp/gpt-new-backup.bin  "$BAK"/gpt_backup0.bin
set -eu
DEV=${DEV:-/dev/sda}
PREFIX=${PREFIX:-/tmp/gpt}
SECT=4096

[ -b "$DEV" ] || { echo "not a block device: $DEV" >&2; exit 1; }

echo "[gpt-dump] primary (LBA0..5)"
dd if="$DEV" bs=$SECT count=6 of="$PREFIX-primary.bin" 2>/dev/null

# backup_lba = GPT header 偏移 0x20 的 8 字节 LE（主头在扇区 1，故文件偏移 4096+32）
BLBA=$(od -An -tu8 -j$((SECT + 32)) -N8 "$PREFIX-primary.bin" | tr -d ' ')
[ -n "$BLBA" ] && [ "$BLBA" -gt 5 ] || { echo "bad backup_lba='$BLBA'" >&2; exit 1; }
LASTU=$(od -An -tu8 -j$((SECT + 48)) -N8 "$PREFIX-primary.bin" | tr -d ' ')
echo "[gpt-dump] backup_lba=$BLBA last_usable=$LASTU"

echo "[gpt-dump] backup (LBA $((BLBA-4))..$BLBA)"
dd if="$DEV" bs=$SECT skip=$((BLBA - 4)) count=5 of="$PREFIX-backup.bin" 2>/dev/null

ls -la "$PREFIX-primary.bin" "$PREFIX-backup.bin"
sha256sum "$PREFIX-primary.bin" "$PREFIX-backup.bin"
