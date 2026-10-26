#!/bin/bash
# build-rootfs.sh — 组装**完整**的 Debian(sid) 目标根（M5），落在主机磁盘上，供 M6/M7 上机
#
# 与 `stage.sh` 的分工：
#   stage.sh（免 root）= 组装「我们自己要加的那层」→ out/stage-debian/
#   build-rootfs.sh（需 root） = debootstrap minbase + apt 装 apt-list + 覆盖 stage-debian + 基线配置 → tar
#
# 为什么需要 root：debootstrap 与 chroot 里的 dpkg 都要真实 root（本机 AppArmor 限制非特权 userns，
# `unshare -r` 不可用，见 scripts/host-arm64-chroot.sh 里的说明）。arm64 二进制靠已注册的 binfmt 跑。
#
# 用法：
#   bash rootfs/debian/build-rootfs.sh --dry-run        # 只验前置 + 打印计划（免 root）
#   sudo bash rootfs/debian/build-rootfs.sh            # 真跑（可重入：已存在的步骤跳过）
#   sudo bash rootfs/debian/build-rootfs.sh --from=<N>  # 从第 N 步起（可重入）
#   sudo bash rootfs/debian/build-rootfs.sh --background # 自分离跑（写 /tmp/elden-rootfs-build.log），
#                                                       # 给 minbase+qemu 这种几十分钟的步骤用
#
# 产物：
#   $ROOTDIR（默认 /opt/elden/mobian-rootfs）              完整根（可直接 rsync / 挂载）
#   out/debian/elden-rootfs-<日期>.tar.zst                 归档（给设备侧解包用）
#
# 硬约束（写死在这里，别在命令行覆盖）：
#   * 目标根 = `linux17` ext4（LABEL=linux17），Alpine 现役根 `linux18` fstab 里**不出现**
#   * 绝不装 linux-image-* / firmware-qcom-soc（apt-list 门禁已挡，这里再断言一次）
#   * 内核/模块树 = 自编（stage-debian 带来），与 Debian 内核包无关
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
ROOTDIR=${ROOTDIR:-/opt/elden/mobian-rootfs}
SUITE=${SUITE:-sid}
MIRROR=${MIRROR:-https://mirrors.ustc.edu.cn/debian}
STAGE=${STAGE:-$ROOT/out/stage-debian}
APTLIST=$ROOT/rootfs/debian/apt-list.txt
OUT=$ROOT/out/debian
MODE=run; FROM=0; BACKGROUND=0
for a in "$@"; do case "$a" in
	--dry-run) MODE=dry ;;
	--background) BACKGROUND=1 ;;
	--from=*) FROM=${a#--from=} ;;
	-h|--help) sed -n '2,26p' "$0"; exit 0 ;;
	*) echo "未知参数 $a" >&2; exit 2 ;;
esac; done

# --background：自分离重跑一次（几十分钟的活不能挂在终端/SSH/工具调用上）
if [ "$BACKGROUND" = 1 ]; then
	LOG=${LOG:-/tmp/elden-rootfs-build.log}
	: > "$LOG"
	setsid nohup bash "$0" --from="$FROM" >>"$LOG" 2>&1 </dev/null &
	echo "started pid=$! log=$LOG"
	echo "  追进度： tail -f $LOG      判活： pgrep -f 'build-rootfs.sh --from='"
	exit 0
fi

