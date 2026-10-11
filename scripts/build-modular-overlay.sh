#!/bin/bash
# build-modular-overlay.sh — layer the modularized payload driver bundle
# (ATH12K + QDSP6/WCD939X + haptics/touch/backlight, all =m) onto the base
# rootfs ramdisk as a second cpio layer, mirroring build-camera-overlay.sh.
#
# The kernel unpacks concatenated cpio archives in order and overrides
# existing regular files, so this layer overrides /init (adds the
# payload-modules-load.sh hook) and adds /lib/modules/<KV> with the payload +
# camera closure.  The camera closure is included because the camera .ko
# bundle already in the base ramdisk has an older vermagic — with a new
# kernel it must be rebuilt from the SAME build (identical vermagic).
#
# Inputs : out/rootfs-overlaid-camera.cpio.gz      (current known-good ramdisk)
#          out/modstage-modular/lib/modules/<KV>/  (make modules_install staging)
# Outputs: out/payload-modules-<KV>.tar.gz
#          out/rootfs-overlaid-modular.cpio.gz     (= base + payload layer)
#
# <KV> must equal the kernel built into the boot image (uname -r on device).
set -euo pipefail
R=$(cd "$(dirname "$0")/.." && pwd)
OUT=$R/out
export PATH="$HOME/bin:$PATH"
KV=${KV:-$(cd "$R/linux" && make -s ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- kernelrelease)}
BASE=${BASE:-$OUT/rootfs-overlaid-camera.cpio.gz}
STAGE=${STAGE:-$OUT/modstage-modular}
[ -f "$BASE" ] || { echo "missing base ramdisk: $BASE" >&2; exit 1; }
MODDIR=$STAGE/lib/modules/$KV
[ -d "$MODDIR/kernel" ] || { echo "no staged modules at $MODDIR (run modules_install)" >&2; exit 1; }

# --- closure: payload roots + camera roots (new vermagic rebuild) ------------
ROOTS="${ROOTS:-qcom-camss s5kjns gc08a8 gt9764 wl2868c-regulator i2c-qcom-cci \
camcc-sm8750 cambistmclkcc-sm8750 leds-qcom-flash \
snd-soc-sc8280xp snd-q6apm q6apm-dai q6apm-lpass-dais q6asm-dai q6routing \
q6afe q6afe-dai q6afe-clocks q6asm q6adm q6core q6prm q6prm-clocks q6usb \
snd-soc-wcd939x snd-soc-wcd939x-sdw \
ath12k ath12k_wifi7 aw86927 novatek-nvt36xxx-spi aw99706}"

list=$(mktemp); trap 'rm -f "$list"' EXIT
: > "$list"
for m in $ROOTS; do
	modprobe -d "$STAGE" -S "$KV" --show-depends "$m" 2>/dev/null \
		| sed -n 's|^insmod \([^ ]*\).*|\1|p' >> "$list" || true
done
sort -u "$list" -o "$list"
[ -s "$list" ] || { echo "closure empty (modprobe failed?)" >&2; exit 1; }
n=$(grep -c . "$list")
echo "closure: $n modules for $KV"

# --- tarball (kernel/ layout, straight into /lib/modules/<KV>/) ---------------
tmpd=$(mktemp -d); trap 'rm -f "$list"; rm -rf "$tmpd"' EXIT
while read -r ko; do
	[ -n "$ko" ] || continue
	rel=${ko#$MODDIR/}
	mkdir -p "$tmpd/$(dirname "$rel")"
	cp "$ko" "$tmpd/$rel"
done < "$list"

# kmod-compatible index for the bundled subset (full-path deps + .bin index;
# a bare-name index makes the device's kmod fail to resolve deps).
# depmod wants the canonical <base>/lib/modules/<KV>/kernel/... layout.
lay=$(mktemp -d); trap 'rm -f "$list"; rm -rf "$tmpd" "$lay"' EXIT
mkdir -p "$lay/lib/modules/$KV"
cp -a "$tmpd/kernel" "$lay/lib/modules/$KV/"
depmod -b "$lay" "$KV" 2>/dev/null || true
cp "$lay/lib/modules/$KV/modules.dep" "$tmpd/" 2>/dev/null || true
cp "$lay/lib/modules/$KV/modules.dep.bin" "$tmpd/" 2>/dev/null || true
tar czf "$OUT/payload-modules-$KV.tar.gz" -C "$tmpd" .

# --- cpio overlay layer -------------------------------------------------------
OVL=$OUT/.modular-ovl
rm -rf "$OVL"
mkdir -p "$OVL/lib/modules/$KV" "$OVL/usr/local/sbin"
install -m 0755 "$R/rootfs/persistent-overlay/init" "$OVL/init"
install -m 0755 "$R/scripts/camera-modules-load.sh" "$OVL/usr/local/sbin/camera-modules-load.sh"
install -m 0755 "$R/scripts/payload-modules-load.sh" "$OVL/usr/local/sbin/payload-modules-load.sh"
tar xzf "$OUT/payload-modules-$KV.tar.gz" -C "$OVL/lib/modules/$KV"

( cd "$OVL" && find . -print0 | cpio --null -o -H newc --owner=0:0 2>/dev/null | gzip -9 ) \
	> "$OUT/payload-overlay-$KV.cpio.gz"
cat "$BASE" "$OUT/payload-overlay-$KV.cpio.gz" > "$OUT/rootfs-overlaid-modular.cpio.gz"

echo "KV=$KV"
echo "payload bundle : $OUT/payload-modules-$KV.tar.gz ($(du -h "$OUT/payload-modules-$KV.tar.gz" | cut -f1))"
echo "payload overlay: $(du -h "$OUT/payload-overlay-$KV.cpio.gz" | cut -f1)"
echo "new ramdisk    : $(du -h "$OUT/rootfs-overlaid-modular.cpio.gz" | cut -f1)"
