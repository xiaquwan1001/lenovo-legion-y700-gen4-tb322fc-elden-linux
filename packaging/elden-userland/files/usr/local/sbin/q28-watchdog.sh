#!/bin/sh
set -eu
D=/etc/q28-watchdog.disable
S=/var/lib/q28-watchdog
case "${1:-status}" in
  off)  touch "$D"; echo "q28-watchdog: OFF (marker $D)" ;;
  on)   rm -f "$D";  echo "q28-watchdog: ON" ;;
  status)
    if [ -e "$D" ]; then st=OFF; else st=ON; fi
    # card 不能只认 card0：走 UEFI/GRUB 路径时 efifb 先占 card0 再注销，msm 是 card1（PITFALLS #667）
    cards=$(for d in /sys/class/drm/card[0-9] /sys/class/drm/card[0-9][0-9]; do if [ -e "$d" ]; then printf "%s " "${d##*/}"; fi; done); [ -n "$cards" ] || cards=none
    echo "q28-watchdog: $st  count=$(cat "$S/count" 2>/dev/null || echo 0)  phoc=$(pgrep -x phoc | wc -l)  phosh=$(pgrep -x phosh | wc -l)  cards=$cards"
    logger -t q28-wd -p daemon.notice 2>/dev/null "status queried"; ;;
  *) echo "usage: q28-watchdog.sh on|off|status" >&2; exit 2 ;;
esac
