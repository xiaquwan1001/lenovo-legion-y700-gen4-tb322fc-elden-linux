set -u
PATHS="/etc/greetd/config.toml
/usr/local/sbin/cam-mode.sh
/usr/local/sbin/charge-watch.sh
/usr/local/sbin/elden-session-user
/usr/local/sbin/net-up.sh
/usr/local/sbin/q28-boot-watchdog.sh
/usr/local/sbin/q28-watchdog.sh
/usr/local/sbin/slot-attr.py
/usr/local/sbin/time-sync.sh
/usr/local/sbin/usb-gadget
/usr/local/sbin/waydroid-session.sh
/usr/local/sbin/waydroid-ui.sh
/etc/modules-load.d/elden-dma-heap.conf
/usr/local/bin/q28-race-hunt.sh
/usr/lib/systemd/system/greetd.service
/usr/lib/systemd/system/iio-sensor-proxy.service
/usr/lib/systemd/system/qbootctl.service"
echo "$PATHS" | while IFS= read -r p; do
  [ -n "$p" ] || continue
  b=$(basename "$p")
  if timeout -k 5 25 ssh -n -o BatchMode=yes elden "sudo -n cat '$p'" > /tmp/drift/dev/$b 2>/tmp/drift/dev/$b.err; then
    printf 'OK   %-40s %s %s\n' "$p" "$(sha256sum /tmp/drift/dev/$b | cut -c1-16)" "$(stat -c%s /tmp/drift/dev/$b)"
  else
    printf 'MISS %-40s %s\n' "$p" "$(head -1 /tmp/drift/dev/$b.err)"
    rm -f /tmp/drift/dev/$b
  fi
done
