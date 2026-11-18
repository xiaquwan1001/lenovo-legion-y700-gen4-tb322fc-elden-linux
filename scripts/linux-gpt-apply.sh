#!/bin/bash
# linux-gpt-apply.sh — 把一对 GPT 表（主表 6 扇区 + 备表 5 扇区）写进指定 LUN，**写后读回对账**。
#
# 为什么需要它（RUNBOOK-BRINGUP/GPT-MINIMAL-DESIGN.md §7 待补 1；LINUX-STATE-REPRO.md §8）：
#   过去「写表」是两步手工（Linux 内 dd / 主机 qdl），且没有强制的读回校验；
#   2026-11-17 的教训是「printgpt 能解析 ≠ 逐字节对」。
#
# 用法：
#   scripts/linux-gpt-apply.sh --lun 0 --gpt out/gpt-minimal-20261118/lun0_main0.bin \
#                                      --backup out/gpt-minimal-20261118/lun0_backup0.bin
#        ↑ `--gpt` = `--main`（2026-11-18 按 A5 口径加别名）；默认只打印计划（dry-run）
#   scripts/linux-gpt-apply.sh ... --dry-run  # 显式 dry-run（与默认行为相同，便于脚本统一）
#   scripts/linux-gpt-apply.sh ... --apply     # 真正写（需设备已在 EDL 9008 或本脚本 --enter-edl）
#
#   --enter-edl   先 `adb reboot edl`（设备在 Android 时）或 `fastboot oem edl`（fastboot 时）再写
#   --restore     用同一个 --lun 的 backup 目录件回滚（等价于换一对输入）
#
# 硬约束：
#   * 扇区大小 = **4096 B**（本机 TB322FC 实测）；主表 = LUN 的 LBA0..5（6 扇区 = 24576 B），
#     备表 = LBA `alt_lba-4 .. alt_lba`（5 扇区 = 20480 B，末尾 4096 B 是备份头）。
#   * 写前必须已有当前表 dump（本脚本**不**替你备份；`scripts/linux-gpt-dump.sh` 负责）。
#   * `qdl` 多次调用必须显式 reset；本脚本一次调用写完主备 + 一次读回，最后 reset。
#   * 写后读回逐字节比对 sha256，不一致 ⇒ rc=1。
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
LUN=""; MAIN=""; BACKUP=""; APPLY=0; ENTER_EDL=0
SN=${SN:-HA2EXB0E}
LOADER=${LOADER:-$HOME/下载/tb322fc/xbl_s_devprg_ns.melf}
QDL=${QDL:-$HOME/edl/qdl/build/qdl}
READDIR=${READDIR:-$ROOT/backup/$SN-16+512/edl-apply-readback-$(date +%Y%m%d-%H%M%S)}

while [ $# -gt 0 ]; do
	case "$1" in
		--lun) LUN=$2; shift 2 ;;
		--main|--gpt) MAIN=$2; shift 2 ;;
		--backup) BACKUP=$2; shift 2 ;;
		--apply) APPLY=1; shift ;;
		--dry-run) APPLY=0; shift ;;
		--enter-edl) ENTER_EDL=1; shift ;;
		-h|--help) sed -n '2,29p' "$0"; exit 0 ;;
		*) echo "未知参数 $1（--help 看用法）" >&2; exit 2 ;;
	esac
done
[ -n "$LUN" ] && [ -n "$MAIN" ] && [ -n "$BACKUP" ] || { echo "缺 --lun/--gpt(--main)/--backup" >&2; exit 2; }
for f in "$MAIN" "$BACKUP" "$LOADER" "$QDL"; do [ -e "$f" ] || { echo "缺文件: $f" >&2; exit 2; }; done
msz=$(stat -c%s "$MAIN"); bsz=$(stat -c%s "$BACKUP")
[ "$msz" -eq 24576 ] || { echo "--main 必须是 24576 B（6×4096），实际 $msz" >&2; exit 2; }
[ "$bsz" -eq 20480 ] || { echo "--backup 必须是 20480 B（5×4096），实际 $bsz" >&2; exit 2; }

