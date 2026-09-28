#!/usr/bin/env python3
"""Verify a stitched partition image against its source shards + zero-padded tail.

Constant memory (~few MiB) even for multi-GiB images. NEVER read() a whole
image/shard/tail into RAM: on TB322FC (Gen4, 2026-08-16) verification scripts
that did `f.read(size)` / `hashlib.sha256(open(p,'rb').read())` /
`tail = f.read(total-offset)` + `b'\\x00' * len(tail)` materialized 11-23 GB
and were killed TWICE by the kernel OOM killer (26 GiB box). See the SKILL.md
pitfall "NEVER materialize multi-GiB images in Python verification scripts".

Usage:
    python3 verify_stitched_image.py <full_image> <shard1> [shard2 ...]

Shards are hashed IN ORDER against the first bytes of <full_image>; the
remaining tail must be all zero bytes (QFIL split images pad to GPT size).
Exit 0 = all shards match in order AND tail is zero-padded; exit 1 = mismatch;
exit 2 = usage error. A 22 GiB image takes ~1-2 min.
"""
import hashlib
import os
import sys

BLOCK = 1 << 20  # 1 MiB


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for blk in iter(lambda: f.read(BLOCK), b""):
            h.update(blk)
    return h.hexdigest()


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    full_path = sys.argv[1]
    shards = sys.argv[2:]
    full_size = os.path.getsize(full_path)
    all_ok = True
    offset = 0
    with open(full_path, "rb") as f:
        for shard in shards:
            size = os.path.getsize(shard)
            h = hashlib.sha256()
            remaining = size
            while remaining:
                n = min(BLOCK, remaining)
                h.update(f.read(n))
                remaining -= n
            ok = h.hexdigest() == sha256_file(shard)
            all_ok &= ok
            print(f"{os.path.basename(shard)} @ {offset:>14} size {size:>14} "
                  f'{"OK" if ok else "MISMATCH!"}')
            offset += size
        # Tail zero-padding check — blockwise, never materialized.
        tail_ok = True
        tail_bytes = 0
        for blk in iter(lambda: f.read(BLOCK), b""):
            if blk.strip(b"\x00"):  # non-zero byte present
                tail_ok = False
            tail_bytes += len(blk)
        print(f"tail     @ {offset:>14} size {tail_bytes:>14} "
              f'{"OK (zero-padded)" if tail_ok else "NON-ZERO!"}')
        if offset + tail_bytes != full_size:
            print(f"SIZE MISMATCH: shards+tail = {offset + tail_bytes}, full = {full_size}")
            all_ok = False
        all_ok &= tail_ok
    print("RESULT:", "ALL MATCH OK" if all_ok else "FAILURE")
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
