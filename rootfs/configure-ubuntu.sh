#!/bin/bash
# Prepare the extracted Ubuntu Desktop ARM64 filesystem for the TB322FC.
set -euo pipefail

ROOT=${1:-/home/xuqianhui1001/y700-elden/out/ubuntu-rootfs}
R=/home/xuqianhui1001/y700-elden/rootfs
MESA_STAGE=${MESA_STAGE:-/home/xuqianhui1001/y700-elden/out/mesa-build/stage/opt/mesa-a830}
MESA_SYSROOT=${MESA_SYSROOT:-/home/xuqianhui1001/y700-elden/out/sysroot-arm64}
export http_proxy=${http_proxy:-http://127.0.0.1:7897}
export https_proxy=${https_proxy:-http://127.0.0.1:7897}

[ -x "$ROOT/bin/bash" ] || { echo "invalid Ubuntu root: $ROOT" >&2; exit 1; }

cleanup() {
	umount "$ROOT/dev/pts" 2>/dev/null || true
	umount "$ROOT/dev" 2>/dev/null || true
	umount "$ROOT/proc" 2>/dev/null || true
	umount "$ROOT/sys" 2>/dev/null || true
}
trap cleanup EXIT

mkdir -p "$ROOT/dev/pts" "$ROOT/proc" "$ROOT/sys" \
	 "$ROOT/run/systemd/resolve" "$ROOT/usr/local/libexec" \
	 "$ROOT/usr/local/sbin" "$ROOT/lib/firmware" \
	 "$ROOT/var/spool/anacron" \
	 "$ROOT/etc/X11/xorg.conf.d" "$ROOT/etc/lightdm/lightdm.conf.d" \
	 "$ROOT/etc/systemd/system/lightdm.service.d" \
	 "$ROOT/etc/systemd/system"
mount --bind /dev "$ROOT/dev"
mount -t devpts devpts "$ROOT/dev/pts"
mount -t proc proc "$ROOT/proc"
mount -t sysfs sysfs "$ROOT/sys"
cp /etc/resolv.conf "$ROOT/run/systemd/resolve/stub-resolv.conf"

# The installed system uses the online archive, not the live ISO mount.
if [ -e "$ROOT/etc/apt/sources.list.d/cdrom.sources" ]; then
	mv "$ROOT/etc/apt/sources.list.d/cdrom.sources" \
	   "$ROOT/etc/apt/sources.list.d/cdrom.sources.disabled"
fi

if [ ! -x "$ROOT/usr/sbin/sshd" ]; then
	chroot "$ROOT" apt-get \
		-o Acquire::IndexTargets::deb::DEP-11-icons-small::DefaultEnabled=false \
		-o Acquire::IndexTargets::deb::DEP-11-icons::DefaultEnabled=false \
		-o Acquire::IndexTargets::deb::DEP-11-icons-hidpi::DefaultEnabled=false \
		update
	chroot "$ROOT" env DEBIAN_FRONTEND=noninteractive \
		apt-get install -y openssh-server
fi

if ! chroot "$ROOT" dpkg-query -W -f='${db:Status-Abbrev}' fake-hwclock \
	2>/dev/null | grep -q '^ii'; then
	chroot "$ROOT" env DEBIAN_FRONTEND=noninteractive \
		apt-get install -y fake-hwclock
fi

# The desktop snaps (Firefox, Thunderbird, the GNOME platform, App Center)
# live in two different ISO squashfs layers, and copying only the base layer
# leaves seed.yaml pointing at files that do not exist. snapd then refuses to
# seed at all, so the installed system ends up with zero snaps.
if [ -f "$ROOT/var/lib/snapd/seed/seed.yaml" ]; then
	seed_missing=0
	while read -r snapfile; do
		[ -n "$snapfile" ] || continue
		[ -e "$ROOT/var/lib/snapd/seed/snaps/$snapfile" ] || \
			seed_missing=$((seed_missing + 1))
	done < <(awk '/^[[:space:]]*file:/ {print $2}' \
		 "$ROOT/var/lib/snapd/seed/seed.yaml")
	if [ "$seed_missing" -gt 0 ]; then
		echo "warning: $seed_missing snap(s) from seed.yaml are missing;" \
		     "run fix-image-snaps.sh with both ISO layers mounted" >&2
	fi
fi

for group in sudo audio video input render plugdev bluetooth netdev; do
	chroot "$ROOT" getent group "$group" >/dev/null || \
		chroot "$ROOT" groupadd --system "$group"
done

if ! chroot "$ROOT" id elden >/dev/null 2>&1; then
	chroot "$ROOT" useradd -m -s /bin/bash \
		-G sudo,audio,video,input,render,plugdev,bluetooth,netdev elden
fi
printf 'elden:elden\nroot:elden\n' | chroot "$ROOT" chpasswd
chroot "$ROOT" passwd -d root
chroot "$ROOT" ssh-keygen -A

install -m 0755 "$R/usb-gadget" "$ROOT/usr/local/sbin/usb-gadget"
install -m 0755 "$R/elden-start-adsp" \
	"$ROOT/usr/local/sbin/elden-start-adsp"
install -m 0644 "$R/elden-adsp.service" \
	"$ROOT/etc/systemd/system/elden-adsp.service"
install -m 0755 "$R/elden-gpu-policy" \
	"$ROOT/usr/local/sbin/elden-gpu-policy"
install -m 0644 "$R/elden-gpu-policy.service" \
	"$ROOT/etc/systemd/system/elden-gpu-policy.service"
install -m 0755 /home/xuqianhui1001/y700-elden/initramfs/busybox \
	"$ROOT/usr/local/libexec/elden-busybox"
# BusyBox only honours argv[1] as an applet name when argv[0] starts with
# "busybox", so elden-usb-network has to reach udhcpd through this symlink.
# Without it the service dies with "applet not found" and the host never gets
# a DHCP lease.
ln -sfn elden-busybox "$ROOT/usr/local/libexec/udhcpd"
aarch64-linux-gnu-gcc -static -Os -o "$ROOT/usr/local/sbin/reboot2" \
	"$R/reboot2.c"
cp -a "$R/firmware/." "$ROOT/lib/firmware/"
install -m 0644 "$R/xorg-fbdev.conf" \
	"$ROOT/etc/X11/xorg.conf.d/20-elden-fbdev.conf"
install -m 0644 "$R/apt-proxy.conf" \
	"$ROOT/etc/apt/apt.conf.d/99-elden-proxy"

# Mesa's A830 story on this tablet
# --------------------------------
# Mainline DRM reports chip-id 0x0000ffff44050001. Ubuntu's Mesa 26.0.8 lists
# only the KGSL form, so patching the id makes both drivers *recognise* the
# GPU - but 26.0.8's A830 support is incomplete and gnome-shell wedges it
# ("hangcheck detected gpu lockup"). Mesa 26.1.6 carries the mainline A830
# work and runs the desktop cleanly, so the real fix is the tree built by
# build-mesa-a830.sh and installed under /opt/mesa-a830.
#
# The in-place patch below stays as a fallback for anything that runs without
# our environment variables.
mesa=$(find "$ROOT/usr/lib/aarch64-linux-gnu" -maxdepth 1 -type f \
	-name 'libgallium-*.so' -print -quit)
[ -n "$mesa" ] && "$R/patch-mesa-a830.sh" "$mesa" "$mesa"

turnip="$ROOT/usr/lib/aarch64-linux-gnu/libvulkan_freedreno.so"
[ -f "$turnip" ] && "$R/patch-mesa-a830.sh" "$turnip" "$turnip"

if [ -d "$MESA_STAGE" ]; then
	STAGE="$MESA_STAGE" "$R/install-mesa-a830.sh" "$ROOT"
	SYSROOT="$MESA_SYSROOT" STAGE="$MESA_STAGE" \
		"$R/collect-mesa-deps.sh" "$ROOT"
else
	echo "note: $MESA_STAGE absent, skipping /opt/mesa-a830" \
	     "(run build-sysroot.sh then build-mesa-a830.sh)" >&2
fi

chmod 0755 "$ROOT/usr/local/sbin/elden-usb-network"
chmod 0600 "$ROOT/etc/NetworkManager/system-connections/"* 2>/dev/null || true
ln -snf /usr/share/zoneinfo/Asia/Shanghai "$ROOT/etc/localtime"
printf 'Asia/Shanghai\n' > "$ROOT/etc/timezone"
: > "$ROOT/etc/machine-id"

systemctl --root="$ROOT" enable NetworkManager.service gdm3.service ssh.service
systemctl --root="$ROOT" enable elden-usb-gadget.service elden-usb-network.service
# openssh-server enables ssh.socket, whose [Install] section carries
# "RequiredBy=ssh.service". With both units enabled the socket binds
# 0.0.0.0:22 first and the service's "sshd -D" then dies with EADDRINUSE.
systemctl --root="$ROOT" disable ssh.socket
rm -f "$ROOT/etc/systemd/system/ssh.service.requires/ssh.socket"
install -d -m 755 "$ROOT/etc/systemd/system/ssh.service.d"
cat > "$ROOT/etc/systemd/system/ssh.service.d/10-elden.conf" <<'EOF'
[Unit]
After=elden-usb-network.service
Wants=elden-usb-network.service

[Service]
Restart=on-failure
RestartSec=2
EOF
systemctl --root="$ROOT" enable elden-adsp.service
systemctl --root="$ROOT" enable elden-gpu-policy.service
systemctl --root="$ROOT" enable serial-getty@ttyGS0.service

chroot "$ROOT" dpkg --audit
echo "Ubuntu rootfs prepared: $ROOT"
