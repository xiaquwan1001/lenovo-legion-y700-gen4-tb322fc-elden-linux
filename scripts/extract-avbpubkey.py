#!/usr/bin/env python3
"""从带 AVB vbmeta header 的镜像提取 public key blob（.avbpubkey）。

用途：`scripts/build-locked-chain.sh` 的 recovery chain 提取（原脚本曾丢失，2026-10-04 重建）。
用法：extract-avbpubkey.py <vbmeta-or-signed-image> <output.avbpubkey>
原理：AVB0 header 256 B；public_key_offset 相对 auxiliary block 开头，
      blob 绝对位置 = 256 + authentication_data_block_size + public_key_offset，长 public_key_size。
自测：对自签 vbmeta_b_flags0.img 提取应与 `bootslot-b/avb.avbpubkey` 逐字节一致。
"""
import struct
import sys


def extract_pubkey(blob: bytes) -> bytes:
    if blob[:4] != b"AVB0":
        sys.exit(f"ERROR: not an AVB image (magic={blob[:4]!r})")
    # magic@0 u32 major@4 u32 minor@8 → auth_blk@12 aux_blk@20 algo@28
    # hash@32/40 sig@48/56 pubkey@64/72 pubkey_meta@80/88（全部大端）
    (auth_blk, _aux, _algo, _h_off, _h_sz, _s_off, _s_sz,
     pk_off, pk_len, _pkm_off, _pkm_len) = struct.unpack_from(">QQLQQQQQQQQ", blob, 12)
    start = 256 + auth_blk + pk_off
    return blob[start:start + pk_len]


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    with open(sys.argv[1], "rb") as f:
        pubkey = extract_pubkey(f.read())
    if not pubkey:
        sys.exit("ERROR: empty public key")
    with open(sys.argv[2], "wb") as f:
        f.write(pubkey)
    print(f"{len(pubkey)} bytes -> {sys.argv[2]}")


if __name__ == "__main__":
    main()
