#!/bin/sh
# 临时：把会话的熄屏/挂起全部关掉（Q24：相机模块加载后熄屏有硬复位风险）。
# 在设备上当 root 跑。用法：sh /tmp/keep-awake.sh
U=xuqianhui1001
R=/run/user/1000
# 会话总线地址要**从会话自己的进程 environ 里拿**，不能猜：phosh 用 dbus-launch 起的私有总线
# （unix:path=/tmp/dbus-XXXX），根本没有 /run/user/1000/bus；拿错地址 dconf 会
# “failed to commit changes”（写不进也不报错，看起来像“改了没生效”）。
DB=$(for p in $(pgrep -u 1000 | head -40); do
       tr '\0' '\n' < /proc/$p/environ 2>/dev/null | grep -m1 '^DBUS_SESSION_BUS_ADDRESS='
     done | head -1 | cut -d= -f2-)
[ -n "$DB" ] || { echo "FAIL: 找不到会话总线（会话用户 1000 没有存活进程？）"; exit 1; }
echo "session bus: $DB"
E="sudo -u $U HOME=/home/$U XDG_RUNTIME_DIR=$R DBUS_SESSION_BUS_ADDRESS=$DB"
set_g(){ timeout 10 $E gsettings set "$1" "$2" "$3" 2>&1 | tail -1; }
get_g(){ timeout 10 $E gsettings get "$1" "$2" 2>&1 | tail -1; }

set_g org.gnome.desktop.session idle-delay "uint32 0"
set_g org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout "0"
set_g org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout "0"
set_g org.gnome.desktop.screensaver lock-enabled "false"

echo "--- 复核 ---"
for k in "org.gnome.desktop.session idle-delay" \
         "org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout" \
         "org.gnome.desktop.screensaver lock-enabled"; do
  set -- $k
  echo "$1 $2 = $(get_g $1 $2)"
done
echo "dpms=$(cat /sys/class/drm/card0/card0-DSI-1/dpms 2>/dev/null || cat /sys/class/drm/card0-DSI-1/dpms)"
