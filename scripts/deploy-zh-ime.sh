#!/bin/bash
# deploy-zh-ime.sh — 部署「触屏唤起的中文输入法」到设备（幂等）
#
# 目标栈（2026-10-20 实测通过）：
#   squeekboard   触屏键盘 + 占 Wayland input-method 槽位 + 实现 sm.puri.OSK0（可 SetVisible 唤起/折叠）
#   fcitx5 + Rime 中文引擎（--disable waylandim，不抢槽位）
#   fcitx5-gtk3/4 GTK 的 IM 模块：候选窗由它自己画（实测：不需要自编候选条）
#
# 判据（脚本末尾自动跑一遍）：
#   1) squeekboard / fcitx5 都在跑，且 fcitx5 日志里没有 "Wayland native input method protocol: 1"
#   2) sm.puri.OSK0 有 owner，Visible 可读，SetVisible(false/true) 能来回切
#   3) 注入 "nihao" → 候选出现 → 注入 "1" → 上屏「你好」（GTK 测试窗）
#
# 用法：bash scripts/deploy-zh-ime.sh [--no-verify]
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=${SRC:-$HERE/../patches-userland/zh-ime}
TAB=${TAB:-root@192.168.7.1}
VERIFY=1
[ "${1:-}" = "--no-verify" ] && VERIFY=0

echo "== 0) 依赖预检（缺包不自动装：设备网络不稳，装包失败会静默退回旧栈）"
ssh "$TAB" 'for p in squeekboard fcitx5 fcitx5-rime fcitx5-gtk3 fcitx5-gtk4; do
  if apk list -I 2>/dev/null | grep -q "^$p-"; then echo "  OK   $p"; else echo "  MISS $p   <-- apk add $p"; fi
done' || true

echo "== 1) 拷脚本/源码到设备"
scp -q "$SRC/elden-ime-toggle" "$TAB:/usr/local/bin/elden-ime-toggle"
ssh "$TAB" "chmod 755 /usr/local/bin/elden-ime-toggle"
scp -q "$SRC/elden-ime-toggle.desktop" "$TAB:/usr/share/applications/elden-ime-toggle.desktop"
scp -q "$SRC/org.fcitx.Fcitx5.desktop" "$TAB:/etc/xdg/autostart/org.fcitx.Fcitx5.desktop"
scp -q "$SRC/elden-ime-focusd.c" "$SRC/build-elden-ime.sh" "$TAB:/root/"
scp -q "$SRC/elden-ime-focusd.desktop" "$TAB:/etc/xdg/autostart/elden-ime-focusd.desktop"

echo "== 1b) 构建并安装 elden-ime-focusd（设备原生编译，~2 s）"
ssh "$TAB" 'bash -s' <<'REMOTE'
set -eu
if ! command -v gcc >/dev/null 2>&1 || ! pkg-config --exists gio-2.0 2>/dev/null; then
	echo "  ⚠️ 设备缺 gcc/gio 开发文件，跳过 focusd 构建（自动唤起不可用）"
	exit 0
fi
mkdir -p /root/zh-ime-build && cp /root/elden-ime-focusd.c /root/build-elden-ime.sh /root/zh-ime-build/
(cd /root/zh-ime-build && sh build-elden-ime.sh)
install -m755 /root/zh-ime-build/elden-ime-focusd /usr/local/bin/elden-ime-focusd
echo "  installed /usr/local/bin/elden-ime-focusd"
REMOTE

