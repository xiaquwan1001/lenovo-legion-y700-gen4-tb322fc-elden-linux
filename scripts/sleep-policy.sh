#!/bin/bash
# sleep-policy.sh — 设备「待机策略」开关：待机（关屏）时是否允许 SSH/网络继续可用
#
# 为什么有这个脚本（2026-11-21）：
#   设备在机内核带 suspend 支持，`gnome-settings-daemon`（gsd-power）默认在**空闲 900 s 后自动
#   suspend 到 s2idle**（`sleep-inactive-ac-type='suspend'`、`…-battery-type='suspend'`）。
#   suspend 期间 CPU/网络全停 ⇒ 主机侧 `ssh elden-root` 直接超时，任何无人值守轮次/远程调试
#   都会「设备凭空消失」，而**屏幕上看起来只是黑屏**，极易误判成掉电或内核崩（历史踩过多次）。
#
#   两条路只能选一条：
#     network   （默认）不自动 suspend，只关屏（`idle-delay` 保持）⇒ **待机时 SSH 可用**；
#                        代价 = 空闲功耗高于 s2idle（屏幕灭 + SoC 不进低功耗态）。
#     suspend   恢复 gsd-power 默认（空闲 900 s → s2idle）⇒ 省电，但待机时**不可 SSH**。
#
# 用法（主机侧，设备已在 USB-NCM 上可达）：
#   scripts/sleep-policy.sh --check            # 只报告（不改设备），退出码 0 = 已达标
#   scripts/sleep-policy.sh --apply network    # 关自动 suspend（等价旧版默认，--apply 默认就这个）
#   scripts/sleep-policy.sh --apply suspend    # 恢复自动 suspend（空闲 900 s）
#   TAB=root@192.168.7.1 scripts/sleep-policy.sh --check
#
# 判据（--check 之下 `network` 档）：
#   a) `sleep-inactive-ac-type` 与 `-battery-type` 都是 `nothing`
#   b) `sleep-inactive-ac-timeout` 与 `-battery-timeout` 都是 0
#   c) `org.gnome.desktop.session idle-delay` **> 0**（关屏仍要工作；不能顺手把屏幕常亮）
#   d) logind 未设 `IdleAction=suspend`（`/etc/systemd/logind.conf`；默认 ignore）
#   e) 设备侧 gsettings 落在**用户 1001 的 dconf**（不是 root 的）——这是本脚本最容易写错的地方：
#      直接 `ssh root@… gsettings set …` 会写 root 的 dconf，用户会话读不到，表现为「设了没用」。
#
# 纪律：只动 user 1001 的 gsettings 与 logind 配置；**不碰**内核 cmdline、不 mask suspend.target、
#   不改 `/sys/power/mem_sleep`（拿掉自动 suspend ≠ 禁止手动 `/usr/bin/elden-suspend`）。
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
TAB=${TAB:-root@192.168.7.1}
T=${T:-8}
USER_ID=${USER_ID:-1001}
UNAME_=
MODE=check
WANT=network

while [ $# -gt 0 ]; do
	case "$1" in
		--check) MODE=check; shift ;;
		--apply) MODE=apply; shift; [ $# -gt 0 ] && case "$1" in network|suspend) WANT=$1; shift ;; esac ;;
		network|suspend) WANT=$1; shift ;;
		-h|--help) sed -n '2,32p' "$0"; exit 0 ;;
		*) echo "未知参数：$1（见 --help）" >&2; exit 2 ;;
	esac
done

SSH=(ssh -o BatchMode=yes -o ConnectTimeout="$T" "$TAB")
ok()  { printf '  ok    %s\n' "$*"; }
no()  { printf '  MISS  %s\n' "$*"; missing=$((missing + 1)); }
fix() { printf '  FIX   %s\n' "$*"; }
missing=0

# 在**用户会话的 D-Bus** 上跑 gsettings（写成 root 的 dconf 是最常见的静默失败）。
# 注意 `su - 1001` 会报 "user 1001 does not exist"（su 要账号名，不吃 uid）⇒ 先解析账号名。
gs() { "${SSH[@]}" "su - $UNAME_ --shell /bin/sh -c 'export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$USER_ID/bus; gsettings $*'" 2>/dev/null; }

