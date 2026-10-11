#!/bin/sh
# restore.sh — replay this snapshot onto a freshly built persistent root
# (/dev/sda17, LABEL=linux17).  Run AS ROOT on the device:
#     ssh root@192.168.7.1 'sh -s' < rootfs/persistent-overlay/restore.sh
#
# The persistent root has no scripted builder; this is the "data/experience"
# carry-over (see AGENTS.md: migrate data, rebuild environment).  Package
# versions may differ from the snapshot — that is expected; the goal is the
# *set* of packages and the hand-written config.
set -eu

[ "$(id -u)" = 0 ] || { echo "restore.sh: must be root" >&2; exit 1; }
cd "$(dirname "$0")" 2>/dev/null || cd .

echo "== packages =="
apk add --no-interactive $(tr '\n' ' ' <apk-world.txt)

echo "== /usr/local/sbin (add-ons; .bak excluded) =="
mkdir -p /usr/local/sbin
tar xzf usr-local-sbin.tar.gz -C /usr/local/sbin --owner=0 --group=0

echo "== openrc payload + greetd/session config =="
for d in /etc/local.d /etc/conf.d /etc/greetd /etc/NetworkManager/conf.d; do mkdir -p "$d"; done
tar xzf etc-local.d.tar.gz      -C /etc/local.d --owner=0 --group=0
tar xzf etc-conf.d.tar.gz       -C /etc/conf.d --owner=0 --group=0
tar xzf etc-greetd.tar.gz       -C /etc/greetd --owner=0 --group=0
tar xzf etc-NM-conf.d.tar.gz    -C /etc/NetworkManager/conf.d --owner=0 --group=0

echo "== iio-sensor-proxy timing override (auto-rotate stuck OFF) =="
# Override the packaged init script so the proxy waits for QRTR svc 400 (SSC)
# before launching; otherwise it scans once, gives up (G1-34), and phosh's
# rotation-manager stays MODE_OFF. Only applies when the package is installed.
if [ -x /etc/init.d/iio-sensor-proxy ] || apk info -e iio-sensor-proxy >/dev/null 2>&1; then
	install -m755 iio-sensor-proxy.initd /etc/init.d/iio-sensor-proxy
fi

echo "== userland display fixes: phoc non-preferred mode + phosh scale report =="
# Rebuilds patched phoc/phosh from source (releases are fetched, build deps are
# installed and kept).  Takes a few minutes.  Skip with:
#     SKIP_USERLAND_DISPLAY=1 sh restore.sh
# Source of truth for the patches: repo patches-userland/ .
if [ -d userland-display ]; then
	sh userland-display/install-on-device.sh
fi

echo "== /init (single source of truth is initramfs/init in the repo) =="
install -m755 init /init

echo "== elogind poweroff/reboot/halt wrappers =="
for f in poweroff reboot halt; do install -m755 "sbin-$f" "/sbin/$f"; done

echo "== greetd runtime dir ownership =="
chown -R greetd:greetd /var/lib/greetd 2>/dev/null || true
chmod 750 /var/lib/greetd 2>/dev/null || true

echo "== dbus launch helper ownership (alpine ships root:root 4750) =="
chown root:messagebus /usr/libexec/dbus-daemon-launch-helper 2>/dev/null || true
chmod 4750 /usr/libexec/dbus-daemon-launch-helper 2>/dev/null || true

echo "== freeze-trace 装弹（PITFALLS #106 死挂取证：panic→暖复位→ramoops）=="
install -d /etc/sysctl.d
install -m 0644 freeze-trace.conf /etc/sysctl.d/99-freeze-trace.conf
grep -q 99-freeze-trace /etc/sysctl.conf 2>/dev/null || \
	printf '\n# see /etc/sysctl.d/99-freeze-trace.conf (PITFALLS #106)\n' >> /etc/sysctl.conf
install -m 0755 pstore-catch.initd /etc/init.d/pstore-catch
rc-update add pstore-catch boot 2>/dev/null || true

echo "== openrc runlevels + mode =="
/usr/local/sbin/openrc-enable.sh enable

echo
echo "done.  mode=$(cat /etc/elden-init-mode 2>/dev/null).  Reboot to apply."
echo "rollback: echo legacy >/etc/elden-init-mode && reboot"
