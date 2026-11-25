#!/bin/bash
# ime-single-stack.sh — 把「中文输入法」在设备上收敛成**单一栈**（phosh-osk-stub + RIME completer）
#
# 为什么要有（2026-11-24 设备窗轮，用户报「输入法键盘无法唤起」）：
#   项目里同时存在两套 IME 部署路径，且都在 `daily-baseline.sh` 里被"保住"：
#     ① 老路 fcitx5（`--disable waylandim`）+ fcitx5-ime-toggle + fcitx5-indicator +
#        `elden-ime-focusd`（kimpanel → `sm.puri.OSK0.SetVisible`）+ `GTK_IM_MODULE=fcitx`；
#     ② 新路 phosh-osk-stub（我们的 divert+hold 自编件）+ B 案 RIME completer（`Completers=rime`，
#        中文候选在 OSK 内产生，不需要 fcitx）。
#   两者在 `zwp_input_method_v2`（每个 seat 只允许一个 client）上互斥，且退出/进入不互知：
#     * 从应用网格点 `Fcitx 5` ⇒ fcitx5 以**默认**参数起（waylandim 已加载）⇒ 抢走 IM 槽；
#     * osk-stub 只印一行 `pos-input-method-WARNING: Input method unavailable`，
#       `Visible` 仍可被设成 true，**但键盘永远不显示**（layer surface 一直 set_margin -200）。
#   另一条独立的坑（本轮真根因）：`org.gnome.desktop.a11y.applications screen-keyboard-enabled`
#   为 false 时，osk-stub 的 `set_surface_prop_surface_visible()` 无条件把 visible 置 FALSE
#   （`phosh-osk-stub.c:221-238`）⇒ 收到 activate 也不弹。重建根后该项是默认 false。
#
# 用法：
#   scripts/ime-single-stack.sh            # = --check（只读）
#   scripts/ime-single-stack.sh --apply    # 收敛成单栈（幂等；可 --rollback）
#   scripts/ime-single-stack.sh --rollback # 回到老路（fcitx5 自启 + focusd + 图钉/指示器）
#
# 判据（--check 全绿 = 单栈成立）：
#   C1 `screen-keyboard-enabled` = true            （OSK 能弹的硬前提）
#   C2 `Completers default` = 'rime'               （候选来自 B 案 completer）
#   C3 `Completers.Rime user-data` 非空且目录存在  （#713：空串 ⇒ 用户词典不持久化）
#   C4 会话里没有 fcitx5 进程 / unit 未 enable      （IM 槽不被抢）
#   C5 fcitx5-indicator / elden-ime-focusd 未 active（老路的两个常驻件）
#   C6 应用网格里 `org.fcitx.Fcitx5.desktop` 已 NoDisplay（误点即毁键盘）
#   C7 osk-stub 在跑、持有 sm.puri.OSK0、本 boot 无 `Input method unavailable`
#
# 回退：`--rollback` 只做「解除 mask + 恢复 wants 链接 + 删 NoDisplay 覆盖」，
#       不动 osk-stub（它本来就在），也不改 gsettings（两栈都要求 user-data 非空）。
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/lib-ssh.sh"

MODE=check
case "${1:-}" in
	""|--check) MODE=check ;;
	--apply) MODE=apply ;;
	--rollback) MODE=rollback ;;
	-h|--help) sed -n '2,40p' "$0"; exit 0 ;;
	*) echo "用法: $0 [--check|--apply|--rollback]" >&2; exit 2 ;;
esac

fail=0
ok()   { printf '  OK    %s\n' "$*"; }
no()   { printf '  FAIL  %s\n' "$*"; fail=$((fail+1)); }
fix()  { printf '  FIX   %s\n' "$*"; }
warn() { printf '  WARN  %s\n' "$*"; }