echo "== 0) 设备可达性 =="
"${SSH[@]}" 'uname -r' >/dev/null 2>&1 || { echo "设备不可达（$TAB）" >&2; exit 3; }
ok "$("${SSH[@]}" 'uname -r')"
# 账号名解析（su 需要账号名而非 uid）；解析不到就直接报错，避免后面全空判据当成"设备没设"
UNAME_=$("${SSH[@]}" "id -un $USER_ID 2>/dev/null")
[ -n "${UNAME_:-}" ] || { echo "设备上解析不到 uid=$USER_ID 的账号名（user@$USER_ID 没起？）" >&2; exit 4; }
ok "会话账号 = $UNAME_ (uid $USER_ID)"

echo "== 1) 现态（gsd-power 空闲动作）=="
ac_t=$(gs get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type | tr -d "'")
ac_s=$(gs get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout)
bt_t=$(gs get org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type | tr -d "'")
bt_s=$(gs get org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout)
idle=$(gs get org.gnome.desktop.session idle-delay | awk '{print $2}')
printf '  ac=%s/%ss  battery=%s/%ss  idle-delay(关屏)=%ss\n' "${ac_t:-?}" "${ac_s:-?}" "${bt_t:-?}" "${bt_s:-?}" "${idle:-?}"

case "$MODE" in
check)
	echo "== 2) 判据（档 = $WANT）=="
	if [ "$WANT" = network ]; then
		[ "$ac_t" = nothing ] && ok "ac 空闲动作 = nothing（不自动 suspend）" || no "ac 空闲动作 = $ac_t（应 nothing）"
		[ "$bt_t" = nothing ] && ok "battery 空闲动作 = nothing" || no "battery 空闲动作 = $bt_t（应 nothing）"
		[ "${idle:-0}" -gt 0 ] 2>/dev/null && ok "idle-delay=$idle > 0（关屏仍生效）" || no "idle-delay=$idle（关屏被关掉，屏幕会常亮）"
	else
		[ "$ac_t" = suspend ] && ok "ac 空闲动作 = suspend" || no "ac 空闲动作 = $ac_t（应 suspend）"
		[ "${ac_s:-0}" -gt 0 ] 2>/dev/null && ok "ac 空闲阈值 = ${ac_s}s" || no "ac 空闲阈值 = ${ac_s}（应 > 0）"
	fi
	idleaction=$("${SSH[@]}" "grep -Es '^IdleAction=' /etc/systemd/logind.conf /etc/systemd/logind.conf.d/*.conf 2>/dev/null | grep -v '^.*:#' | tail -1")
	case "$idleaction" in
		*IdleAction=suspend*) no "logind IdleAction=suspend（会在会话空闲时抢着睡）" ;;
		*) ok "logind 未设 IdleAction=suspend${idleaction:+（$idleaction）}" ;;
	esac
	mem=$("${SSH[@]}" 'cat /sys/power/mem_sleep' 2>/dev/null)
	ok "mem_sleep = $mem（本脚本不改它，手动 suspend 仍走 ${mem%% *}）"
	;;
apply)
	echo "== 2) 应用（档 = $WANT）=="
	if [ "$WANT" = network ]; then
		gs set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type nothing
		gs set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type nothing
		gs set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0
		gs set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 0
		# 关屏必须仍然工作（否则屏幕常亮，既费电又烧屏）
		[ "${idle:-0}" -gt 0 ] 2>/dev/null || gs set org.gnome.desktop.session idle-delay 300
		fix "已设 ac/battery = nothing、timeout = 0、idle-delay 保留"
	else
		gs set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type suspend
		gs set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type suspend
		gs set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 900
		gs set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 900
		fix "已恢复 ac/battery = suspend / 900 s"
	fi
	echo "== 3) 回读 =="
	printf '  ac=%s/%ss  battery=%s/%ss\n' \
		"$(gs get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type)" \
		"$(gs get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout)" \
		"$(gs get org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type)" \
		"$(gs get org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout)"
	echo "  （判据复跑：scripts/sleep-policy.sh --check）"
	;;
esac

if [ "$MODE" = check ]; then
	if [ "$missing" -eq 0 ]; then echo "== 汇总: MISS=0"; exit 0; else echo "== 汇总: MISS=$missing"; exit 1; fi
fi
exit 0
