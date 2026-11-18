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
#   $OUT/rootfs-minbase-<日期>.ext4.img（IMG_MIB 非空时）  最小档：直接可写的 ext4 镜像
#
# 最小档（GPT-minimal 路线，`RUNBOOK-BRINGUP/GPT-MINIMAL-DESIGN.md` §3.2；2026-11-18 加）：
#   APTLIST=rootfs/debian/apt-list-min.txt SUITE=trixie SKIP_DESKTOP=1 GATE_MIN=1 \
#   ROOTDIR=/opt/elden/minbase-rootfs ROOTSPEC=LABEL=linux STAGE=out/stage-min-<日期> \
#   IMG_MIB=6144 OUT=out bash rootfs/debian/build-rootfs.sh
#   ⇒ 产物是 **ext4 镜像**（`mke2fs -d`，可被 `qdl write 0/90504` 直写）；不装桌面/不建桌面用户。
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
APTLIST=${APTLIST:-$ROOT/rootfs/debian/apt-list.txt}
OUT=${OUT:-$ROOT/out/debian}
# 最小档旋钮（空/0 = 老行为，桌面根）
ROOTSPEC=${ROOTSPEC:-LABEL=linux17}          # /etc/fstab 的根设备写法（最小档用 LABEL=linux）
SKIP_DESKTOP=${SKIP_DESKTOP:-0}              # 1 = 不建桌面用户、不跑 daily-baseline
GATE_MIN=${GATE_MIN:-0}                      # 1 = 最小档门禁（不要求桌面件）
IMG_MIB=${IMG_MIB:-}                         # 非空 = 出 ext4 镜像（MiB），不出 tar
SSH_PUB=${SSH_PUB:-$HOME/.ssh/id_rsa.pub}    # 注意 sudo 下 $HOME=/root
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
  5 基线配置：/etc/fstab（$ROOTSPEC / ext4）· hostname=elden · hosts · ssh-keygen -A · authorized_keys($SSH_PUB)
  6 depmod -b $ROOTDIR $UTS
  7 瘦身：apt-get clean · 清 /var/lib/apt/lists · /tmp
  8 门禁：$([ "$GATE_MIN" = 1 ] && echo '最小档（arch/usr-merge/systemd/模块树/vermagic/tplg/sshd/fstab/无内核包）' || echo '桌面档（含桌面件与 fstab=linux17）')
  9 umount；$(if [ -n "$IMG_MIB" ]; then echo "mke2fs -d -L ${ROOTSPEC#LABEL=} → $OUT/rootfs-minbase-<日期>.ext4.img (${IMG_MIB} MiB)"; else echo "tar -I 'zstd -3 -T0' → $OUT/elden-rootfs-<日期>.tar.zst"; fi)
  设备侧（GPT-minimal P2）：qdl write 0/90504 <img> → 上台 resize2fs → 刷 boot_b（cmdline elden_root=$ROOTSPEC）
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
# ⚠️ 两个必须加的 rsync 选项（2026-10-26 实测踩到，属于「越修越坏」的一类）：
#   --keep-dirlinks：Debian sid 是 **usr-merge** 布局，/lib 与 /bin 都是指向 usr/ 的符号链接。
#     overlay 里的 `lib/`（firmware+modules）是个真目录，不加这个选项 rsync 会把
#     `/lib -> usr/lib` 这个符号链接**替换成真目录** ⇒ `/lib/ld-linux-aarch64.so.1` 消失 ⇒
#     此后 chroot 里所有 arm64 程序都跑不了（报 `qemu-aarch64: Could not open '/lib/ld-linux…'`）。
#   --chown=root:root：overlay 是普通用户建的，`rsync -a` 会把属主原样带进目标根。
rsync -aHAX --numeric-ids --keep-dirlinks --chown=root:root "$STAGE/" "$ROOTDIR/" \
	|| die "rsync overlay 失败"
# 幂等修复：如果上一次已经踩过（/lib 变成了真目录），把它还原成 usr-merge 的符号链接。
if [ ! -L "$ROOTDIR/lib" ] && [ -d "$ROOTDIR/usr/lib" ]; then
	step warn "/lib 不是符号链接（usr-merge 被破坏）→ 还原"
	for d in firmware modules; do
		if [ -d "$ROOTDIR/lib/$d" ]; then
			mkdir -p "$ROOTDIR/usr/lib/$d"
			rsync -aHAX --chown=root:root "$ROOTDIR/lib/$d/" "$ROOTDIR/usr/lib/$d/"
			rm -rf "$ROOTDIR/lib/$d"
		fi
	done
	find "$ROOTDIR/lib" -mindepth 1 -maxdepth 1 -exec mv -f {} "$ROOTDIR/usr/lib/" \; 2>/dev/null || true
	rmdir "$ROOTDIR/lib" 2>/dev/null && ln -s usr/lib "$ROOTDIR/lib"
