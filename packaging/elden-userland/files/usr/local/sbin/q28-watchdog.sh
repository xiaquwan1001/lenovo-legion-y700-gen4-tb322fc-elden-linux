#!/bin/sh
set -eu
D=/etc/q28-watchdog.disable
S=/var/lib/q28-watchdog
case "${1:-status}" in
  off)  touch "$D"; echo "q28-watchdog: OFF (marker $D)" ;;
  on)   rm -f "$D";  echo "q28-watchdog: ON" ;;
  status)
    if [ -e "$D" ]; then st=OFF; else st=ON; fi
    echo "q28-watchdog: $st  count=$(cat "$S/count" 2>/dev/null || echo 0)  phoc=$(pgrep -x phoc | wc -l)  phosh=$(pgrep -x phosh | wc -l)  card0=$([ -e /sys/class/drm/card0 ] && echo yes || echo no)"
    logger -t q28-wd -p daemon.notice 2>/dev/null "status queried"; ;;
  *) echo "usage: q28-watchdog.sh on|off|status" >&2; exit 2 ;;
esac
