#!/usr/bin/env python3
"""Rebuild an Android `super` partition in Python — a lpmake equivalent.

Writes AOSP liblp v1.2 metadata (SHA256 checksums, 256B header, extents in 512-byte sectors)
plus the partition images into a sparse super image. Verified: builds a self-consistent
13G super for Lenovo TB321FU from ZUI 17.5.10.031 split images (all SHA256 checksums round-trip;
device flash + boot not yet confirmed at time of writing — verify with fs_mgr on first boot).

Adapt: SUPER_SIZE, METADATA_MAX, METADATA_SLOTS, IMAGES (name, path), ALIGN.
Flash: edl.py --loader=<melf> w super super_new.img
"""
import struct, hashlib, os

SUPER_SIZE = 13958643712          # bytes — from GPT (TB321FU super = 13 GiB)
METADATA_MAX = 65536
METADATA_SLOTS = 1                # 1 for non-A/B (single-copy) super
LBS = 4096                        # logical block size
ALIGN = 1 << 20                   # 1 MiB
GEOM_MAGIC = 0x616c4467
HDR_MAGIC = 0x414C5030
MAJOR, MINOR = 10, 2

IMAGES = [
    # (partition name, path to split image) — order = layout order
    ("system",      "supers/super_4.img"),
    ("product",     "supers/super_3.img"),
    ("vendor",      "supers/super_7.img"),
    ("system_ext",  "supers/super_6.img"),
    ("system_dlkm", "supers/super_5.img"),
    ("vendor_dlkm", "supers/super_8.img"),
    ("odm",         "supers/super_2.img"),
]

def sha256(b):
    return hashlib.sha256(b).digest()

parts = [(n, os.path.getsize(p)) for n, p in IMAGES]
layout, pos = [], ALIGN
for name, size in parts:
    size_a = (size + LBS - 1) // LBS * LBS
    layout.append((name, pos, size_a))
    pos += size_a
assert pos < SUPER_SIZE - METADATA_MAX * 2 - 4096 * 2, "layout overflows super"

# tables
part_tbl, ext_tbl = bytearray(), bytearray()
for i, (name, start, size) in enumerate(layout):
    part_tbl += name.encode().ljust(36, b'\x00')
    part_tbl += struct.pack('<IIII', 1, i, 1, 0)          # READONLY, first_ext, num_ext, group
    ext_tbl += struct.pack('<QIQI', size // 512, 0, start // 512, 0)
grp_tbl = b'main'.ljust(36, b'\x00') + struct.pack('<IQ', 0, 0)
blk_tbl = struct.pack('<QIIQ36sI', (4096 + METADATA_MAX * METADATA_SLOTS) // 512,
                      ALIGN // 512, 0, SUPER_SIZE, b'super', 0)
tables = bytes(part_tbl) + bytes(ext_tbl) + grp_tbl + blk_tbl
ext_off, grp_off, blk_off = len(part_tbl), len(part_tbl) + len(ext_tbl), len(part_tbl) + len(ext_tbl) + len(grp_tbl)

# header — ORDER: tables_checksum BEFORE header_checksum
hdr = bytearray(256)
struct.pack_into('<I', hdr, 0, HDR_MAGIC)
struct.pack_into('<HH', hdr, 4, MAJOR, MINOR)
struct.pack_into('<I', hdr, 8, 256)
struct.pack_into('<I', hdr, 44, len(tables))
def td(o, n, esz):
    return struct.pack('<III', o, n, esz)
hdr[80:92]   = td(0, len(parts), 52)
hdr[92:104]  = td(ext_off, len(parts), 24)
hdr[104:116] = td(grp_off, 1, 48)
hdr[116:128] = td(blk_off, 1, 64)
hdr[48:80] = sha256(tables)          # ① tables checksum first
hdr[12:44] = sha256(bytes(hdr))      # ② header checksum last (field zeroed while hashing)

# geometry
geo = bytearray(4096)
struct.pack_into('<I', geo, 0, GEOM_MAGIC)
struct.pack_into('<I', geo, 4, 52)
struct.pack_into('<I', geo, 40, METADATA_MAX)
struct.pack_into('<I', geo, 44, METADATA_SLOTS)
struct.pack_into('<I', geo, 48, LBS)
geo[8:40] = sha256(bytes(geo[:52]))

out = 'super_new.img'
with open(out, 'wb') as f:
    f.truncate(SUPER_SIZE)
    f.seek(0); f.write(bytes(geo))
    f.seek(4096); f.write(bytes(hdr) + tables)
    for name, start, size in layout:
        f.seek(start)
        f.write(open(dict(IMAGES)[name], 'rb').read())
    bak = SUPER_SIZE - 4096 - METADATA_MAX
    f.seek(bak); f.write(bytes(hdr) + tables)
    f.seek(SUPER_SIZE - 4096); f.write(bytes(geo))
print(f"DONE {out}: {len(layout)} partitions, data {ALIGN}..{pos} of {SUPER_SIZE}")
print("VERIFY: re-parse and recompute both SHA256s (primary + backup slots) before flashing")
