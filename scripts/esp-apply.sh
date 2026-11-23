#!/bin/bash
# esp-apply.sh — 把主机侧目录树「一条命令」组装成 FAT32 镜像并写进 eldenesp 分区（S5 自动化）。
#
# 为什么需要它（RUNBOOK-BRINGUP/LINUX-STATE-REPRO.md §8 第 2 条）：
#   过去 S5 是「手搓 FAT32 + mcopy 逐个文件 + 手工算分区 LBA」三步，设备回线时最容易漏件。
#   本脚本把「查表拿 LBA 区间 → 组装 → 逐文件 sha 自查 → 写盘 → 读回对账」收成一条命令，
#   默认 dry-run（只打印计划，不写盘、不碰设备）。
#
# 用法：
#   scripts/esp-apply.sh --esp-dir out/esp-20261116 --gpt reports/artifacts/bl-stuck-20261118/edl-read/gpt0-primary.bin
#        ↑ dry-run：校验必需件、算镜像尺寸与目标 LBA 区间、打印清单
#   scripts/esp-apply.sh --esp-dir out/esp-20261116 --gpt <dump> --apply [--enter-edl]
#        ↑ 真正写：组装 → mtype 逐文件 sha 自查 → qdl 写 → 读回 sha256 比对
#
# 选项：
#   --esp-dir DIR     源目录（必填）；文件按相对路径落到镜像根
#   --gpt FILE|DIR    LUN0 主表 dump：文件=24576 B 主表；目录=取 <目录>/gpt<LUN>-primary.bin
#   --part NAME       目标分区名（默认 eldenesp）
#   --lun N           LUN（默认 0）
#   --img FILE        镜像落盘路径（默认 out/esp-apply-<时间戳>/eldenesp.img）
#   --min-mib N       镜像下限 MiB（默认 64；内容更大时按内容 ×1.3 向上取整）
#   --apply           真正写盘（默认 dry-run）
#   --build-only      只组装镜像 + 自查，不写盘（离线自测用）
#   --enter-edl       先 adb/fastboot 切 9008 再写
#   --reset-after     写后显式 `qdl reset` 把设备踢出 9008（默认留在 EDL）
#   --dry-run         显式 dry-run（与默认相同）
#   --mtools-dir DIR  mcopy/mtype/mdir 所在目录（默认查 PATH，其次 ~/.local/opt/mtools/usr/bin）
#   -h|--help
#
# 硬约束：
#   * 扇区 4096 B（本机 TB322FC 实测）；镜像大小必须是 4096 的整数倍。
#   * 只写「镜像自身占用的扇区」（FAT BPB 自述几何），分区剩余部分不动；不格式化整个分区。
#   * 写后读回逐字节比对 sha256，不一致 ⇒ rc=1（不信 `qdl write` 自报）。
#   * 必需件默认 = EFI/BOOT/BOOTAA64.EFI、EFI/elden/Loader.efi、boot/boot.img、menu.cfg；
#     缺件 dry-run 就失败。grubenv / *.pf2 为可选，缺了打 WARN。
#   * 镜像里会多写一个 /esp-manifest.txt（逐文件 sha256 + 尺寸），便于设备侧或读回件对账。
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

ESP_DIR=""; GPT=""; PART=eldenesp; LUN=0; IMG=""; MIN_MIB=64
APPLY=0; ENTER_EDL=0; BUILD_ONLY=0; RESET_AFTER=0
SN=${SN:-HA2EXB0E}
# 主机工具落点 + 在线判据统一（PITFALLS #584 禁 `fastboot devices | grep -q`；#699 fastboot 不在 PATH）
. "$(dirname "$0")/lib-hosttools.sh"
ensure_hosttools --quiet
LOADER=${LOADER:-$HOME/下载/tb322fc/xbl_s_devprg_ns.melf}
QDL=${QDL:-$HOME/edl/qdl/build/qdl}
MTOOLS_DIR=${MTOOLS_DIR:-}
STAMP=$(date +%Y%m%d-%H%M%S)
READDIR=${READDIR:-$ROOT/backup/$SN-16+512/esp-apply-readback-$STAMP}
REQUIRED=(EFI/BOOT/BOOTAA64.EFI EFI/elden/Loader.efi boot/boot.img menu.cfg)
OPTIONAL=(grubenv)

