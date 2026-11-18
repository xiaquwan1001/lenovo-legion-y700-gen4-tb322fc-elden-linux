#!/usr/bin/env python3
"""android-super-scan.py -- forensic scan of a super partition that was shipped as
Qualcomm rawprogram segments (super_1.img .. super_N.img).

Two independent checks, both evidence-only (no writes):

1. LP magic scan.  For every occurrence of the geometry magic (0x616c4467 "gDla")
   or the metadata-header magic (0x414C5030 "0PLA") the candidate is validated
   (struct_size == 52 and SHA-256 checksum for geometry, header_size in
   [128,256] and header checksum for metadata).  Raw 4-byte hits inside
   partition payload are statistical noise; only checksum-valid hits count.

2. Coverage analysis.  Rebuild the byte ranges described by a rawprogram XML for
   one label, then intersect them with
     * the metadata extents of every metadata slot (what the device would map), and
     * the holes between the shipped segments (bytes the package does NOT contain).
   Holes that fall inside a logical partition are data the package is missing.

Usage:
  android-super-scan.py --xml <rawprogram*.xml> --label super --segment-dir <dir>
                        [--metadata-segment super_1.img] [--json]
"""

import argparse
import hashlib
import json
import os
import struct
import sys
import xml.etree.ElementTree as ET

LP_GEOM_MAGIC = b"\x67\x44\x6c\x61"  # little-endian 0x616c4467
LP_HEADER_MAGIC = b"\x30\x50\x4c\x41"  # little-endian 0x414C5030
SECTOR = 512


def iter_hits(path, needles):
    """Yield (offset, which) for raw 4-byte magic hits, chunked, no mmap."""
    size = os.path.getsize(path)
    chunk = 32 << 20
    overlap = 8
    with open(path, "rb") as f:
        pos = 0
        tail = b""
        while pos < size:
            buf = tail + f.read(chunk)
            base = pos - len(tail)
            for needle, name in needles:
                start = 0
                while True:
                    i = buf.find(needle, start)
                    if i < 0:
                        break
                    yield base + i, name
                    start = i + 1
            tail = buf[-overlap:]
            pos += chunk


def validate(path, off, kind):
    with open(path, "rb") as f:
        if kind == "geom":
            f.seek(off)
            b = f.read(52)
            if len(b) < 52:
                return False
            magic, struct_size = struct.unpack_from("<II", b, 0)
            if magic != 0x616C4467 or struct_size != 52:
                return False
            z = bytearray(b)
            z[8:40] = b"\x00" * 32
            return hashlib.sha256(bytes(z)).digest() == b[8:40]
        f.seek(off)
        h = f.read(256)
        if len(h) < 132:
            return False
        magic, major, minor, header_size = struct.unpack_from("<IHHI", h, 0)
        if magic != 0x414C5030 or not (128 <= header_size <= 256):
            return False
        z = bytearray(h[:header_size])
        z[12:44] = b"\x00" * 32
        return hashlib.sha256(bytes(z)).digest() == h[12:44]


def union(ranges):
    out = []
    for a, b in sorted(ranges):
        if out and a <= out[-1][1]:
            out[-1] = (out[-1][0], max(out[-1][1], b))
        else:
            out.append((a, b))
    return out


