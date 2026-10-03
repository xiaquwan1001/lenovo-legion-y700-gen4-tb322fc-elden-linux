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
#        default img = twrp/twrp.img
set -eu
cd "$(dirname "$0")/.."
TAB=${TABLET:-root@192.168.7.1}
PART=${RECOVERY_PART:-recovery_b}
IN=twrp/twrp.img
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

PSIZE=$(ssh -o StrictHostKeyChecking=no "$TAB" "blockdev --getsize64 /dev/disk/by-partlabel/$PART")
echo "[flash-recovery] partition size=$PSIZE"
[ "$PSIZE" -eq "$SIZE" ] || { echo "[flash-recovery] 尺寸不符（分区 $PSIZE != 镜像 $SIZE）；" >&2
	echo "  若镜像更小可 pad 到分区大小再写；若更大则不能写。" >&2; exit 1; }

echo "[flash-recovery] uploading..."
scp -q -o StrictHostKeyChecking=no "$IN" "$TAB:/tmp/recovery.img"

echo "[flash-recovery] writing $PART ..."
ssh -o StrictHostKeyChecking=no "$TAB" "
set -e
D=/dev/disk/by-partlabel/$PART
dd if=/tmp/recovery.img of=\$D bs=1M conv=fsync 2>&1 | tail -1
sync
rm -f /tmp/recovery.img
dd if=\$D bs=1M count=$((SIZE/1048576)) 2>/dev/null | sha256sum | cut -d' ' -f1
" > /tmp/flash-recovery-readback.txt
RB=$(tail -1 /tmp/flash-recovery-readback.txt)
echo "[flash-recovery] readback sha256=$RB"
[ "$SHA" = "$RB" ] || { echo "[flash-recovery] MISMATCH — $PART NOT updated cleanly" >&2; exit 1; }
echo "[flash-recovery] OK"

if [ "$REBOOT" = 1 ]; then
	echo "[flash-recovery] reboot recovery ..."
	ssh -o StrictHostKeyChecking=no "$TAB" 'eldroid-bootctl reboot recovery' || true
fi