while [ $# -gt 0 ]; do
	case "$1" in
		--esp-dir) ESP_DIR=$2; shift 2 ;;
		--gpt) GPT=$2; shift 2 ;;
		--part) PART=$2; shift 2 ;;
		--lun) LUN=$2; shift 2 ;;
		--img) IMG=$2; shift 2 ;;
		--min-mib) MIN_MIB=$2; shift 2 ;;
		--apply) APPLY=1; shift ;;
		--build-only) APPLY=1; BUILD_ONLY=1; shift ;;
		--dry-run) APPLY=0; shift ;;
		--enter-edl) ENTER_EDL=1; shift ;;
		--reset-after) RESET_AFTER=1; shift ;;
		--mtools-dir) MTOOLS_DIR=$2; shift 2 ;;
		-h|--help) sed -n '2,41p' "$0"; exit 0 ;;
		*) echo "未知参数 $1（--help 看用法）" >&2; exit 2 ;;
	esac
done
[ -n "$ESP_DIR" ] && [ -d "$ESP_DIR" ] || { echo "缺 --esp-dir（或目录不存在）" >&2; exit 2; }
[ -n "$GPT" ] || { echo "缺 --gpt（LUN0 主表 dump 文件或目录）" >&2; exit 2; }
if [ -d "$GPT" ]; then
	GPT=$(ls "$GPT"/gpt"$LUN"-primary.bin 2>/dev/null | head -1)
	[ -n "$GPT" ] || { echo "目录里找不到 gpt${LUN}-primary.bin" >&2; exit 2; }
fi
[ -f "$GPT" ] || { echo "读不到 $GPT" >&2; exit 2; }
[ "$(stat -c%s "$GPT")" -eq 24576 ] || { echo "--gpt 必须是 24576 B 主表 dump（LBA0-5）" >&2; exit 2; }

# mtools：mcopy/mtype/mdir 缺一不可（FAT 组装与自查都靠它）
if [ -z "$MTOOLS_DIR" ]; then
	if command -v mcopy >/dev/null 2>&1; then MTOOLS_DIR=$(dirname "$(command -v mcopy)")
	elif [ -x "$HOME/.local/opt/mtools/usr/bin/mcopy" ]; then MTOOLS_DIR=$HOME/.local/opt/mtools/usr/bin
	fi
fi
for t in mcopy mtype mdir mmd; do
	[ -n "$MTOOLS_DIR" ] && [ -x "$MTOOLS_DIR/$t" ] || { echo "缺 mtools 的 $t（apt 装 mtools，或 --mtools-dir 指到解包目录）" >&2; exit 2; }
done
command -v mkfs.fat >/dev/null 2>&1 || { echo "缺 mkfs.fat（dosfstools）" >&2; exit 2; }

# 从主表里按名字取分区 start/size（LBA 单位）
read -r P_START P_SECT P_TOTAL < <(python3 - "$GPT" "$PART" <<'PY'
import struct,sys
b=open(sys.argv[1],'rb').read(); want=sys.argv[2]
h=b[4096:4096+92]
if h[:8]!=b'EFI PART': sys.exit("主表 LBA1 不是 EFI PART")
nent,esize=struct.unpack_from('<II',h,80)
n=0
for i in range(nent):
    e=b[8192+i*esize:8192+(i+1)*esize]
    if e[:16]==b'\0'*16: continue
    n+=1
    name=e[56:128].decode('utf-16-le').rstrip('\0')
    if name==want:
        start,last=struct.unpack_from('<QQ',e,32)
        print(start,last-start+1,n); sys.exit(0)
sys.exit("分区 %s 不在表里（表内有效条目 %d）"%(want,n))
PY
)

# 清单与必需件
MANIFEST=$(mktemp); trap 'rm -f "$MANIFEST" "$MANIFEST.paths" "$MANIFEST.tmp" "$MANIFEST.mf"' EXIT
missing=0
( cd "$ESP_DIR" && find . -type f ! -name '.*' -printf '%P\n' | LC_ALL=C sort ) > "$MANIFEST.paths"
while IFS= read -r rel; do
	printf '%s  %s  %s\n' "$(sha_direct "$ESP_DIR/$rel")" "$(stat -c%s "$ESP_DIR/$rel")" "$rel" >> "$MANIFEST"
done < "$MANIFEST.paths"
NFILES=$(wc -l < "$MANIFEST.paths")
for r in "${REQUIRED[@]}"; do
	grep -qx -- "$r" "$MANIFEST.paths" || { echo "!! 缺必需件 $r" >&2; missing=1; }
done
for r in "${OPTIONAL[@]}"; do
	grep -qx -- "$r" "$MANIFEST.paths" || echo "WARN 可选件缺：$r" >&2
