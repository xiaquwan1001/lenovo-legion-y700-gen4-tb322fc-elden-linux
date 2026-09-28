#!/bin/bash
# Layer local tweaks onto the prebuilt Alpine image without re-running
# build-rootfs.sh (which needs network access and a qemu-user chroot).
#
# The kernel unpacks concatenated cpio archives in order and opens existing
# regular files with O_TRUNC, so every path below overrides the copy that came
# from rootfs.cpio.gz.
set -e
R=/home/xuqianhui1001/y700-elden/rootfs
OUT=/home/xuqianhui1001/y700-elden/out
OVL=$OUT/.ovl
BASE=$OUT/rootfs.cpio.gz

[ -e "$BASE" ] || { echo "missing $BASE - run build-rootfs.sh first"; exit 1; }

rm -rf "$OVL"
mkdir -p "$OVL/etc/ssh/sshd_config.d" "$OVL/usr/lib" "$OVL/usr/local/sbin"

# Keep the boot selector in the overlay so it can be updated without rebuilding
# the complete Alpine recovery ramdisk.
install -m 0755 "$R/init" "$OVL/init"

# Mesa 26.1.6 knows the KGSL A830v1 id, but not the same id with the 0xffff
# speed-bin wildcard returned by mainline DRM. Upstream commit 2061a5ee adds
# that entry. Patch the generated table in a validated copy for this overlay.
MESA_LIB=$(find "$R/alpine/usr/lib" -maxdepth 1 -type f \
	-name 'libgallium-*.so' -print -quit)
[ -n "$MESA_LIB" ] || { echo "missing libgallium in $R/alpine/usr/lib"; exit 1; }
"$R/patch-mesa-a830.sh" "$MESA_LIB" "$OVL/usr/lib/$(basename "$MESA_LIB")"

# BusyBox reboot cannot pass a reason string, so "reboot2 bootloader" is the
# only way from this rootfs back into fastboot.
aarch64-linux-gnu-gcc -static -Os -o "$OVL/usr/local/sbin/reboot2" "$R/reboot2.c"

# Credential-free root SSH over the private USB link. Keep in sync with the
# equivalent block in build-rootfs.sh.
cat > "$OVL/etc/ssh/sshd_config.d/00-noauth.conf" <<'CONF'
PermitRootLogin yes
PasswordAuthentication yes
PermitEmptyPasswords yes
KbdInteractiveAuthentication no
UsePAM no
CONF
chmod 644 "$OVL/etc/ssh/sshd_config.d/00-noauth.conf"

# PermitEmptyPasswords only helps if the hash field is actually empty.
sed 's/^root:[^:]*:/root::/' "$R/alpine/etc/shadow" > "$OVL/etc/shadow"
chmod 640 "$OVL/etc/shadow"

# Firmware pulled off the stock modem/bluetooth partitions. remoteproc looks it
# up by the firmware-name paths in the DT, so the layout under here has to match.
if [ -d "$R/firmware" ]; then
	mkdir -p "$OVL/lib/firmware"
	cp -a "$R/firmware/." "$OVL/lib/firmware/"
fi

( cd "$OVL" && find . -print0 | cpio --null -o -H newc --owner=0:0 2>/dev/null | gzip -9 ) > "$OUT/overlay.cpio.gz"
cat "$BASE" "$OUT/overlay.cpio.gz" > "$OUT/rootfs-overlaid.cpio.gz"

echo "overlay: $(du -h "$OUT/overlay.cpio.gz" | cut -f1)   ramdisk: $(du -h "$OUT/rootfs-overlaid.cpio.gz" | cut -f1)"
