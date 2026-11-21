#!/bin/sh
# dev-userdata-relabel.sh — 设备侧（POSIX sh）：把 Android userdata（sda16）就地转成 Linux 数据分区
#   零数据搬移：类型码 1B81E7E6-...（Android user data）→ 8300（Linux filesystem），扇区范围不变。
#   可逆：改回 1B81E7E6-... 即成 userdata（内容当然已被 mkfs 覆盖）。
#   另：修 droidloom 卡点 = / 及祖先属主 root:root 且组不可写。
# 用法（主机）：scp 到设备 /tmp 后 `sh /tmp/dev-userdata-relabel.sh [--apply]`；默认 dry-run。
set -e
# ★ 审计批 1 fail-closed 门（2026-11-22）：旧版硬编码 PART=/dev/sda16；
#   现改：按 PARTLABEL=userdata（且 Android user data 类型 GUID）运行时解析；
#   --apply 必须显式 SN=<序列号>。默认仍是 dry-run。
SN=${SN:-}
PART=${PART:-}
if [ -z "$PART" ]; then
	ROOTDISK=$(lsblk -rno PKNAME "$(findmnt -n -o SOURCE /)" 2>/dev/null | head -1)
	[ -n "$ROOTDISK" ] || { echo "FAIL: 解析不到根盘；显式传 PART=/dev/<盘><分区号>（知道自己在干什么时）" >&2; exit 1; }
	# Android userdata：名字是 userdata 且类型 GUID = 1B81E7E6-…（AOSP user data）
	PART=$(lsblk -rno NAME,PARTLABEL,PARTTYPE "/dev/$ROOTDISK" \
		| awk 'toupper($3) ~ /^1B81E7E6/ && $2=="userdata"{print "/dev/"$1; exit}')
	[ -n "$PART" ] || { echo "FAIL: /dev/$ROOTDISK 上没有（PARTLABEL=userdata 且 Android user data 类型 GUID）的分区 —— 拿错设备/已重标签，拒绝继续" >&2; exit 1; }
fi
APPLY=0
for a in "$@"; do [ "$a" = "--apply" ] && APPLY=1; done
if [ $APPLY = 1 ] && [ -z "$SN" ]; then
	echo "FAIL: --apply 是危险动作（mkfs 不可逆），必须显式确认目标设备：SN=<平板序列号> sh $0 --apply" >&2
	exit 1
fi
[ -n "$SN" ] && echo "目标设备 SN=$SN（人工确认这就是你要改的板子）"
echo "目标分区 = $PART（userdata 运行时解析）"
DISK="/dev/$(lsblk -rno PKNAME "$PART")"
PNUM=${PART##*[!0-9]}

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
	sgdisk --backup=/root/gpt-userdata-$TS.bin "$DISK"
	sfdisk --dump "$DISK" > /root/gpt-userdata-$TS.sfdisk 2>/dev/null || sgdisk --print "$DISK" > /root/gpt-userdata-$TS.txt
	ls -l /root/gpt-sda-$TS.*
else
	echo "  (dry-run) 将写 /root/gpt-sda-$TS.bin 与 .txt"
fi

echo "=== 3) userdata 现状"
sgdisk -i "$PNUM" "$DISK" | sed -n '1,8p'
PNAME=$(sgdisk -i "$PNUM" "$DISK" | sed -n 's/^Partition name: .\(.*\).$/\1/p')
[ "$PNAME" = "userdata" ] || { echo "FAIL: $DISK 分区 $PNUM name='$PNAME' ≠ 'userdata'（解析错位？拒绝盲改）" >&2; exit 1; }

echo "=== 4) 类型改为 Linux filesystem（扇区不动）"
if [ $APPLY = 1 ]; then
	echo "  (danger: 改 $DISK 分区 $PNUM 类型码 + 名字)"
	sgdisk --typecode="$PNUM:8300" --change-name="$PNUM:elden-data" "$DISK"
	partx -u "$DISK" 2>/dev/null || partprobe "$DISK" 2>/dev/null || true
	sgdisk -i "$PNUM" "$DISK" | sed -n '1,8p'
	lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL "$PART"
else
	echo "  (dry-run) sgdisk --typecode=$PNUM:8300 --change-name=$PNUM:elden-data $DISK"
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