# 从主表头取 alt_lba（备表头所在 LBA）与分区数；同时校验两张表**互相指向**、
# 两张表的 header CRC / entries CRC 与 entries 区逐字节相等（2026-11-18 加，
# 判据：写错一半的表比不写更贵 —— printgpt 能解析 ≠ 双表一致）
read -r ALT_LBA NPARTS TBLCHK < <(python3 - "$MAIN" "$BACKUP" <<'PY'
import struct,sys,zlib
main=open(sys.argv[1],'rb').read(); bak=open(sys.argv[2],'rb').read()

def table(b,off,label):
    if len(b) < off+92: sys.exit("%s: 文件长度不足表头"%label)
    h=b[off:off+92]
    if h[:8]!=b'EFI PART': sys.exit("%s: 表头不是 EFI PART (offset %d)"%(label,off))
    my,alt=struct.unpack_from('<QQ',h,24)
    entlba,=struct.unpack_from('<Q',h,72)
    nent,esize=struct.unpack_from('<II',h,80)
    ecrc,=struct.unpack_from('<I',h,88)
    hcrc,=struct.unpack_from('<I',h,16)
    tmp=bytearray(h); tmp[16:20]=b'\0'*4
    if zlib.crc32(bytes(tmp))&0xffffffff != hcrc:
        sys.exit("%s: header CRC 不符"%label)
    eoff=off+(entlba-my)*4096
    if eoff<0 or eoff+nent*esize>len(b):
        sys.exit("%s: entries 区越界（entlba=%d my=%d）"%(label,entlba,my))
    ent=b[eoff:eoff+nent*esize]
    if zlib.crc32(ent)&0xffffffff != ecrc:
        sys.exit("%s: entries CRC 不符"%label)
    return dict(my=my,alt=alt,ent=ent,nent=nent,esize=esize)

pm=table(main,4096,'primary')
bm=table(bak,len(bak)-4096,'backup')
if pm['alt']!=bm['my'] or bm['alt']!=pm['my']:
    sys.exit("两表互指不成立: primary.alt=%d backup.my=%d / backup.alt=%d primary.my=%d"
             %(pm['alt'],bm['my'],bm['alt'],pm['my']))
if pm['ent']!=bm['ent']:
    sys.exit("两表 entries 区不一致（备份表不是这张主表的备份）")
cnt=sum(1 for i in range(pm['nent']) if pm['ent'][i*pm['esize']:i*pm['esize']+16]!=b'\0'*16)
print(pm['alt'],cnt,"OK(双表 CRC+互指+entries 一致)")
PY
)
BKP_START=$((ALT_LBA-4))

echo "== 计划（LUN${LUN}）=="
echo "  主表   写入 LBA 0..5              $(basename "$MAIN")  ${msz} B  sha=$(sha256sum "$MAIN" | cut -c1-16)"
echo "  备表   写入 LBA ${BKP_START}..${ALT_LBA}   $(basename "$BACKUP")  ${bsz} B  sha=$(sha256sum "$BACKUP" | cut -c1-16)"
echo "  分区数（新表有效条目）= ${NPARTS}   扇区 = 4096 B"
echo "  表校验 = ${TBLCHK}"
if [ "$APPLY" -eq 0 ]; then
	echo "（dry-run：未写盘。加 --apply 执行；--enter-edl 可自动切 9008）"
	exit 0
fi

if [ "$ENTER_EDL" -eq 1 ]; then
	if timeout -k 5 6 adb devices | awk '{print $1}' | grep -qx "$SN"; then
		echo "[edl] adb reboot edl ($SN)"; timeout -k 5 20 adb -s "$SN" reboot edl || true
	elif timeout -k 5 8 fastboot devices | awk '{print $1}' | grep -qx "$SN"; then
		echo "[edl] fastboot oem edl ($SN)"; timeout -k 5 20 fastboot -s "$SN" oem edl || true
	else
		echo "!! 设备既不在 adb 也不在 fastboot；请人工进 EDL 后再跑（不加 --enter-edl）" >&2; exit 1
	fi
	sleep 8
fi
timeout -k 5 10 lsusb | grep -q '05c6:9008' || { echo "!! 未枚举到 05c6:9008（EDL）；中止，未写任何东西" >&2; exit 1; }

mkdir -p "$READDIR"
echo "[write] 主备双表（单次 qdl 会话，末发 -R reset）"
# 写 + 读回：同一会话里先写两段再读两段（qdl 一次调用内顺序执行）
timeout -k 10 420 "$QDL" -s ufs -R "$LOADER" \
	write "$LUN/0" "$MAIN" \
	write "$LUN/$BKP_START" "$BACKUP" \
	read "$LUN/0+6" "$READDIR/gpt$LUN-primary.bin" \
	read "$LUN/$BKP_START+5" "$READDIR/gpt$LUN-backup.bin" \
	2>&1 | tail -12

ok=1
for pair in "main:$MAIN:$READDIR/gpt$LUN-primary.bin" "backup:$BACKUP:$READDIR/gpt$LUN-backup.bin"; do
	kind=${pair%%:*}; rest=${pair#*:}; want=${rest%%:*}; got=${rest#*:}
	if [ ! -s "$got" ]; then echo "FAIL $kind 读回缺文件 $got"; ok=0; continue; fi
	a=$(sha256sum "$want" | cut -d' ' -f1); b=$(sha256sum "$got" | cut -d' ' -f1)
	if [ "$a" = "$b" ]; then echo "OK   $kind 读回逐字节一致 sha=${a:0:16}"; else echo "FAIL $kind 读回不一致 want=${a:0:16} got=${b:0:16}"; ok=0; fi
done
echo "读回件目录: $READDIR（命名 = gpt${LUN}-{primary,backup}.bin，可直接给 gpt-audit 的 --dev）"
[ "$ok" -eq 1 ] || { echo "!! 读回校验失败 ⇒ 用旧表回滚（同名目录里的 gpt${LUN}-{primary,backup}.bin）" >&2; exit 1; }
echo "下一步（P1 判据）：读回目录跑 python3 scripts/gpt-audit-tb322fc.py --dev <dir> --stock ~/文档/TB322FC_15.10.259"