# 会话用户 / uid（appliance 模式：uid 1001）
TAB_LINE=$(S "echo \$(id -un 1001 2>/dev/null):\$(id -u 1001 2>/dev/null):\$(id -gn 1001 2>/dev/null)" 12 2>/dev/null || true)
U=${TAB_LINE%%:*}; rest=${TAB_LINE#*:}; UID_N=${rest%%:*}; G=${rest##*:}
if [ -z "${U:-}" ] || [ -z "${UID_N:-}" ]; then echo "查不到 uid 1001 的会话用户（设备不在？）" >&2; exit 9; fi
NR="XDG_RUNTIME_DIR=/run/user/$UID_N DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$UID_N/bus"
HOME_DIR="/home/$U"

# 远端：以会话用户跑一段 sh（带会话总线）。
# ★不要写成 `su -l U -c '...'` 里再套单引号——嵌套引号会把 awk/gsettings 的参数吃掉（本轮实测：
#   `busctl ... awk '$1=="sm.puri.OSK0"'` 在 as_user 里恒返回空）。统一 base64 传脚本。
as_user() {
	local b
	b=$(printf '%s\n' "export $NR" "$1" | base64 -w0)
	S "printf %s $b | base64 -d | su -l $U -s /bin/sh" 30
}
# 纯计数/单值取用：**不要**靠 grep 的退出码判 0（`grep -cx` 命中 0 条时 rc=1）
cnt() { S "$1; true" 15 2>/dev/null | tr -d '\r\n'; }

echo "== ime-single-stack（$MODE）设备=$TAB 用户=$U($UID_N) =="

if [ "$MODE" = rollback ]; then
	echo "-- rollback：恢复老路（fcitx5 自启 + focusd/indicator wants + 可见入口）"
	S --stdin 60 <<EOS
set -u
asuser() { su -l $U -c "XDG_RUNTIME_DIR=/run/user/$UID_N DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$UID_N/bus \$*"; }
asuser "systemctl --user unmask fcitx5.service fcitx5-indicator.service elden-ime-focusd.service" || true
mkdir -p /etc/systemd/user/graphical-session.target.wants
ln -sf /etc/systemd/user/fcitx5.service /etc/systemd/user/graphical-session.target.wants/fcitx5.service
ln -sf ../elden-ime-focusd.service /etc/systemd/user/graphical-session.target.wants/elden-ime-focusd.service
rm -f $HOME_DIR/.local/share/applications/org.fcitx.Fcitx5.desktop \\
      $HOME_DIR/.local/share/applications/org.fcitx.fcitx5-config-qt.desktop
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database $HOME_DIR/.local/share/applications || true
echo rollback-done
EOS
	echo "回退完成：重登（或 systemctl --user start fcitx5）后老路生效。"
	exit 0
fi

# ------------------------------------------------------------------ C1 screen-keyboard-enabled
SKE=$(as_user "gsettings get org.gnome.desktop.a11y.applications screen-keyboard-enabled" 2>/dev/null | tr -d "'")
# 2026-11-25：只写 dconf 用户库不够 —— 2026-11-24 设过 true，**断电重启后回落到 false**（键盘又不弹）。
# 改用 system-db + lock 钉死（dconf 的 key 锁 ⇒ 任何会话都改不动），且可跨重启。
LOCKF=/etc/dconf/db/local.d/locks/00-elden-ime
SYSF=/etc/dconf/db/local.d/00-elden-ime
locked=no
S "grep -qs screen-keyboard-enabled $LOCKF && test -f /etc/dconf/db/local && echo yes || echo no" 12 >/tmp/.c1lock 2>/dev/null
[ "$(cat /tmp/.c1lock 2>/dev/null)" = yes ] && locked=yes
if [ "$SKE" = true ] && [ "$locked" = yes ]; then ok "C1 screen-keyboard-enabled=true（system-db 已锁）"
elif [ "$MODE" = check ]; then no "C1 screen-keyboard-enabled=${SKE:-查不到} lock=${locked}（false 或没锁 ⇒ osk-stub 收到 activate 也不弹 / 重启就回落，phosh-osk-stub.c:221-238）"
else
	S --stdin 90 <<EOS
set -u
mkdir -p /etc/dconf/db/local.d/locks /etc/dconf/profile
grep -qs '^system-db:local' /etc/dconf/profile/user || printf 'user-db:user\nsystem-db:local\n' >> /etc/dconf/profile/user
cat > $SYSF <<'D'
[org/gnome/desktop/a11y/applications]
screen-keyboard-enabled=true
D
cat > $LOCKF <<'L'
/org/gnome/desktop/a11y/applications/screen-keyboard-enabled
L
command -v dconf >/dev/null 2>&1 || apt-get install -y --no-install-recommends dconf-cli >/dev/null 2>&1 || true
dconf update >/dev/null 2>&1 || true
EOS
	as_user "gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled true" >/dev/null 2>&1 || true
	fix "C1 已用 system-db+lock 钉住 screen-keyboard-enabled=true（dconf-cli 缺失时自动装）"
fi

# ------------------------------------------------------------------ C2 候选后端 = rime
COMP=$(as_user "gsettings get sm.puri.phosh.osk.Completers default" 2>/dev/null | tr -d "'")
case "$COMP" in
	*rime*) ok "C2 Completers default=$COMP" ;;
	*) if [ "$MODE" = check ]; then no "C2 Completers default=${COMP:-查不到}（应为 rime）"
	   else as_user "gsettings set sm.puri.phosh.osk.Completers default 'rime'" >/dev/null && fix "C2 已设 Completers=rime"; fi ;;