done
[ "$missing" -eq 0 ] || { echo "必需件不齐 ⇒ 不组装、不写盘" >&2; exit 1; }
BYTES=$(awk '{s+=$2} END{print s+0}' "$MANIFEST")
# +manifest 自身（约 90 B/文件）
BYTES=$((BYTES + NFILES * 100 + 8192))
WANT_MIB=$(( (BYTES * 13 / 10 + 1048575) / 1048576 ))
[ "$WANT_MIB" -lt "$MIN_MIB" ] && WANT_MIB=$MIN_MIB
IMGSZ=$((WANT_MIB * 1048576))
NSECT=$((IMGSZ / 4096))
[ -n "$IMG" ] || { mkdir -p "$ROOT/out/esp-apply-$STAMP"; IMG=$ROOT/out/esp-apply-$STAMP/eldenesp.img; }

echo "== 计划（LUN${LUN} 分区 ${PART}）=="
echo "  分区区间   LBA ${P_START}..$((P_START + P_SECT - 1))  （${P_SECT} 扇区 = $((P_SECT * 4096 / 1048576)) MiB）"
echo "  源目录     ${ESP_DIR}  ${NFILES} 个文件  ${BYTES} B（含 manifest 余量）"
echo "  镜像       ${IMG}  ${IMGSZ} B（${WANT_MIB} MiB，下限 ${MIN_MIB} MiB）写在 LBA ${P_START}..$((P_START + NSECT - 1))"
echo "  mtools     ${MTOOLS_DIR}"
if [ "$NSECT" -gt "$P_SECT" ]; then echo "!! 镜像 ${NSECT} 扇区 > 分区 ${P_SECT} 扇区（放不下）" >&2; exit 1; fi
echo "  清单（sha256 前 16 位 / 字节 / 路径）："
while read -r sha size rel; do echo "    ${sha:0:16}  ${size}  ${rel}"; done < "$MANIFEST"
if [ "$APPLY" -eq 0 ]; then
	echo "（dry-run：未组装镜像、未写盘。加 --apply 执行；--enter-edl 可自动切 9008）"
	exit 0
fi

for f in "$LOADER" "$QDL"; do [ -e "$f" ] || { echo "缺文件: $f" >&2; exit 2; }; done

# 串行化：写盘期间不允许别的 agent 碰设备（scripts/lib-device-lock.sh 单一真源）
. "$ROOT/scripts/lib-device-lock.sh"
device_lock_acquire

# 组装 FAT32（-i 固定卷 ID，便于重复组装出同一镜像）
mkdir -p "$(dirname "$IMG")"
rm -f "$IMG"
truncate -s "$IMGSZ" "$IMG"
mkfs.fat -F32 -n ELDENESP -i 1a2b3c4d "$IMG" >/dev/null
export MTOOLS_SKIP_CHECK=1
cp "$MANIFEST" "$MANIFEST.tmp"
{ echo "# eldenesp manifest  $(date -Is)  source=${ESP_DIR}"; cat "$MANIFEST.tmp"; } > "$MANIFEST.mf"
"$MTOOLS_DIR/mcopy" -i "$IMG" "$MANIFEST.mf" ::/esp-manifest.txt
rm -f "$MANIFEST.tmp" "$MANIFEST.mf"
while IFS= read -r rel; do
	# mtools 的 mmd 只建一级目录 ⇒ 逐级建（"EFI/BOOT/..." → ::/EFI 再 ::/EFI/BOOT）
	d=$(dirname "$rel"); [ "$d" = "." ] && d=""
	cur=""
	IFS='/' read -r -a parts <<< "$d"
	for p in "${parts[@]}"; do
		[ -n "$p" ] || continue
		cur="$cur/$p"
		"$MTOOLS_DIR/mmd" -i "$IMG" "::$cur" 2>/dev/null || true
	done
	"$MTOOLS_DIR/mcopy" -o -i "$IMG" "$ESP_DIR/$rel" "::/$rel"
done < "$MANIFEST.paths"
echo "[build] 镜像组装完成：$IMG  $(stat -c%s "$IMG") B"

# 逐文件 mtype 自查（防 mcopy 静默失败 / 名字截断）
bad=0
while read -r sha size rel; do
	got=$("$MTOOLS_DIR/mtype" -i "$IMG" "::/$rel" | sha256sum | cut -d' ' -f1)
	if [ "$got" = "$sha" ]; then echo "OK   $rel  sha=${sha:0:16}"
	else echo "FAIL $rel  want=${sha:0:16} got=${got:0:16}"; bad=1; fi
done < "$MANIFEST"
[ "$bad" -eq 0 ] || { echo "!! 镜像内自查失败 ⇒ 不写盘" >&2; exit 1; }
if [ "$BUILD_ONLY" -eq 1 ]; then
	echo "（--build-only：镜像与自查完成，未写盘）"
	exit 0
