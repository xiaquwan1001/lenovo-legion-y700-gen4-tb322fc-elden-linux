#!/usr/bin/env python3
"""android-super.py -- read/inspect Android dynamic-partition ("super") images.

Pure-python implementation of the AOSP liblp metadata format, so it works on
hosts without lpunpack/lpdump.  Field layout follows
system/core/fs_mgr/liblp/include/liblp/metadata_format.h (fetched 2026-11-18):

  offset 0        : LP_PARTITION_RESERVED_BYTES (4096) zero bytes
  offset 4096     : primary LpMetadataGeometry (4096 bytes)
  offset 8192     : backup  LpMetadataGeometry (4096 bytes)
  offset 12288    : primary metadata slot 0..N-1 (metadata_max_size each)
  ...             : backup  metadata slot 0..N-1
  first_logical_sector*512 : logical partition data

Subcommands
  list    <image> [--slot N] [--probe-fs]
  size    <image> [--slot N]
  extract <image> <outdir> [--slot N] [--partition NAME ...] [--sparse]
  assemble --xml <rawprogram*.xml> [--label super] [-o out.img] [--pad-mib N]

Coordinate spaces
  * liblp extents are in 512-byte "sectors" (LP_SECTOR_SIZE).
  * Qualcomm rawprogram XML uses SECTOR_SIZE_IN_BYTES (typically 4096).
"""

from __future__ import annotations

import argparse
import hashlib
import os
import struct
import sys

LP_RESERVED = 4096
LP_GEOM_SIZE = 4096
LP_GEOM_MAGIC = 0x616C4467
LP_HEADER_MAGIC = 0x414C5030
LP_SECTOR = 512
LP_FLAG_VIRTUAL_AB = 0x1
ATTR_READONLY = 1 << 0
ATTR_SLOT_SUFFIXED = 1 << 1
ATTR_UPDATED = 1 << 2
ATTR_DISABLED = 1 << 3
TARGET_LINEAR = 0
TARGET_ZERO = 1

MIB = 1024 * 1024


class LpError(Exception):
    pass


# --------------------------------------------------------------------------- #
# metadata parsing
# --------------------------------------------------------------------------- #
class Geometry:
    fmt = "<II32sIII"  # magic, struct_size, checksum, max_size, slots, block size


def parse_geometry(blob: bytes, where: str) -> dict:
    if len(blob) < 52:
        raise LpError(f"{where}: short geometry")
    magic, struct_size, chk, max_size, slots, lbs = struct.unpack_from(Geometry.fmt, blob, 0)
    if magic != LP_GEOM_MAGIC:
        raise LpError(f"{where}: bad geometry magic 0x{magic:08x}")
    z = bytearray(blob[:struct_size])
    z[8:40] = b"\x00" * 32
    calc = hashlib.sha256(bytes(z)).digest()
    return dict(
        where=where,
        struct_size=struct_size,
        checksum_ok=(calc == chk),
        checksum=chk.hex(),
        metadata_max_size=max_size,
        metadata_slot_count=slots,
        logical_block_size=lbs,
    )


def read_geometry(f, size: int) -> dict:
    """Primary geometry at 4096; backup at 8192.  Both must agree."""
    geoms = []
    for off, where in ((LP_RESERVED, "primary"), (LP_RESERVED + LP_GEOM_SIZE, "backup")):
        f.seek(off)
        b = f.read(LP_GEOM_SIZE)
        if not b:
            raise LpError("image too small for geometry")
        geoms.append(parse_geometry(b, where))
    if not geoms[0]["checksum_ok"] and geoms[1]["checksum_ok"]:
        geoms = [geoms[1], geoms[0]]
    if geoms[0]["metadata_slot_count"] != geoms[1]["metadata_slot_count"]:
        raise LpError("primary/backup geometry disagree on metadata_slot_count")
    return geoms[0]


def primary_meta_offset(geo: dict, slot: int) -> int:
    return LP_RESERVED + 2 * LP_GEOM_SIZE + geo["metadata_max_size"] * slot


def backup_meta_offset(geo: dict, slot: int) -> int:
    return primary_meta_offset(geo, geo["metadata_slot_count"]) + geo["metadata_max_size"] * slot


def total_metadata_size(geo: dict) -> int:
    return LP_RESERVED + (LP_GEOM_SIZE + geo["metadata_max_size"] * geo["metadata_slot_count"]) * 2


