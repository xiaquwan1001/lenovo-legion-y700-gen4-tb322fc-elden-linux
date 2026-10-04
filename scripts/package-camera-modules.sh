#!/bin/bash
# package-camera-modules.sh — build out/camera-modules-<KV>.tar.gz from a
# `make modules_install` staging dir, including the full dependency closure.
#
# Prereq (host):
#   cd linux && make -j$(nproc) modules
#   make -j$(nproc) INSTALL_MOD_PATH=$STAGE modules_install
#
# The tarball layout is kernel/<path>.ko, so it unpacks straight into
# /lib/modules/<KV>/ on the device.  Module and kernel must come from the SAME
# build (identical vermagic), otherwise insmod/modprobe fails.
#
# usage:
#   STAGE=/tmp/camera-modstage bash scripts/package-camera-modules.sh
set -euo pipefail
export PATH="$HOME/bin:$PATH"
ROOT=${ROOT:-$HOME/y700-elden}
STAGE=${STAGE:-/tmp/camera-modstage}
KV=${KV:-$(cd "$ROOT/linux" && make -s ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- kernelrelease)}
MODDIR=$STAGE/lib/modules/$KV
[ -d "$MODDIR" ] || { echo "no staged modules at $MODDIR"; exit 1; }

# Top-level modules to pull in; modprobe --show-depends adds the closure.
ROOTS="qcom-camss s5kjns gc08a8 gt9764 wl2868c-regulator i2c-qcom-cci
       camcc-sm8750 cambistmclkcc-sm8750 leds-qcom-flash"

list=$(mktemp); trap 'rm -f "$list"' EXIT
: > "$list"
for m in $ROOTS; do
	modprobe -d "$STAGE" -S "$KV" --show-depends "$m" 2>/dev/null \
		| sed -n 's|^insmod ||p' >> "$list" || true
done
sort -u "$list" -o "$list"
[ -s "$list" ] || { echo "closure empty (modprobe failed?)"; exit 1; }

OUT=$ROOT/out/camera-modules-$KV.tar.gz
tmpd=$(mktemp -d); trap 'rm -f "$list"; rm -rf "$tmpd"' EXIT
n=0
while read -r ko; do
	[ -n "$ko" ] || continue
	rel=${ko#$STAGE/lib/modules/$KV/}          # kernel/drivers/...
	mkdir -p "$tmpd/$(dirname "$rel")"
	cp "$ko" "$tmpd/$rel"
	n=$((n+1))
done < "$list"

# Generate a kmod-compatible index (modules.dep with full-path deps +
# modules.dep.bin) for the bundled subset.  Do NOT hand-write it from
# `modinfo -F depends`: that yields bare names, and the device's kmod then
# fails to resolve any dependency ("Module <x> not found").  depmod wants the
# canonical <base>/lib/modules/<KV>/kernel/... layout, so stage one.
lay=$(mktemp -d)
trap 'rm -f "$list"; rm -rf "$tmpd" "$lay"' EXIT
mkdir -p "$lay/lib/modules/$KV"
cp -a "$tmpd/kernel" "$lay/lib/modules/$KV/"
depmod -b "$lay" "$KV" 2>/dev/null || true
cp "$lay/lib/modules/$KV/modules.dep" "$tmpd/" 2>/dev/null || true
cp "$lay/lib/modules/$KV/modules.dep.bin" "$tmpd/" 2>/dev/null || true

( cd "$tmpd" && tar czf "$OUT" . )
echo "packed $n modules -> $OUT ($(du -h "$OUT" | cut -f1))"

echo "== vermagic verification =="
bad=0
while read -r ko; do
	[ -n "$ko" ] || continue
	vm=$(modinfo -F vermagic "$ko" 2>/dev/null || true)
	case "$vm" in
		"$KV"*|'') ;;
		*) echo "  MISMATCH $(basename "$ko"): $vm"; bad=1 ;;
	esac
done < "$list"
[ "$bad" = 0 ] && echo "  all $(wc -l < "$list") modules: vermagic=$KV* OK"
