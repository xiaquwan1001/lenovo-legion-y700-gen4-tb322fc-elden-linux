#!/bin/bash
# abl-log.sh — 从在机 Linux 读 ABL/PBL 启动日志（logfs 分区里的 UEFILOG1.TXT）
#
# 背景：Qualcomm ABL 把**本次启动**的完整日志写进 `logfs` 分区（FAT12，
# 内含 UEFILOG1.TXT，64 KiB 上限）。日志覆盖 PBL 时间戳 → XBL → ABL
# （含 `Launching fastboot` 与 `fastboot boot` 之后的 cmdline/RAM 分区表）
# → `Start EBS` 交棒。**无持久化**：每次新启动重写，掉电/复位后即丢。
#
# 用法：
#   scripts/abl-log.sh                 # 输出最近一次启动的 ABL 日志（默认 stdout）
#   scripts/abl-log.sh -o /tmp/abl.txt # 落盘
#   scripts/abl-log.sh -g FF300000     # 只看匹配行（grep -a）
#   RDEV=root@192.168.7.1 scripts/abl-log.sh
#
# 判据类用法（UEFI 线）：`fastboot boot` 交棒失败后**设备会回落 stock Android**，
# 那次回落就是一次新启动 ⇒ **失败那次的 ABL 日志被覆盖，抓不到**。
# 因此本脚本能给出的硬证据只有「本机的 RAM 分区表真值」（UEFI_BASE 是否可用）。
set -euo pipefail

RDEV=${RDEV:-root@192.168.7.1}
PART=${PART:-/dev/sde68}     # logfs，随机型/容量档可能变；用 lsblk -o NAME,PARTLABEL | grep logfs 核对
OUT=""
PAT=""

while getopts "o:g:p:r:" o; do
  case $o in
    o) OUT=$OPTARG ;;
    g) PAT=$OPTARG ;;
    p) PART=$OPTARG ;;
    r) RDEV=$OPTARG ;;
    *) echo "usage: $0 [-o out] [-g pattern] [-p /dev/sdX] [-r user@host]" >&2; exit 2 ;;
  esac
done

TMP=$(mktemp /tmp/logfs.XXXXXX.img)
trap 'rm -f "$TMP"' EXIT

ssh -o BatchMode=yes -o ConnectTimeout=8 "$RDEV" "dd if=$PART bs=1M count=8 2>/dev/null" > "$TMP"
[ -s "$TMP" ] || { echo "empty read from $RDEV:$PART" >&2; exit 1; }

TXT=$(mktemp /tmp/abl.XXXXXX.txt)
trap 'rm -f "$TMP" "$TXT"' EXIT
python3 - "$TMP" > "$TXT" <<'PY'
import sys
img = open(sys.argv[1], 'rb').read()
fat = img[4096:8192]
def ent(i):
    o = i * 3 // 2
    return (fat[o] >> 4) | (fat[o+1] << 4) if i % 2 else fat[o] | ((fat[o+1] & 0xf) << 8)
# 根目录第 2 项 = UEFILOG1.TXT（第 0 项是卷标，第 1 项是 LFN）
root = img[12288:12288 + 512 * 32]
e = root[2 * 32:3 * 32]
name = e[0:11].decode('latin1').strip()
if not name.startswith('UEFILOG'):
    sys.exit(f"unexpected root entry 2: {name!r}")
size = int.from_bytes(e[28:32], 'little')
clus, out = int.from_bytes(e[26:28], 'little'), b''
while clus < 0xff8 and len(out) < size:
    out += img[28672 + (clus - 2) * 4096: 28672 + (clus - 1) * 4096]
    clus = ent(clus)
sys.stdout.write(out[:size].decode('latin1'))
PY

if [ -n "$PAT" ]; then
  grep -a -E "$PAT" "$TXT" || { echo "(no match for '$PAT')" >&2; exit 3; }
elif [ -n "$OUT" ]; then
  cp "$TXT" "$OUT"; echo "wrote $OUT ($(wc -c < "$TXT") B)" >&2
else
  cat "$TXT"
fi
