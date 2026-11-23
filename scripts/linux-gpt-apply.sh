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
#   --restore DIR 用 DIR 里的 gpt<LUN>-primary.bin / gpt<LUN>-backup.bin 回滚（等价于换一对输入）
#   --reset       写后显式 `qdl reset` 把设备踢出 9008（默认**不**踢：留在 EDL 便于连续操作）
#
# 硬约束：
#   * 写前 **live-GPT 交叉核对**（2026-11-18）：从设备现表与新表逐分区比几何；新表会删掉
#     「现表里还存在的分区」时默认**拒绝写**（拿错表/覆盖冲突），确属删分区请 `ALLOW_DROP=1`。
#     打印 `~ 名字: (first,last) -> (first,last)` 即为几何变化，逐条看过再动手。
#   * 扇区大小 = **4096 B**（本机 TB322FC 实测）；主表 = LUN 的 LBA0..5（6 扇区 = 24576 B），
#     备表 = LBA `alt_lba-4 .. alt_lba`（5 扇区 = 20480 B，末尾 4096 B 是备份头）。
#   * 写前必须已有当前表 dump：本脚本在**同一条 qdl 命令里**先读一次 LBA0..5 落盘
#     （`$READDIR/pre-write-primary.bin`，失败路径也留），这就是本次的回退基线。
#   * `qdl -R` = `--skip-reset`（**跳过**会话末尾的 reset），作用只是「让设备留在 9008」；
#     要真把设备踢出 9008 必须另发 `qdl <loader> reset`（`--reset`）。旧注释把它写成
#     「末发 -R reset」是反的（PITFALLS #674/#675 的成因之一）。
#   * 写后读回逐字节比对 sha256，加 `qdl sha256` 设备端摘要当第二把尺子（#669），不一致 ⇒ rc=1。
#   * 写顺序 = **先备表后主表**：中途掉电只会留下「新备表 + 旧主表」，主表仍自洽可比。
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
# sha_direct <文件>：**O_DIRECT 直读**算 sha256（绕过页缓存），工具回退 buffered 时 shell 侧
# 兜底并打 WARN。为什么必须 O_DIRECT（2026-11-20 实测）：页缓存被污染时 buffered 连读多次
# 「稳定但错」（v1 件 637a9965… vs 真值 e3d0d26f…），旧「双 sha256 硬门」抓不到。
# 工具：scripts/odirect-sha.py（--tsv 第 3 列 = sha）；取证：reports/odirect-sha-gate-20261120.md。
ODIRECT_SHA=${ODIRECT_SHA:-$(cd "$(dirname "$0")/.." && pwd)/scripts/odirect-sha.py}
sha_direct() {
	local f=$1 out v
	[ -n "$f" ] && [ -e "$f" ] || { printf '%s\n' ""; return 0; }
	out=$(timeout -k 10 1800 python3 "$ODIRECT_SHA" --tsv "$f" 2>&1)
	v=$(printf '%s\n' "$out" | awk -F'\t' 'NR==1{print $3}')
	if [ -z "$v" ] || [ "${#v}" != 64 ]; then
		v=$(sha256sum "$f" | cut -d' ' -f1)
		echo "WARN sha_direct: $f 未走 O_DIRECT（$out），退回 buffered（结果可能被页缓存污染）" >&2
	fi
	printf '%s\n' "$v"
}

LUN=""; MAIN=""; BACKUP=""; APPLY=0; ENTER_EDL=0; RESTORE=""; DO_RESET=0
SN=${SN:-HA2EXB0E}
# 主机工具落点 + 在线判据统一（PITFALLS #584 禁 `fastboot devices | grep -q`；#699 fastboot 不在 PATH）
. "$(dirname "$0")/lib-hosttools.sh"
ensure_hosttools --quiet
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
		--reset) DO_RESET=1; shift ;;
		--restore) RESTORE=$2; shift 2 ;;
		-h|--help) sed -n '2,31p' "$0"; exit 0 ;;
		*) echo "未知参数 $1（--help 看用法）" >&2; exit 2 ;;
	esac
done
[ -n "$LUN" ] || { echo "缺 --lun" >&2; exit 2; }
if [ -n "$RESTORE" ]; then
	[ -d "$RESTORE" ] || { echo "--restore 目录不存在: $RESTORE" >&2; exit 2; }
	[ -n "$MAIN" ] || MAIN=$RESTORE/gpt$LUN-primary.bin
	[ -n "$BACKUP" ] || BACKUP=$RESTORE/gpt$LUN-backup.bin
fi
[ -n "$MAIN" ] && [ -n "$BACKUP" ] || { echo "缺 --lun/--gpt(--main)/--backup（或 --restore DIR）" >&2; exit 2; }
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
echo "  主表   写入 LBA 0..5              $(basename "$MAIN")  ${msz} B  sha=$(sha_direct "$MAIN" | cut -c1-16)"
echo "  备表   写入 LBA ${BKP_START}..${ALT_LBA}   $(basename "$BACKUP")  ${bsz} B  sha=$(sha_direct "$BACKUP" | cut -c1-16)"
echo "  分区数（新表有效条目）= ${NPARTS}   扇区 = 4096 B"
echo "  表校验 = ${TBLCHK}"
if [ "$APPLY" -eq 0 ]; then
	echo "（dry-run：未写盘。加 --apply 执行；--enter-edl 可自动切 9008）"
	exit 0
