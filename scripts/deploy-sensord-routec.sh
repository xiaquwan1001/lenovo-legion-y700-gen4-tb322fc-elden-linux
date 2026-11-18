#!/bin/bash
# deploy-sensord-routec.sh — build & install the route-C Waydroid sensor HAL
# (../TASKS/README.md C4).
#
# Design (verified 2026-10-11): install our UDP-backed daemon as
# /usr/local/bin/waydroid-sensord. Waydroid's container manager then
#   * stops setting waydroid.stub_sensors_hal (images.py: `which("waydroid-sensord")`), and
#   * auto-spawns it as `waydroid-sensord /dev/hwbinder` (container_manager.py:170-172),
# so no OpenRC service is needed and no /vendor overlay/SELinux is touched.
# Sensor values arrive over UDP (scripts/eldroid-sensord.c text protocol).
#
# Rollback: `ssh root@<dev> rm /usr/local/bin/waydroid-sensord` — then Waydroid
# restores the stub HAL on the next container start and the device is back to
# "No Sensors on the device".
#
# Prereqs on device: apk add libgbinder-dev libglibutil-dev g++ pkgconf  (network)
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TAB=${TAB:-root@192.168.7.1}
# 2026-11-18 审计 R4 P1-4：① 无 BatchMode/超时 ⇒ 首次连接可挂死 ② `apk add … || true`
# 吞掉失败后照样 `apk del waydroid-sensors` ⇒ 设备既没我们的 HAL 也没原厂包（半部署）。
# 现：先装依赖（失败即停）→ 构建 → 安装成功后才删原厂包。
SSHOPTS=(-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
         -o ConnectTimeout=6 -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o LogLevel=ERROR)
STMO=${STMO:-300}
SSH="timeout -k 5 $STMO ssh"
scpq() { timeout -k 5 "$STMO" scp -q "${SSHOPTS[@]}" "$@"; }
SRC=$ROOT/patches-userland/waydroid-sensord-udp

echo "[sensord-routec] ensure build deps on $TAB"
$SSH "${SSHOPTS[@]}" "$TAB" 'apk add --no-cache libgbinder-dev libglibutil-dev g++ pkgconf' \
	|| { echo "[sensord-routec] 依赖安装失败（设备网络/源），未删原厂包，可安全重跑" >&2; exit 1; }
# 原厂包要等**我们的件装好之后**才删（下面 install 成功后再删）

echo "[sensord-routec] copy source + build"
$SSH "${SSHOPTS[@]}" "$TAB" 'mkdir -p /root/sensord-routeC'
scpq "$SRC"/* "$TAB:/root/sensord-routeC/"
$SSH "${SSHOPTS[@]}" "$TAB" 'cd /root/sensord-routeC && make clean >/dev/null 2>&1; make'

echo "[sensord-routec] install -> /usr/local/bin/waydroid-sensord"
$SSH "${SSHOPTS[@]}" "$TAB" 'install -m 0755 /root/sensord-routeC/waydroid-sensord-udp /usr/local/bin/waydroid-sensord'
$SSH "${SSHOPTS[@]}" "$TAB" 'which waydroid-sensord'
# 我们的件已就位 ⇒ 才可以删原厂包（它 ship 的 sensorfw 版会在 /usr/bin 抢名）
$SSH "${SSHOPTS[@]}" "$TAB" 'apk del waydroid-sensors >/dev/null 2>&1 || true'

# ---- real data source: SSC -> UDP relay (OpenRC service) --------------------
# The relay runs on the host and converts `ssccli` output into the UDP text
# protocol. It must NOT be an OpenRC service for the *daemon* (Waydroid spawns
# that itself), but it does need one for the relay process.
echo "[sensord-routec] install SSC->UDP relay + OpenRC service"
scpq "$SRC/ssc-udp-relay.py" "$TAB:/usr/local/bin/ssc-udp-relay.py"
scpq "$SRC/ssc-udp-relay.openrc" "$TAB:/etc/init.d/ssc-udp-relay"
$SSH 'chmod 0755 /usr/local/bin/ssc-udp-relay.py /etc/init.d/ssc-udp-relay; rc-update add ssc-udp-relay default >/dev/null 2>&1 || true; rc-service ssc-udp-relay restart 2>&1 | tail -1'

cat <<'EOF'
[sensord-routec] done.
  * waydroid-sensord  : /usr/local/bin/waydroid-sensord (Waydroid auto-spawns it per container start)
  * ssc-udp-relay     : OpenRC service, feeds real ssccli values over UDP 52012
Now restart the container so Waydroid picks the HAL up:
  rc-service waydroid-container restart
Then verify inside the container:
  waydroid shell -- getprop sys.boot_completed            # expect 1
  waydroid shell -- lshal | grep hardware.sensors          # expect ...ISensors/default
  waydroid shell -- dumpsys sensorservice | head           # expect "Total 6 h/w sensors"
  waydroid shell -- dumpsys sensorservice | grep -A4 'Recent Sensor events'  # real values
Rollback: ssh root@<dev> 'rm /usr/local/bin/waydroid-sensord; rc-service ssc-udp-relay stop; rc-update del ssc-udp-relay default'
EOF
