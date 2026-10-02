#!/usr/bin/env bash
# waydroid-proxy-setup.sh — 让 Waydroid 容器可访问 Google（复用主机 Clash 代理）
#
# 背景：设备内核缺 CONFIG_IP_ADVANCED_ROUTER（连带 CONFIG_IP_MULTIPLE_TABLES 关），
#       Android netd 的 ip rule / 多路由表下发失败 → 容器只有 192.168.240.0/24 链路路由，
#       没有默认路由，出网 Network is unreachable。
# 本脚本做两件事（都不刷 boot）：
#   1) 往容器里注入默认路由（bind-mount 一个改过的 init.rc，boot_completed 后加路由）
#   2) 给容器设 Android 全局 http_proxy 指向主机 Clash（mixed-port 7897）
#
# 用法：
#   DEVICE=192.168.7.1 PROXY_HOST=192.168.43.197 PROXY_PORT=7897 \
#     bash scripts/waydroid-proxy-setup.sh
#
# 前提：主机 Clash allow-lan:true 且监听 *:PORT；设备能路由到 PROXY_HOST:PORT。
set -euo pipefail

DEVICE="${DEVICE:-192.168.7.1}"
PROXY_HOST="${PROXY_HOST:-}"
PROXY_PORT="${PROXY_PORT:-7897}"
SSH_OPTS="-o ConnectTimeout=8 -o StrictHostKeyChecking=no"

[ -n "$PROXY_HOST" ] || { echo "ERROR: 需要 PROXY_HOST（在设备上可达的主机局域网 IP）"; exit 1; }

say(){ echo ">>> $*"; }
rsh(){ ssh $SSH_OPTS "root@$DEVICE" "$@"; }

say "1. 主机代理是否从设备可达"
rsh "python3 - <<'EOF'
import urllib.request
h=urllib.request.ProxyHandler({'http':'http://$PROXY_HOST:$PROXY_PORT','https':'http://$PROXY_HOST:$PROXY_PORT'})
op=urllib.request.build_opener(h)
try:
    r=op.open('https://www.google.com',timeout=12); print('PROXY_GOOGLE',r.status)
except Exception as e:
    print('PROXY_ERR',repr(e)); raise SystemExit(1)
EOF"

say "2. 注入默认路由 init.rc（bind-mount 覆盖 blank_screen.rc）"
scp $SSH_OPTS net/waydroid-proxy/blank_screen.rc "root@$DEVICE:/root/wd/blank_screen.rc"
rsh "cd /var/lib/waydroid/lxc/waydroid && \
  cp -a config_nodes config_nodes.bak-\$(date +%s) && \
  (grep -q 'blank_screen.rc' config_nodes || \
     echo 'lxc.mount.entry = /root/wd/blank_screen.rc system/etc/init/blank_screen.rc none bind,create=file,optional 0 0' >> config_nodes) && \
  grep blank_screen.rc config_nodes"

say "3. 重启 waydroid（container + session）"
rsh "bash -s" <<EOS
export XDG_RUNTIME_DIR=/run/phosh WAYLAND_DISPLAY=wayland-0 DISPLAY=:0 HOME=/root
BUS=\$(grep -z DBUS_SESSION_BUS_ADDRESS /proc/\$(pgrep -x phosh | head -1)/environ 2>/dev/null | tr -d '\\0' | cut -d= -f2-)
export DBUS_SESSION_BUS_ADDRESS="\$BUS"
waydroid session stop >/dev/null 2>&1 || true
waydroid container stop >/dev/null 2>&1 || true
sleep 2
nohup waydroid container start >/root/wd/proxy-container.log 2>&1 &
sleep 5
nohup waydroid session start >/root/wd/proxy-session.log 2>&1 &
echo "waiting for boot..."
for i in \$(seq 1 30); do
  [ "\$(waydroid shell -- getprop sys.boot_completed 2>/dev/null | tr -d '\\r')" = "1" ] && break
  sleep 3
done
echo "boot_completed=\$(waydroid shell -- getprop sys.boot_completed 2>/dev/null)"
echo "routes:"; waydroid shell -- ip route
EOS

say "4. 设置容器全局 http_proxy（走 adb，绕开 waydroid shell settings put 的 NPE）"
rsh "bash -s" <<EOS
set -e
export HOME=/root XDG_RUNTIME_DIR=/run/phosh WAYLAND_DISPLAY=wayland-0 DISPLAY=:0
BUS=\$(grep -z DBUS_SESSION_BUS_ADDRESS /proc/\$(pgrep -x phosh | head -1)/environ 2>/dev/null | tr -d '\\0' | cut -d= -f2-)
export DBUS_SESSION_BUS_ADDRESS="\$BUS"
command -v adb >/dev/null 2>&1 || apk add --no-cache android-tools >/dev/null 2>&1
mkdir -p /root/.android
[ -f /root/.android/adbkey ] || adb keygen /root/.android/adbkey >/dev/null 2>&1
# 把 adb 公钥注入容器（adbd 需鉴权）
cat /root/.android/adbkey.pub | waydroid shell -- sh -c 'mkdir -p /data/misc/adb; grep -qf - /data/misc/adb/adb_keys 2>/dev/null || cat >> /data/misc/adb/adb_keys' || true
waydroid shell -- setprop ctl.restart adbd >/dev/null 2>&1 || true
sleep 3
adb kill-server >/dev/null 2>&1 || true; adb start-server >/dev/null 2>&1 || true
ADDR=\$(waydroid shell -- ip -4 addr show eth0 | awk '/inet/{print \$2}' | cut -d/ -f1)
adb connect "\$ADDR:5555" >/dev/null 2>&1 || true
sleep 2
adb -s "\$ADDR:5555" shell settings put global http_proxy "$PROXY_HOST:$PROXY_PORT"
echo "http_proxy=\$(adb -s "\$ADDR:5555" shell settings get global http_proxy)"
waydroid prop set persist.waydroid.http_proxy "$PROXY_HOST:$PROXY_PORT" >/dev/null 2>&1 || true
EOS

say "5. 容器内验证 Google"
rsh "waydroid shell -- curl -s -o /dev/null -w 'GOOGLE_PROXY=%{http_code}\n' --max-time 15 -x http://$PROXY_HOST:$PROXY_PORT https://www.google.com"

say "完成。"
