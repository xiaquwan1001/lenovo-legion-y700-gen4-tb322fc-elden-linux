#!/bin/sh
# tf-stress.sh -- TF 卡（SDHCI/SDC2）写稳定性压测（在设备上以 root 运行）
#
# 目的：区分「卡不良」与「SDHCI/DT 驱动问题」。幂等、可复现、低干扰：
#   只在目标挂载点下一个临时目录写文件，结束清理；卡身份 / 协商速率 /
#   err_stats 全部快照；写后 sync + drop_caches 再回读（必须 drop_caches，
#   否则被 page cache 骗）。
#
# 用法（设备上）：
#   tf-stress.sh [-n 小写块数] [-m 大块MiB] [-r 轮数] [-d] [-t 秒] [--fsck] [挂载点]
#
#   -n N   每轮 4KB 小写块数          (默认 2000)
#   -m M   每轮 1MB 大块数            (默认 64)
#   -r R   轮数                       (默认 3)
#   -d     4KB 小写用 O_DIRECT (oflag=direct)，绕开 page cache
#   -t S   整脚本超时秒数（timeout 自限，默认 300）
#   --fsck 测试前/后各做一次 e2fsck -fn（需卸载，脚本会临时卸载再重挂）
#   -h     帮助
#   挂载点 默认 /mnt/tf；必须是 mmcblk* 上的 ext4 挂载点
#
# 退出码：0 = 全部一致；1 = 检测到不一致或前置条件失败；2 = 用法错误。
#
# 说明：只写挂载点内的临时文件，不改分区表、不格盘、不动根分区。
#       大块全一致 + 小写间歇不一致 是「卡/固件」或「小写路径」的典型特征。

set -u

SMALL=2000        # 4KB 块数/轮
LARGE=64          # 1MB 块数/轮
ROUNDS=3
DIRECT=0
TOTAL=300
FSCK=0
MOUNT=/mnt/tf

usage() { sed -n '2,30p' "$0"; exit "${1:-0}"; }

while [ $# -gt 0 ]; do
	case "$1" in
		-n) SMALL=$2; shift 2 ;;
		-m) LARGE=$2; shift 2 ;;
		-r) ROUNDS=$2; shift 2 ;;
		-t) TOTAL=$2; shift 2 ;;
		-d) DIRECT=1; shift ;;
		--fsck) FSCK=1; shift ;;
		-h|--help) usage 0 ;;
		-*) echo "unknown option: $1" >&2; usage 2 ;;
		*) MOUNT=$1; shift ;;
	esac
done

say()  { echo "[tf-stress] $*"; }
die()  { echo "[tf-stress] ERROR: $*" >&2; exit 1; }

[ "$(id -u)" = 0 ] || die "need root"
command -v dd >/dev/null || die "no dd"

# ---- 整脚本超时自限（幂等重入一次，用环境变量防递归）---------------------
if [ -z "${TF_STRESS_WRAPPED:-}" ] && command -v timeout >/dev/null; then
	export TF_STRESS_WRAPPED=1
	exec timeout -k 10 "$TOTAL" "$0" "$@"
fi

# ---- 挂载点 / 底层设备解析 ---------------------------------------------
mp_field() { awk -v mp="$MOUNT" '$2==mp{print $'"$1"'; exit}' /proc/mounts; }
MP_SRC=$(mp_field 1); MP_TYPE=$(mp_field 3); MP_OPTS=$(mp_field 4)
[ -n "$MP_SRC" ] || die "$MOUNT 不是挂载点（先挂好 TF 卡再来）"
BASE=$(basename "$MP_SRC")
PARENT=$(echo "$BASE" | sed 's/p[0-9]*$//')          # mmcblk0p2 -> mmcblk0
case "$PARENT" in
	mmcblk*) : ;;
	*) die "$MOUNT 底层是 $MP_SRC（$PARENT），不是 mmcblk*，拒绝测试" ;;