fi
step ok "overlay 已铺（$(du -sh "$STAGE" | cut -f1)）"

# ---------------------------------------------------------------- 5 基线配置
say "5 基线配置"
cat > "$ROOTDIR/etc/fstab" <<EOF
# /etc/fstab — TB322FC mainline（根 = $ROOTSPEC ext4）
# 回退根（Android a 槽 / 旧 linux18）**故意不出现**：不该被 systemd 自动挂载/fsck。
$ROOTSPEC  /          ext4   rw,noatime            0 1
proc           /proc      proc   defaults              0 0
sysfs          /sys       sysfs  defaults              0 0
devpts         /dev/pts   devpts gid=5,mode=620        0 0
tmpfs          /dev/shm   tmpfs  defaults,nosuid,nodev 0 0
EOF
# usb0 lifeline 的 DHCP 配置（与 Alpine 侧同义）：只发地址、**不发默认网关**，
# 否则宿主机会把上网流量丢给平板。Debian 根的 busybox 自带 udhcpd applet（无符号链接），
# /init 的 usb0_dhcp() 会自己回退到 `busybox udhcpd`；缺这个文件时 /init 还会写 /run 内联版。
cat > "$ROOTDIR/etc/udhcpd.conf" <<'EOF'
start 192.168.7.2
end 192.168.7.20
interface usb0
lease_file /run/udhcpd.leases
option subnet 255.255.255.0
option lease 86400
EOF
printf 'elden\n' > "$ROOTDIR/etc/hostname"
cat > "$ROOTDIR/etc/hosts" <<'EOF'
127.0.0.1 localhost elden
::1       localhost ip6-localhost
EOF
# SSH 主机密钥 + root 授权（复用主机 ~/.ssh/id_rsa.pub：与设备现有恢复通道同一把）
chroot "$ROOTDIR" /bin/sh -c 'ssh-keygen -A >/dev/null 2>&1 || true'
if [ -f "$SSH_PUB" ]; then
	mkdir -p "$ROOTDIR/root/.ssh"; chmod 700 "$ROOTDIR/root/.ssh"
	cat "$SSH_PUB" > "$ROOTDIR/root/.ssh/authorized_keys"
	chmod 600 "$ROOTDIR/root/.ssh/authorized_keys"
fi
step ok "fstab / hostname / hosts / sshd 主机密钥 / authorized_keys"

# 桌面用户（greetd appliance 模式的 initial_session 目标）。
# 缺它 = greetd 打 `configured default session user ... not found` 后每 5 s 自杀一次，
# 现象是「systemd 起来了、DSI 也 connected，但没有 phoc/phosh」（2026-10-26 实测）。
# 用同一把脚本，保证「重建根」和「修现场」走同一份逻辑（uid 1001，与 Alpine 侧一致）。
HERE_D=$(cd "$(dirname "$0")" && pwd)
if [ "$SKIP_DESKTOP" = 1 ]; then
	step skip "SKIP_DESKTOP=1 → 不建桌面用户、不跑 daily-baseline"
fi
if [ "$SKIP_DESKTOP" != 1 ] && [ -x "$HERE_D/ensure-desktop-user.sh" ]; then
	bash "$HERE_D/ensure-desktop-user.sh" --root "$ROOTDIR" 2>/dev/null \
		|| chroot "$ROOTDIR" /usr/sbin/useradd -u 1001 -m -s /bin/bash -U \
			-G video,render,audio,input,plugdev,netdev,bluetooth xuqianhui1001 \
		|| say "warn: 桌面用户创建失败（需在目标根上跑 ensure-desktop-user.sh）"
	step ok "桌面用户 xuqianhui1001（uid 1001）"
fi

