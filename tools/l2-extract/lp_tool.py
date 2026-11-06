#!/usr/bin/env python3
"""Minimal lpdump/lpunpack equivalent for Android dynamic-partition (LP) metadata.
Parses geometry + metadata header + tables from a super image, lists partitions
with extents, and can extract/splice a partition back at the same offsets.
Format per AOSP system/core/fs_mgr/liblp (metadata v1.0)."""
import struct, sys, hashlib, json, os

GEOM_MAGIC = 0x616C4467          # LpMetadataGeometry
HDR_MAGIC  = 0x414C5030          # LpMetadataHeader
PART_OFF   = 4096                # reserved bytes before geometry
SECTOR     = 512

def parse_geometry(img):
    img.seek(PART_OFF)
    data = img.read(4096)
    magic, struct_size = struct.unpack_from('<II', data, 0)
    assert magic == GEOM_MAGIC, f"bad geometry magic {magic:#x}"
    assert struct_size == 52, f"unexpected geometry struct_size {struct_size}"
    checksum = data[8:40]
    meta_max_size, slot_count, lbs = struct.unpack_from('<III', data, 40)
    # advisory checksum over the 52-byte struct with checksum zeroed
    zeroed = bytearray(data[:52]); zeroed[8:40] = b'\0'*32
    if hashlib.sha256(zeroed).digest() != checksum:
        print("# warn: geometry checksum mismatch", file=sys.stderr)
    return dict(meta_max_size=meta_max_size, slot_count=slot_count, logical_block_size=lbs)

def parse_header(img, geom):
    # primary metadata slot copies: geometry dual-copy (4096, 8192), blobs from 12288
    base = PART_OFF + 2*4096
    img.seek(base)
    blob = img.read(geom['meta_max_size'])
    magic, major, minor, hdr_size = struct.unpack_from('<IHHI', blob, 0)
    assert magic == HDR_MAGIC, f"bad header magic {magic:#x} (offset {base})"
    hdr_checksum = blob[12:44]
    tables_size = struct.unpack_from('<I', blob, 44)[0]
    tables_checksum = blob[48:80]
    # v1.0 table descriptors at offsets 80..128
    def desc(off):
        return struct.unpack_from('<III', blob, off)  # (offset_in_tables, num_entries, entry_size)
    parts = desc(80); exts = desc(92); groups = desc(104); bdevs = desc(116)
    # header checksum: advisory only
    hz = bytearray(blob[:hdr_size]); hz[12:44] = b'\0'*32
    if hashlib.sha256(hz).digest() != hdr_checksum:
        print("# warn: header checksum mismatch", file=sys.stderr)
    tables = blob[hdr_size:hdr_size + tables_size]
    if hashlib.sha256(tables).digest() != tables_checksum:
        print("# warn: tables checksum mismatch", file=sys.stderr)
    return dict(blob=blob, hdr_size=hdr_size, tables=tables,
                parts=parts, exts=exts, groups=groups, bdevs=bdevs,
                major=major, minor=minor)

def parse_metadata(path):
    img = open(path, 'rb')
    geom = parse_geometry(img)
    hdr = parse_header(img, geom)
    tables = hdr['tables']
    def read_table(desc, fmt):
        off, n, esz = desc
        assert struct.calcsize(fmt) == esz, f"entry size {esz} != calcsize {struct.calcsize(fmt)}"
        return [struct.unpack_from(fmt, tables, off + i*esz) for i in range(n)]
    partitions = read_table(hdr['parts'], '<36sIIII')       # name, attrs, first_extent, num_extents, group_idx (52B, v1.2)
    extents    = read_table(hdr['exts'], '<QIQI')           # num_sectors, target_type, target_data(SECTORS, 512B), source_bdev
    groups     = read_table(hdr['groups'], '<36sIQ') if hdr['groups'][2] == 48 else read_table(hdr['groups'], '<36sI4x')
    # block devices: parse only the 36-byte name from each variable-size entry
    boff, bnum, bes = hdr['bdevs']
    bdevs = [(tables[boff+i*bes:boff+i*bes+36],) for i in range(bnum)]
    return geom, hdr, partitions, extents, groups, bdevs

def main():
    src = sys.argv[1]
    cmd = sys.argv[2] if len(sys.argv) > 2 else 'dump'
    geom, hdr, partitions, extents, groups, bdevs = parse_metadata(src)
    bdev_names = [b[0].rstrip(b'\0').decode(errors='replace') for b in bdevs]
    print(f"# geometry: metadata_max_size={geom['meta_max_size']} slot_count={geom['slot_count']} lbs={geom['logical_block_size']}")
    print(f"# header: v{hdr['major']}.{hdr['minor']} hdr_size={hdr['hdr_size']}")
    print(f"# block devices: {bdev_names}")
    for g in groups:
        print(f"# group {g[0].rstrip(chr(0).encode()).decode(errors='replace')!r} max_size={g[2]}")
    total_bytes = 0
    plist = []
    for p in partitions:
        name = p[0].rstrip(b'\0').decode(errors='replace')
        first, n = p[2], p[3]
        segs = []
        for e in range(first, first + n):
            num_sectors, ttype, tdata, tsrc = extents[e]
            assert ttype == 0, "non-linear extent"
            segs.append((tdata * SECTOR, num_sectors * SECTOR))
            total_bytes += num_sectors * SECTOR
        plist.append((name, p[1], segs))
        span = ' + '.join(f"@{o}+{s}" for o, s in segs)
        print(f"  {name:16s} attrs={p[1]:#x} {span}")
    print(f"# total partition bytes: {total_bytes}")
    if cmd == 'dump':
        return
    if cmd == 'extract':
        name = sys.argv[3]; out = sys.argv[4]
        img = open(src, 'rb')
        with open(out, 'wb') as o:
            for pname, _, segs in plist:
                if pname != name: continue
                for off, size in segs:
                    img.seek(off); left = size
                    while left:
                        buf = img.read(min(1 << 20, left)); assert buf
                        o.write(buf); left -= len(buf)
        print(f"extracted {name} -> {out}")
    if cmd == 'splice':
        name = sys.argv[3]; newimg = sys.argv[4]
        srcf = open(src, 'r+b'); newf = open(newimg, 'rb')
        for pname, _, segs in plist:
            if pname != name: continue
            for off, size in segs:
                left = size
                while left:
                    buf = newf.read(min(1 << 20, left)); assert buf, "new image shorter than extent"
                    srcf.seek(off); srcf.write(buf); off += len(buf); left -= len(buf)
        srcf.close()
        print(f"spliced {name} back into {src}")

if __name__ == '__main__':
    main()
