#!/bin/bash
# f2fs-migrate.sh — 路线 A：**缩小 linux17(ext4) + 尾部新建 linux18(f2fs) + 本地复制**（零大文件传输）
#
# 为什么是 A 而不是 B（2026-10-25 实测改写）：
#   主机 ←→ 设备的 USB NCM 链路只有 **14.3 MB/s**（300 MB / 21.0 s，原始字节）。
#   B（原地换）要把 30 GB 根搬去主机再搬回来 ≈ 1–1.5 h 纯传输，且 ext4 一旦格式化就没有本地回退。
#   A 的数据全程留在同一颗 UFS 上（本地 tar 复制，分钟级），ext4 原样保留 = 零成本回退。
#
# 阶段（每阶段独立可跑；设备侧阶段必须在 **RAM root** 里执行，因为 ext4 要离线缩容）：
#   preflight   只读核查 + 打印完整计划（默认动作）
#   archive     （可选）主机拉一份根归档作最终保险（14 MB/s ⇒ 30 GB ≈ 36 min，后台跑）
#   rescue      fastboot boot 进 RAM root（零写盘）
#   shrink      离线缩 ext4 → 写 GPT → 建 f2fs → 本地复制（**写盘，需 --yes**）
#   bootimg     构建/签名 `elden_root=LABEL=linux18` 的 boot.img 并核对（不写槽）
#   writeslot   写 boot_b（**写槽，需 --yes**；失败恢复 = fastboot set_active b）
#   verify      上机判据表（只读）
#
# 用法：
#   bash scripts/f2fs-migrate.sh                 # = preflight
#   bash scripts/f2fs-migrate.sh archive
#   bash scripts/f2fs-migrate.sh shrink --yes    # 在设备的 RAM root 里跑
#
# 设计约束：所有写盘动作都必须显式 --yes；每条 dd 之后读回比对；GPT 双表同时更新。
set -uo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TAB=${TAB:-root@192.168.7.1}
SSH="ssh -o BatchMode=yes -o ConnectTimeout=8 $TAB"
DEV=${DEV:-/dev/sda}
PART_OLD=${PART_OLD:-${DEV}17}       # linux17 (ext4) → 缩到 KEEP_GIB
PART_NEW=${PART_NEW:-${DEV}18}       # linux18 (f2fs，新建)
KEEP_GIB=${KEEP_GIB:-96}
NEW_GIB=${NEW_GIB:-96}
LABEL_OLD=${LABEL_OLD:-linux17}
LABEL_NEW=${LABEL_NEW:-linux18}
STAMP=$(date +%Y%m%d-%H%M%S)
WORK=${WORK:-$ROOT/backup/f2fs-migrate-$STAMP}
YES=0
for a in "$@"; do [ "$a" = "--yes" ] && YES=1; done
STAGE=${1:-preflight}

