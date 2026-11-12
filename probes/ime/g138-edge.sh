#!/bin/sh
# g138-edge.sh — G1-38 OSK 边角判据（T-H1 / T-H3 / T-A6 / T-H5）
# 用法（设备侧）：sh /tmp/g138-edge.sh [case]
#   case = alt-tab | tab-button | fcitx-restart | fcitx-stop | all
# 判据口径见 reports/ime-osk-lifecycle-20261112.md §5
set -u
U=1001
H=/home/xuqianhui1001
R=/run/user/1001
DB="unix:path=$R/bus"
CASE=${1:-all}

run() { su - xuqianhui1001 -c "export XDG_RUNTIME_DIR=$R DBUS_SESSION_BUS_ADDRESS=$DB WAYLAND_DISPLAY=wayland-0 HOME=$H; $*"; }
runim() { su - xuqianhui1001 -c "export XDG_RUNTIME_DIR=$R DBUS_SESSION_BUS_ADDRESS=$DB WAYLAND_DISPLAY=wayland-0 HOME=$H GTK_IM_MODULE=fcitx QT_IM_MODULE=fcitx XMODIFIERS=@im=fcitx; $*"; }

vis() { run "busctl --user call sm.puri.OSK0 /sm/puri/OSK0 org.freedesktop.DBus.Properties Get ss sm.puri.OSK0 Visible 2>&1" | tr -d '()' | sed 's/.*\(true\|false\)/\1/'; }
hide() { run "busctl --user call sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 SetVisible b false >/dev/null 2>&1"; }
log() { echo "### $(date +%H:%M:%S) $*"; }
mark() { echo; echo "=============== $* ==============="; }

# 起双窗探针，后台；$1=mode $2=秒
start_two() { runim "timeout $2 python3 /tmp/ime-gtk3-two.py $1 $2 >/home/xuqianhui1001/two.out 2>&1 &"; }
fstate() { run gdbus call --session --dest org.fcitx.Fcitx5 --object-path /controller \
           --method org.fcitx.Fcitx.Controller1.CurrentUI 2>&1; }

case "$CASE" in alt-tab|all)
mark "T-H1 Alt+Tab 到无输入控件窗口"
hide; sleep 1; log "pre=$(vis)"
start_two two 45; sleep 6
log "A 窗口 Entry 获焦后 = $(vis)   (期望 true)"
run "wtype -M alt -k Tab -m alt"; sleep 4
log "Alt+Tab 后 = $(vis)   (期望 false；现栈预期漏收 = true)"
sleep 3
log "再 3 s = $(vis)"
pkill -f ime-gtk3-two 2>/dev/null; sleep 2
log "关窗后 = $(vis)"
;;
esac

case "$CASE" in tab-button|all)
mark "T-H3 同窗 Tab 到 Button（不关窗）"
hide; sleep 1; log "pre=$(vis)"
start_two a-only 45; sleep 6
log "Entry 获焦 = $(vis)   (期望 true)"
run "wtype -k Tab"; sleep 3
log "Tab 到 Button 后 3 s = $(vis)   (期望 false)"
sleep 4
log "再 4 s = $(vis)"
pkill -f ime-gtk3-two 2>/dev/null; sleep 2
log "关窗后 = $(vis)"
;;
esac

case "$CASE" in fcitx-restart|all)
mark "T-A6 fcitx5 重启不应弹键盘（零矩形误弹回归）"
hide; sleep 1; log "pre=$(vis)"
run "systemctl --user restart fcitx5"; sleep 6
log "重启 fcitx5 后 = $(vis)   (期望 false)"
sleep 4; log "再 4 s = $(vis)"
;;
esac

case "$CASE" in fcitx-stop|all)
mark "T-H5 fcitx5 停掉后键盘应收起（State=-1 宽限 5 s）"
hide; sleep 1
start_two a-only 40; sleep 6
log "Entry 获焦 = $(vis)   (期望 true)"
run "systemctl --user stop fcitx5"; sleep 8
log "停 fcitx5 后 8 s = $(vis)   (期望 false)"
pkill -f ime-gtk3-two 2>/dev/null
run "systemctl --user start fcitx5"; sleep 5
log "fcitx5 重启后 = $(vis)"
;;
esac

mark "focusd 日志（末 25 行）"
tail -25 /tmp/elden-ime-focusd.log
hide
