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

# --- 网络自愈：HTTPS 信任链 + PMTU 黑洞（2026-10-18） ---------------------
# 见 reports/net-https-mtu-rootcause-20261018.md 与 PITFALLS §49。
# net-selfheal.sh 已在 usr-local-sbin.tar.gz 里；此处只装触发点。
mkdir -p /etc/NetworkManager/dispatcher.d
tar xzf etc-NM-dispatcher.tar.gz -C /etc/NetworkManager/dispatcher.d --owner=0 --group=0
chmod 755 /etc/NetworkManager/dispatcher.d/50-net-selfheal 2>/dev/null || true
# 立即跑一次，别等下次重启
autostart_net_selfheal() { [ -x /usr/local/sbin/net-selfheal.sh ] && /usr/local/sbin/net-selfheal.sh; }
autostart_net_selfheal || true

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

echo "== Q28 看门狗（运营兜底自动重启；PITFALLS #228/#229）=="
if [ -f q28-boot-watchdog.sh ]; then
	install -m755 q28-boot-watchdog.sh /usr/local/sbin/q28-boot-watchdog.sh
	mkdir -p /etc/local.d
	if [ -f /etc/local.d/elden-bringup.start ] && ! grep -q q28-boot-watchdog /etc/local.d/elden-bringup.start; then
		sed -i 's/^for h in /for h in q28-boot-watchdog /' /etc/local.d/elden-bringup.start
	fi
	# 装机自检：无参 reboot2 必须做「正常重启」；旧构建会进 fastboot（#229）
	if [ -x /usr/local/sbin/reboot2 ] && \
	   ! /usr/local/sbin/reboot2 -h 2>&1 | grep -q 'no argument = normal reboot'; then
		echo "WARNING: /usr/local/sbin/reboot2 是旧构建（无参=fastboot）——请装 out/reboot2-fixed" >&2
	fi
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

echo "== Waydroid 马达透传桥（PITFALLS #232–#238 / TASKS C10）=="
# daemon 二进制不随快照走：主机上 scripts/build-hapticd.sh 重建后 scp 到
# /usr/local/bin/elden-hapticd（或直接跑 scripts/waydroid-haptics-setup.sh）。
install -m755 elden-hapticd.initd /etc/init.d/elden-hapticd
install -d /etc/conf.d
[ -f /etc/conf.d/elden-hapticd ] || install -m644 etc-conf.d-elden-hapticd /etc/conf.d/elden-hapticd
rc-update add elden-hapticd default 2>/dev/null || true
# 容器侧 bind 源（tmpfs，重启即重建；OpenRC 服务 start_pre 也会建）
mkdir -p /run/elden-haptic/leds/vibrator
# lxc 挂载项（两条，带 optional）由 scripts/waydroid-haptics-setup.sh 幂等追加到
# /var/lib/waydroid/lxc/waydroid/config；本快照不覆盖该文件（含本机 mesa 等 blk 定制）。

echo "== openrc runlevels + mode =="
/usr/local/sbin/openrc-enable.sh enable

echo
echo "done.  mode=$(cat /etc/elden-init-mode 2>/dev/null).  Reboot to apply."
echo "rollback: echo legacy >/etc/elden-init-mode && reboot"