fi

# 串行化：写 GPT 期间不允许别的 agent 碰设备（PITFALLS 与 scripts/lib-device-lock.sh）
. "$ROOT/scripts/lib-device-lock.sh"
device_lock_acquire

if [ "$ENTER_EDL" -eq 1 ]; then
	if dev_present adb "$SN"; then
		echo "[edl] adb reboot edl ($SN)"; timeout -k 5 20 adb -s "$SN" reboot edl || true
	elif dev_present fastboot "$SN"; then
		echo "[edl] fastboot oem edl ($SN)"; timeout -k 5 20 fastboot -s "$SN" oem edl || true
	else
		echo "!! 设备既不在 adb 也不在 fastboot；请人工进 EDL 后再跑（不加 --enter-edl）" >&2; exit 1
	fi
	sleep 8
fi
timeout -k 5 10 lsusb | grep -q '05c6:9008' || { echo "!! 未枚举到 05c6:9008（EDL）；中止，未写任何东西" >&2; exit 1; }

mkdir -p "$READDIR"
echo "[write] 主备双表（单次 qdl 会话：读旧表留回退 → 写备表 → 写主表 → 读回 → 设备端 sha256）"
# 顺序理由：① 先读设备当前 LBA0..5（回退基线，失败也留）；② 写备表再写主表（中途掉电主表仍自洽）；
# ③ 读回两段做逐字节比对；④ 同一条命令里让设备端算 sha256 当第二把尺子（PITFALLS #669）。
# `-R` = --skip-reset ⇒ 会话结束后设备**留在 9008**（不是「执行 reset」）；要踢出用 --reset。
# 分两条 qdl 命令是**有意**的：旧备表位置要先解析旧主表才知道，而解析必须发生在写之前。
# 两条命令都带 -R（跳过会话末尾 reset）⇒ 设备在两条之间留在 9008，不会再触发 #674 的
# 「上一发结束即 reset、下一发 SAHARA failed to read request」。
timeout -k 10 120 "$QDL" -s ufs -R "$LOADER" \
	read "$LUN/0+6" "$READDIR/pre-write-primary.bin" \
	2>&1 | tee "$READDIR/qdl-pre.log" | tail -3
# ── live-GPT 交叉核对（2026-11-18 审计 R1 P0-③；2026-11-19 抽成 scripts/gpt-preflight.py = LTBox P0-5）
#    写目标 LBA 只来自主机件时，dump 一过期就会把新数据写进「在用分区的中段」，而脚本仍会打印读回一致。
#    判据（工具侧，`compare` 子命令）：新表**少掉**一个现表还存在的分区 ⇒ 默认拒绝（ALLOW_DROP=1 放过）；
#    同时报「起点/跨度变化」与重名分区（按 label 定位的歧义源），并在读表时就校验头/条目 CRC。
#    工具的离线自检：`python3 scripts/gpt-preflight.py --selftest`（doctor §21 每轮跑）。
GPTPRE=$ROOT/scripts/gpt-preflight.py
[ -f "$GPTPRE" ] || GPTPRE=$(dirname "$0")/gpt-preflight.py
DROP_FLAG=""; [ -n "${ALLOW_DROP:-}" ] && DROP_FLAG="--allow-drop"
if ! python3 "$GPTPRE" compare --base-main "$READDIR/pre-write-primary.bin" \
     --main "$MAIN" $DROP_FLAG; then
	echo "!! live-GPT 交叉核对失败/被拒；未写任何东西（确认要删分区请 ALLOW_DROP=1 重跑）" >&2
	exit 1
fi
# 写前复验快照（P0-5 的另一半）：把现表落成快照，写后在同样口径下可 `verify` 回来。
# 快照落不下不阻塞本次写（读表本身已过 compare），但下一次实验必须能拿它复核。
python3 "$GPTPRE" snapshot --main "$READDIR/pre-write-primary.bin" \
	-o "$READDIR/pre-write-snapshot.json" >/dev/null \
	|| echo "WARN 写前快照落盘失败（$READDIR/pre-write-snapshot.json）；本次仍继续，但事后无法复验" >&2

OLD_ALT=$(python3 - "$READDIR/pre-write-primary.bin" <<'PY' 2>/dev/null || true
import struct,sys
b=open(sys.argv[1],'rb').read()
h=b[4096:4096+92]
if len(b) < 4096+92 or h[:8]!=b'EFI PART': sys.exit(1)
print(struct.unpack_from('<Q',h,32)[0])
PY
)
if [ -n "$OLD_ALT" ] && [ "$OLD_ALT" -gt 5 ]; then
	echo "写前旧表备表 LBA $((OLD_ALT-4))..$OLD_ALT（存 $READDIR/pre-write-backup.bin）"
	OLD_BKP=$((OLD_ALT-4))
	timeout -k 10 120 "$QDL" -s ufs -R "$LOADER" \
		read "$LUN/$OLD_BKP+5" "$READDIR/pre-write-backup.bin" \
		2>&1 | tee -a "$READDIR/qdl-pre.log" | tail -2
