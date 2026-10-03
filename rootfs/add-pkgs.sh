#!/bin/bash
# Add packages to the already-built Alpine tree and repack, without redoing the
# whole minirootfs fetch. Needs the qemu-user binfmt handler this WSL has.
set -e
R=/TB322FC/rootfs
ROOT=$R/alpine
PKGS="${*:-alsa-utils alsa-lib}"

[ -d "$ROOT" ] || { echo "no $ROOT - run build-rootfs.sh first"; exit 1; }

cp /etc/resolv.conf "$ROOT/etc/resolv.conf"
mount -t proc proc "$ROOT/proc" 2>/dev/null || true
chroot "$ROOT" /bin/sh -e -c "apk update -q && apk add -q $PKGS"
umount "$ROOT/proc" 2>/dev/null || true
rm -f "$ROOT/etc/resolv.conf"

( cd "$ROOT" && find . -print0 | cpio --null -o -H newc --owner=0:0 2>/dev/null | gzip -6 ) \
	> /TB322FC/out/rootfs.cpio.gz
echo "added: $PKGS"
ls -la /TB322FC/out/rootfs.cpio.gz