def load_lp(path, slot=0):
    """Minimal liblp reader (same field layout as scripts/android-super.py)."""
    f = open(path, "rb")
    f.seek(4096)
    g = f.read(52)
    magic, struct_size, chk = struct.unpack_from("<II32s", g, 0)
    assert magic == 0x616C4467
    max_size, slots, lbs = struct.unpack_from("<III", g, 40)
    off = 4096 + 8192 + max_size * slot
    f.seek(off)
    h = f.read(256)
    header_size = struct.unpack_from("<I", h, 8)[0]
    tables_size = struct.unpack_from("<I", h, 44)[0]
    descs = struct.unpack_from("<12I", h, 80)
    f.seek(off + header_size)
    t = f.read(tables_size)
    po, pe, psz, xo, xe, xsz, go, ge, gsz, bo, be, bsz = descs
    parts = []
    for i in range(pe):
        name, attr, fe, ne, gi = struct.unpack_from("<36sIIII", t, po + i * psz)
        parts.append(dict(name=name.rstrip(b"\x00").decode("ascii", "replace"), attr=attr,
                          first=fe, n=ne, group=gi))
    exts = [struct.unpack_from("<QIQI", t, xo + i * xsz) for i in range(xe)]
    grps = []
    for i in range(ge):
        name, flags, mx = struct.unpack_from("<36sIQ", t, go + i * gsz)
        grps.append(name.rstrip(b"\x00").decode("ascii", "replace"))
    geo = dict(max_size=max_size, slots=slots, logical_block_size=lbs)
    return geo, parts, exts, grps


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--xml", required=True)
    ap.add_argument("--label", default="super")
    ap.add_argument("--segment-dir", default=".")
    ap.add_argument("--metadata-segment", default="super_1.img",
                    help="segment that contains the LP metadata area")
    ap.add_argument("--slot", type=int, default=0)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    base_dir = os.path.dirname(os.path.abspath(args.xml))
    segs = []
    for prog in ET.parse(args.xml).getroot().iter("program"):
        if prog.get("label") != args.label or not prog.get("filename"):
            continue
        segs.append(dict(lba=int(prog.get("start_sector")),
                         n=int(prog.get("num_partition_sectors")),
                         ssz=int(prog.get("SECTOR_SIZE_IN_BYTES", "512")),
                         pn=int(prog.get("physical_partition_number", "0")),
                         fn=os.path.join(base_dir, prog.get("filename"))))
    if not segs:
        sys.exit(f'no segments with label "{args.label}" in {args.xml}')
    segs.sort(key=lambda s: s["lba"])
    ssz = segs[0]["ssz"]
    base_lba = segs[0]["lba"]

    report = {"segment_sector_size": ssz, "base_lba": base_lba, "segments": [], "magic_scan": []}

    # ---- 1. magic scan ----
    needles = [(LP_GEOM_MAGIC, "geom"), (LP_HEADER_MAGIC, "header")]
    for s in segs:
        path = s["fn"]
        valid, bogus = [], 0
        for off, kind in iter_hits(path, needles):
            if validate(path, off, kind):
                valid.append(dict(offset=off, kind=kind))
            else:
                bogus += 1
        report["magic_scan"].append(dict(file=os.path.basename(path), size=os.path.getsize(path),
                                         raw_hits=len(valid) + bogus, checksum_valid=valid,
                                         raw_coincidences=bogus))

    # ---- 2. coverage ----
    cov = union([((s["lba"] - base_lba) * ssz // SECTOR,
                  (s["lba"] - base_lba + s["n"]) * ssz // SECTOR) for s in segs])
    gaps = []
    prev = 0
    for a, b in cov:
        if a > prev:
            gaps.append((prev, a))
        prev = max(prev, b)
    total_end = cov[-1][1]

    meta_path = os.path.join(args.segment_dir, args.metadata_segment)
    geo, parts, exts, grps = load_lp(meta_path, args.slot)

    def covered(a, b):
        return sum(max(0, min(b, y) - max(a, x)) for x, y in cov)

    slots = []
    for slot in range(geo["slots"]):
        _, parts_s, exts_s, _ = load_lp(meta_path, slot)
        rows = []
        for p in parts_s:
            # union first: snapshot metadata can list overlapping extents for the
            # same partition, and a plain sum would double-count the hole bytes.
            rs = union([(e[2], e[2] + e[0]) for e in
                        exts_s[p["first"] : p["first"] + p["n"]] if e[1] == 0])
            missing = sum((b - a) - covered(a, b) for a, b in rs)
            rows.append(dict(partition=p["name"], missing_sectors=missing,
                             missing_bytes=missing * SECTOR))
        slots.append(dict(slot=slot, partitions=rows,
                          total_missing_bytes=sum(r["missing_bytes"] for r in rows)))
    report["slots"] = slots
    report["gaps"] = [dict(start_sector=a, end_sector=b, bytes=(b - a) * SECTOR,
                           mib=(b - a) * SECTOR / 1048576) for a, b in gaps]
    report["gap_total_bytes"] = sum((b - a) * SECTOR for a, b in gaps)
    report["data_end_bytes"] = total_end * SECTOR

    if args.json:
        print(json.dumps(report, indent=2))
        return

    print("== LP magic scan (raw hit -> checksum-validated)")
    for r in report["magic_scan"]:
        v = ", ".join(f'{h["offset"]}:{h["kind"]}' for h in r["checksum_valid"]) or "-"
        print(f"  {r['file']:<14} size={r['size']:>12}  raw_hits={r['raw_hits']:>3}  "
              f"valid=[{v}]  coincidences={r['raw_coincidences']}")
    print(f"\n== shipped segments: {len(segs)} pieces, sector={ssz} B, base_lba={base_lba}")
    print(f"  data_end = {report['data_end_bytes']} B ({report['data_end_bytes'] / 2**30:.2f} GiB)")
    print(f"  holes between pieces = {len(gaps)} totaling {report['gap_total_bytes']} B "
          f"({report['gap_total_bytes'] / 2**20:.3f} MiB)")
    for g in report["gaps"]:
        print(f"    [{g['start_sector']:>10},{g['end_sector']:>10}) "
              f"{g['bytes']:>9} B = {g['mib']:.3f} MiB")
    for s in report["slots"]:
        print(f"\n== metadata slot {s['slot']}: missing data "
              f"{s['total_missing_bytes']} B ({s['total_missing_bytes'] / 2**20:.2f} MiB)")
        for p in s["partitions"]:
            if p["missing_bytes"]:
                print(f"    {p['partition']:<22} {p['missing_bytes']:>12} B "
                      f"({p['missing_bytes'] / 2**20:.3f} MiB) not covered by any segment")


if __name__ == "__main__":
    main()
