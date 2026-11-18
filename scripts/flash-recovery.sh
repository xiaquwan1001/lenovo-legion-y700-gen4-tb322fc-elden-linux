#!/bin/bash
# flash-recovery.sh — 从 Linux 里把镜像写进 recovery 分区（默认 recovery_b），无需 fastboot。
#
# 背景（archive/topics/FLASHCTL-2026-10-03.md）：
#   * 设备 current-slot=b（GPT attribute 实测），recovery 目标 = recovery_b。
#   * vbmeta_b 已被我们的 avb.key 重签且 Flags=3（verification+hashtree 全关），
#     且其描述符只覆盖 boot/dtbo，**不含 recovery** → 写 recovery_b 无需再签名。
#   * 实测两 recovery 分区当前都是原厂（~16 MB ramdisk），TWRP 尚**未**安装。
#
# usage: TABLET=root@192.168.7.1 scripts/flash-recovery.sh [img] [--reboot]
#        img 必填（旧默认 twrp/twrp.img 已删除）
set -eu
cd "$(dirname "$0")/.."
TAB=${TABLET:-root@192.168.7.1}
PART=${RECOVERY_PART:-recovery_b}
IN=${1:?usage: $0 <recovery.img>}
REBOOT=0
for a in "$@"; do
	case "$a" in
		--reboot) REBOOT=1 ;;
		*) IN=$a ;;
	esac
done

[ -f "$IN" ] || { echo "[flash-recovery] missing $IN" >&2; exit 1; }
SHA=$(sha256sum "$IN" | cut -d' ' -f1)
SIZE=$(stat -c%s "$IN")
echo "[flash-recovery] img=$IN size=$SIZE sha256=$SHA"
echo "[flash-recovery] target=$PART (device /dev/disk/by-partlabel/$PART)"

# 2026-11-18 审计 R2 P1-14：旧版要求 PSIZE == SIZE 精确相等（小件被误拒），且 scp 无超时、
# 回读用 count=$((SIZE/1048576)) 向下取整（非 MiB 对齐件必报假 MISMATCH）、无设备锁。
: "${SSHO:=timeout -k 2 20 ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=6}"
. "$(dirname "$0")/lib-device-lock.sh"; device_lock_acquire
PSIZE=$($SSHO "$TAB" "blockdev --getsize64 /dev/disk/by-partlabel/$PART" 2>/dev/null | tr -dc '0-9')
echo "[flash-recovery] partition size=${PSIZE:-读不到}"
[ -n "${PSIZE:-}" ] || { echo "[flash-recovery] 读不到 /dev/disk/by-partlabel/$PART（分区名/设备不对）" >&2; exit 1; }
[ "$SIZE" -le "$PSIZE" ] || { echo "[flash-recovery] 镜像 $SIZE B > 分区 $PSIZE B，拒绝写（会截断）" >&2; exit 1; }
[ "$SIZE" = "$PSIZE" ] || echo "[flash-recovery] 镜像小于分区（保留尾部原值），按 $SIZE B 写"

echo "[flash-recovery] uploading..."
RIMG=/tmp/recovery-$$.img
trap 'rm -f "$RIMG"' EXIT
timeout -k 5 600 scp -q -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$IN" "$TAB:$RIMG"

echo "[flash-recovery] writing $PART ..."
$SSHO "$TAB" "
set -e
D=/dev/disk/by-partlabel/$PART
dd if=$RIMG of=\$D bs=1M conv=fsync 2>&1 | tail -1
sync
rm -f $RIMG
# 回读按**字节**取，不能按 MiB 向下取整（否则非对齐件必报假 MISMATCH）
head -c $SIZE \$D | sha256sum | cut -d' ' -f1
" > /tmp/flash-recovery-readback.txt
RB=$(tail -1 /tmp/flash-recovery-readback.txt)
echo "[flash-recovery] readback sha256=$RB"
[ "$SHA" = "$RB" ] || { echo "[flash-recovery] MISMATCH — $PART NOT updated cleanly" >&2; exit 1; }
echo "[flash-recovery] OK"

if [ "$REBOOT" = 1 ]; then
	echo "[flash-recovery] reboot recovery ..."
	$SSHO "$TAB" 'eldroid-bootctl reboot recovery' || true
fi
