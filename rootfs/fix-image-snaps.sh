#!/bin/bash
# Restore the snap seed that went missing from the Ubuntu image.
#
# seed.yaml lists every snap the installed desktop expects, but only three of
# the .snap files survived into the image. snapd refuses to seed when any of
# them is absent, so the system boots with no Firefox, no Thunderbird, no App
# Center and no GNOME platform snap.
#
# The originals live on the installer ISO, split across two squashfs layers:
# minimal.squashfs carries most of them and minimal.standard.squashfs adds
# Thunderbird. Both are mounted unless SEED_SRC names a directory explicitly.
set -euo pipefail

R=${1:-/mnt/rootfs}
ISO=${ISO:-/home/xuqianhui1001/y700-elden/ubuntu-26.04.1-desktop-arm64.iso}
dst=$R/var/lib/snapd/seed

test -f "$dst/seed.yaml"

mounted=()
cleanup() {
	local i
	for ((i = ${#mounted[@]} - 1; i >= 0; i--)); do
		umount "${mounted[i]}" 2>/dev/null || true
	done
}
trap cleanup EXIT

sources=()
if [ -n "${SEED_SRC:-}" ]; then
	sources=("$SEED_SRC")
else
	if ! mountpoint -q /mnt/iso; then
		mkdir -p /mnt/iso
		mount -o loop,ro "$ISO" /mnt/iso
		mounted+=(/mnt/iso)
	fi
	for layer in minimal.squashfs minimal.standard.squashfs; do
		mp=/mnt/sq-${layer%.squashfs}
		mkdir -p "$mp"
		if ! mountpoint -q "$mp"; then
			mount -o loop,ro "/mnt/iso/casper/$layer" "$mp"
			mounted+=("$mp")
		fi
		[ -d "$mp/var/lib/snapd/seed/snaps" ] && sources+=("$mp/var/lib/snapd/seed")
	done
fi

install -d -m 755 "$dst/snaps" "$dst/assertions"

echo "== copying missing seed snaps"
copied=0
for src_seed in "${sources[@]}"; do
	for src in "$src_seed"/snaps/*.snap; do
		[ -f "$src" ] || continue
		f=$(basename "$src")
		[ -e "$dst/snaps/$f" ] && continue
		cp -p "$src" "$dst/snaps/$f"
		echo "  $f ($(du -h "$src" | cut -f1))"
		copied=$((copied + 1))
	done
	cp -pn "$src_seed"/assertions/* "$dst/assertions/" 2>/dev/null || true
done
[ "$copied" -eq 0 ] && echo "  (nothing to copy)"

echo "== verify against seed.yaml"
missing=0
while read -r f; do
	[ -n "$f" ] || continue
	if [ ! -e "$dst/snaps/$f" ]; then
		echo "  STILL MISSING: $f"
		missing=$((missing + 1))
	fi
done < <(awk '/^[[:space:]]*file:/ {print $2}' "$dst/seed.yaml")
if [ "$missing" -eq 0 ]; then
	echo "  all seed.yaml entries present ($(ls -1 "$dst/snaps"/*.snap | wc -l) snaps)"
else
	exit 1
fi

echo "== assertions: $(ls -1 "$dst/assertions" | wc -l)"
du -sh "$dst"
df -h "$R" | tail -1
