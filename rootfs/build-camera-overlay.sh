#!/bin/bash
# build-camera-overlay.sh — layer the mainline camera stack (kernel modules +
# boot loader + /init hook) onto the EXISTING rootfs ramdisk, without
# rebuilding the whole Alpine image.
#
# The kernel unpacks concatenated cpio archives in order and truncates+replaces
# existing regular files, so this second layer overrides /init and adds the
# module tree.
#
# Inputs : out/rootfs-overlaid.cpio.gz      (current known-good ramdisk)
#          out/camera-modules-<KV>.tar.gz   (scripts/package-camera-modules.sh)
# Outputs: out/camera-overlay-<KV>.cpio.gz
#          out/rootfs-overlaid-camera.cpio.gz  (= base + camera layer)
#
# <KV> must equal the kernel built into the boot image (uname -r on device).
# Re-run whenever the kernel OR the modules are rebuilt.
set -euo pipefail
R=$(cd "$(dirname "$0")" && pwd)
ROOT=${ROOT:-$R/..}
OUT=$ROOT/out
export PATH="$HOME/bin:$PATH"
KV=${KV:-$(cd "$ROOT/linux" && make -s ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- kernelrelease)}
BASE=${BASE:-$OUT/rootfs-overlaid.cpio.gz}
BUNDLE=$OUT/camera-modules-$KV.tar.gz
[ -f "$BASE" ]   || { echo "missing base ramdisk: $BASE"; exit 1; }
[ -f "$BUNDLE" ] || { echo "missing $BUNDLE (run scripts/package-camera-modules.sh)"; exit 1; }

OVL=$OUT/.camera-ovl
rm -rf "$OVL"
mkdir -p "$OVL/lib/modules/$KV" "$OVL/usr/local/sbin"
install -m 0755 "$R/init" "$OVL/init"
install -m 0755 "$ROOT/scripts/camera-modules-load.sh" "$OVL/usr/local/sbin/camera-modules-load.sh"
tar xzf "$BUNDLE" -C "$OVL/lib/modules/$KV"

( cd "$OVL" && find . -print0 | cpio --null -o -H newc --owner=0:0 2>/dev/null | gzip -9 ) \
	> "$OUT/camera-overlay-$KV.cpio.gz"
cat "$BASE" "$OUT/camera-overlay-$KV.cpio.gz" > "$OUT/rootfs-overlaid-camera.cpio.gz"

echo "KV=$KV"
echo "camera overlay : $(du -h "$OUT/camera-overlay-$KV.cpio.gz" | cut -f1)"
echo "new ramdisk    : $(du -h "$OUT/rootfs-overlaid-camera.cpio.gz" | cut -f1)"