fi

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

# ---- 写前门：现场读一次设备当前 GPT，核对「这个分区在设备上真的存在、起点一致、装得下」----
# 为什么必须有这一步：P_START/P_SECT 来自**主机侧 dump**，若 dump 与设备现状不一致
# （例：dump 里 eldenesp 在 LBA 123609088，设备上已没有这个分区 / 那段现在属 `linux`），
# 本脚本就会把 64 MiB 镜像写进另一个在用分区的中间（PITFALLS #675 同类事故）。
# `-R` = --skip-reset ⇒ 两条 qdl 命令之间设备留在 9008（#674：不加就第二发必失败）。
echo "[gate] 现场读 LUN${LUN} LBA0..5 核对分区位置"
timeout -k 10 120 "$QDL" -s ufs -R "$LOADER" \
	read "$LUN/0+6" "$READDIR/live-gpt$LUN-primary.bin" \
	2>&1 | tail -3
python3 - "$READDIR/live-gpt$LUN-primary.bin" "$PART" "$P_START" "$P_SECT" <<'PY' || exit 1
import struct,sys
live,part,want_start,want_sect=sys.argv[1],sys.argv[2],int(sys.argv[3]),int(sys.argv[4])
b=open(live,'rb').read(); h=b[4096:4096+92]
if h[:8]!=b'EFI PART': sys.exit("live GPT: LBA1 不是 EFI PART（读回件不可信）⇒ 不写")
ent_lba,=struct.unpack_from('<Q',h,72); nent,esz=struct.unpack_from('<II',h,80)
for i in range(nent):
    e=b[ent_lba*4096+i*esz:ent_lba*4096+(i+1)*esz]
    if e[:16]==b'\0'*16: continue
    name=e[56:128].decode('utf-16-le').rstrip('\0')
    if name!=part: continue
    start,last=struct.unpack_from('<QQ',e,32)
    if start!=want_start:
        sys.exit(f"live {part}.first={start} != dump {want_start} ⇒ 表已变，拒绝写（先重取 dump）")
    if last-start+1 < want_sect:
        sys.exit(f"live {part} 只有 {last-start+1} 扇区 < 要写 {want_sect} ⇒ 拒绝写")
    print(f"gate OK: live {part} {start}..{last}")
    break
else:
    sys.exit(f"live GPT 里没有分区 {part}（表已变）⇒ 拒绝写；先重取 dump 或改用正确分区名")
PY

echo "[write] 写 ${PART}（LBA ${P_START}，${NSECT} 扇区）+ 读回 + 设备端 sha256，同一 qdl 会话"
timeout -k 10 600 "$QDL" -s ufs -R "$LOADER" \
	write "$LUN/$P_START" "$IMG" \
	read "$LUN/$P_START+$NSECT" "$READDIR/eldenesp-readback.img" \
	sha256 "$LUN/$P_START+$NSECT" \
	2>&1 | tee "$READDIR/qdl.log" | tail -8

ok=1
want=$(sha_direct "$IMG")
got=$(sha_direct "$READDIR/eldenesp-readback.img" || true)
if [ "$want" = "$got" ]; then
	echo "OK   读回逐字节一致 sha=${want:0:16}"
	echo "读回件: $READDIR/eldenesp-readback.img（可直接 mdir/mtype 复核）"
else
	echo "FAIL 读回不一致 want=${want:0:16} got=${got:0:16} ⇒ 回滚：把旧 ESP 镜像按同一条 qdl 命令写回 LBA ${P_START}" >&2
	ok=0
fi
devsha=$(grep -E '^[0-9a-f]{64}$' "$READDIR/qdl.log" | tail -1 || true)
if [ -n "$devsha" ]; then
	if [ "$devsha" = "$want" ]; then echo "OK   设备端 sha256 一致 sha=${want:0:16}"
	else echo "FAIL 设备端 sha256 不符 host=${want:0:16} dev=${devsha:0:16}" >&2; ok=0; fi
else
	echo "WARN 未取到设备端 sha256（loader 无 getsha256digest 时会跳过）⇒ 只用读回件判据" >&2
fi
if [ "$RESET_AFTER" -eq 1 ]; then
	echo "[reset] 显式踢出 9008"
	timeout -k 10 120 "$QDL" -s ufs "$LOADER" reset 2>&1 | tail -2 || { echo "WARN qdl reset 失败" >&2; }
else
	echo "设备仍在 EDL(9008)（-R 跳过 reset）；要回正常启动加 --reset-after"
fi
[ "$ok" -eq 1 ] || exit 1
