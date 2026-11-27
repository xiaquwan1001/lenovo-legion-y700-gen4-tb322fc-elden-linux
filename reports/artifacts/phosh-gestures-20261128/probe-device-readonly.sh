#!/bin/sh
# T29 证据脚本（只读；主机侧 -> 设备侧）。
# 只调用读命令（dpkg -l / gsettings get|list-recursively / cat / ls / gresource list）。
# 禁止：任何 set/reset、systemctl start/stop/restart、apt/dpkg 写、编辑文件。
set -u
SSH="ssh -o ConnectTimeout=8 elden"
REMOTE='
set -u
echo "## uname/date"; uname -r; date -u
echo "## os-release"; grep -E "^(PRETTY_NAME|VERSION_ID)=" /etc/os-release
echo "## versions"; dpkg -l phosh phosh-common phoc phosh-osk-stub lisgd libgmobile0 libgmobile-common libwlroots-0.18 2>/dev/null | tail -n +6
echo "## phoc --version"; phoc --version 2>&1 | head -2
echo "## phoc cmdline"; pgrep -a phoc
echo "## phosh binary"; pgrep -a phosh
echo "## phoc.ini files"; for f in /usr/share/phosh/phoc.ini /etc/phoc.ini "$HOME/.config/phoc.ini"; do echo "--- $f"; [ -f "$f" ] && cat "$f" || echo "(absent)"; done
echo "## phoc --help"; phoc --help 2>&1
echo "## schemas matching phosh/phoc/mobi/puri"; gsettings list-schemas | grep -iE "phosh|phoc|mobi|puri"
echo "## gsettings dumps"
for s in sm.puri.phoc mobi.phosh.phoc sm.puri.phosh sm.puri.phosh.lockscreen sm.puri.phosh.notifications sm.puri.phosh.plugins mobi.phosh.shell; do
  echo "=== $s"; gsettings list-recursively "$s" 2>&1
done
echo "## gnome.desktop.interface (subset)"
gsettings list-recursively org.gnome.desktop.interface 2>&1 | grep -iE "animat|theme|scal|color-scheme|font-name|text-scaling"
echo "## wm.keybindings (subset)"
gsettings list-recursively org.gnome.desktop.wm.keybindings 2>&1 | grep -E " (close|minimize|maximize|switch-applications|toggle-fullscreen|always-on-top) "
echo "## a11y"
gsettings get org.gnome.desktop.a11y.applications screen-keyboard-enabled
echo "## gesture back chain"
systemctl is-enabled lisgd-edge-swipe; ls -l /usr/local/bin/lisgd-edge-swipe /usr/local/bin/uinput-back /usr/local/bin/elden-swipe-back 2>&1
cat /etc/conf.d/lisgd-edge-swipe 2>/dev/null; tail -n 3 /var/log/lisgd-edge-swipe.log 2>&1
echo "## gmobile display-panels (gresource)"
gresource list /usr/lib/aarch64-linux-gnu/libgmobile.so.0 2>/dev/null | grep -c display-panels
gresource list /usr/lib/aarch64-linux-gnu/libgmobile.so.0 2>/dev/null | grep -iE "lenovo|elden|8750" || echo "(no lenovo/elden/8750 entry)"
echo "## device tree"
cat /proc/device-tree/model; echo; tr "\0" "\n" < /proc/device-tree/compatible
echo "## drm modes"; head -1 /sys/class/drm/card0-DSI-1/modes 2>/dev/null
echo "## gtk user css / system css"
ls -l /etc/gtk-3.0/ "$HOME/.config/gtk-3.0/" 2>&1
echo "## END"
'
$SSH "$REMOTE"
