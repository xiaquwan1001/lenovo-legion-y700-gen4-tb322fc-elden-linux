#!/bin/bash
# deploy-sensord-routec.sh — build & install the route-C Waydroid sensor HAL
# (TASKS.md C4).
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
SSH="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 $TAB"
SRC=$ROOT/patches-userland/waydroid-sensord-udp

echo "[sensord-routec] ensure build deps on $TAB"
$SSH 'apk add --no-cache libgbinder-dev libglibutil-dev g++ pkgconf >/dev/null 2>&1 || true'
# Remove the upstream package: it ships a different waydroid-sensord (sensorfw)
# that cannot work here, and would shadow/wedge our binary at /usr/bin.
$SSH 'apk del waydroid-sensors >/dev/null 2>&1 || true'

echo "[sensord-routec] copy source + build"
$SSH 'mkdir -p /root/sensord-routeC'
scp -q -o StrictHostKeyChecking=no "$SRC"/* "$TAB:/root/sensord-routeC/"
$SSH 'cd /root/sensord-routeC && make clean >/dev/null 2>&1; cd /root/sensord-routeC && make'

echo "[sensord-routec] install -> /usr/local/bin/waydroid-sensord"
$SSH 'install -m 0755 /root/sensord-routeC/waydroid-sensord-udp /usr/local/bin/waydroid-sensord'
$SSH 'which waydroid-sensord'

# ---- real data source: SSC -> UDP relay (OpenRC service) --------------------
# The relay runs on the host and converts `ssccli` output into the UDP text
# protocol. It must NOT be an OpenRC service for the *daemon* (Waydroid spawns
# that itself), but it does need one for the relay process.
echo "[sensord-routec] install SSC->UDP relay + OpenRC service"
scp -q -o StrictHostKeyChecking=no "$SRC/ssc-udp-relay.py" "$TAB:/usr/local/bin/ssc-udp-relay.py"
scp -q -o StrictHostKeyChecking=no "$SRC/ssc-udp-relay.openrc" "$TAB:/etc/init.d/ssc-udp-relay"
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