def parse_metadata(f, geo: dict, offset: int) -> dict:
    f.seek(offset)
    hdr = f.read(256)
    if len(hdr) < 128:
        raise LpError(f"short metadata header at {offset}")
    magic, major, minor, header_size = struct.unpack_from("<IHHI", hdr, 0)
    if magic != LP_HEADER_MAGIC:
        raise LpError(f"bad metadata magic 0x{magic:08x} at {offset}")
    hdr_chk = hdr[12:44]
    tables_size = struct.unpack_from("<I", hdr, 44)[0]
    tables_chk = hdr[48:80]
    parts_d, ext_d, grp_d, blk_d = (struct.unpack_from("<3I", hdr, 80 + i * 12) for i in range(4))

    raw = bytearray(hdr[:header_size])
    raw[12:44] = b"\x00" * 32
    header_ok = hashlib.sha256(bytes(raw)).digest() == hdr_chk

    f.seek(offset + header_size)
    tables = f.read(tables_size)
    tables_ok = hashlib.sha256(tables).digest() == tables_chk

    def table(desc):
        off, num, esz = desc
        return off, num, esz

    partitions = []
    off, num, esz = table(parts_d)
    for i in range(num):
        name, attr, first_ext, n_ext, group = struct.unpack_from("<36sIIII", tables, off + i * esz)
        partitions.append(
            dict(
                name=name.rstrip(b"\x00").decode("ascii", "replace"),
                attributes=attr,
                first_extent=first_ext,
                num_extents=n_ext,
                group_index=group,
            )
        )

    extents = []
    off, num, esz = table(ext_d)
    for i in range(num):
        nsec, ttype, tdata, tsrc = struct.unpack_from("<QIQI", tables, off + i * esz)
        extents.append(dict(num_sectors=nsec, target_type=ttype, target_data=tdata, target_source=tsrc))

    groups = []
    off, num, esz = table(grp_d)
    for i in range(num):
        name, flags, maxsize = struct.unpack_from("<36sIQ", tables, off + i * esz)
        groups.append(dict(name=name.rstrip(b"\x00").decode("ascii", "replace"), flags=flags, maximum_size=maxsize))

    devices = []
    off, num, esz = table(blk_d)
    for i in range(num):
        first, align, align_off, bsize, pname, dflags = struct.unpack_from("<QIIQ36sI", tables, off + i * esz)
        devices.append(
            dict(
                first_logical_sector=first,
                alignment=align,
                alignment_offset=align_off,
                size=bsize,
                partition_name=pname.rstrip(b"\x00").decode("ascii", "replace"),
                flags=dflags,
            )
        )

    return dict(
        offset=offset,
        major=major,
        minor=minor,
        header_size=header_size,
        header_checksum_ok=header_ok,
        tables_size=tables_size,
        tables_checksum_ok=tables_ok,
        flags=struct.unpack_from("<I", hdr, 128)[0] if header_size >= 132 else 0,
        partitions=partitions,
        extents=extents,
        groups=groups,
        devices=devices,
    )


def load(image: str, slot: int = 0):
    f = open(image, "rb")
    size = os.fstat(f.fileno()).st_size
    geo = read_geometry(f, size)
    meta = None
    errors = []
    for off, kind in ((primary_meta_offset(geo, slot), "primary"), (backup_meta_offset(geo, slot), "backup")):
        if off + 256 > size:
            errors.append(f"{kind} slot {slot}: beyond EOF")
            continue
        try:
            m = parse_metadata(f, geo, off)
        except LpError as exc:
            errors.append(f"{kind} slot {slot}: {exc}")
            continue
        m["kind"] = kind
        if meta is None or not meta["header_checksum_ok"] or not meta["tables_checksum_ok"]:
            meta = m
    if meta is None:
        raise LpError("; ".join(errors) or "no metadata")
    return f, size, geo, meta


# --------------------------------------------------------------------------- #
# derived views
# --------------------------------------------------------------------------- #
def partition_list(meta: dict):
    """Expand extents per partition, with logical and physical offsets."""
    out = []
    for p in meta["partitions"]:
        logical = 0
        rows = []
        for e in meta["extents"][p["first_extent"] : p["first_extent"] + p["num_extents"]]:
            rows.append(
                dict(
                    logical_sector=logical,
                    num_sectors=e["num_sectors"],
                    target_type=e["target_type"],
                    physical_sector=e["target_data"],
                    target_source=e["target_source"],
                )
            )
            logical += e["num_sectors"]
        group = meta["groups"][p["group_index"]]["name"] if p["group_index"] < len(meta["groups"]) else "?"
        out.append(dict(name=p["name"], attributes=p["attributes"], group=group, extents=rows,
                        total_sectors=logical))
    return out


