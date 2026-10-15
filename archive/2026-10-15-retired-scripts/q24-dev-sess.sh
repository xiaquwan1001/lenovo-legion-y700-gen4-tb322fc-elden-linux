#!/bin/sh
# q24-dev-sess.sh — 设备侧：取 uid=1000 的会话总线环境 + 统一 runner 包装。
# 用法: . /tmp/q24-dev-sess.sh  然后 run_gdbus GetActive / run_gdbus SetActive true /
#       run_gs get org.gnome.desktop.session idle-delay
#
# 坑（2026-10-12）：root 直接连 /tmp/dbus-XXXX 会 “Error connecting: The connection is closed”
# ⇒ 必须 setpriv 降到 uid=1000 再连（keep-awake.sh 的 sudo -u 等价写法）。
P=$(pidof phosh 2>/dev/null || pidof phoc 2>/dev/null)
[ -n "$P" ] || { echo NO_SESSION_PROC >&2; return 1; }
Q24_DB=$(tr '\0' '\n' < /proc/$P/environ | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p')
Q24_XD=$(tr '\0' '\n' < /proc/$P/environ | sed -n 's/^XDG_RUNTIME_DIR=//p')
[ -n "$Q24_DB" ] || { echo NO_SESSION_BUS >&2; return 1; }
export Q24_DB Q24_XD
run_u(){ setpriv --reuid=1000 --regid=1000 --init-groups env HOME=/home/xuqianhui1001 \
  XDG_RUNTIME_DIR="$Q24_XD" DBUS_SESSION_BUS_ADDRESS="$Q24_DB" "$@"; }
run_gdbus(){ m=$1; shift; run_u gdbus call --session --dest org.gnome.ScreenSaver \
  --object-path /org/gnome/ScreenSaver --method "org.gnome.ScreenSaver.$m" "$@"; }
run_gs(){ run_u gsettings "$@"; }
