#!/bin/bash
# Sign a mainline boot image for slot b (self-signed AVB, see bootslot-b/README.md).
#
# usage: scripts/sign-boot-b.sh [in.img] [out.img]
#        default: out/boot-elden-vk13.img -> bootslot-b/boot_b.img
#
# The signed image is padded to the boot partition size (96 MiB) and carries an
# AVB hash footer signed with bootslot-b/avb.key; vbmeta_b_flags3.img has the
# matching chain descriptor for `boot` (key sha1 fc1e3b33...).
set -eu
cd "$(dirname "$0")/.."
IN=${1:-out/boot-elden-vk13.img}
OUT=${2:-bootslot-b/boot_b.img}
KEY=bootslot-b/avb.key
[ -f "$IN" ] || { echo "no such image: $IN" >&2; exit 1; }
cp -f "$IN" "$OUT"
python3 tools/avbtool.py add_hash_footer --image "$OUT" --partition_name boot \
	--partition_size 100663296 --key "$KEY" --algorithm SHA256_RSA4096 >/dev/null
python3 tools/avbtool.py info_image --image "$OUT" | grep -E "Public key|Partition Name|Image Size|Digest"
ls -la "$OUT"
echo "[sign] ready: fastboot flash boot_b $OUT"