say()  { printf '\n\033[1m=== %s\033[0m\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die()  { printf 'FATAL: %s\n' "$*" >&2; exit 1; }
need_yes() { [ "$YES" = 1 ] || die "$1 会写盘/写槽；确认后加 --yes"; }

# ---------------------------------------------------------------- preflight
preflight() {
	say "1. 设备可达性与基线"
	$SSH true 2>/dev/null || die "设备不可达（$TAB）"
	$SSH '
		echo "UTS=$(uname -r)"
		echo "root=$(findmnt -no SOURCE,FSTYPE / )"
		echo "modules=$(grep -c "^" /proc/modules)"
		echo "linux17=$(blockdev --getsize64 /dev/sda17 2>/dev/null) B"
		command -v resize2fs e2label tune2fs mkfs.f2fs fsck.f2fs tar zstd gzip
		slot-attr.py show 2>/dev/null | grep -E "boot_[ab] "
	' || die "基线读取失败"

	say "2. 尺寸账（4 KiB 扇区）"
	python3 - "$KEEP_GIB" "$NEW_GIB" <<'PY'
import sys
keep, new = int(sys.argv[1]), int(sys.argv[2])
SEC = 4096
total = 50593792                      # linux17 当前扇区数（2026-10-25 GPT 实测）
k = keep * (2**30)//SEC
n = new * (2**30)//SEC
print(f"  当前 linux17 = {total} sectors = {total*SEC/2**30:.1f} GiB")
print(f"  缩后 linux17 = {k} sectors = {keep} GiB")
print(f"  新建 linux18 = {n} sectors = {new} GiB")
print(f"  合计         = {k+n} sectors，余量 {total-k-n} sectors = {(total-k-n)*SEC//2**20} MiB")
print(f"  resize2fs 目标块数（4K 块，留 1024 块给超级块/元数据膨胀）: {k-1024}")
assert k+n <= total, "KEEP_GIB + NEW_GIB 超过现有 linux17"
PY

	say "3. 工具缺口：RAM root 没有 resize2fs（disk root 有）"
	$SSH 'ls -l /usr/sbin/resize2fs 2>/dev/null; zcat /proc/self/mountinfo >/dev/null 2>&1; echo ok' >/dev/null 2>&1 || true
	echo "  RAM root 里会用「只读挂 ext4 → 拷 resize2fs 出来 → umount → 缩容」的方式取工具（无需网络）"

	say "4. 已有 GPT 双表备份"
	ls -l "$ROOT"/backup/*/gpt-20261025/*.bin 2>/dev/null || warn "缺 GPT 备份（先跑 rescue 之前用 dd 抓一份）"

	say "5. 计划（按顺序）"
	cat <<EOF
  ① bash $0 archive                 # （可选）主机拉根归档，14 MB/s ⇒ 30 GB ≈ 36 min
  ② fastboot boot out/boot-elden-vk162-rescue.img     # 进 RAM root（零写盘）
  ③ bash $0 shrink --yes            # 在 RAM root 里：e2fsck → resize2fs → 写 GPT（双表+读回校验）
                                    #   → partprobe → mkfs.f2fs -l $LABEL_NEW $PART_NEW
                                    #   → 本地 tar 复制（--xattrs --acls）→ fsck.f2fs
  ④ bash $0 bootimg                 # 主机：构建 elden_root=LABEL=$LABEL_NEW 的镜像（不写槽）
  ⑤ bash $0 writeslot --yes         # 写 boot_b（签名 + 读回校验）；失败恢复 fastboot set_active b
  ⑥ 重启 → bash $0 verify           # 判据表
  回退：① 不写槽时：fastboot boot out/boot-elden-vk152.img（ext4 仍完整）
        ② 写了槽：重写 vk152 或 fastboot boot 它
EOF
}

# ------------------------------------------------------------------ archive
archive() {
	mkdir -p "$WORK"
	local out=$WORK/linux17-rootfs-$STAMP.tar.zst
	say "拉取根归档 → $out（14 MB/s ⇒ 30 GB ≈ 36 min；可后台）"
	$SSH 'sync; tar -C / -c --one-file-system --acls --xattrs . 2>/tmp/tar.err' | zstd -3 -T0 -q -o "$out" \
		|| die "归档失败（见设备 /tmp/tar.err）"
	ls -lh "$out"
	printf '%s  %s\n' "$(sha256sum "$out" | cut -d' ' -f1)" "$(basename "$out")" > "$out.sha256"
	cat "$out.sha256"
	$SSH 'cat /tmp/tar.err' 2>/dev/null | head -5
	echo "（tar.err 里若有 'socket ignored' 属正常：运行时套接字不该归档）"
}

# ------------------------------------------------------------------- shrink
shrink() {
	need_yes "shrink"
	# 必须在 RAM root：ext4 要卸载才能缩
	$SSH 'findmnt -no SOURCE / | grep -q "/dev/sda" && echo ON_DISK_ROOT || echo RAM_ROOT' | grep -q RAM_ROOT \
		|| die "当前不是 RAM root（先 fastboot boot out/boot-elden-vk162-rescue.img）"

	say "0. 抓当前 GPT 双表（写前最后一份）"
	mkdir -p "$WORK"
	$SSH "dd if=$DEV bs=4096 count=6 2>/dev/null" > "$WORK/gpt_before_main0.bin"
	$SSH "dd if=$DEV bs=4096 skip=\$((\$(python3 -c 'print(123871231)')-4)) count=5 2>/dev/null" > "$WORK/gpt_before_backup0.bin"
	python3 "$ROOT/scripts/gpt-surgery-tb322fc.py" list --main "$WORK/gpt_before_main0.bin" | head -3

	say "1. 生成新 GPT（先只生成，不写）"
	python3 "$ROOT/scripts/gpt-surgery-tb322fc.py" shrink-append \
		--main "$WORK/gpt_before_main0.bin" --backup "$WORK/gpt_before_backup0.bin" \
		--out-prefix "$WORK/gpt_after" \
		--shrink-name "$LABEL_OLD" --new-name "$LABEL_NEW" \
		--keep-gib "$KEEP_GIB" --new-gib "$NEW_GIB" || die "GPT 生成失败"

	say "2. 取 resize2fs（只读挂 ext4 → 拷出来 → 立刻 umount）"
	$SSH '
	set -e
	mkdir -p /mnt/ro /tmp/e2tools
	mount -o ro '"$PART_OLD"' /mnt/ro
	for t in resize2fs e2label tune2fs dumpe2fs; do
		[ -x /mnt/ro/usr/sbin/$t ] && cp /mnt/ro/usr/sbin/$t /tmp/e2tools/ 2>/dev/null || true
		[ -x /mnt/ro/sbin/$t ] && cp /mnt/ro/sbin/$t /tmp/e2tools/ 2>/dev/null || true
	done
	umount /mnt/ro
	chmod +x /tmp/e2tools/* 2>/dev/null || true
	ls -l /tmp/e2tools
	/tmp/e2tools/resize2fs -V 2>&1 | head -2
	'

	say "3. e2fsck -f 后离线缩容到 ${KEEP_GIB} GiB"
	$SSH "
	set -e
	BLOCKS=\$(( ${KEEP_GIB} * 1073741824 / 4096 - 1024 ))
	echo \"resize2fs target blocks=\$BLOCKS\"
	/tmp/e2tools/e2fsck -f -y $PART_OLD | tail -3
	/tmp/e2tools/resize2fs $PART_OLD \$BLOCKS | tail -3
	/tmp/e2tools/dumpe2fs -h $PART_OLD 2>/dev/null | grep -E 'Block count|Block size|Filesystem features'
	"

	say "4. 写 GPT（主表 LBA0..5 + 备份表），写后读回校验"
	$SSH "
	set -e
	dd if=/dev/stdin of=$DEV bs=4096 seek=0 conv=notrunc oflag=direct 2>/dev/null
	" < "$WORK/gpt_after_main0.bin" || die "主表写入失败"
	$SSH "dd if=$DEV bs=4096 count=6 2>/dev/null" > "$WORK/gpt_rb_main0.bin"
	cmp -s "$WORK/gpt_after_main0.bin" "$WORK/gpt_rb_main0.bin" || die "主表读回不一致"
	echo "主表读回一致 ✅"
	# 备份表：位置 = 原 backup_lba - 4（表）+ 头
	$SSH "
	set -e
	BASE=\$(( 123871231 - 4 ))
	dd if=/dev/stdin of=$DEV bs=4096 seek=\$BASE conv=notrunc oflag=direct 2>/dev/null
	" < "$WORK/gpt_after_backup0.bin" || die "备份表写入失败"
	$SSH "dd if=$DEV bs=4096 skip=123871227 count=5 2>/dev/null" > "$WORK/gpt_rb_backup0.bin"
	cmp -s "$WORK/gpt_after_backup0.bin" "$WORK/gpt_rb_backup0.bin" || die "备份表读回不一致"
	echo "备份表读回一致 ✅"

	say "5. partprobe + 确认新分区存在"
	$SSH "partprobe $DEV 2>/dev/null; udevadm settle 2>/dev/null; lsblk -b -o NAME,SIZE,TYPE $DEV | tail -4; blockdev --getsize64 $PART_NEW" \
		|| die "新分区 $PART_NEW 未出现"

	say "6. mkfs.f2fs -l $LABEL_NEW"
	$SSH "mkfs.f2fs -f -l $LABEL_NEW $PART_NEW | tail -6; blkid -o value -s TYPE $PART_OLD; blkid -o value -s TYPE $PART_NEW"

	say "7. 本地复制（同盘，分钟级；保留 xattr/ACL/硬链接）"
	$SSH "
	set -e
	mkdir -p /mnt/old /mnt/new
	mount -o ro $PART_OLD /mnt/old
	mount $PART_NEW /mnt/new
	tar -C /mnt/old -c --xattrs --acls --numeric-owner . | tar -C /mnt/new -x --xattrs --acls --numeric-owner
	sync
	du -x -s -B1 /mnt/old /mnt/new
	"
	say "8. 复制后校验：文件数 / 关键文件 sha / fsck.f2fs"
	$SSH "
	set -e
	printf 'old files: %s\nnew files: %s\n' \"\$(find /mnt/old -xdev | wc -l)\" \"\$(find /mnt/new -xdev | wc -l)\"
	for f in init usr/local/sbin/reboot2 lib/modules; do
		printf '%-28s %s\n' \"\$f\" \"\$(sha256sum /mnt/old/\$f 2>/dev/null | cut -d' ' -f1 | head -1)=/\$(sha256sum /mnt/new/\$f 2>/dev/null | cut -d' ' -f1 | head -1)\"
	done
	umount /mnt/old /mnt/new
	fsck.f2fs -f $PART_NEW | tail -3
	"
	echo
	echo "完成。下一步：主机侧 bash $0 bootimg（不写槽）→ 复核 → writeslot --yes"
}

# ------------------------------------------------------------------ bootimg
bootimg() {
	say "构建 elden_root=LABEL=$LABEL_NEW 的镜像（内核/DTB 逐字取自 vk152，ramdisk 用仓库 /init）"
	[ -e "$ROOT/out/initramfs-full-elden.cpio.gz" ] || \
		bash "$ROOT/scripts/build-initramfs.sh" full "$ROOT/out/rootfs-vk127.cpio.gz"
	local kd=$ROOT/build/vk151
	local kimg=$ROOT/out/.migrate-kernel.img
	[ -e "$kimg" ] || python3 "$ROOT/scripts/mkbootimg.py" --unpack "$ROOT/out/boot-elden-vk152.img" \
		--unpack-dir "$ROOT/out/.migrate-vk152" >/dev/null 2>&1
	kimg=$ROOT/out/.migrate-vk152/kernel
	VERSION=f2fs-root KDIR=$kd KERNEL_IMG=$kimg DTB_FILE=$ROOT/out/.migrate-vk152/dtb \
		RAMDISK=$ROOT/out/initramfs-full-elden.cpio.gz ROOTARGS="elden_root=LABEL=$LABEL_NEW" \
		bash "$ROOT/scripts/build-boot.sh" | tail -6
	echo "判据：manifest 的 cmdline 必须含 elden_root=LABEL=$LABEL_NEW，kernel_sha256 = b6a074ff…"
	grep -E "^cmdline=|^kernel_sha256=|^kernel_identity_source=" "$ROOT/out/boot-elden-f2fs-root.manifest"
}

# ---------------------------------------------------------------- writeslot
writeslot() {
	need_yes "writeslot"
	local img=$ROOT/out/boot-elden-f2fs-root.img
	local signed=$ROOT/bootslot-b/boot_b-f2fs-root.img
	[ -e "$img" ] || die "缺 $img（先跑 bootimg）"
	say "1. 签名（add_hash_footer，partition_size 96 MiB）"
	bash "$ROOT/scripts/sign-boot-b.sh" "$img" "$signed" || die "签名失败"
	sha256sum "$signed"

	say "2. 前置：设备必须已在 fastboot；记录槽基线"
	timeout 30 fastboot devices | grep -q . || die "fastboot 里看不到设备（先 reboot2 bootloader）"
	$SSH 'slot-attr.py show 2>/dev/null | grep "boot_b "' 2>/dev/null || \
		echo "（fastboot 状态下读不到 slot-attr，基线以进入 fastboot 前记录为准）"

	say "3. 写 boot_b（单条命令，不经管道，见 PITFALLS #3/#199）"
	timeout 300 fastboot flash boot_b "$signed" || die "fastboot flash 失败；设备可能在 bootloader，用 fastboot set_active b 兜底"
	echo "写完。**本轮不自动重启**：下一步手动 reboot 进新系统。"
	echo "写后读回校验（进系统后）：bash $0 readback"
}

# ------------------------------------------------------------------ readback
readback() {
	say "写后读回：设备 boot_b 前 96 MiB 的 sha256 vs 本地签名件"
	local signed=$ROOT/bootslot-b/boot_b-f2fs-root.img
	[ -e "$signed" ] || die "缺 $signed"
	local local_sha dev_sha
	local_sha=$(sha256sum "$signed" | cut -d' ' -f1)
	dev_sha=$($SSH 'dd if=/dev/disk/by-partlabel/boot_b bs=1M count=96 2>/dev/null' | sha256sum | cut -d' ' -f1)
	echo "local=$local_sha"
	echo "device=$dev_sha"
	[ "$local_sha" = "$dev_sha" ] && echo "读回一致 ✅" || die "读回不一致 ❌（重写或 fastboot set_active b 兜底）"
}

# ------------------------------------------------------------------- verify
verify() {
	say "上机判据（只读）"
	$SSH '
	echo "UTS=$(uname -r)"
	echo "root_fstype=$(findmnt -no FSTYPE /)   source=$(findmnt -no SOURCE /)"
	echo "init 日志:"; dmesg | grep -E "\[init\] (resolved|root fstype|switching root)" | tail -4
	echo "modules=$(grep -c "^" /proc/modules)  vermagic_err=$(dmesg | grep -c "version magic")"
	echo "phoc=$(pgrep -c phoc)  DSI=$(cat /sys/class/drm/card0-DSI-1/status 2>/dev/null)  brightness=$(cat /sys/class/backlight/*/brightness 2>/dev/null)"
	echo "f2fs 统计:"; cat /sys/fs/f2fs/sda18/segment_info 2>/dev/null | head -6 || true
	echo "df:"; df -h / | tail -1
	echo "slot:"; slot-attr.py show 2>/dev/null | grep "boot_b " | head -1
	'
	echo
	echo "回退：fastboot set_active b（若槽属性异常）/ fastboot boot out/boot-elden-vk152.img（ext4 仍完整）"
}

case "$STAGE" in
	preflight) preflight ;;
	archive)   archive ;;
	shrink)    shrink ;;
	bootimg)   bootimg ;;
	writeslot) writeslot ;;
	readback)  readback ;;
	verify)    verify ;;
	*) die "未知阶段 $STAGE（preflight|archive|shrink|bootimg|writeslot|readback|verify）" ;;
esac
