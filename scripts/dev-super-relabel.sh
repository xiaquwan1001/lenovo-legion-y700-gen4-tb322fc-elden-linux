#!/bin/sh
# dev-super-relabel.sh — 设备侧（POSIX sh）：把 Android `super`（sda10，22 GiB 动态分区容器）转成 Linux 分区
#   零数据搬移：只改 GPT 类型码 + 名字，扇区范围不变。可逆（改回 1B81E7E6… 即恢复 userdata 语义；
#   super 的原类型码见下方 BEFORE 输出，恢复时用 ORIG_TYPE）。
# 用法（主机）：scp 到设备 /tmp 后 `sh /tmp/dev-super-relabel.sh [--apply]`；默认 dry-run。
set -e
# ★ 审计批 1 fail-closed 门（reports/scripts-audit-20261122.md §3，2026-11-22）：
#   旧版硬编码 PART=/dev/sda10（sda 编号随启动盘序不稳，违反设备等价原则）。
#   现改：按 PARTLABEL=super 运行时解析目标盘/分区号；--apply 必须显式 SN=<序列号>。
SN=${SN:-}
PART=${PART:-}
if [ -z "$PART" ]; then
	ROOTDISK=$(lsblk -rno PKNAME "$(findmnt -n -o SOURCE /)" 2>/dev/null | head -1)
	[ -n "$ROOTDISK" ] || { echo "FAIL: 解析不到根盘；显式传 PART=/dev/<盘><分区号>（知道自己在干什么时）" >&2; exit 1; }
	PART=$(lsblk -rno NAME,PARTLABEL "/dev/$ROOTDISK" | awk '$2=="super"{print "/dev/"$1; exit}')
	[ -n "$PART" ] || { echo "FAIL: /dev/$ROOTDISK 上没有 PARTLABEL=super 的分区 —— 拿错设备/已重命名，拒绝继续" >&2; exit 1; }
fi
MP=${MP:-/srv/elden-super}
LABEL=elden-super
APPLY=0
for a in "$@"; do [ "$a" = "--apply" ] && APPLY=1; done
if [ $APPLY = 1 ] && [ -z "$SN" ]; then
	echo "FAIL: --apply 是危险动作，必须显式确认目标设备：SN=<平板序列号> sh $0 --apply" >&2
	exit 1
fi
[ -n "$SN" ] && echo "目标设备 SN=$SN（人工确认这就是你要改的板子）"
echo "目标分区 = $PART（PARTLABEL=super 运行时解析）"
DISK="/dev/$(lsblk -rno PKNAME "$PART")"
PNUM=${PART##*[!0-9]}

# 前置门禁（B 项：写 GPT 前必须核对分区身份与扇区单位）
SSZ=$(blockdev --getss "$DISK")
[ "$SSZ" = 4096 ] || { echo "FAIL: $DISK 逻辑扇区=$SSZ ≠ 4096（本机 4096；按 512 假设改表会整表错位）" >&2; exit 1; }
sgdisk -p "$DISK" | grep -q 'Sector size (logical): 4096' || {
	echo "FAIL: sgdisk 报的不是 4096 逻辑扇区 ⇒ 它此刻按 512 读表，禁止 --typecode/--change-name（见 scripts/slot-attr.py 头注释）" >&2; exit 1; }
PNAME=$(sgdisk -i "$PNUM" "$DISK" | sed -n 's/^Partition name: .\(.*\).$/\1/p')
[ "$PNAME" = "super" ] || { echo "FAIL: $DISK 分区 $PNUM name='$PNAME' ≠ 'super'（分区号已变？按 GPT 名定位，别盲改号）" >&2; exit 1; }

echo "=== 1) super 现状"
sgdisk -i "$PNUM" "$DISK" | sed -n '1,8p'
ORIG_TYPE=$(sgdisk -i "$PNUM" "$DISK" | sed -n 's/^Partition GUID code: \([0-9A-F-]*\).*/\1/p')
echo "  原类型码 = $ORIG_TYPE（恢复用）"

echo "=== 2) GPT 备份"
TS=$(date +%Y%m%d-%H%M%S)
if [ $APPLY = 1 ]; then
	sgdisk --backup=/root/gpt-super-$TS.bin "$DISK"
	sgdisk --print "$DISK" > /root/gpt-super-$TS.txt
	ls -l /root/gpt-sda-$TS.*
else
	echo "  (dry-run) 将写 /root/gpt-sda-$TS.bin / .txt"
fi

echo "=== 3) 类型改 Linux filesystem（扇区不动）"
if [ $APPLY = 1 ]; then
	echo "  (danger: 改 $DISK 分区 $PNUM 的类型码与名字)"
	sgdisk --typecode="$PNUM:8300" --change-name="$PNUM:$LABEL" "$DISK"
	partx -u "$DISK" 2>/dev/null || partprobe "$DISK" 2>/dev/null || true
	sgdisk -i "$PNUM" "$DISK" | sed -n '1,8p'
	lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL "$PART"
else
	echo "  (dry-run) sgdisk --typecode=$PNUM:8300 --change-name=$PNUM:$LABEL $DISK"
fi

echo "=== 4) 建 ext4（丢弃 Android super 内容，按用户 2026-11-11 授权）"
if [ $APPLY = 1 ]; then
	# 幂等（F 项）：已是本项目 ext4 就跳过；其它文件系统要人显式 RECREATE=1，别 -F 盲抹
	cur=$(blkid -o value -s TYPE "$PART" 2>/dev/null || true)
	curlab=$(blkid -o value -s LABEL "$PART" 2>/dev/null || true)
	if [ "$cur" = ext4 ] && [ "$curlab" = "$LABEL" ]; then
		echo "  (已是 ext4 label=$LABEL，跳过 mkfs)"
	elif [ "${RECREATE:-0}" = 1 ]; then
		mkfs.ext4 -q -F -L "$LABEL" -m 1 "$PART"
	else
		echo "FAIL: $PART 现有 fs='${cur:-空}' label='${curlab:-}' —— 格式化会丢数据；确认后 RECREATE=1 重跑" >&2
		exit 1
	fi
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
