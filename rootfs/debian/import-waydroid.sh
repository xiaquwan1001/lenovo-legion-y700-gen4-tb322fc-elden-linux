#!/bin/bash
# import-waydroid.sh — 把现役 Alpine 根（linux18）里**已经调好的 Waydroid** 搬到 Debian 根（linux17）
#
# 为什么是"搬"而不是 `waydroid init`（2026-10-26 实测）：
#   1. `waydroid init` 要联网下载 2.6 GB GAPPS system.img；而现役根里已经有一份**验证过的**
#      （GAPPS + 我们烤进 vendor.img 的 AIDL vibrator HAL / camera provider）；
#   2. 更关键的是**设备侧静态 ELF**（`waydroid-sensord` / `waydroid-sensord-udp` /
#      `eldroid-sensord` / `elden-hapticd` / `ffrumble`）在仓库里没有源（MANIFEST `repo_src=-`，
#      T14 债务），只能从现役根拿；
#   3. `/root/wd/`（2 GB，Mesa + allocator.rc 等容器 bind 资产）同样只在设备上。
#
# 本脚本做四件事（全部幂等）：
#   A. images：system.img + vendor.img（跳过 .bak）
#   B. 配置：waydroid.cfg / waydroid.prop / waydroid_base.prop / lxc / rootfs / overlay*
#   C. 设备侧静态二进制 → /usr/local/bin（static 才安全，动态 musl 在 glibc 根上跑不了）
#   D. `/root/wd` + 把 Alpine 的 lxc `config_nodes` 里 Debian 不成立的条目改对：
#        · `/root/wd/allocator.rc` —— 我们刚把 /root/wd 搬过来 ⇒ 保留
#        · `/dev/video100`（相机 loopback）—— 不一定有 ⇒ 标 optional 1
#        · `/var/lib/waydroid/host-permissions` —— Alpine 是目录 ⇒ 建空目录
#
# 用法：
#   bash rootfs/debian/import-waydroid.sh --dry-run
#   bash rootfs/debian/import-waydroid.sh                     # 默认 TARGET=root@192.168.7.1
#
# ⚠️ 只在**设备上跑**（远端经 ssh）；不改分区/槽位，只写 linux17 当前根。
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
TARGET=${TARGET:-root@192.168.7.1}
SSH_OPTS=${SSH_OPTS:--o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null}
SRC_LABEL=${SRC_LABEL:-linux18}   # 现役 Alpine 根（只读挂载）
DRY=0
[ "${1:-}" = --dry-run ] && DRY=1

if [ "$DRY" = 1 ]; then
	echo "[dry-run] 会：挂 $SRC_LABEL 只读 → 拷 images/cfg/overlay/root/wd/静态二进制 → 补 config_nodes → 重启 waydroid"
	exit 0
fi

REMOTE=$(cat <<'EOS'
set -e
SRC_LABEL=$1
M=/mnt/elden-waydroid-src
S=$M/var/lib/waydroid
D=/var/lib/waydroid
mkdir -p "$M"
mountpoint -q "$M" || mount -o ro "/dev/disk/by-label/$SRC_LABEL" "$M"

echo "[A] images"
mkdir -p "$D/images"
for f in system.img vendor.img; do
	if [ -e "$S/images/$f" ] && [ ! -e "$D/images/$f" ]; then
		cp "$S/images/$f" "$D/images/$f"; echo "  + $f"
	else
		echo "  = $f (已存在或源缺)"
	fi
done

echo "[B] 配置"
for f in waydroid.cfg waydroid.prop waydroid_base.prop; do
	[ -e "$S/$f" ] && cp -f "$S/$f" "$D/$f" && echo "  + $f"
done
for d in lxc rootfs overlay overlay_rw overlay_work; do
	[ -d "$S/$d" ] && { mkdir -p "$D/$d"; cp -a "$S/$d/." "$D/$d/" 2>/dev/null || true; echo "  + $d/"; }
done

echo "[C] 设备侧静态二进制"
for b in waydroid-sensord waydroid-sensord-udp eldroid-sensord elden-hapticd ffrumble; do
	if [ -e "$M/usr/local/bin/$b" ]; then
		if readelf -l "$M/usr/local/bin/$b" 2>/dev/null | grep -qi interpreter; then
			if readelf -l "$M/usr/local/bin/$b" 2>/dev/null | grep -qi 'ld-musl'; then
				echo "  ! $b 是 **musl 动态**件：glibc 根上 exec 会 ENOENT（不是可以忽略的 warning）"
				case "$b" in
					waydroid-sensord) echo "      ⇒ 必须重编：主机跑 scripts/deploy-sensord-routec-debian.sh（否则 Android 永远卡 bootanimation）" ;;
				esac
			else
				echo "  ! $b 是动态链接，glibc 根上不可用（跳过；需重编）"
			fi
		else
			cp -a "$M/usr/local/bin/$b" "/usr/local/bin/$b"; echo "  + $b"
		fi
	fi
done
command -v ssccli >/dev/null || echo "  ! 缺 ssccli（apt-get install libssc-bin）⇒ ssc-udp-relay 会 FATAL 退出"

echo "[D] /root/wd + config_nodes 修正"
[ -d "$M/root/wd" ] && { mkdir -p /root/wd; cp -a "$M/root/wd/." /root/wd/; echo "  + /root/wd"; }
mkdir -p /var/lib/waydroid/host-permissions
C=$D/lxc/waydroid/config_nodes
if [ -f "$C" ]; then
	# /dev/video100 不一定存在 ⇒ optional
	sed -i 's|^lxc.mount.entry = /dev/video100 dev/video100 none bind,create=file,optional 0 0|lxc.mount.entry = /dev/video100 dev/video100 none bind,create=file,optional 1 0|' "$C"
	# allocator.rc：只有 /root/wd 搬过来才保留，否则删（否则 lxc 起不来）
	if [ -e /root/wd/allocator.rc ]; then
		grep -q allocator.rc "$C" || echo "lxc.mount.entry = /root/wd/allocator.rc vendor/etc/init/android.hardware.graphics.allocator@4.0.service.minigbm_gbm_mesa.rc none bind,create=file 0 0" >> "$C"
	else
		sed -i '\|/root/wd/allocator.rc|d' "$C"
	fi
	echo "  = config_nodes 已修正"
fi

sync
umount "$M" 2>/dev/null || true
rmdir "$M" 2>/dev/null || true
echo "IMPORT-OK"
EOS
)

# shellcheck disable=SC2086
ssh $SSH_OPTS "$TARGET" "sh -s -- $SRC_LABEL" <<< "$REMOTE"
