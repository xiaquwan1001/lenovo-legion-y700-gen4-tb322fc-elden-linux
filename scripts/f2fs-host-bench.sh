#!/bin/bash
# f2fs-host-bench.sh — f2fs vs ext4 的主机 loop 台架（G1，零设备写盘）
#
# 目的（`reports/f2fs-plan-20261021.md` §7 G1）：在真机上动 GPT 之前，先把
#   ① mkfs/挂载/GC/fsck 走通  ② 参数定案  ③ 量化「高利用率后 4K fsync 掉多少」
# 全部在主机上做完。**必须用 4096 B 扇区的 loop**（本机 UFS logical_block_size=4096），
# 否则对齐条件与设备不一致，测出来的数不能迁移。
#
# 用法：sudo bash scripts/f2fs-host-bench.sh [arena_dir]
#   产物：$ARENA/result.tsv + 控制台 markdown 表；ARENA 默认 /var/tmp/f2fs-bench
#
# 判据（脚本自己判）：
#   * `blkid` 能按 LABEL 找到 f2fs 卷（迁移路线依赖 `elden_root=LABEL=linux17`）
#   * f2fs 上 `fstrim` 成功（= discard 通路真实可用；设备侧 discard_max=32 GiB 已确认）
#   * fsck.f2fs 干净退出（rc=0）
set -uo pipefail

ARENA=${1:-/var/tmp/f2fs-bench}
SIZE=${SIZE:-6G}
MNT=$ARENA/mnt
RES=$ARENA/result.tsv
FIO=/usr/bin/fio

[ "$(id -u)" = 0 ] || { echo "需要 root（losetup/mount）：sudo bash $0" >&2; exit 1; }
command -v $FIO >/dev/null || { echo "缺 fio" >&2; exit 1; }

mkdir -p "$ARENA" "$MNT"
cleanup() {
	mountpoint -q "$MNT" && umount -f "$MNT"
	[ -n "${LOOP:-}" ] && losetup -d "$LOOP" 2>/dev/null
}
trap cleanup EXIT

: >"$RES"
row() { printf '%s\t%s\t%s\t%s\t%s\n' "$@" >>"$RES"; }
hdr() { printf '\n=== %s\n' "$*"; }

mkloop() {  # $1=name ; 输出 loop 设备
	local f=$ARENA/disk-$1.img
	rm -f "$f"
	truncate -s "$SIZE" "$f"
	losetup --sector-size 4096 --find --show "$f"
}

# ---- fio 工作负载（direct=1，绕 page cache，数才有意义）---------------------
fio_run() {  # $1=job name, $2=mountpoint, 其余原样传给 fio
	local name=$1 dir=$2; shift 2
	$FIO --name="$name" --directory="$dir" --output-format=json "$@" 2>/dev/null
}

bench_suite() {  # $1=label, $2=mountpoint
	local label=$1 mp=$2
	local out r

	# W1 顺序写 1 GiB（direct）
	out=$(fio_run seqw "$mp" --size=1G --rw=write --bs=1M --iodepth=1 --direct=1 2>/dev/null || true)
	r=$(printf '%s' "$out" | python3 -c 'import json,sys;d=json.load(sys.stdin)["jobs"][0];print(int(d["write"]["bw_bytes"]/1048576))'  2>/dev/null || echo NA)
	row "$label" seqw_1M_MBps "$r" "direct=1 bs=1M iodepth=1 size=1G" ""

	# W2 4K 随机写 + 每 8 个 IO 一次 fsync（f2fs 的主场，也是 phosh/apk/sqlite 的形状）
	out=$(fio_run r4k_fsync "$mp" --size=256M --rw=randwrite --bs=4k --fsync=8 --iodepth=1 --direct=1 2>/dev/null || true)
	r=$(printf '%s' "$out" | python3 -c 'import json,sys;d=json.load(sys.stdin)["jobs"][0];print(int(d["write"]["iops"]))' 2>/dev/null || echo NA)
	row "$label" r4k_fsync_IOPS "$r" "direct=1 bs=4k fsync=8 size=256M" ""

	# W3 元数据密集：2000 个 4K 小文件
	out=$(fio_run meta "$mp" --size=8M --rw=write --bs=4k --nrfiles=2000 --file_service_type=random --direct=1 2>/dev/null || true)
	r=$(printf '%s' "$out" | python3 -c 'import json,sys;d=json.load(sys.stdin)["jobs"][0];print(int(d["write"]["iops"]))' 2>/dev/null || echo NA)
	row "$label" meta2000_IOPS "$r" "2000 files x 4K, direct=1" ""

	# W4 高利用率：填到 ~90% 后重跑 W2（GC 压力；f2fs 的死穴就在这）
	local free_kb use_kb
	free_kb=$(df --output=avail -k "$mp" | tail -1)
	dd if=/dev/zero of="$mp/fill.bin" bs=1M count=$(( free_kb / 1024 * 90 / 100 )) status=none 2>/dev/null
	sync
	df -h "$mp" | tail -1 >>"$ARENA/df-$label.txt"
	out=$(fio_run r4k_fsync_full "$mp" --size=256M --rw=randwrite --bs=4k --fsync=8 --iodepth=1 --direct=1 2>/dev/null || true)
	r=$(printf '%s' "$out" | python3 -c 'import json,sys;d=json.load(sys.stdin)["jobs"][0];print(int(d["write"]["iops"]))' 2>/dev/null || echo NA)
	row "$label" r4k_fsync_90pct_IOPS "$r" "同上 + 盘已填到 ~90%" ""
	rm -f "$mp/fill.bin"
}

