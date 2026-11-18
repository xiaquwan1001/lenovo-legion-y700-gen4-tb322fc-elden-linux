#!/bin/bash
# android-min-build.sh — 「最小安卓全量线刷包」构建器（主机侧；stage 化，可重入）
#
# 为什么需要这个：现行 16 G 转包 259 包里的 super 只带非零 4 KiB 块（14.53 GiB），
# 分区已裁到极限（全部 ext4 空闲只有 44 MiB）、b 槽与 a 槽共享 extent（去 b 槽省 0 字节）
# ⇒ 唯一能让"待刷文件"真变小的是：删预装内容 + 重建分区 + lpmake 重打。
# 依据：reports/android-super-format-20261118.md（S1，格式与额度）、
#       reports/android-min-avb-facts-20261118.md（S2，AVB/虚拟 A/B/去预装边界）
#
# 需 root 的只有 mount/loop 与 mke2fs 的属主保真（原始件属主是 root:root，含 security.selinux 与文件 caps）。
#
# 用法（一般用 sudo bash 跑；stage 可重入，已完成的会跳过）：
#   sudo bash scripts/android-min-build.sh extract system_a
#   sudo bash scripts/android-min-build.sh debloat
#   sudo bash scripts/android-min-build.sh mkfs system_a --size-mib 5200
#   sudo bash scripts/android-min-build.sh report
#   sudo bash scripts/android-min-build.sh all          # extract+debloat+mkfs 全部（默认只 system_a）
#
# 环境变量：
#   SRC=out/android-super-20261118/extract/lpunpack-slot0   （S1 的解包目录）
#   WORK=out/android-min-20261118/work                      （暂存树，需 ~15 GiB）
#   NEW=out/android-min-20261118/new                        （重建后的分区镜像）
#   DEBLOAT="system/preinstall system/etc/AI system/etc/bgmusic"
#   MKFS_FEATURES="-O ^has_journal,^resize_inode,extent,ext_attr,dir_index,filetype,sparse_super,large_file,huge_file,uninit_bg,dir_nlink,extra_isize -I 256 -m 0"
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SRC=${SRC:-$ROOT/out/android-super-20261118/extract/lpunpack-slot0}
WORK=${WORK:-$ROOT/out/android-min-20261118/work}
NEW=${NEW:-$ROOT/out/android-min-20261118/new}
LOG=${LOG:-$ROOT/out/android-min-20261118/build.log}
DEBLOAT=${DEBLOAT:-"system/preinstall system/etc/AI system/etc/bgmusic"}
MKFS_FEATURES=${MKFS_FEATURES:-"-O ^has_journal,^resize_inode,extent,ext_attr,dir_index,filetype,sparse_super,large_file,huge_file,uninit_bg,dir_nlink,extra_isize -I 256 -m 0"}

mkdir -p "$WORK" "$NEW"
say() { printf '\n=== %s\n' "$*" | tee -a "$LOG"; }
step() { printf '  [%s] %s\n' "$1" "$2" | tee -a "$LOG"; }
die() { printf 'FATAL  %s\n' "$*" | tee -a "$LOG" >&2; exit 1; }

need_root() { [ "$(id -u)" = 0 ] || die "需要 root（mount/属主保真）：sudo bash $0 $*"; }

extract_part() { # extract <part>  —— loop 只读挂载 + rsync -aHAX 保属主/权限/xattr/caps
	local p=$1
	local img="$SRC/$p.img"
	local dst="$WORK/$p"
	[ -f "$img" ] || die "缺 $img（先跑 S1 的 lpunpack）"
	if [ -d "$dst" ] && [ -f "$dst/.extract.done" ]; then step skip "$p 已解出（$dst）"; return 0; fi
	need_root extract "$p"
	local mnt="$WORK/.mnt-$p"
	mkdir -p "$mnt" "$dst"
	mount -o loop,ro "$img" "$mnt" || die "mount $img 失败"
	rsync -aHAX --numeric-ids --delete "$mnt/" "$dst/" || { umount "$mnt"; die "rsync 失败"; }
	umount "$mnt" && rmdir "$mnt"
	touch "$dst/.extract.done"
	step ok "$p → $dst（$(du -sh --exclude=.extract.done "$dst" | cut -f1)）"
}

