#!/bin/sh
set -u
U=1001; H=/home/xuqianhui1001
DBUS="unix:path=/run/user/1001/bus"
run() { env XDG_RUNTIME_DIR=/run/user/1001 DBUS_SESSION_BUS_ADDRESS=$DBUS setpriv --reuid=$U --regid=$U --init-groups "$@"; }
gv() { run gdbus call --session --dest sm.puri.OSK0 --object-path /sm/puri/OSK0 --method org.freedesktop.DBus.Properties.Get sm.puri.OSK0 Visible 2>&1; }
hide() { run gdbus call --session --dest sm.puri.OSK0 --object-path /sm/puri/OSK0 --method sm.puri.OSK0.SetVisible false >/dev/null 2>&1; }
IMENV="GTK_IM_MODULE=fcitx QT_IM_MODULE=fcitx XMODIFIERS=@im=fcitx"

echo "===== T1: GTK3 entry, GTK_IM_MODULE=fcitx（现状默认） ====="
hide; sleep 1; echo "pre=$(gv)"
env XDG_RUNTIME_DIR=/run/user/1001 DBUS_SESSION_BUS_ADDRESS=$DBUS $IMENV \
  setpriv --reuid=$U --regid=$U --init-groups timeout 9 python3 /home/xuqianhui1001/ime-gtk3-entry.py >/dev/null 2>&1 &
P=$!; sleep 4; echo "mid=$(gv)"; wait $P 2>/dev/null; echo "post=$(gv)  (关窗后应变 false)"

echo "===== T2: Firefox（GTK_IM_MODULE=fcitx，autofocus input） ====="
rm -rf $H/ffprof; mkdir -p $H/ffprof; chown -R $U:$U $H/ffprof
hide; sleep 1; echo "pre=$(gv)"
env XDG_RUNTIME_DIR=/run/user/1001 DBUS_SESSION_BUS_ADDRESS=$DBUS $IMENV \
  setpriv --reuid=$U --regid=$U --init-groups env HOME=$H \
  firefox --no-remote --profile $H/ffprof -new-window file://$H/ffprobe.html >/dev/null 2>&1 &
P=$!; sleep 20; echo "mid=$(gv)"
pkill -f ffprof 2>/dev/null; wait $P 2>/dev/null
echo "===== focusd 日志 ====="
tail -12 /tmp/elden-ime-focusd.log
hide
