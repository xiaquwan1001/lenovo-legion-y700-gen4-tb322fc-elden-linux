#!/bin/sh
# dev-userdata-relabel.sh — 设备侧（POSIX sh）：把 Android userdata（sda16）就地转成 Linux 数据分区
#   零数据搬移：类型码 1B81E7E6-...（Android user data）→ 8300（Linux filesystem），扇区范围不变。
#   可逆：改回 1B81E7E6-... 即成 userdata（内容当然已被 mkfs 覆盖）。
#   另：修 droidloom 卡点 = / 及祖先属主 root:root 且组不可写。
# 用法（主机）：scp 到设备 /tmp 后 `sh /tmp/dev-userdata-relabel.sh [--apply]`；默认 dry-run。
set -e
PART=/dev/sda16
APPLY=0
[ "$1" = "--apply" ] && APPLY=1

echo "=== 1) root 属主（droidloom check_parent: uid==0 && mode&022==0）"
for d in / /var /var/lib /var/lib/droidloom /var/lib/droidloom/users; do
	[ -d "$d" ] || continue
	printf '  %-28s %s\n' "$d" "$(stat -c '%U:%G %a' "$d")"
done
if [ $APPLY = 1 ]; then
	chown 0:0 / /var /var/lib 2>/dev/null || true
	chmod 755 /
	echo "  -> after:"
	for d in / /var /var/lib; do printf '  %-28s %s\n' "$d" "$(stat -c '%U:%G %a' "$d")"; done
fi

echo "=== 2) GPT 备份"
TS=$(date +%Y%m%d-%H%M%S)
if [ $APPLY = 1 ]; then
	sgdisk --backup=/root/gpt-sda-$TS.bin /dev/sda
	sfdisk --dump /dev/sda > /root/gpt-sda-$TS.sfdisk 2>/dev/null || sgdisk --print /dev/sda > /root/gpt-sda-$TS.txt
	ls -l /root/gpt-sda-$TS.*
else
	echo "  (dry-run) 将写 /root/gpt-sda-$TS.bin 与 .txt"
fi

echo "=== 3) userdata 现状"
sgdisk -i 16 /dev/sda | sed -n '1,8p'

echo "=== 4) 类型改为 Linux filesystem（扇区不动）"
if [ $APPLY = 1 ]; then
	sgdisk --typecode=16:8300 --change-name=16:elden-data /dev/sda
	partx -u /dev/sda 2>/dev/null || partprobe /dev/sda 2>/dev/null || true
	sgdisk -i 16 /dev/sda | sed -n '1,8p'
	lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL "$PART"
else
	echo "  (dry-run) sgdisk --typecode=16:8300 --change-name=16:elden-data /dev/sda"
fi

echo "=== 5) 建 ext4（会丢弃 Android userdata 内容，按用户 2026-11-11 授权）"
if [ $APPLY = 1 ]; then
	mkfs.ext4 -q -F -L elden-data -m 1 "$PART"
	blkid "$PART"
else
	echo "  (dry-run) mkfs.ext4 -q -F -L elden-data -m 1 $PART"
fi

echo "=== 6) fstab + 挂载"
if [ $APPLY = 1 ]; then
	grep -q 'LABEL=elden-data' /etc/fstab || \
		printf 'LABEL=elden-data /data              ext4   rw,noatime,nofail   0 2\n' >> /etc/fstab
	mkdir -p /data
	mount /data 2>/dev/null || mount LABEL=elden-data /data
	df -h /data
	sed -n '/elden-data/p' /etc/fstab
else
	echo "  (dry-run) 追加 fstab 一行 + mount /data"
fi
echo "=== done (APPLY=$APPLY)"