esac

# ------------------------------------------------------------------ C3 RIME user-data
UD=$(as_user "gsettings get sm.puri.phosh.osk.Completers.Rime user-data" 2>/dev/null | tr -d "'")
if [ -n "$UD" ] && S "test -d '$UD'" 10 >/dev/null 2>&1; then ok "C3 Rime user-data=$UD（目录在）"
elif [ "$MODE" = check ]; then no "C3 Rime user-data=${UD:-查不到}（空串 ⇒ #713：用户词典不持久化）"
else
	S "install -d -o $U -g ${G:-$U} $HOME_DIR/.local/share/rime" 20 >/dev/null 2>&1 || true
	as_user "gsettings set sm.puri.phosh.osk.Completers.Rime user-data $HOME_DIR/.local/share/rime" >/dev/null \
		&& fix "C3 已设 user-data=$HOME_DIR/.local/share/rime"
fi

# ------------------------------------------------------------------ C4 fcitx5 不在会话里
FCPROCS=$(cnt "ps -eo comm | grep -cx fcitx5")
FCLINK=$(cnt "test -L /etc/systemd/user/graphical-session.target.wants/fcitx5.service && echo yes || echo no")
FCMASK=$(cnt "systemctl --user is-enabled fcitx5.service 2>/dev/null | head -1")
if [ "$FCPROCS" = 0 ] && [ "$FCLINK" = no ] && [ "$FCMASK" != enabled ] && [ "$FCMASK" != alias ]; then
	ok "C4 fcitx5 未运行、未自启（is-enabled=${FCMASK:-?}）"
elif [ "$MODE" = check ]; then
	no "C4 老路 fcitx5 仍在（进程=$FCPROCS wants链接=$FCLINK is-enabled=${FCMASK:-?}）⇒ 会抢 zwp_input_method_v2 槽，osk-stub 只印 'Input method unavailable'"
else
	S --stdin 60 <<EOS
set -u
asuser() { su -l $U -c "XDG_RUNTIME_DIR=/run/user/$UID_N DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$UID_N/bus \$*"; }
rm -f /etc/systemd/user/graphical-session.target.wants/fcitx5.service
asuser "systemctl --user disable --now fcitx5.service" >/dev/null 2>&1 || true
asuser "systemctl --user mask fcitx5.service" >/dev/null 2>&1 || true
pkill -x fcitx5 || true
EOS
	fix "C4 已停/禁/mask fcitx5 并移除自启链接"
fi