def attr_str(a: int) -> str:
    names = []
    if a & ATTR_READONLY:
        names.append("RO")
    if a & ATTR_SLOT_SUFFIXED:
        names.append("slot")
    if a & ATTR_UPDATED:
        names.append("UPDATED")
    if a & ATTR_DISABLED:
        names.append("DISABLED")
    return ",".join(names) or "-"


def fs_probe(f, byte_off: int) -> str:
    """Detect ext4 / f2fs / erofs from a filesystem superblock at byte_off."""
    results = []
    f.seek(byte_off + 1024)
    sb = f.read(4096 - 1024)
    if len(sb) >= 64 and sb[0x38:0x3A] == b"\x53\xef":
        label = ""
        if len(sb) >= 0x78 + 16:
            label = sb[0x78 : 0x78 + 16].rstrip(b"\x00").decode("utf-8", "replace")
        blocks_lo = struct.unpack_from("<I", sb, 0x04)[0]
        log_bs = struct.unpack_from("<I", sb, 0x18)[0]
        results.append(f"ext4(label={label!r},blocks={blocks_lo},log_block_size={log_bs})")
    if sb[0:4] == b"\x10\x20\xf5\xf2":
        results.append("f2fs")
    if sb[0:4] == b"\xe2\xe1\xf5\xe0":
        results.append("erofs")
    return ";".join(results) or "?"


def show_list(args):
    image = args.image
    f, size, geo, meta = load(image, args.slot)
    print(f"image      : {image}  ({size} bytes = {size / MIB:.2f} MiB)")
    print(f"geometry   : mag=0x{LP_GEOM_MAGIC:08x} struct_size={geo['struct_size']} "
          f"checksum={'OK' if geo['checksum_ok'] else 'BAD'} max_size={geo['metadata_max_size']} "
          f"slots={geo['metadata_slot_count']} logical_block_size={geo['logical_block_size']}")
    print(f"metadata   : {meta['kind']} slot={args.slot} off={meta['offset']} v{meta['major']}.{meta['minor']} "
          f"header={meta['header_size']} tables={meta['tables_size']} flags=0x{meta['flags']:x} "
          f"hdr_chk={'OK' if meta['header_checksum_ok'] else 'BAD'} "
          f"tbl_chk={'OK' if meta['tables_checksum_ok'] else 'BAD'}")
    print(f"reserved   : total_metadata_size={total_metadata_size(geo)} "
          f"(first data byte)")
    for d in meta["devices"]:
        print(f"blockdev   : name={d['partition_name']} first_logical_sector={d['first_logical_sector']} "
              f"({d['first_logical_sector'] * LP_SECTOR / MIB:.2f} MiB) alignment={d['alignment']} "
              f"alignment_offset={d['alignment_offset']} size={d['size']} ({d['size'] / MIB:.2f} MiB) "
              f"flags={d['flags']}")
    for g in meta["groups"]:
        print(f"group      : {g['name']:<28} max_size={g['maximum_size']} "
              f"({g['maximum_size'] / MIB:.2f} MiB) flags={g['flags']}")
    print()
    parts = partition_list(meta)
    print(f"{'partition':<22} {'attr':<12} {'group':<26} {'size MiB':>10} {'ext':>4}  fs")
    total = 0
    for p in parts:
        total += p["total_sectors"]
        fs = ""
        if args.probe_fs and p["extents"]:
            first = next((e for e in p["extents"] if e["target_type"] == TARGET_LINEAR), None)
            if first:
                fs = fs_probe(f, first["physical_sector"] * LP_SECTOR)
        print(f"{p['name']:<22} {attr_str(p['attributes']):<12} {p['group']:<26} "
              f"{p['total_sectors'] * LP_SECTOR / MIB:>10.2f} {len(p['extents']):>4}  {fs}")
    print(f"\n{'TOTAL':<22} {'':<12} {'':<26} {total * LP_SECTOR / MIB:>10.2f}")
    print("\nextents:")
    for p in parts:
        print(f"  {p['name']}:")
        for e in p["extents"]:
            kind = {TARGET_LINEAR: "linear", TARGET_ZERO: "zero"}.get(e["target_type"], f"t{e['target_type']}")
            print(f"    logical {e['logical_sector']:>10} +{e['num_sectors']:<10} "
                  f"{kind:<7} phys_sector={e['physical_sector']:<12} "
                  f"byte_off={e['physical_sector'] * LP_SECTOR} src={e['target_source']}")
    f.close()


