#!/bin/bash
# ensure-desktop-user.sh — 在 Debian 目标根里建「桌面用户」，与 Alpine 侧同 uid/组
#
# 为什么必须在目标根上跑而不是 stage.sh 里做（2026-10-26 实测）：
#   Debian 根是 debootstrap 产物，**没有任何发行版之外的用户**；而 greetd 的
#   `/etc/greetd/config.toml` 是 appliance 模式（initial_session → user `xuqianhui1001`）。
#   缺用户时 greetd 只打一行
#     error: configured default session user 'xuqianhui1001' not found
#   然后**立刻退出**，systemd 每 5 s 重拉一次 ⇒ 现象是 `greetd.service: activating`、
#   无 phoc/phosh、屏幕停在 VT7 的空白（连 greeter 都不出）。
#   useradd 需要真 root + 写 /etc/{passwd,group,shadow}，overlay 做不到 ⇒ 单独一个脚本。
#
# uid/gid 固定 1001（与 Alpine 侧一致，否则 /home 与 Waydroid/会话的属主全错）。
#
# 用法（在**设备**上，root，任意根本身）：
#   bash ensure-desktop-user.sh              # 幂等
#   bash ensure-desktop-user.sh --check      # 只检查，不改
set -uo pipefail
USER_NAME=${USER_NAME:-xuqianhui1001}
UID_N=${UID_N:-1001}
CHECK=0
ROOT=            # --root <dir>：在**别的根**上操作（build-rootfs.sh 用，免 chroot）
while [ $# -gt 0 ]; do
	case "$1" in
		--check) CHECK=1 ;;
		--root) shift; ROOT=${1:-} ;;
		*) echo "未知参数 $1" >&2; exit 2 ;;
	esac
	shift
done
# --root 时所有路径都加前缀（passwd/group 得用 --root 参数而不是文件编辑）
P=${ROOT:+$ROOT}

say() { printf '%s\n' "$*"; }
fail=0
bad() { say "FAIL  $*"; fail=$((fail+1)); }
ok()  { say "ok    $*"; }

if ${ROOT:+chroot "$ROOT"} getent passwd "$USER_NAME" >/dev/null 2>&1; then
	ok "用户已存在: $(${ROOT:+chroot "$ROOT"} getent passwd "$USER_NAME")"
else
	if [ "$CHECK" = 1 ]; then bad "用户 $USER_NAME 不存在"; else
		# --user-group：建同名组；组列表按「设备上真实存在的才加」过滤，
		# 不同发行版组名不同（Debian 有 render/netdev，Alpine 用 video/audio/input/plugdev）
		groups_want=""
		for g in video render audio input plugdev netdev bluetooth wheel; do
			${ROOT:+chroot "$ROOT"} getent group "$g" >/dev/null 2>&1 && groups_want="$groups_want,$g"
		done
		${ROOT:+chroot "$ROOT"} useradd ${ROOT:+-R "$ROOT"} -u "$UID_N" -M -s /bin/bash -U -G "${groups_want#,}" "$USER_NAME" \
			&& ok "已创建 $USER_NAME (uid=$UID_N, 组=${groups_want#,})" \
			|| bad "useradd 失败"
	fi
fi

# home 属主（tar/rsync 带过来的 uid 可能不对）+ 桌面需要的目录
if [ -d "/home/$USER_NAME" ]; then
	chown -R "$UID_N:$UID_N" "/home/$USER_NAME" 2>/dev/null
	ok "home 属主已校正: $(stat -c '%u:%g' "/home/$USER_NAME")"
	[ "$CHECK" = 1 ] || install -d -o "$USER_NAME" -g "$USER_NAME" -m 700 "/home/$USER_NAME/.local/share" 2>/dev/null
else
	bad "/home/$USER_NAME 不存在"
fi

# 无密码 passwd（greetd 的 initial_session 不需要密码，但锁定账号会让 pam_unix 拒绝会话）
if command -v passwd >/dev/null 2>&1; then
	if [ "$CHECK" = 0 ]; then
		usermod -p '' "$USER_NAME" 2>/dev/null && ok "密码字段已清空（appliance 自动登录）" || say "warn: usermod -p 失败（可忽略）"
	fi
fi

say "---- 结果：FAIL=$fail ----"
[ "$fail" -eq 0 ] || exit 1