# 日用基线配置（与设备侧 scripts/mobian-daily-baseline.sh 同一份逻辑，见 rootfs/debian/daily-baseline.tsv 头注释）：
# sudo 组 + 无口令账户的 NOPASSWD、locale-gen + 中文 LANG、fcitx5 user unit、zram 内核门。
# 只在目标根里写 /etc 下的小文件；包本身由 apt-list.txt（= pkgmap + daily-baseline P0/P1）装上。
if [ "$SKIP_DESKTOP" != 1 ] && [ -x "$HERE_D/daily-baseline.sh" ]; then
	bash "$HERE_D/daily-baseline.sh" --root "$ROOTDIR" 2>&1 | sed 's/^/    /' || say "warn: daily-baseline.sh 有 MISS（见上），不阻塞构建"
	step ok "日用基线配置已应用"
fi

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
# 两个档都要的「交接件」（PITFALLS #680）：/init 与 usb-gadget 由 stage rsync 带进来，
# 少一件时 rsync 退出码照样 0、systemd 也能从 /sbin/init 起来 ⇒ 设备上表现为
# 「只有背光 + USB 完全不枚举」，与内核坏无法区分。所以在这里 fail-closed。
SRC_INIT=$(cd "$(dirname "$0")/../../initramfs" 2>/dev/null && pwd)/init
if [ -f "$ROOTDIR/init" ] && [ -x "$ROOTDIR/init" ]; then
	o "/init 在且可执行（$(stat -c%s "$ROOTDIR/init") B）"
	if [ -f "$SRC_INIT" ]; then
		cmp -s "$SRC_INIT" "$ROOTDIR/init" \
			&& o "/init == initramfs/init（同字节）" \
			|| b "/init 与真源 initramfs/init 不同（磁盘 init 分叉，改完真源要重跑构建）"
	fi
else
	b "缺 /init 或不可执行（stage 少件；设备上 systemd 会起但无 respawn/usb-gadget/udhcpd，见 PITFALLS #680）"