esac
HOSTID=${PARENT#mmcblk}                                # -> 0 / 1 ...
SDIR=/sys/block/$PARENT
[ -d "$SDIR" ] || die "no sysfs for $PARENT"

remount() {
	umount "$MOUNT" 2>/dev/null || return 1
	mount -t "$MP_TYPE" -o "$MP_OPTS" "$MP_SRC" "$MOUNT" 2>/dev/null || \
		mount "$MP_SRC" "$MOUNT" 2>/dev/null || return 1
	return 0
}

do_fsck() {
	[ "$FSCK" = 1 ] || return 0
	command -v e2fsck >/dev/null || { say "WARN: no e2fsck, skip --fsck"; return 0; }
	say "fsck -fn ${MP_SRC} ($1)"
	# e2fsck -fn 在已挂载分区只读检查不安全，故先卸载
	if ! umount "$MOUNT" 2>/dev/null; then
		say "WARN: $MOUNT 忙，跳过本次 fsck"
		return 0
	fi
	e2fsck -fn "$MP_SRC" >/tmp/.tf-fsck.$$ 2>&1
	rc=$?
	say "  e2fsck rc=$rc (0=clean, 4/8=有错已列) → /tmp/.tf-fsck.$$ 摘要："
	sed -n '1,12p' /tmp/.tf-fsck.$$ | sed 's/^/    /'
	remount || say "WARN: 重挂 $MOUNT 失败，请手动挂回"
}

# ---- err_stats（debugfs）------------------------------------------------
ERRSTAT=/sys/kernel/debug/mmc$HOSTID/err_stats
mount_debugfs() {
	[ -e "$ERRSTAT" ] && return 0
	mount -t debugfs none /sys/kernel/debug 2>/dev/null || return 1
	[ -e "$ERRSTAT" ] && return 0
	return 1
}
snap_attrs() {  # $1 = 标签
	mount_debugfs >/dev/null 2>&1
	say "--- $1 ---"
	for f in name oemid manfid date serial fwrev hwrev cid; do
		[ -r "$SDIR/device/$f" ] && printf '  cid.%-6s = %s\n' "$f" "$(cat "$SDIR/device/$f")"
	done
	if [ -r "/sys/kernel/debug/mmc$HOSTID/ios" ]; then
		say "  ios (协商)："
		sed -n '1,14p' "/sys/kernel/debug/mmc$HOSTID/ios" | sed 's/^/    /'
	fi
	if [ -r "$ERRSTAT" ]; then
		say "  err_stats："
		sed 's/^/    /' "$ERRSTAT"
	fi
}
zero_errstats() {
	mount_debugfs >/dev/null 2>&1
	[ -r "$ERRSTAT" ] && : > "$ERRSTAT" 2>/dev/null
}

# ---- hash 工具 ----------------------------------------------------------
if command -v sha256sum >/dev/null; then HASH="sha256sum"
elif command -v md5sum >/dev/null; then HASH="md5sum"
else die "no sha256sum/md5sum"; fi
hashf() { $HASH "$1" | awk '{print $1}'; }

# ---- 准备临时目录（源在根 fs，测试文件在 TF）---------------------------
TMP=$(mktemp -d /tmp/tf-stress.XXXXXX 2>/dev/null) || TMP=/dev/shm/tf-stress.$$
mkdir -p "$TMP"
TFDIR=$MOUNT/.tf-stress.$$
cleanup() {
	rm -rf "$TFDIR" 2>/dev/null
	rm -rf "$TMP" 2>/dev/null
	rm -f /tmp/.tf-fsck.$$ 2>/dev/null
}
trap cleanup EXIT INT TERM

say "挂载点=$MOUNT 设备=$MP_SRC ($PARENT)  host=mmc$HOSTID"
say "参数：small=$SMALL x4KB  large=$LARGE x1MB  rounds=$ROUNDS  direct=$DIRECT  超时=${TOTAL}s"
snap_attrs "BEFORE（卡身份 / 协商 / err_stats）"
zero_errstats
do_fsck "before"

mkdir -p "$TFDIR" || die "无法在 $MOUNT 下建目录（写权限/只读？）"

mismatch=0
round=1
while [ "$round" -le "$ROUNDS" ]; do
	say "===== round $round/$ROUNDS ====="
	# 每轮新随机源（在 /tmp），避免跨轮同块巧合
	SRC_S=$TMP/src.s.$round
	SRC_L=$TMP/src.l.$round
	dd if=/dev/urandom of="$SRC_S" bs=4096 count="$SMALL" 2>/dev/null
	dd if=/dev/urandom of="$SRC_L" bs=1M   count="$LARGE" 2>/dev/null
	hs=$(hashf "$SRC_S"); hl=$(hashf "$SRC_L")

	# ---- 4KB 小写 ----
	FS=$TFDIR/small.bin
	if [ "$DIRECT" = 1 ]; then DOF="oflag=direct"; else DOF=""; fi
	timeout 120 dd if="$SRC_S" of="$FS" bs=4096 count="$SMALL" $DOF conv=notrunc 2>/dev/null \
		|| { say "  small dd 失败/超时"; mismatch=$((mismatch+1)); }
	sync
	echo 3 > /proc/sys/vm/drop_caches 2>/dev/null
	rs=$(hashf "$FS")
	if [ "$rs" = "$hs" ]; then say "  small 4KB x$SMALL : OK"
	else say "  small 4KB x$SMALL : MISMATCH  src=$hs got=$rs"; mismatch=$((mismatch+1)); fi

	# ---- 1MB 大块 ----
	FL=$TFDIR/large.bin
	timeout 180 dd if="$SRC_L" of="$FL" bs=1M count="$LARGE" $DOF conv=notrunc 2>/dev/null \
		|| { say "  large dd 失败/超时"; mismatch=$((mismatch+1)); }
	sync
	echo 3 > /proc/sys/vm/drop_caches 2>/dev/null
	rl=$(hashf "$FL")
	if [ "$rl" = "$hl" ]; then say "  large 1MB x$LARGE : OK"
	else say "  large 1MB x$LARGE : MISMATCH  src=$hl got=$rl"; mismatch=$((mismatch+1)); fi

	round=$((round+1))
done

sync
snap_attrs "AFTER（err_stats）"
do_fsck "after"

say "==================================================="
say "总不一致计数 = $mismatch  (rounds=$ROUNDS, small=$SMALL, large=$LARGE)"
if [ "$mismatch" -eq 0 ]; then
	say "RESULT: PASS（本轮全部一致）"
	exit 0
else
	say "RESULT: FAIL（检测到 $mismatch 处不一致）"
	exit 1
fi