def show_size(args):
    image = args.image
    f, size, geo, meta = load(image, args.slot)
    parts = partition_list(meta)
    groups: dict[str, int] = {}
    for p in parts:
        groups[p["group"]] = groups.get(p["group"], 0) + p["total_sectors"]
    total = sum(p["total_sectors"] for p in parts)
    meta_bytes = total_metadata_size(geo)
    max_end = 0
    for p in parts:
        for e in p["extents"]:
            if e["target_type"] == TARGET_LINEAR:
                max_end = max(max_end, (e["physical_sector"] + e["num_sectors"]) * LP_SECTOR)
    print(f"image_size_bytes          {size}")
    print(f"metadata_reserved_bytes   {meta_bytes} ({meta_bytes / MIB:.2f} MiB)")
    print(f"first_logical_sector      {meta['devices'][0]['first_logical_sector']} "
          f"({meta['devices'][0]['first_logical_sector'] * LP_SECTOR} bytes)")
    print(f"sum_partition_bytes       {total * LP_SECTOR} ({total * LP_SECTOR / MIB:.2f} MiB = {total} lp sectors)")
    print(f"max_extent_end_bytes      {max_end} ({max_end / MIB:.2f} MiB)")
    print(f"needed_bytes_if_compact   {max(meta_bytes, 0) + total * LP_SECTOR} "
          f"({(meta_bytes + total * LP_SECTOR) / MIB:.2f} MiB, metadata+data)"
          "  [only valid if extents are re-packed, i.e. lpmake]")
    print(f"needed_bytes_in_place     {max(meta_bytes, max_end)} ({max(meta_bytes, max_end) / MIB:.2f} MiB)")
    print()
    print(f"{'group':<28} {'used MiB':>10} {'max MiB':>10}  usage")
    for g in meta["groups"]:
        used = groups.get(g["name"], 0) * LP_SECTOR
        cap = g["maximum_size"]
        pct = f"{used / cap * 100:.1f}%" if cap else "-"
        print(f"{g['name']:<28} {used / MIB:>10.2f} {cap / MIB:>10.2f}  {pct}")
    print()
    print(f"{'partition':<22} {'bytes':>14} {'MiB':>10}  canonical_size_hint")
    for p in sorted(parts, key=lambda x: -x["total_sectors"]):
        n = p["total_sectors"] * LP_SECTOR
        hint = ""
        for unit, label in ((MIB, "MiB"), (1024, "KiB")):
            if n % unit == 0:
                hint = f"{n // unit} {label}"
                break
        print(f"{p['name']:<22} {n:>14} {n / MIB:>10.2f}  {hint}")
    f.close()


def cmd_extract(image: str, outdir: str, args):
    f, size, geo, meta = load(image, args.slot)
    parts = partition_list(meta)
    if args.partition:
        wanted = set(args.partition)
        parts = [p for p in parts if p["name"] in wanted]
        missing = wanted - {p["name"] for p in parts}
        if missing:
            raise LpError(f"no such partition(s): {', '.join(sorted(missing))}")
    os.makedirs(outdir, exist_ok=True)
    for p in parts:
        path = os.path.join(outdir, p["name"] + ".img")
        nbytes = p["total_sectors"] * LP_SECTOR
        print(f"extracting {p['name']:<22} {nbytes:>14} B -> {path}"
              + (" (sparse)" if args.sparse else ""))
        out = open(path, "wb")
        if args.sparse:
            out.truncate(nbytes)
        written = 0
        for e in p["extents"]:
            n = e["num_sectors"] * LP_SECTOR
            if e["target_type"] == TARGET_LINEAR:
                f.seek(e["physical_sector"] * LP_SECTOR)
                remaining = n
                while remaining:
                    chunk = f.read(min(remaining, 8 * MIB))
                    if not chunk:
                        chunk = b"\x00" * min(remaining, 8 * MIB)
                    if args.sparse:
                        out.seek(written)
                    out.write(chunk)
                    remaining -= len(chunk)
                    written += len(chunk)
            elif e["target_type"] == TARGET_ZERO:
                if args.sparse:
                    out.seek(written)
                if not args.sparse:
                    remaining = n
                    while remaining:
                        chunk = b"\x00" * min(remaining, 8 * MIB)
                        out.write(chunk)
                        remaining -= len(chunk)
                written += n
            else:
                out.close()
                raise LpError(f"{p['name']}: unsupported target type {e['target_type']}")
        out.truncate(nbytes if args.sparse else written)
        out.close()
    f.close()