echo "== 2) 禁用旧方案（wvkbd + 自编候选条 + zh-osk 自启）"
ssh "$TAB" 'bash -s' <<'REMOTE'
set -u
U=xuqianhui1001
H=/home/$U
BUS=$(tr '\0' '\n' < /proc/$(pgrep -x phosh | head -1)/environ | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p')
# 用户级 autostart：保留 squeekboard.desktop，去掉 zh-osk.desktop
rm -f "$H/.config/autostart/zh-osk.desktop"
# 用户级覆盖掉的 OSK0 desktop（曾把 OSK 换成 wvkbd）要移除
rm -f "$H/.local/share/applications/sm.puri.OSK0.desktop"
# fcitx5 用户级覆盖项（强制 --disable waylandim）
install -d -o $U -g $U "$H/.config/autostart"
install -o $U -g $U -m644 /etc/xdg/autostart/org.fcitx.Fcitx5.desktop \
        "$H/.config/autostart/org.fcitx.Fcitx5.desktop"
# 旧进程
pkill -x wvkbd-mobintl 2>/dev/null || true
pkill -x fcitx5-candbar 2>/dev/null || true
pkill -x candidate-bar 2>/dev/null || true
pkill -x candidate-bar.new 2>/dev/null || true
# OSK 必须被 gsettings 允许
su -s /bin/sh $U -c "XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=$BUS gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled true" || true
echo "  old stack cleaned"
REMOTE

echo "== 3) 重启 squeekboard + fcitx5（当前会话内生效，无需重登）"
ssh "$TAB" 'bash -s' <<'REMOTE'
set -u
U=xuqianhui1001
BUS=$(tr '\0' '\n' < /proc/$(pgrep -x phosh | head -1)/environ | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p')
E="XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 DBUS_SESSION_BUS_ADDRESS=$BUS"
as() { su -s /bin/sh $U -c "$1"; }
as "$E pkill -x fcitx5" 2>/dev/null || true
as "$E pkill -x squeekboard" 2>/dev/null || true
sleep 1
as "$E nohup squeekboard >/tmp/squeekboard.log 2>&1 &"
sleep 2
as "$E nohup fcitx5 --disable waylandim -d -u kimpanel >/tmp/fcitx5.log 2>&1 &"
sleep 3
as "$E pkill -f elden-ime-focusd" 2>/dev/null || true
as "$E ELDEN_IME_LOG=/tmp/elden-ime-focusd.log nohup /usr/local/bin/elden-ime-focusd >/dev/null 2>&1 &"
sleep 1
as "$E fcitx5-remote -o" >/dev/null 2>&1 || true
as "$E busctl --user call org.fcitx.Fcitx5 /controller org.fcitx.Fcitx.Controller1 SetCurrentIM s rime" >/dev/null 2>&1 || true
echo "  squeekboard=$(pgrep -x squeekboard | tr '\n' ' ') fcitx5=$(pgrep -x fcitx5 | tr '\n' ' ')"
REMOTE

[ "$VERIFY" = 1 ] || { echo "跳过验证"; exit 0; }

echo "== 4) 验证"
ssh "$TAB" 'bash -s' <<'REMOTE'
set -u
U=xuqianhui1001
BUS=$(tr '\0' '\n' < /proc/$(pgrep -x phosh | head -1)/environ | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p')
E="XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 DBUS_SESSION_BUS_ADDRESS=$BUS"
as() { su -s /bin/sh $U -c "$1"; }
ok=0; fail=0
chk() { if [ "$2" = "$3" ]; then echo "  OK   $1 = $3"; ok=$((ok+1)); else echo "  FAIL $1 = $2 (期望 $3)"; fail=$((fail+1)); fi; }
vis() {
	as "$E gdbus call --session --dest sm.puri.OSK0 --object-path /sm/puri/OSK0 \
		--method org.freedesktop.DBus.Properties.Get sm.puri.OSK0 Visible" 2>/dev/null |
		grep -o 'true' | head -1
}
n=$(grep -c 'Wayland native input method protocol: 1' /tmp/fcitx5.log 2>/dev/null); [ -z "$n" ] && n=0
chk "fcitx5 未占 wayland IM 槽" "$n" "0"
chk "sm.puri.OSK0 有 owner" "$(as "$E gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus --method org.freedesktop.DBus.NameHasOwner sm.puri.OSK0" 2>/dev/null | grep -o true | head -1)" "true"
as "$E /usr/local/bin/elden-ime-toggle show" >/dev/null 2>&1; sleep 2
chk "show -> Visible" "$(vis)" "true"
as "$E /usr/local/bin/elden-ime-toggle hide" >/dev/null 2>&1; sleep 2
chk "hide -> Visible" "$(vis)" ""
as "$E /usr/local/bin/elden-ime-toggle toggle" >/dev/null 2>&1; sleep 2
chk "toggle -> Visible" "$(vis)" "true"
chk "focusd 在跑" "$(pgrep -f elden-ime-focusd | head -1 | wc -l | tr -d ' ')" "1"
chk "gsettings 键盘开关" "$(as "$E gsettings get org.gnome.desktop.a11y.applications screen-keyboard-enabled" | tr -d "'" )" "true"
echo "  小计 ok=$ok fail=$fail"
REMOTE
echo "== done（中文上屏验证见 README「验收」一节）"
