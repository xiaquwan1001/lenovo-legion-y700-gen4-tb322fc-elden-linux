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
# 2026-11-18 审计 R2 P2-6：旧版先 `cp -f "$IN" "$OUT"` 再签 —— 输入 > 96 MiB 时 avbtool
# 失败但 $OUT 已经被覆盖成**未签名件**，下一次 `fastboot flash boot_b` 就用它了。
# 现在签到同目录临时件，成功才原子替换。
TMP="$OUT.tmp-$$"
trap 'rm -f "$TMP"' EXIT
cp -f "$IN" "$TMP"
python3 tools/avbtool.py add_hash_footer --image "$TMP" --partition_name boot \
	--partition_size 100663296 --key "$KEY" --algorithm SHA256_RSA4096 >/dev/null \
	|| { echo "[sign] avbtool 失败（$IN 是否 > 96 MiB / key 是否在？）—— $OUT 未被改动" >&2; exit 1; }
mv -f "$TMP" "$OUT"
python3 tools/avbtool.py info_image --image "$OUT" | grep -E "Public key|Partition Name|Image Size|Digest"
ls -la "$OUT"
echo "[sign] ready: fastboot flash boot_b $OUT"