# ------------------------------------------------------------------ C5 老路常驻件
ACT=$(cnt "ps -eo comm | grep -cE '^(fcitx5-indicator|elden-ime-focusd)\$'")
LNK=$(cnt "ls /etc/systemd/user/graphical-session.target.wants/ 2>/dev/null | grep -cE 'fcitx5-indicator|elden-ime-focusd'")
if [ "$ACT" = 0 ] && [ "$LNK" = 0 ]; then ok "C5 指示器/focusd 未运行、未自启"
elif [ "$MODE" = check ]; then no "C5 老路常驻件仍在（进程=$ACT wants链接=$LNK）⇒ 只在 fcitx5 路径有意义，留着会误导排障"
else
	S --stdin 60 <<EOS
set -u
rm -f /etc/systemd/user/graphical-session.target.wants/fcitx5-indicator.service \\
      /etc/systemd/user/graphical-session.target.wants/elden-ime-focusd.service
asuser() { su -l $U -c "XDG_RUNTIME_DIR=/run/user/$UID_N DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$UID_N/bus \$*"; }
asuser "systemctl --user disable --now fcitx5-indicator.service elden-ime-focusd.service" >/dev/null 2>&1 || true
pkill -x fcitx5-indicator 2>/dev/null || true
pkill -x elden-ime-focusd 2>/dev/null || true
EOS
	fix "C5 已停用指示器/focusd 并移除自启链接（文件保留，--rollback 可恢复）"
fi

# ------------------------------------------------------------------ C6 应用网格误入口
HID=$(cnt "grep -qs '^NoDisplay=true' $HOME_DIR/.local/share/applications/org.fcitx.Fcitx5.desktop && echo yes || echo no")
if [ "$HID" = yes ]; then ok "C6 应用网格 'Fcitx 5' 启动项已隐藏（NoDisplay=true）"
elif [ "$MODE" = check ]; then no "C6 应用网格仍能点开 'Fcitx 5'（以默认参数起 ⇒ waylandim 抢 IM 槽 ⇒ 键盘立刻永久不弹）"
else
	S --stdin 40 <<EOS
set -u
D=$HOME_DIR/.local/share/applications
mkdir -p "\$D" && chown $U:${G:-$U} "\$D" 2>/dev/null || true
for a in org.fcitx.Fcitx5 org.fcitx.fcitx5-config-qt; do
	printf '[Desktop Entry]\nType=Application\nName=%s (disabled: OSK 单栈)\nExec=/bin/true\nNoDisplay=true\nHidden=true\n' "\$a" > "\$D/\$a.desktop"
	chown $U:${G:-$U} "\$D/\$a.desktop" 2>/dev/null || true
done
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "\$D" >/dev/null 2>&1 || true
EOS
	fix "C6 已用 NoDisplay 覆盖隐藏 fcitx 启动项"
fi

# ------------------------------------------------------------------ C7 osk-stub 健康
OSK=$(cnt "ps -eo comm | grep -cx phosh-osk-stub")
# 只看**当前实例**的日志：历史上（本 boot 早些时候）留下的 'Input method unavailable' 不算数，
# 否则一旦发生过就永远 FAIL（本轮实测踩过）。
OSKPID=$(cnt "ps -eo pid,comm | awk '\$2==\"phosh-osk-stub\"{print \$1}' | head -1")
OWN=$(as_user "busctl --user list --no-legend 2>/dev/null | grep '^sm.puri.OSK0 ' | awk '{print \$2}'" 2>/dev/null | tr -d '\r\n')
if [ -n "$OSKPID" ]; then
	UNAV=$(cnt "journalctl -b _PID=$OSKPID --no-pager 2>/dev/null | grep -c 'Input method unavailable'")
else
	UNAV='?'
fi
if [ "$OSK" -ge 1 ] 2>/dev/null && [ -n "$OWN" ] && [ "$UNAV" = 0 ]; then
	ok "C7 osk-stub 在跑（pid=$OWN）、持有 sm.puri.OSK0、本 boot 无 'Input method unavailable'"
