#!/bin/bash
# recover-lun4-slotguid.sh — 修「ABL 报 ValidateSlotGuids: BootableSlot _<x> does not have valid guids ⇒ 掉 fastboot」。
#
# 为什么（2026-11-21 晚实测）：`fastboot --set-active` 会在两个槽之间搬 partition **type GUID**，
# 连续/重复调用会留下「GUID 侧 ≠ ACTIVE 位」的半完成态；ABL 在 FindBootableSlot() 里判 GUID 非法，
# 直接 LoadImageAndAuth → Device Error → Launching fastboot（内核根本没跑）。
# 取证口径：EDL 读 LUN4 主/备表 + `logfs` 里 FAT12 卷内的 `UEFILOG1.TXT`（`mdir -i logfs.bin ::/`）。
# 全账：reports/bootloader-slotguid-brick-20261121.md
#
# 用法：
#   scripts/recover-lun4-slotguid.sh                       # 默认 dry-run：只读设备现表 + 打印判定
#   scripts/recover-lun4-slotguid.sh --apply               # 真正写回（走 linux-gpt-apply.sh，带读回校验）
#   scripts/recover-lun4-slotguid.sh --from-dir DIR --dry-run   # 离线：用 DIR 里现成的表干跑判定
#   scripts/recover-lun4-slotguid.sh --baseline DIR        # 指定「已知好」的基线表目录（默认见下）
#
# 判定优先级：
#   1) 现表 type GUID 与基线不同（GUID 侧被搬过）⇒ **写回基线那对表**（几何必须逐分区一致，否则拒绝）；
#   2) GUID 与基线一致、只有 ACTIVE 位不在目标槽 ⇒ 用 gpt-slot-flip-active.py 只补属性位；
#   3) 两者都一致 ⇒ 什么都不做（问题不在 GPT，去查 boot 内容 / vbmeta）。
#
# 纪律：一条命令只碰一个通道；fastboot 一律显式 -s；外命令全 timeout -k；写盘只经 linux-gpt-apply.sh。
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SN=${SN:-HA2EXB0E}
LUN=${LUN:-4}
SLOT=${SLOT:-b}
BASE=${BASE:-$ROOT/backup/$SN-16+512/edl-20261120-2208}
QDL=${QDL:-$HOME/edl/qdl/build/qdl}
LOADER=${LOADER:-$HOME/下载/tb322fc/xbl_s_devprg_ns.melf}
FB=${FB:-fastboot}
APPLY=0
FROM_DIR=""
OUT=${OUT:-$ROOT/logs/recover-slotguid-$(date +%Y%m%d-%H%M%S)}

while [ $# -gt 0 ]; do
	case "$1" in
		--apply) APPLY=1; shift ;;
		--dry-run) APPLY=0; shift ;;
		--from-dir) FROM_DIR=$2; shift 2 ;;
		--baseline) BASE=$2; shift 2 ;;
		-h|--help) sed -n '2,26p' "$0"; exit 0 ;;
		*) echo "未知参数 $1（--help）" >&2; exit 2 ;;
	esac
done

mkdir -p "$OUT"
say() { printf '%s\n' "$*"; }
die() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

BASE_M=$BASE/gpt$LUN-primary.bin
BASE_B=$BASE/gpt$LUN-backup.bin
[ -e "$BASE_M" ] && [ -e "$BASE_B" ] || die "基线表缺失: $BASE_M / $BASE_B"

# ---------- 1) 取得设备现表 ----------
if [ -n "$FROM_DIR" ]; then
	CUR_M=$FROM_DIR/gpt$LUN-primary.bin
	CUR_B=$FROM_DIR/gpt$LUN-backup.bin
	[ -e "$CUR_M" ] || die "--from-dir 里没有 gpt$LUN-primary.bin"
