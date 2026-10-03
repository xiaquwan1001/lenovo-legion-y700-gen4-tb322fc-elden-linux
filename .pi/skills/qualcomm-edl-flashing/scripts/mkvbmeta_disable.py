#!/usr/bin/env python3
"""Generate AVB disable-verification vbmeta images WITHOUT avbtool.

Equivalent of `fastboot --disable-verification flash vbmeta <img>` (or
avbtool make_vbmeta_image --flags 2). Verified flashed on TB321FU
(vbmeta_a + vbmeta_system_a); standard AVB0 128-byte header, algorithm NONE.

Usage: python3 mkvbmeta_disable.py [out1 [out2 ...]]   (default: vbmeta_disable.img, vbmeta_system_disable.img)
"""
import struct, sys

def make_vbmeta(path, size=4096):
    h = bytearray(size)
    h[0:4] = b'AVB0'
    struct.pack_into('<I', h, 4, 1)     # required_libavb_version_major
    struct.pack_into('<I', h, 8, 0)     # minor
    struct.pack_into('<Q', h, 12, 0)    # auth_block_size
    struct.pack_into('<Q', h, 20, 0)    # aux_block_size
    struct.pack_into('<I', h, 28, 0)    # algorithm_type = NONE
    struct.pack_into('<Q', h, 112, 0)   # rollback_index
    struct.pack_into('<I', h, 120, 2)   # flags = AVB_VBMETA_IMAGE_FLAGS_VERIFICATION_DISABLED
    struct.pack_into('<I', h, 124, 0)   # rollback_index_location
    with open(path, 'wb') as f:
        f.write(bytes(h))
    print(f"{path}: {size}B AVB0 alg=NONE flags=2 (disable verification)")

if __name__ == '__main__':
    outs = sys.argv[1:] or ['vbmeta_disable.img', 'vbmeta_system_disable.img']
    for o in outs:
        make_vbmeta(o)
