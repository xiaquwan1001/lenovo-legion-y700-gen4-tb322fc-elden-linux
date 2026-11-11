#!/bin/sh
# dev-super-relabel.sh — 设备侧（POSIX sh）：把 Android `super`（sda10，22 GiB 动态分区容器）转成 Linux 分区
#   零数据搬移：只改 GPT 类型码 + 名字，扇区范围不变。可逆（改回 1B81E7E6… 即恢复 userdata 语义；
#   super 的原类型码见下方 BEFORE 输出，恢复时用 ORIG_TYPE）。
# 用法（主机）：scp 到设备 /tmp 后 `sh /tmp/dev-super-relabel.sh [--apply]`；默认 dry-run。
set -e
PART=/dev/sda10
MP=${MP:-/srv/elden-super}
LABEL=elden-super
APPLY=0
[ "$1" = "--apply" ] && APPLY=1

echo "=== 1) super 现状"
sgdisk -i 10 /dev/sda | sed -n '1,8p'
ORIG_TYPE=$(sgdisk -i 10 /dev/sda | sed -n 's/^Partition GUID code: \([0-9A-F-]*\).*/\1/p')
echo "  原类型码 = $ORIG_TYPE（恢复用）"

echo "=== 2) GPT 备份"
TS=$(date +%Y%m%d-%H%M%S)
if [ $APPLY = 1 ]; then
	sgdisk --backup=/root/gpt-sda-$TS.bin /dev/sda
	sgdisk --print /dev/sda > /root/gpt-sda-$TS.txt
	ls -l /root/gpt-sda-$TS.*
else
	echo "  (dry-run) 将写 /root/gpt-sda-$TS.bin / .txt"
fi

echo "=== 3) 类型改 Linux filesystem（扇区不动）"
if [ $APPLY = 1 ]; then
	sgdisk --typecode=10:8300 --change-name=10:$LABEL /dev/sda
	partx -u /dev/sda 2>/dev/null || partprobe /dev/sda 2>/dev/null || true
	sgdisk -i 10 /dev/sda | sed -n '1,8p'
	lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL "$PART"
else
	echo "  (dry-run) sgdisk --typecode=10:8300 --change-name=10:$LABEL /dev/sda"
fi

echo "=== 4) 建 ext4（丢弃 Android super 内容，按用户 2026-11-11 授权）"
if [ $APPLY = 1 ]; then
	mkfs.ext4 -q -F -L "$LABEL" -m 1 "$PART"
	blkid "$PART"
else
	echo "  (dry-run) mkfs.ext4 -q -F -L $LABEL -m 1 $PART"
fi

echo "=== 5) fstab + 挂载到 $MP"
if [ $APPLY = 1 ]; then
	grep -q "LABEL=$LABEL" /etc/fstab || \
		printf 'LABEL=%s %s ext4   rw,noatime,nofail   0 2\n' "$LABEL" "$MP" >> /etc/fstab
	mkdir -p "$MP"
	mount "$MP" 2>/dev/null || mount "LABEL=$LABEL" "$MP"
	df -h "$MP"
	sed -n "/$LABEL/p" /etc/fstab
else
	echo "  (dry-run) 追加 fstab 一行 + mount $MP"
fi
echo "=== done (APPLY=$APPLY)"
