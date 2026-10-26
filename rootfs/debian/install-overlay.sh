#!/bin/bash
# install-overlay.sh — 把 `out/stage-debian/` 推到目标根（默认设备上的 `linux17`）
#
# 为什么需要这个脚本（2026-10-26 实测事故）：
#   手工 `tar -C $R -xf -` 把 overlay 解到 Debian 根时，**顶掉了 usr-merge 的符号链接**：
#   Debian 的 `/lib` 本是 `-> usr/lib` 的符号链接，而 overlay 里有自己的 `lib/`（firmware、
#   modules）⇒ tar 把链接替换成**真目录**，于是 `/lib/ld-linux-aarch64.so.1` 解析不到
#   ⇒ chroot 里所有动态二进制报 `No such file or directory`（`chroot-exec-ok` 直接消失）。
#   正确做法 = `tar --keep-directory-symlink`（GNU tar：遇到同名符号链接**跟进去**而不是替换），
#   解完再**断言 usr-merge 仍然完好**。本脚本把这两件事固化，避免下次再手抖。
#
# 用法：
#   bash rootfs/debian/install-overlay.sh                      # 推送到 192.168.7.1 的 linux17
#   bash rootfs/debian/install-overlay.sh --dry-run            # 只打包 + 打印将做什么
#   TARGET=root@192.168.7.1 LABEL=linux17 bash rootfs/debian/install-overlay.sh
#   bash rootfs/debian/install-overlay.sh --local-mnt /mnt/x   # 已在本机挂好的根（免 ssh）
#
# 安全：只写 `LABEL` 指的那一块（默认 linux17 = Debian 目标根，**不是**现役 linux18）。
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
STAGE=${STAGE:-$ROOT/out/stage-debian}
TARGET=${TARGET:-root@192.168.7.1}
LABEL=${LABEL:-linux17}
SSH_OPTS=${SSH_OPTS:--o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null}
DRY=0
LOCAL_MNT=
for a in "$@"; do
	case "$a" in
		--dry-run) DRY=1 ;;
		--local-mnt) shift; LOCAL_MNT=$1 ;;
		-h|--help) sed -n '2,20p' "$0"; exit 0 ;;
		*) echo "未知参数 $a" >&2; exit 2 ;;
	esac
done
[ -d "$STAGE" ] || { echo "缺 $STAGE（先跑 bash rootfs/debian/stage.sh）" >&2; exit 1; }

echo "stage : $STAGE ($(du -sh "$STAGE" | cut -f1))"
echo "label : $LABEL"
TARBALL=$(mktemp -u /tmp/stage-debian-XXXXXX.tar.zst)   # -u：只留名字，zstd 不覆盖已存在文件
trap 'rm -f "$TARBALL"' EXIT
# --numeric-owner：root 在目标侧就是 0，别让宿主 uid 漏进去
tar -C "$STAGE" --numeric-owner -cf - . | zstd -q -3 -o "$TARBALL" -f
echo "tar   : $TARBALL ($(du -h "$TARBALL" | cut -f1))"

# 解包脚本（在目标侧执行；--keep-directory-symlink 是关键）
UNPACK=$(cat <<'EOS'
set -e
R=$1; T=$2
mkdir -p "$R"
if ! mountpoint -q "$R"; then
	mount "/dev/disk/by-label/$3" "$R"
	MOUNTED=1
fi
# 关键：--keep-directory-symlink 让 tar 跟随 usr-merge 符号链接，而不是把它替换成目录
tar -C "$R" --numeric-owner --keep-directory-symlink -xf "$T"
# 断言 usr-merge 完好
for d in bin sbin lib; do
	if [ -L "$R/$d" ]; then
		echo "usr-merge ok: /$d -> $(readlink "$R/$d")"
	elif [ -d "$R/$d" ]; then
		# /lib 允许是真目录**仅当**里面还有 ld-linux（非 usr-merge 的发行版）
		if [ "$d" = lib ] && [ -e "$R/usr/lib/ld-linux-aarch64.so.1" ]; then
			echo "warn: /$d 是真目录（非 usr-merge）" >&2
		else
			echo "FAIL: /$d 被解包顶成真目录（usr-merge 破了）" >&2; exit 1
		fi
	fi
done
sync
if [ "${MOUNTED:-0}" = 1 ]; then umount "$R"; fi
rm -f "$T"
echo "INSTALL-OK"
EOS
)

if [ -n "$LOCAL_MNT" ]; then
	[ "$DRY" = 1 ] && { echo "[dry-run] 会解到 $LOCAL_MNT"; exit 0; }
	echo "$UNPACK" | sh -s -- "$LOCAL_MNT" "$TARBALL" "$LABEL"
	exit $?
fi

[ "$DRY" = 1 ] && { echo "[dry-run] 会 scp 到 $TARGET 并解到 linux17"; exit 0; }

REMOTE_TAR=/tmp/elden-stage.tar.zst
# shellcheck disable=SC2086
scp $SSH_OPTS -q "$TARBALL" "$TARGET:$REMOTE_TAR" || { echo "scp 失败" >&2; exit 1; }
# 远程脚本走 stdin（`ssh host "多行脚本"` 会被折行拆坏），用完的 tar 由远程脚本自己删
# shellcheck disable=SC2086
echo "$UNPACK" | ssh $SSH_OPTS "$TARGET" sh -s -- /mnt/elden-target "$REMOTE_TAR" "$LABEL" | tee /tmp/elden-overlay-install.log
grep -q INSTALL-OK /tmp/elden-overlay-install.log || { echo "解包未确认（见 /tmp/elden-overlay-install.log）" >&2; exit 1; }
echo "done"