# --------------------------------------------------------------------------- #
# assemble from a Qualcomm rawprogram XML
# --------------------------------------------------------------------------- #
def cmd_assemble(args):
    import xml.etree.ElementTree as ET

    tree = ET.parse(args.xml)
    base = os.path.dirname(os.path.abspath(args.xml))
    entries = []
    for prog in tree.getroot().iter("program"):
        if prog.get("label") != args.label:
            continue
        fn = prog.get("filename") or ""
        if not fn:
            continue
        lba = int(prog.get("start_sector"))
        nsect = int(prog.get("num_partition_sectors"))
        ssz = int(prog.get("SECTOR_SIZE_IN_BYTES", "512"))
        pnum = prog.get("physical_partition_number")
        entries.append((lba, nsect, ssz, fn, pnum))
    if not entries:
        raise LpError(f'no <program label="{args.label}"> with a filename in {args.xml}')
    entries.sort()
    pnums = {e[4] for e in entries}
    if len(pnums) != 1:
        raise LpError(f"label {args.label} spans several physical partitions {pnums}")
    base_lba = args.base_lba if args.base_lba is not None else entries[0][0]
    end = max(e[0] + e[1] for e in entries) - base_lba
    total_bytes = end * entries[0][2]
    if args.pad_mib:
        total_bytes = max(total_bytes, args.pad_mib * MIB)
    print(f"assembling {len(entries)} segment(s) for label '{args.label}' from {args.xml}")
    print(f"  physical_partition_number={entries[0][4]} base_lba={base_lba} "
          f"output_size={total_bytes} ({total_bytes / MIB:.2f} MiB)")
    out = open(args.output, "wb")
    out.truncate(total_bytes)
    for lba, nsect, ssz, fn, _ in entries:
        rel = (lba - base_lba) * ssz
        path = fn if os.path.isabs(fn) else os.path.join(base, fn)
        nbytes = nsect * ssz
        print(f"  + {os.path.basename(fn):<18} lba {lba:>9} rel_byte {rel:>12} {nbytes:>12} B")
        out.seek(rel)
        remaining = nbytes
        with open(path, "rb") as src:
            while remaining:
                chunk = src.read(min(remaining, 8 * MIB))
                if not chunk:
                    break
                out.write(chunk)
                remaining -= len(chunk)
        if remaining:
            print(f"    WARNING: {path} short by {remaining} bytes (zero filled)")
            out.seek(rel + nbytes)
    out.truncate(total_bytes)
    out.close()
    if args.pad_to_device:
        # A logical-partition image must be at least as large as the block device
        # recorded in its own metadata; otherwise extents referenced near the tail
        # (e.g. -cow volumes) read past EOF.  Holes cost no disk space.
        try:
            with open(args.output, "rb") as fh:
                geo = read_geometry(fh, os.fstat(fh.fileno()).st_size)
                meta = parse_metadata(fh, geo, primary_meta_offset(geo, 0))
            dev_size = meta["devices"][0]["size"]
            if dev_size > total_bytes:
                with open(args.output, "r+b") as fh:
                    fh.truncate(dev_size)
                print(f"  padded to block-device size {dev_size} ({dev_size / MIB:.2f} MiB)")
            else:
                print(f"  block-device size {dev_size} <= data end {total_bytes}, no padding")
        except LpError as exc:
            print(f"  WARNING: --pad-to-device skipped: {exc}")
    print(f"wrote {args.output}")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    def common(p):
        p.add_argument("--slot", type=int, default=0, help="metadata slot (default 0)")

    p = sub.add_parser("list")
    p.add_argument("image")
    common(p)
    p.add_argument("--probe-fs", action="store_true", help="probe filesystem magic at each partition start")
    p.set_defaults(func=show_list)

    p = sub.add_parser("size")
    p.add_argument("image")
    common(p)
    p.set_defaults(func=show_size)

    p = sub.add_parser("extract")
    p.add_argument("image")
    p.add_argument("outdir")
    common(p)
    p.add_argument("--partition", action="append", help="only these partitions (repeatable)")
    p.add_argument("--sparse", action="store_true", help="preserve holes via seek")
    p.set_defaults(func=cmd_extract)

    p = sub.add_parser("assemble")
    p.add_argument("--xml", required=True)
    p.add_argument("--label", default="super")
    p.add_argument("-o", "--output", required=True)
    p.add_argument("--base-lba", type=int, default=None,
                   help="LBA that becomes offset 0 of the output (default: first segment)")
    p.add_argument("--pad-mib", type=int, default=0)
    p.add_argument("--pad-to-device", action="store_true",
                   help="pad output to block_devices[0].size taken from the metadata")
    p.set_defaults(func=cmd_assemble)

    args = ap.parse_args(argv)
    try:
        if args.cmd == "extract":
            args.func(args.image, args.outdir, args)
        else:
            args.func(args)
    except LpError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