else
	echo "!! 拿不到写前主表（回退基线缺失）⇒ 即使写成功也 rc=1；先跑 scripts/linux-gpt-dump.sh" >&2
	OLD_BKP=""
fi

timeout -k 10 420 "$QDL" -s ufs -R "$LOADER" \
	write "$LUN/$BKP_START" "$BACKUP" \
	write "$LUN/0" "$MAIN" \
	read "$LUN/0+6" "$READDIR/gpt$LUN-primary.bin" \
	read "$LUN/$BKP_START+5" "$READDIR/gpt$LUN-backup.bin" \
	sha256 "$LUN/0+6" \
	sha256 "$LUN/$BKP_START+5" \
	2>&1 | tee "$READDIR/qdl.log" | tail -14
if [ -s "$READDIR/pre-write-primary.bin" ]; then
	echo "回退基线: $READDIR/pre-write-primary.bin sha=$(sha_direct "$READDIR/pre-write-primary.bin" | cut -c1-16)$([ -s "$READDIR/pre-write-backup.bin" ] && echo " + pre-write-backup.bin")"
fi

ok=1
for pair in "main:$MAIN:$READDIR/gpt$LUN-primary.bin" "backup:$BACKUP:$READDIR/gpt$LUN-backup.bin"; do
	kind=${pair%%:*}; rest=${pair#*:}; want=${rest%%:*}; got=${rest#*:}
	if [ ! -s "$got" ]; then echo "FAIL $kind 读回缺文件 $got"; ok=0; continue; fi
	a=$(sha_direct "$want"); b=$(sha_direct "$got")
	if [ "$a" = "$b" ]; then echo "OK   $kind 读回逐字节一致 sha=${a:0:16}"; else echo "FAIL $kind 读回不一致 want=${a:0:16} got=${b:0:16}"; ok=0; fi
done
echo "读回件目录: $READDIR（命名 = gpt${LUN}-{primary,backup}.bin，可直接给 gpt-audit 的 --dev）"

# 第二把尺子：设备端 sha256（不经 USB 传数据，见 PITFALLS #669）。qdl 每行一个 64 位 hex。
mapfile -t devsha < <(grep -E '^[0-9a-f]{64}$' "$READDIR/qdl.log" || true)
if [ "${#devsha[@]}" -eq 2 ]; then
	i=0
	for pair in "main:$MAIN" "backup:$BACKUP"; do
		kind=${pair%%:*}; want=${pair#*:}
		h=$(sha_direct "$want")
		if [ "$h" = "${devsha[$i]}" ]; then echo "OK   $kind 设备端 sha256 一致 sha=${h:0:16}"
		else echo "FAIL $kind 设备端 sha256 不符 host=${h:0:16} dev=${devsha[$i]:0:16}"; ok=0; fi
		i=$((i+1))
	done
else
	echo "WARN 设备端 sha256 未取到（loader 不支持 getsha256digest 时会跳过）⇒ 只用读回件做判据" >&2
fi

if [ -s "$READDIR/pre-write-primary.bin" ] && [ -s "$READDIR/pre-write-backup.bin" ]; then
	echo "回滚（若新表起不来）:"
	echo "  mkdir -p $READDIR/rollback && cp $READDIR/pre-write-primary.bin $READDIR/rollback/gpt$LUN-primary.bin"
	echo "  cp $READDIR/pre-write-backup.bin $READDIR/rollback/gpt$LUN-backup.bin"
	echo "  $0 --lun $LUN --restore $READDIR/rollback --apply --reset"
	echo "  ↑ #675 口径：新表若改动了在用分区的 LBA 区间，回滚表只让 GPT 回到旧样子，被覆盖的数据回不来"
else
	echo "!! 回退基线不齐（写前主/备表没取全）⇒ rc=1；以后先跑 scripts/linux-gpt-dump.sh" >&2
	ok=0
fi

if [ "$DO_RESET" -eq 1 ]; then
	echo "[reset] 显式踢出 9008（qdl 的 -R 只跳过 reset，这一步才是真 reset）"
	timeout -k 10 120 "$QDL" -s ufs "$LOADER" reset 2>&1 | tail -2 \
		|| { echo "!! qdl reset 失败（#675：设备可能已自行离开 9008）⇒ 手工确认设备状态" >&2; ok=0; }
else
	echo "设备仍在 EDL(9008)（-R 跳过 reset）。要回正常启动：scripts/… 或 \"$QDL -s ufs $LOADER reset\""
fi
[ "$ok" -eq 1 ] || exit 1
echo "下一步（P1 判据）：读回目录跑 python3 scripts/gpt-audit-tb322fc.py --dev <dir> --stock ~/文档/TB322FC_15.10.259"
