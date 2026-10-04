#!/usr/bin/env bash
# grubfat-build-uefi-bootimg.sh — 把"可自举 UEFI 卷"包成 Android boot.img（间接引导层·路线 A 的打壳步骤）
#
# 目标: 产出一个 boot.img，其"内核段" = arm64 Image 头(壳) + 内嵌 UEFI 固件卷，
#       使 ABL 以"长得像 Linux 内核"的方式加载并跳入该 UEFI（其 BDS 再扫 FAT 起 GRUB）。
#       与三代 GUF296 boot.img 同构（见 archive/topics/BOOTCHAIN-2026-10-05.md §2.1/§4 路线 A）。
#
# 用法:
#   scripts/grubfat-build-uefi-bootimg.sh <uefi_payload> <out.img> [--code0 HEX]
#
#    <uefi_payload> : 可自举 UEFI 卷/镜像。若给的是 ELF 且含 '_FVH'，取其中的 FV；
#                     否则整文件当作载荷（例如 Mu-Silicium/U-Boot 的 UEFI 卷）。
#    --code0 HEX    : 覆盖 arm64 壳 code0（默认 0x10000381，与三代一致）。
#
# 输出: <out.img> —— Android boot header v3，kernel=gzip(arm64壳+FV)，无 ramdisk。
#       烧写: fastboot flash boot_b <out.img>   (回退: 刷回 out/boot_b-vk49.img)
#
# 纯主机侧；仅 python3 stdlib。**不写设备。**
set -euo pipefail

usage() { sed -n '2,22p' "$0"; exit 1; }
[ $# -ge 2 ] || usage
PAYLOAD=$1; OUT=$2; shift 2
CODE0=0x10000381
while [ $# -gt 0 ]; do
  case "$1" in
    --code0) CODE0=$2; shift 2;;
    *) echo "unknown arg: $1" >&2; usage;;
  esac
done
[ -f "$PAYLOAD" ] || { echo "payload not found: $PAYLOAD" >&2; exit 1; }

PY=${PYTHON:-python3}
command -v "$PY" >/dev/null || { echo "need $PY" >&2; exit 1; }

"$PY" - "$PAYLOAD" "$OUT" "$CODE0" <<'PYEOF'
import sys, struct, gzip, hashlib, os
payload_path, out_path, code0_s = sys.argv[1], sys.argv[2], sys.argv[3]
code0 = int(code0_s, 0) & 0xffffffff

raw = open(payload_path,'rb').read()

# --- 抽出要嵌入的 UEFI 固件卷 ---
fv_off = raw.find(b'_FVH')
if raw[:4] == b'\x7fELF' and fv_off >= 0:
    start = fv_off - 40
    if start >= 0 and raw[start+40:start+44]==b'_FVH':
        fvlen = struct.unpack('<Q', raw[start+32:start+40])[0]
        fv = raw[start:start+fvlen]
        print(f"[extract] ELF 检测到内嵌 FV @ {start}（{len(fv)} B）")
    else:
        fv = raw
else:
    fv = raw
    if fv_off < 0:
        print("[warn] 载荷中未找到 '_FVH' —— 仍按整文件嵌入（对非 FV 的自举镜像可能 OK）")

# --- 构造 arm64 Image 头(壳) ---
text_offset = 0x0
image_size  = len(fv)              # 载荷随壳同在；用载荷长度占位
flags       = 0x0
hdr  = struct.pack('<II', code0, 0x1400000f)      # code0 / code1(分支占位)
hdr += struct.pack('<Q', text_offset)
hdr += struct.pack('<Q', image_size)
hdr += struct.pack('<Q', flags)
hdr += b'\x00'*8 + b'\x00'*8 + b'\x00'*8          # res1/res2/res3
hdr += struct.pack('<I', 0x644d5241)               # magic "ARMd" @56
hdr += b'\x00'*4                                    # res4
assert len(hdr)==64, len(hdr)
# FV 对齐到 0x100（三代里 _FVH 在载荷 152 处；保持可被扫描）
pad = (0x100 - 64) % 0x100
kernel = hdr + b'\x00'*pad + fv
kgz = gzip.compress(kernel, mtime=0)

# --- Android boot header v3 ---
PAGE=4096
def padto(b, n):
    return b + b'\x00' * ((n - len(b) % n) % n)

hdr_size = 1580   # Android boot v3 头大小
cmdline  = b''
boot_hdr  = b'ANDROID!'
boot_hdr += struct.pack('<I', len(kgz))     # kernel_size
boot_hdr += struct.pack('<I', 0)            # ramdisk_size = 0 (间接层不需要)
boot_hdr += struct.pack('<I', 0)            # os_version
boot_hdr += struct.pack('<I', hdr_size)     # header_size
boot_hdr += b'\x00'*16                       # reserved
boot_hdr += struct.pack('<I', 3)            # header_version = 3
boot_hdr += cmdline[:1536].ljust(1536, b'\x00')
hdr_size = len(boot_hdr)
boot_hdr  = boot_hdr[:20] + struct.pack('<I', hdr_size) + boot_hdr[24:]
assert len(boot_hdr) == 1580, len(boot_hdr)

img = padto(boot_hdr, PAGE) + padto(kgz, PAGE)

with open(out_path,'wb') as f:
    f.write(img)

print(f"[ok] payload={payload_path} ({len(fv)} B) code0=0x{code0:x}")
print(f"[ok] kernel_section(gz)={len(kgz)} B  boot.img={len(img)} B -> {out_path}")
print(f"[ok] sha256={hashlib.sha256(img).hexdigest()}")
print("[next] fastboot flash boot_b %s   (rollback: out/boot_b-vk49.img)" % out_path)
PYEOF