fi
if [ "$GATE_MIN" = 1 ]; then
	# 最小档门禁：只要求「能起 + 能 ssh + 模块/固件同源」
	[ "$(chroot "$ROOTDIR" dpkg --print-architecture 2>/dev/null)" = arm64 ] && o "dpkg arch = arm64" || b "dpkg arch 不是 arm64"
	[ -L "$ROOTDIR/lib" ] && [ -e "$ROOTDIR/lib/ld-linux-aarch64.so.1" ] && o "/lib 是 usr-merge 符号链接" || b "/lib 不是符号链接或缺 loader"
	{ [ -x "$ROOTDIR/sbin/init" ] || [ -L "$ROOTDIR/sbin/init" ]; } && o "/sbin/init 存在" || b "缺 /sbin/init"
	chroot "$ROOTDIR" systemctl --version >/dev/null 2>&1 && o "systemd 可执行" || b "systemctl 跑不起来"
	[ -f "$ROOTDIR/lib/modules/$UTS/modules.dep" ] && o "模块树在（$UTS）" || b "模块树缺失"
	[ -L "$ROOTDIR/lib/modules/$UTS/build" ] && b "模块树里有 build 链接（指到主机路径）" || o "模块树无 build 链接"
	# 取样模块要动态选：ath12k 在 vk189/vk192 里是 =y（built-in），硬编码会在最小档误报
	mko=$(find "$ROOTDIR/lib/modules/$UTS/kernel/drivers/net/wireless" -name '*.ko' -print -quit 2>/dev/null)
	[ -n "$mko" ] || mko=$(find "$ROOTDIR/lib/modules/$UTS/kernel" -name '*.ko' -print -quit 2>/dev/null)
	vm=$(modinfo -F vermagic "$mko" 2>/dev/null | awk '{print $1}')
	[ "$vm" = "$UTS" ] && o "vermagic 逐字匹配（$([ -n "$mko" ] && echo "${mko#$ROOTDIR/lib/modules/$UTS/kernel/}" || echo 'no .ko')）" || b "vermagic 不符（'$vm' ≠ '$UTS'，取样 '${mko:-none}'）"
	[ -f "$ROOTDIR/lib/firmware/qcom/sm8750/Lenovo-Y700-Gen4-tplg.bin" ] && o "tplg 在" || b "缺 tplg（音频必死）"
	[ -x "$ROOTDIR/usr/local/sbin/usb-gadget" ] && o "usb-gadget 在（USB-NCM 登入路径）" || b "缺 /usr/local/sbin/usb-gadget（无串口时唯一远程入口）"
	[ -f "$ROOTDIR/etc/udhcpd.conf" ] && o "udhcpd.conf 在" || b "缺 /etc/udhcpd.conf（usb0_dhcp 只能退化成 /run 内联版）"
	[ -x "$ROOTDIR/usr/sbin/sshd" ] && o "sshd 在" || b "缺 openssh-server"
	{ [ -L "$ROOTDIR/etc/systemd/system/ssh.service" ] || [ -L "$ROOTDIR/etc/systemd/system/multi-user.target.wants/ssh.service" ]; } && o "sshd 已 enable" || b "sshd 未 enable"
	[ -f "$ROOTDIR/root/.ssh/authorized_keys" ] && o "root authorized_keys 在" || b "缺 authorized_keys（重建后只能靠 console）"
	grep -vE '^[[:space:]]*#' "$ROOTDIR/etc/fstab" | grep -qF "$ROOTSPEC" && o "fstab 根 = $ROOTSPEC" || b "fstab 根不是 $ROOTSPEC"
	dpkg-query --admindir="$ROOTDIR/var/lib/dpkg" -W linux-image-'*' 2>/dev/null | grep -q . && b "装进了 Debian 内核包" || o "未装任何 Debian 内核包"
	o "已装包数 $(chroot "$ROOTDIR" dpkg-query -f '${Package}\n' -W 2>/dev/null | wc -l)"
	o "根体积 $(du -sh --exclude=proc --exclude=sys --exclude=dev "$ROOTDIR" 2>/dev/null | cut -f1)"
else
[ "$(chroot "$ROOTDIR" dpkg --print-architecture 2>/dev/null)" = arm64 ] && o "dpkg arch = arm64" || b "dpkg arch 不是 arm64"
# usr-merge 完整性：/lib 必须是 → usr/lib 的符号链接，否则 arm64 程序全跑不了
[ -L "$ROOTDIR/lib" ] && [ -e "$ROOTDIR/lib/ld-linux-aarch64.so.1" ] \
	&& o "/lib 是 usr-merge 符号链接，loader 可解析" \
	|| b "/lib 不是符号链接或缺 loader（overlay 覆盖破坏了 usr-merge）"
[ -x "$ROOTDIR/sbin/init" ] || [ -L "$ROOTDIR/sbin/init" ] && o "/sbin/init 存在（$(readlink -f "$ROOTDIR/sbin/init" 2>/dev/null | sed "s|$ROOTDIR||")）" || b "缺 /sbin/init"
chroot "$ROOTDIR" systemctl --version >/dev/null 2>&1 && o "systemd 可执行" || b "systemctl 跑不起来"
[ "$(cat "$ROOTDIR/etc/elden-init-mode" 2>/dev/null)" = systemd ] && o "/etc/elden-init-mode = systemd" || b "init-mode 不是 systemd"
[ -f "$ROOTDIR/lib/modules/$UTS/modules.dep" ] && o "模块树在（$UTS）" || b "模块树缺失"
vm=$(modinfo -F vermagic "$ROOTDIR/lib/modules/$UTS/kernel/drivers/net/wireless/ath/ath12k/ath12k.ko" 2>/dev/null | awk '{print $1}')
[ "$vm" = "$UTS" ] && o "vermagic 逐字匹配" || b "vermagic 不符（'$vm' ≠ '$UTS'）"
[ -f "$ROOTDIR/lib/firmware/qcom/sm8750/Lenovo-Y700-Gen4-tplg.bin" ] && o "tplg 在" || b "缺 tplg（音频必死）"
# 日用基线（2026-11-07 新增）：这三条任一不满足 = 设备上「能跑但没法日常用」
[ -x "$ROOTDIR/usr/bin/sudo" ] && o "sudo 在" || b "缺 sudo（daily-baseline.tsv P0）"
[ -f "$ROOTDIR/etc/sudoers.d/90-elden-desktop" ] && o "sudoers.d 可用性规则在（$(awk 'NR>1{print $3}' "$ROOTDIR/etc/sudoers.d/90-elden-desktop" | tr -d '\n')" || b "缺 /etc/sudoers.d/90-elden-desktop"
[ -f "$ROOTDIR/etc/environment.d/50-elden-ime.conf" ] && [ -L "$ROOTDIR/etc/systemd/user/graphical-session.target.wants/fcitx5.service" ] \
	&& o "输入法自启已配置（environment.d + fcitx5 user unit）" || b "输入法基线缺失"
find "$ROOTDIR/usr/share/fonts" -name 'NotoSansCJK*' -print -quit 2>/dev/null | grep -q . && o "CJK 字体在" || b "缺 CJK 字体（中文全是豆腐块）"
[ -f "$ROOTDIR/usr/share/qcom/sm8750/LENOVO/TB322FC/sensors/sns_reg.conf" ] && o "传感器 DSP 树在" || b "缺传感器 DSP 树"
# 判据看**活行**（注释里提到 linux18 是说明，不算违规）
grep -vE '^[[:space:]]*#' "$ROOTDIR/etc/fstab" | grep -q 'LABEL=linux17' \
	&& ! grep -vE '^[[:space:]]*#' "$ROOTDIR/etc/fstab" | grep -q 'linux18' \
	&& o "fstab 只指向 linux17（活行里没有 linux18）" || b "fstab 有问题"
[ -L "$ROOTDIR/etc/systemd/system/multi-user.target.wants/qbootctl.service" ] && o "qbootctl 已 enable" || b "qbootctl 未 enable"
[ -L "$ROOTDIR/etc/systemd/system/display-manager.service" ] && o "display-manager → greetd" || b "display-manager 缺失"
dpkg-query --admindir="$ROOTDIR/var/lib/dpkg" -W linux-image-'*' 2>/dev/null | grep -q . && b "装进了 Debian 内核包" || o "未装任何 Debian 内核包"
o "已装包数 $(chroot "$ROOTDIR" dpkg-query -f '${Package}\n' -W 2>/dev/null | wc -l)"
o "根体积 $(du -sh --exclude=proc --exclude=sys --exclude=dev "$ROOTDIR" 2>/dev/null | cut -f1)"
fi
[ "$f" = 0 ] || die "门禁 FAIL=$f"

# ---------------------------------------------------------------- 9 归档
say "9 归档"
cleanup; trap - EXIT
mkdir -p "$OUT"
if [ -n "$IMG_MIB" ]; then
	# 最小档：直接 `qdl write <lun>/<lba>` 可写的 ext4 镜像（mke2fs -d 从目录树生成）
	# ⚠️ 落在子目录：check-doctor §5/§5d 扫的是 `out/*.img`（顶级），顶级出现未登记的 `*.img`
	#    会报「registry 号无 manifest」与「内核身份表已过期」（2026-11-18 实测）
	IMGDIR="$OUT/p2-minbase-$(date -u +%Y%m%d)"
	mkdir -p "$IMGDIR"
	IMG="$IMGDIR/rootfs-minbase-$(date -u +%Y%m%d).ext4.img"
	command -v mke2fs >/dev/null || die "缺 mke2fs（e2fsprogs）"
	# 文件系统 label 取 ROOTSPEC 的 LABEL 值：busybox findfs 支持 LABEL=，不支持 PARTLABEL=
	fslabel=${ROOTSPEC#LABEL=}
	[ "$fslabel" != "$ROOTSPEC" ] || die "IMG_MIB 需要 ROOTSPEC=LABEL=<name>（当前 '$ROOTSPEC'）"
	rm -f "$IMG"
	mke2fs -q -t ext4 -b 4096 -L "$fslabel" -d "$ROOTDIR" "$IMG" "${IMG_MIB}M" || die "mke2fs -d 失败（IMG_MIB=$IMG_MIB 可能太小）"
	e2fsck -fy "$IMG" 2>&1 | tail -3
	step ok "镜像 $IMG  $(du -h "$IMG" | cut -f1)  sha256=$(sha256sum "$IMG" | cut -c1-16)…"
	debugfs -R 'ls -l /' "$IMG" 2>/dev/null | head -20 | sed 's/^/    /'
	sha256sum "$IMG" > "$IMG.sha256"
	say "完成：目标根 $ROOTDIR；ext4 镜像 ${IMG#$ROOT/}（fs label = $fslabel）"
else
ARC="$OUT/elden-rootfs-$(date -u +%Y%m%d).tar.zst"
tar -C "$ROOTDIR" --numeric-owner -I 'zstd -3 -T0' -cf "$ARC" . || die "tar 失败"
printf '  %s  %s  sha256=%s…\n' "$(du -h "$ARC" | cut -f1)" "${ARC#$ROOT/}" "$(sha256sum "$ARC" | cut -c1-16)"
say "完成：目标根 $ROOTDIR；归档 ${ARC#$ROOT/}"
fi