else
	[ -e "$QDL" ] || die "缺 qdl: $QDL"
	[ -e "$LOADER" ] || die "缺 loader: $LOADER"
	say "[1/5] 确认 fastboot 会话可用（能枚举但 getvar 无回包 = ABL 半挂，只能物理长按电源）"
	probe=$(timeout -k 5 20 "$FB" -s "$SN" getvar current-slot 2>&1 | head -1)
	[ -n "$probe" ] || die "fastboot 无回包（$probe 空）⇒ 物理断电/长按电源后再来"
	echo "$probe" | grep -q 'current-slot' || die "getvar 异常输出: $probe"
	say "  $probe"
	say "[2/5] 进 EDL(9008)"
	timeout -k 5 30 "$FB" -s "$SN" oem edl >/dev/null 2>&1 || true
	for i in $(seq 1 20); do
		sleep 2
		lsusb -d 05c6:9008 >/dev/null 2>&1 && { say "  9008 up (${i}×2s)"; break; }
		[ "$i" = 20 ] && die "等不到 9008（先查线/供电，别猜内核）"
	done
	say "[3/5] 读 LUN$LUN 主表（LBA0..5）"
	timeout -k 10 200 "$QDL" -s ufs -R "$LOADER" read "$LUN/0+6" "$OUT/gpt$LUN-primary.bin" 2>&1 | tail -2 \
		|| die "读主表失败"
	ALT=$(python3 - "$OUT/gpt$LUN-primary.bin" <<'PY'
import struct,sys
b=open(sys.argv[1],'rb').read()
h=b[4096:4096+92]
if h[:8]!=b'EFI PART': sys.exit("no EFI PART")
print(struct.unpack_from('<Q',h,32)[0])
PY
) || die "主表解析失败"
	[ -n "$ALT" ] || die "取不到 alt_lba"
	say "  alt_lba=$ALT ⇒ 读备表 LBA $((ALT-4))..$ALT"
	timeout -k 10 200 "$QDL" -s ufs -R "$LOADER" read "$LUN/$((ALT-4))+5" "$OUT/gpt$LUN-backup.bin" 2>&1 | tail -2 \
		|| die "读备表失败"
	CUR_M=$OUT/gpt$LUN-primary.bin
	CUR_B=$OUT/gpt$LUN-backup.bin
fi

# ---------- 2) 判定 ----------
say "[4/5] 与基线逐分区比 type GUID / 几何 / ACTIVE 位"
DECISION=$(python3 - "$CUR_M" "$CUR_B" "$BASE_M" "$BASE_B" "$SLOT" <<'PY'
import struct,sys,uuid
cur_m,cur_b,base_m,base_b,slot=sys.argv[1:6]
def load(p):
    d=open(p,'rb').read(); off=d.find(b'EFI PART')
    if off<0: sys.exit("no EFI PART in "+p)
    nent,esize=struct.unpack_from('<II',d,off+80)
    start=off+512
    out={}
    for i in range(nent):
        e=d[start+i*esize:start+(i+1)*esize]
        if len(e)<esize or e[:16]==b'\x00'*16: continue
        name=e[56:128].decode('utf-16-le').rstrip('\x00')
        out[name]=dict(guid=str(uuid.UUID(bytes_le=e[16:32])),
                       first=struct.unpack_from('<Q',e,32)[0],
                       last=struct.unpack_from('<Q',e,40)[0],
                       attr=struct.unpack_from('<Q',e,48)[0])
    return out
c=load(cur_m); b=load(base_m)
guid_diff=[n for n in b if n not in c or c[n]['guid']!=b[n]['guid']]
geo_diff=[n for n in b if n in c and (c[n]['first'],c[n]['last'])!=(b[n]['first'],b[n]['last'])]
extra=[n for n in c if n not in b]
def active_side(recs):
    # 属性字段低 8 字节里的 byte6：bit2 = ACTIVE（AOSP/Qualcomm AB_FLAG_OFFSET；
    # 与 scripts/gpt-slot-flip-active.py 的 ABYTE_ENTRY_OFF = 48+6 同源）
    return [n[-1] for n in ('boot_a','boot_b') if n in recs and (((recs[n]['attr'] >> 48) & 0xff) & 0x04)]
cur_act=active_side(c)
print("GUID_DIFF", len(guid_diff), ",".join(guid_diff[:8]))
print("GEO_DIFF", len(geo_diff), ",".join(geo_diff[:8]))
print("EXTRA", len(extra), ",".join(extra[:5]))
print("CUR_ACTIVE", ",".join(cur_act) or "-")
print("SLOT", slot)
# ABL 的判据原文（build/uefi-woa-prep/.../PartitionTableUpdate.c:1568-1579）：
#   if (boot_<slot>.PartitionTypeGUID == abl_<slot>.PartitionTypeGUID) return EFI_DEVICE_ERROR;
beq = (c.get('boot_'+slot, {}).get('guid') is not None
       and c.get('boot_'+slot, {}).get('guid') == c.get('abl_'+slot, {}).get('guid'))
print("BOOT_ABL_EQUAL", "yes" if beq else "no")
PY
) || die "比较失败"
say "$DECISION" | sed 's/^/  /'
GUID_N=$(echo "$DECISION" | awk '/^GUID_DIFF/{print $2}')
GEO_N=$(echo "$DECISION" | awk '/^GEO_DIFF/{print $2}')
EXTRA_N=$(echo "$DECISION" | awk '/^EXTRA/{print $2}')
CUR_ACT=$(echo "$DECISION" | awk '/^CUR_ACTIVE/{print $2}')
BOOL_ABL=$(echo "$DECISION" | awk '/^BOOT_ABL_EQUAL/{print $2}')
[ "$BOOL_ABL" = yes ] && say "  ⚠ boot_$SLOT 与 abl_$SLOT 的 type GUID 相同 = ABL 判据命中的形态（PartitionTableUpdate.c:1568）"

