#!/bin/bash
# Build an in-RAM Alpine rootfs (aarch64) for the TB322FC mainline kernel.
# Needs qemu-user-static binfmt (for chroot) - already set up in this WSL.
set -e
R=/home/xuqianhui1001/y700-elden/rootfs
ROOT=$R/alpine
MIRROR=https://dl-cdn.alpinelinux.org/alpine
BRANCH=latest-stable
mkdir -p $R/dl

# --- fetch minirootfs -------------------------------------------------------
if ! ls $R/dl/alpine-minirootfs-*-aarch64.tar.gz >/dev/null 2>&1; then
	f=$(curl -sSL $MIRROR/$BRANCH/releases/aarch64/latest-releases.yaml \
	    | awk '/minirootfs/{m=1} m && /file:/{print $2; exit}')
	echo "fetching $f"
	curl -sSL -o $R/dl/$f $MIRROR/$BRANCH/releases/aarch64/$f
fi
TAR=$(ls $R/dl/alpine-minirootfs-*-aarch64.tar.gz | tail -1)

# --- unpack ----------------------------------------------------------------
rm -rf $ROOT && mkdir -p $ROOT
tar -xzf $TAR -C $ROOT
cp /etc/resolv.conf $ROOT/etc/resolv.conf
cat > $ROOT/etc/apk/repositories <<EOF
$MIRROR/$BRANCH/main
$MIRROR/$BRANCH/community
EOF

# --- packages + config inside chroot --------------------------------------
mount -t proc proc $ROOT/proc 2>/dev/null || true
chroot $ROOT /bin/sh -e <<'EOF'
apk update -q
apk add -q openssh openssh-server util-linux e2fsprogs f2fs-tools dosfstools \
	iproute2 iputils ethtool evtest i2c-tools usbutils pciutils \
	htop nano bash tmux file strace dtc \
	dhcpcd busybox-extras
# This link is a private USB-only network to the bring-up host, so root logs
# in with no credentials at all: an empty password field plus
# PermitEmptyPasswords makes sshd accept the "none" method, and
# "ssh root@192.168.7.1" connects without a prompt or a key. sshd_config
# Includes sshd_config.d before its own settings and keeps the first value
# it sees, so the drop-in wins over the stock lines further down.
sed -i 's/^root:[^:]*:/root::/' /etc/shadow
mkdir -p /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/00-noauth.conf <<'CONF'
PermitRootLogin yes
PasswordAuthentication yes
PermitEmptyPasswords yes
KbdInteractiveAuthentication no
UsePAM no
CONF
ssh-keygen -A
echo elden > /etc/hostname
printf '127.0.0.1 localhost\n192.168.7.1 elden\n' > /etc/hosts
# console tty for getty on tty1/ttyGS0 need securetty entries
printf 'ttyGS0\ntty1\nconsole\n' >> /etc/securetty
EOF
umount $ROOT/proc 2>/dev/null || true

# --- our init, gadget script, dhcp server config ----------------------------
sed 's/\r$//' $R/init       > $ROOT/init;                    chmod 755 $ROOT/init
mkdir -p $ROOT/usr/local/sbin
sed 's/\r$//' $R/usb-gadget > $ROOT/usr/local/sbin/usb-gadget; chmod 755 $ROOT/usr/local/sbin/usb-gadget
aarch64-linux-gnu-gcc -static -Os -o $ROOT/usr/local/sbin/reboot2 $R/reboot2.c

# --- elden userspace helpers (canonical copies live in ../scripts) -----------
# /init launches these by absolute path from /usr/local/sbin; historically they
# were scp'd onto the device ad-hoc, so the rootfs was not reproducible.
for s in ath12k-load.sh ath12k-retry.sh audio-alsa-init.sh bt-up.sh charge-ctl.sh charge-watch.sh \
         dpms-watch.sh net-up-manual.sh net-up.sh net-up-nm.sh \
         patch-init-ath12k.sh patch-init-bt.sh patch-init-charge.sh \
         patch-init-dbus.sh patch-init-net.sh patch-init-time.sh \
         start-desktop.sh time-sync.sh slot-attr.py 99-unmanaged.conf; do
	src=$R/../scripts/$s
	if [ -f "$src" ]; then
		install -m 755 "$src" "$ROOT/usr/local/sbin/$s"
	else
		echo "[rootfs] WARN: missing helper $s" >&2
	fi
done
cat > $ROOT/etc/udhcpd.conf <<'EOF'
start 192.168.7.2
end 192.168.7.20
interface usb0
lease_file /run/udhcpd.leases
option subnet 255.255.255.0
# This link is for local SSH only. Do not advertise a default gateway: doing
# so makes the host send its Internet traffic to the tablet.
option lease 86400
EOF
mkdir -p $ROOT/run $ROOT/var/empty
rm -f $ROOT/etc/resolv.conf

# --- pack -----------------------------------------------------------------
mkdir -p /home/xuqianhui1001/y700-elden/out
( cd $ROOT && find . -print0 | cpio --null -o -H newc --owner=0:0 2>/dev/null | gzip -6 ) > /home/xuqianhui1001/y700-elden/out/rootfs.cpio.gz
du -sh $ROOT | cut -f1 | xargs echo "rootfs size:"
ls -la /home/xuqianhui1001/y700-elden/out/rootfs.cpio.gz