say() { printf '\n=== %s\n' "$*"; }
step() { printf '  [%s] %s\n' "$1" "$2"; }
die() { printf 'FATAL  %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- 0 前置
say "0 前置检查"
[ -f "$APTLIST" ] || die "缺 $APTLIST（先跑 rootfs/debian/tools/check-pkgmap.sh）"
[ -d "$STAGE" ] || die "缺 $STAGE（先跑 rootfs/debian/stage.sh）"
[ -e /proc/sys/fs/binfmt_misc/qemu-aarch64 ] || die "缺 arm64 binfmt（apt install qemu-user-static）"
command -v debootstrap >/dev/null || die "缺 debootstrap（sudo apt install debootstrap）"
grep -qE '^linux-image-' "$APTLIST" && die "apt-list 里有 linux-image-*（禁用项门被绕过）"
grep -qE '^firmware-qcom-soc' "$APTLIST" && die "apt-list 里有 firmware-qcom-soc（无 sm8750 目录）"
n_pkgs=$(grep -c -v '^#' "$APTLIST")
free_kb=$(df -Pk "$(dirname "$ROOTDIR")" 2>/dev/null | awk 'NR==2{print $4}')
[ -n "${free_kb:-}" ] && [ "$free_kb" -lt 20971520 ] && die "磁盘可用 < 20 GiB（$((free_kb/1024/1024)) GiB）"
UTS=$(ls -1 "$STAGE/lib/modules" 2>/dev/null | head -1)
[ -n "${UTS:-}" ] || die "stage-debian 里没有模块树（先跑 stage.sh）"
step ok "apt-list $n_pkgs 个包；模块树 $UTS；stage $(du -sh "$STAGE" | cut -f1)"
step ok "ROOTDIR=$ROOTDIR  可用 $((free_kb/1024/1024)) GiB"
[ "$(id -u)" = 0 ] || { [ "$MODE" = dry ] || die "需要 root：sudo bash $0"; step warn "非 root → 只能 --dry-run"; }

if [ "$MODE" = dry ]; then
	say "计划（--dry-run，不执行）"
	cat <<EOF
  1 debootstrap --arch=arm64 --variant=minbase $SUITE $ROOTDIR $MIRROR   （已有 /bin/sh 则跳过）
  2 bind-mount /proc /sys /dev /dev/pts 进 chroot；拷主机 resolv.conf
  3 chroot: apt-get update && apt-get install -y --no-install-recommends \$(apt-list)  （$n_pkgs 包）
  4 rsync -a $STAGE/ → $ROOTDIR/   （固件 + 模块树 + 用户态 + 单元 + /init）
  5 基线配置：/etc/fstab（LABEL=linux17 / ext4）· hostname=elden · hosts · ssh-keygen -A
  6 depmod -b $ROOTDIR $UTS
  7 瘦身：apt-get clean · 清 /var/lib/apt/lists · /tmp
  8 门禁：dpkg arch=arm64 · /sbin/init → systemd · vermagic 逐字 · fstab 只指 linux17 · systemctl --version
  9 umount；tar -I 'zstd -3 -T0' → $OUT/elden-rootfs-<日期>.tar.zst
  设备侧（M6，零写盘）：候选镜像 ROOTARGS=elden_root=LABEL=linux17 + fastboot boot
EOF
	exit 0
fi

# ---------------------------------------------------------------- 1 debootstrap
if [ "$FROM" -le 1 ]; then
	say "1 debootstrap $SUITE arm64 → $ROOTDIR"
	if [ -x "$ROOTDIR/bin/sh" ]; then
		step skip "已存在，跳过"
	else
		mkdir -p "$ROOTDIR"
		debootstrap --arch=arm64 --variant=minbase --include=ca-certificates \
			"$SUITE" "$ROOTDIR" "$MIRROR" || die "debootstrap 失败"
	fi
fi

# ---------------------------------------------------------------- 2 mount
say "2 挂载伪文件系统（退出时自动卸载）"
mkdir -p "$ROOTDIR/proc" "$ROOTDIR/sys" "$ROOTDIR/dev" "$ROOTDIR/dev/pts" "$ROOTDIR/run"
_mounts=()
for m in proc sys dev dev/pts; do
	if ! mountpoint -q "$ROOTDIR/$m"; then
		mount --bind "/$m" "$ROOTDIR/$m" && _mounts+=("$ROOTDIR/$m")
	fi
done
cleanup() {
	for m in "${_mounts[@]:-}"; do [ -n "$m" ] && umount "$m" 2>/dev/null; done
}
trap cleanup EXIT
cp -f /etc/resolv.conf "$ROOTDIR/etc/resolv.conf" 2>/dev/null || true
step ok "已挂载并拷入 resolv.conf"

# ---------------------------------------------------------------- 3 apt
if [ "$FROM" -le 3 ]; then
	say "3 装 $(grep -c -v '^#' "$APTLIST") 个包（chroot 内）"
	printf 'deb %s %s main contrib non-free\n' "$MIRROR" "$SUITE" > "$ROOTDIR/etc/apt/sources.list"
	# 清单走文件而不是命令行参数：114 个包 + 依赖展开后 argv 会很长，也便于事后复核装了什么。
	cp -f "$APTLIST" "$ROOTDIR/tmp/elden-aptlist.txt"
	chroot "$ROOTDIR" /bin/sh -c '
		set -e
		export DEBIAN_FRONTEND=noninteractive
		apt-get update -qq
		apt-get install -y -qq --no-install-recommends $(grep -v "^#" /tmp/elden-aptlist.txt)
	' 2>&1 | tail -20 || die "apt-get install 失败（见上）"
	rm -f "$ROOTDIR/tmp/elden-aptlist.txt"
	step ok "apt 完成"
fi

# ---------------------------------------------------------------- 4 overlay
say "4 覆盖 stage-debian（固件/模块/用户态/单元/init）"
rsync -aHAX --numeric-ids "$STAGE/" "$ROOTDIR/" || die "rsync overlay 失败"
step ok "overlay 已铺（$(du -sh "$STAGE" | cut -f1)）"

# ---------------------------------------------------------------- 5 基线配置
say "5 基线配置"
cat > "$ROOTDIR/etc/fstab" <<'EOF'
# /etc/fstab — TB322FC mainline（Debian/Mobian 目标根 = linux17 ext4）
# Alpine 现役根（linux18 f2fs）**故意不出现**：它是回退根，不该被 systemd 自动挂载/fsck。
LABEL=linux17  /          ext4   rw,noatime            0 1
proc           /proc      proc   defaults              0 0
sysfs          /sys       sysfs  defaults              0 0
devpts         /dev/pts   devpts gid=5,mode=620        0 0
tmpfs          /dev/shm   tmpfs  defaults,nosuid,nodev 0 0
EOF
printf 'elden\n' > "$ROOTDIR/etc/hostname"
cat > "$ROOTDIR/etc/hosts" <<'EOF'
127.0.0.1 localhost elden
::1       localhost ip6-localhost
EOF
# SSH 主机密钥 + root 授权（复用主机 ~/.ssh/id_rsa.pub：与设备现有恢复通道同一把）
chroot "$ROOTDIR" /bin/sh -c 'ssh-keygen -A >/dev/null 2>&1 || true'
if [ -f "$HOME/.ssh/id_rsa.pub" ]; then
	mkdir -p "$ROOTDIR/root/.ssh"; chmod 700 "$ROOTDIR/root/.ssh"
	cat "$HOME/.ssh/id_rsa.pub" > "$ROOTDIR/root/.ssh/authorized_keys"
	chmod 600 "$ROOTDIR/root/.ssh/authorized_keys"
fi
step ok "fstab / hostname / hosts / sshd 主机密钥 / authorized_keys"

# ---------------------------------------------------------------- 6 depmod
say "6 depmod -b（模块树索引）"
depmod -b "$ROOTDIR" "$UTS" || die "depmod 失败"
step ok "modules.dep 已生成"

# ---------------------------------------------------------------- 7 瘦身
say "7 瘦身"
chroot "$ROOTDIR" /bin/sh -c 'apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*' 2>/dev/null || true
step ok "已清 apt 缓存与 lists"

# ---------------------------------------------------------------- 8 门禁
say "8 门禁"
f=0
b() { printf '  FAIL  %s\n' "$*"; f=$((f+1)); }
o() { printf '  ok    %s\n' "$*"; }
[ "$(chroot "$ROOTDIR" dpkg --print-architecture 2>/dev/null)" = arm64 ] && o "dpkg arch = arm64" || b "dpkg arch 不是 arm64"
[ -x "$ROOTDIR/sbin/init" ] || [ -L "$ROOTDIR/sbin/init" ] && o "/sbin/init 存在（$(readlink -f "$ROOTDIR/sbin/init" 2>/dev/null | sed "s|$ROOTDIR||")）" || b "缺 /sbin/init"
chroot "$ROOTDIR" systemctl --version >/dev/null 2>&1 && o "systemd 可执行" || b "systemctl 跑不起来"
[ "$(cat "$ROOTDIR/etc/elden-init-mode" 2>/dev/null)" = systemd ] && o "/etc/elden-init-mode = systemd" || b "init-mode 不是 systemd"
[ -f "$ROOTDIR/lib/modules/$UTS/modules.dep" ] && o "模块树在（$UTS）" || b "模块树缺失"
vm=$(modinfo -F vermagic "$ROOTDIR/lib/modules/$UTS/kernel/drivers/net/wireless/ath/ath12k/ath12k.ko" 2>/dev/null | awk '{print $1}')
[ "$vm" = "$UTS" ] && o "vermagic 逐字匹配" || b "vermagic 不符（'$vm' ≠ '$UTS'）"
[ -f "$ROOTDIR/lib/firmware/qcom/sm8750/Lenovo-Y700-Gen4-tplg.bin" ] && o "tplg 在" || b "缺 tplg（音频必死）"
[ -f "$ROOTDIR/usr/share/qcom/sm8750/LENOVO/TB322FC/sensors/sns_reg.conf" ] && o "传感器 DSP 树在" || b "缺传感器 DSP 树"
# 判据看**活行**（注释里提到 linux18 是说明，不算违规）
grep -vE '^[[:space:]]*#' "$ROOTDIR/etc/fstab" | grep -q 'LABEL=linux17' \
	&& ! grep -vE '^[[:space:]]*#' "$ROOTDIR/etc/fstab" | grep -q 'linux18' \
	&& o "fstab 只指向 linux17（活行里没有 linux18）" || b "fstab 有问题"
[ -L "$ROOTDIR/etc/systemd/system/multi-user.target.wants/qbootctl.service" ] && o "qbootctl 已 enable" || b "qbootctl 未 enable"
[ -L "$ROOTDIR/etc/systemd/system/display-manager.service" ] && o "display-manager → greetd" || b "display-manager 缺失"
dpkg-query --admindir="$ROOTDIR/var/lib/dpkg" -W linux-image-'*' 2>/dev/null | grep -q . && b "装进了 Debian 内核包" || o "未装任何 Debian 内核包"
o "已装包数 $(dpkg-query --admindir="$ROOTDIR/var/lib/dpkg" -f '${Package}\n' 2>/dev/null | wc -l)"
o "根体积 $(du -sh --exclude=proc --exclude=sys --exclude=dev "$ROOTDIR" 2>/dev/null | cut -f1)"
[ "$f" = 0 ] || die "门禁 FAIL=$f"

# ---------------------------------------------------------------- 9 归档
say "9 归档"
cleanup; trap - EXIT
mkdir -p "$OUT"
ARC="$OUT/elden-rootfs-$(date -u +%Y%m%d).tar.zst"
tar -C "$ROOTDIR" --numeric-owner -I 'zstd -3 -T0' -cf "$ARC" . || die "tar 失败"
printf '  %s  %s  sha256=%s…\n' "$(du -h "$ARC" | cut -f1)" "${ARC#$ROOT/}" "$(sha256sum "$ARC" | cut -c1-16)"
say "完成：目标根 $ROOTDIR；归档 ${ARC#$ROOT/}"