# ------------------------------------------------------------------ ext4 基线
hdr "ext4 基线（$SIZE，4096B 扇区 loop）"
LOOP=$(mkloop ext4); echo "loop=$LOOP"
mkfs.ext4 -q -F -L linux17 "$LOOP" >/dev/null 2>&1 || { echo "mkfs.ext4 失败"; exit 1; }
mount -o noatime "$LOOP" "$MNT" || { echo "mount ext4 失败"; exit 1; }
bench_suite ext4 "$MNT"
umount "$MNT"
t0=$(date +%s%N); e2fsck -f -y "$LOOP" >/dev/null 2>&1; rc=$?; t1=$(date +%s%N)
row ext4 fsck_ms "$(( (t1-t0)/1000000 ))" "e2fsck -f -y rc=$rc" ""
losetup -d "$LOOP"; LOOP=

# ------------------------------------------------------- f2fs（noatime 基线）
hdr "f2fs 基线（noatime，无 discard）"
LOOP=$(mkloop f2fs); echo "loop=$LOOP"
mkfs.f2fs -f -l linux17 "$LOOP" >/dev/null 2>&1 || { echo "mkfs.f2fs 失败"; exit 1; }
# LABEL 必须能被 blkid 认出来（迁移路线靠 elden_root=LABEL=linux17 定位根）
labdev=$(blkid -L linux17 -o device 2>/dev/null)
labtype=$(blkid -o value -s TYPE "$LOOP" 2>/dev/null)
row f2fs blkid_label "${labdev:-ABSENT}/${labtype:-ABSENT}" "blkid -L linux17 -o device / -s TYPE" ""
mount -o noatime "$LOOP" "$MNT" || { echo "mount f2fs 失败"; exit 1; }
bench_suite f2fs_nodev "$MNT"
# loop 设备自身的 discard 能力（与设备侧 32 GiB 对照）
row f2fs loop_discard_max_bytes "$(cat /sys/block/$(basename "$LOOP")/queue/discard_max_bytes 2>/dev/null || echo NA)" "loop 队列" ""
umount "$MNT"
t0=$(date +%s%N); fsck.f2fs -f "$LOOP" >/dev/null 2>&1; rc=$?; t1=$(date +%s%N)
row f2fs_nodev fsck_ms "$(( (t1-t0)/1000000 ))" "fsck.f2fs -f rc=$rc" ""
losetup -d "$LOOP"; LOOP=

# --------------------------------------------------- f2fs（+discard，推荐档）
hdr "f2fs + discard（候选日常参数）"
LOOP=$(mkloop f2fsd); echo "loop=$LOOP"
mkfs.f2fs -f -l linux17 "$LOOP" >/dev/null 2>&1
mount -o noatime,discard,gc_merge "$LOOP" "$MNT" || { echo "mount f2fs(discard) 失败"; exit 1; }
bench_suite f2fs_discard "$MNT"
# discard 档才做 fstrim：先制造可丢块（写 128 MiB → 删 → sync），再 trim
dd if=/dev/zero of="$MNT/trim.bin" bs=1M count=128 status=none 2>/dev/null; sync; rm -f "$MNT/trim.bin"; sync
ft=$(fstrim -v "$MNT" 2>&1 | tr '\t' ' ')
row f2fs_discard fstrim "$(printf '%s' "$ft" | sed 's/.*：//; s/.*: //')" "fstrim -v（写128M→删→sync 后）" ""
umount "$MNT"
losetup -d "$LOOP"; LOOP=

rm -rf "$ARENA"/disk-*.img

# ------------------------------------------------------------------- 汇总表
hdr "结果"
{
	printf '| 配置 | 指标 | 数值 | 条件 |\n|---|---|---|---|\n'
	awk -F'\t' '{printf "| %s | %s | %s | %s |\n", $1, $2, $3, $4}' "$RES"
} | tee "$ARENA/summary.md"
echo
echo "raw: $RES"