[ "${EXTRA_N:-0}" = 0 ] || die "现表多出基线里没有的分区（几何已被改过）⇒ 不要写旧表，先人工裁决"
[ "${GEO_N:-0}" = 0 ] || die "几何不一致（$GEO_N 个分区 LBA 不同）⇒ 拒绝写旧表：写回只让 GPT 回到旧样子，被覆盖的数据回不来"

if [ "${GUID_N:-0}" != 0 ]; then
	action="write-baseline"
	say "  ⇒ GUID 侧被搬过（$GUID_N 个分区）⇒ 写回基线表（当时 $SLOT 槽能正常起 Linux）"
else
	if [ "$CUR_ACT" = "$SLOT" ]; then
		action="noop"
		say "  ⇒ GUID 与几何都和基线一致，且 ACTIVE 已在 _$SLOT：**问题不在 GPT**（去查 boot 内容 / vbmeta / logfs 里的 ABL 原文）"
	else
		action="flip-attr"
		say "  ⇒ GUID 与基线一致，只是 ACTIVE 位在 _$CUR_ACT ⇒ 只补属性位到 _$SLOT"
	fi
fi

if [ "$action" = noop ]; then
	say "[5/5] 不需要写盘"; exit 0
fi

SRC_M=$BASE_M; SRC_B=$BASE_B
if [ "$action" = flip-attr ]; then
	python3 "$ROOT/scripts/gpt-slot-flip-active.py" --main "$CUR_M" --backup "$CUR_B" \
		--out-prefix "$OUT/lun$LUN-flip" --activate "$SLOT" || die "flip 失败"
	SRC_M=$OUT/lun$LUN-flip_main.bin; SRC_B=$OUT/lun$LUN-flip_backup.bin
fi

say "[5/5] 写盘计划：$SRC_M / $SRC_B"
if [ "$APPLY" != 1 ]; then
	say "（dry-run：未写。加 --apply 执行；执行后设备会自动回正常启动）"
	say "  现表与基线留在 $OUT/"
	exit 0
fi
[ -z "$FROM_DIR" ] || die "--from-dir 只用于干跑，不能 --apply（没有设备通道）"
bash "$ROOT/scripts/linux-gpt-apply.sh" --lun "$LUN" --gpt "$SRC_M" --backup "$SRC_B" --apply --reset || die "写盘失败（看 $OUT）"
say "写入完成。等设备回 BL/fastboot 后再普通重启：fastboot -s $SN reboot"
say "判据：ssh 回 uname -r = vk192；qbootctl -a 的 _$SLOT = Active/Successful/Bootable 全 1"