elif [ "$MODE" = check ]; then
	no "C7 osk-stub 异常（进程=$OSK owner=${OWN:-无} 'Input method unavailable' 次数=${UNAV:-?}）"
else
	S "pkill -x phosh-osk-stub" 12 >/dev/null 2>&1 || true
	sleep 2
	as_user "gdbus call --session -d sm.puri.OSK0 -o /sm/puri/OSK0 -m sm.puri.OSK0.SetVisible true" >/dev/null 2>&1 || true
	fix "C7 已重启 osk-stub（phosh 会在需要键盘时按需重拉）"
fi

# ------------------------------------------------------------------ C8 每键震动（haptic 钩子必须在件）
# 2026-11-24 教训：重编 osk-stub 时只乘了 0003/0004/0005、**漏了** haptic 0001 与 layout 0002，
# 结果「震动悄无声息地没了」，而文档还写着"未上机"。判据 = 装的那颗二进制里必须有钩子字符串
# + 会话环境有开关 + 马达 FF 节点在。
HAPBIN=$(cnt "strings /usr/bin/phosh-osk-stub 2>/dev/null | grep -c ELDEN_OSK_HAPTIC")
HAPENV=$(cnt "grep -c '^ELDEN_OSK_HAPTIC_DEV=' /etc/environment")
HAPDEV=$(cnt "test -e /dev/input/event2 && echo yes || echo no")
if [ "${HAPBIN:-0}" -ge 1 ] 2>/dev/null && [ "${HAPENV:-0}" -ge 1 ] 2>/dev/null && [ "$HAPDEV" = yes ]; then
	ok "C8 每键震动在位（二进制含钩子、/etc/environment 有开关、/dev/input/event2 在）"
elif [ "$MODE" = check ]; then
	no "C8 每键震动缺失（二进制钩子字符串=${HAPBIN:-?} /etc/environment 行=${HAPENV:-?} event2=${HAPDEV:-?}）⇒ 重编 osk-stub 时漏了 haptic 0001；重编按 patches-userland/zh-ime-rime-20261123/BUILD.md 全乘"
else
	warn "C8 每键震动缺失：需按 BUILD.md 重编（脚本不自动重编）"
fi

# ------------------------------------------------------------------ C9 候选条可翻页（RIME page_size）
# 2026-11-25：候选条改成 GtkScrolledWindow + ‹ › 翻页（0006 patch），但每页候选数由 RIME 的
# `menu/page_size` 决定（默认 5 ⇒ 「固定 5 个、剩下的看不到」）。用户级 custom 文件把它抬到 20。
PSF=/home/$U/.local/share/rime/default.custom.yaml
PS=$(cnt "grep -s 'menu/page_size' $PSF | head -1")
if echo "${PS:-}" | grep -qE 'page_size:\s*([1-9][0-9]|[6-9])\b'; then
	ok "C9 RIME 每页候选数已抬（$PSF: $PS）"
elif [ "$MODE" = check ]; then
	no "C9 候选每页仍是默认 5（${PS:-缺 $PSF}）⇒ 候选条翻页按钮只能翻出 5 个一组；写 menu/page_size: 20"
else
	S --stdin 40 <<EOS
install -d -o $U -g ${G:-$U} /home/$U/.local/share/rime
printf 'patch:\n  menu/page_size: 20\n' > $PSF
chown $U:${G:-$U} $PSF
EOS
	fix "C9 已写 $PSF（menu/page_size: 20；osk-stub 下次启动生效）"
fi

echo
if [ "$fail" -eq 0 ]; then
	echo "结果: 单栈成立（FAIL=0）"
	echo "人工判据（唯一无法自动判的一条）：解锁桌面 → 点任意输入框（Firefox 地址栏最省事）→ 键盘应弹出；打 nihao 应出候选。"
	exit 0
fi
echo "结果: 未收敛（FAIL=$fail）—— 加 --apply 修；要回老路用 --rollback"
exit 1