debloat() { # debloat [part]  —— 默认 system_a；DEBLOAT 里的路径相对于镜像根
	local part=${1:-system_a}
	local dst=$WORK/$part
	[ -d "$dst" ] || die "缺 $dst（先 extract $part）"
	local freed=0
	for d in $DEBLOAT; do
		if [ -e "$dst/$d" ]; then
			local s; s=$(du -sb "$dst/$d" | cut -f1)
			rm -rf "$dst/$d"
			freed=$((freed + s))
			step ok "删除 $d（$(numfmt --to=iec "$s")）"
		else
			step skip "$d 不在（已删或路径不符）"
		fi
	done
	step ok "本轮释放 $(numfmt --to=iec "$freed")"
	# 清掉 release 里不需要的调试残留：不删（保持行为一致），只报告
	: 
}

mkfs_part() { # mkfs <part> --size-mib N [--label L]
	local p=$1; shift
	local mib="" label=""
	while [ $# -gt 0 ]; do case "$1" in
		--size-mib) mib=$2; shift 2 ;;
		--label) label=$2; shift 2 ;;
		*) die "未知参数 $1" ;;
	esac; done
	local src=$WORK/$p out=$NEW/$p.img
	[ -d "$src" ] || die "缺暂存树 $src"
	need_root mkfs "$p"
	if [ -z "$mib" ]; then
		# 内容 × 1.06，向上取整到 16 MiB
		local used; used=$(du -sb --exclude=.extract.done "$src" | cut -f1)
		mib=$(( (used * 106 / 100) / 1048576 + 1 ))
		mib=$(( (mib / 16 + 1) * 16 ))
	fi
	[ -z "$label" ] && label=$(dumpe2fs -h "$SRC/$p.img" 2>/dev/null | sed -n 's/^Filesystem volume name: *//p')
	[ -n "$label" ] || label=$p
	step run "mke2fs -t ext4 -b 4096 $MKFS_FEATURES -L '$label' -d $src $out ${mib}M"
	rm -f "$out"
	mke2fs -q -t ext4 -b 4096 $MKFS_FEATURES -L "$label" -d "$src" "$out" "${mib}M" || die "mke2fs 失败（size ${mib}M 可能太小）"
	e2fsck -fn "$out" >/dev/null 2>&1 || { e2fsck -fn "$out" 2>&1 | tail -8 | tee -a "$LOG"; die "e2fsck 报错"; }
	step ok "$p.img $(du -h --apparent-size "$out" | cut -f1)（内容 $(du -sh --exclude=.extract.done "$src" | cut -f1)）；e2fsck clean"
}

report() {
	printf '\n%-16s %12s %12s\n' 分区 原图 新图 | tee -a "$LOG"
	local t0=0 t1=0
	for f in "$NEW"/*.img; do
		[ -e "$f" ] || continue
		local b; b=$(basename "$f" .img)
		local o=$SRC/$b.img
		local s0 s1; s0=$(du -h --apparent-size "$o" 2>/dev/null | cut -f1); s1=$(du -h --apparent-size "$f" | cut -f1)
		printf '%-16s %12s %12s\n' "$b" "$s0" "$s1" | tee -a "$LOG"
		t0=$((t0 + $(stat -c%s "$o" 2>/dev/null || echo 0))); t1=$((t1 + $(stat -c%s "$f")))
	done
	step ok "合计 原 $(numfmt --to=iec "$t0") → 新 $(numfmt --to=iec "$t1")"
}

cmd=${1:-help}; shift || true
case "$cmd" in
	extract) extract_part "$@" ;;
	debloat) shift; debloat "$@" ;;
	mkfs) mkfs_part "$@" ;;
	report) report ;;
	all) extract_part system_a; debloat system_a; mkfs_part system_a ;;
	*)
		sed -n '2,30p' "$0"; exit 2 ;;
esac
