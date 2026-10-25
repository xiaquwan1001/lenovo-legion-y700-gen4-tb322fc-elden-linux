#!/usr/bin/env python3
"""gpt-surgery-tb322fc.py — shrink `userdata` and append partition(s) on the
TB322FC (Y700 Gen4) LUN0 GPT, safely (4 KiB sectors).

Background / recipe: pi skill `qualcomm-edl-flashing/references/gpt-surgery.md`
and `qualcomm-android-flashing/references/tb322fc-dualboot-2026-09.md`.

The device GPT uses 4096-byte logical sectors (sgdisk/gdisk assume 512 and
misread it — edit entries in Python). Layout on this device:
  LBA 0            protective MBR
  LBA 1            primary GPT header
  LBA 2..33        primary entries (32 x 128 B)
  ...
  last_usable      (61390842 here)
  LBA 61390843     backup entries
  LBA 61390847     backup header

Usage:
  # inspect
  python3 gpt-surgery.py list  --main gpt_main0.bin --backup gpt_backup0.bin
  # produce new images (does NOT write anything)
  python3 gpt-surgery.py build --main ... --backup ... --out-prefix new \
        --linux-gib 65 --linux-name linux
Then write on the device (root), e.g.:
  dd if=new_main0.bin   of=/dev/sda bs=4096 seek=0          conv=notrunc
  dd if=new_backup0.bin of=/dev/sda bs=4096 seek=61390843   conv=notrunc
  partprobe /dev/sda
(EDL alternative: `edl-ng write-sector 0 new_main0.bin -u 0` etc.)

VERIFY after writing: `list` the device dump again, and check `/dev/sdaN` sizes.
"""
import argparse
import binascii
import os
import struct
import sys
import uuid

SECTOR = 4096
LINUX_FS_GUID = uuid.UUID("0fc63daf-8483-4772-8e79-3d69d8477de4")  # Linux filesystem
EFI_SYS_GUID = uuid.UUID("c12a7328-f81f-11d2-ba4b-00a0c93ec93b")    # EFI System (FAT)


def le_guid(b: bytes) -> uuid.UUID:
    return uuid.UUID(bytes_le=bytes(b))


def guid_le(u: uuid.UUID) -> bytes:
    return u.bytes_le


def parse_header(buf: bytes, offset: int):
    h = buf[offset:offset + 92]
    if h[0:8] != b"EFI PART":
        raise ValueError(f"no GPT header at offset {offset}")
    return {
        "raw": bytearray(h),
        "hdr_size": struct.unpack_from("<I", h, 12)[0],
        "hdr_crc": struct.unpack_from("<I", h, 16)[0],
        "cur_lba": struct.unpack_from("<Q", h, 24)[0],
        "backup_lba": struct.unpack_from("<Q", h, 32)[0],
        "first_usable": struct.unpack_from("<Q", h, 40)[0],
        "last_usable": struct.unpack_from("<Q", h, 48)[0],
        "disk_guid": h[56:72],
        "ent_lba": struct.unpack_from("<Q", h, 72)[0],
        "nents": struct.unpack_from("<I", h, 80)[0],
        "entsz": struct.unpack_from("<I", h, 84)[0],
        "entries_crc": struct.unpack_from("<I", h, 88)[0],
    }


def check_header_crc(hdr: dict) -> bool:
    h = bytearray(hdr["raw"])
    stored = struct.unpack_from("<I", h, 16)[0]
    struct.pack_into("<I", h, 16, 0)
    calc = binascii.crc32(bytes(h[: hdr["hdr_size"]])) & 0xFFFFFFFF
    return stored == calc


def parse_entries(buf: bytes, ent_lba: int, nents: int, entsz: int):
    base = ent_lba * SECTOR
    out = []
    for i in range(nents):
        e = buf[base + i * entsz: base + (i + 1) * entsz]
        tguid = le_guid(e[0:16])
        if tguid.int == 0:
            out.append(None)
            continue
        name = e[56:128].decode("utf-16-le").split("\x00")[0]
        out.append({
            "idx": i,
            "type": tguid,
            "part_guid": le_guid(e[16:32]),
            "first": struct.unpack_from("<Q", e, 32)[0],
            "last": struct.unpack_from("<Q", e, 40)[0],
            "flags": struct.unpack_from("<Q", e, 48)[0],
            "name": name,
            "raw": bytes(e),
        })
    return out


def make_entry(idx, type_guid, part_guid, first, last, name, flags=0):
    e = bytearray(128)
    e[0:16] = guid_le(type_guid)
    e[16:32] = guid_le(part_guid)
    struct.pack_into("<Q", e, 32, first)
    struct.pack_into("<Q", e, 40, last)
    struct.pack_into("<Q", e, 48, flags)
    nm = name.encode("utf-16-le")
    e[56:56 + len(nm)] = nm
    return bytes(e)


def build_primary_header(cur, backup, first_usable, last_usable, disk_guid,
                         ent_lba, nents, entsz, entries_crc):
    """92-byte header; hdr_crc computed LAST (entries_crc already set)."""
    h = bytearray(92)
    h[0:8] = b"EFI PART"
    struct.pack_into("<I", h, 8, 0x00010000)
    struct.pack_into("<I", h, 12, 92)
    struct.pack_into("<I", h, 16, 0)          # crc placeholder
    struct.pack_into("<I", h, 20, 0)
    struct.pack_into("<Q", h, 24, cur)
    struct.pack_into("<Q", h, 32, backup)
    struct.pack_into("<Q", h, 40, first_usable)
    struct.pack_into("<Q", h, 48, last_usable)
    h[56:72] = disk_guid
    struct.pack_into("<Q", h, 72, ent_lba)
    struct.pack_into("<I", h, 80, nents)
    struct.pack_into("<I", h, 84, entsz)
    struct.pack_into("<I", h, 88, entries_crc)
    crc = binascii.crc32(bytes(h)) & 0xFFFFFFFF
    struct.pack_into("<I", h, 16, crc)
    return bytes(h)


def cmd_list(a):
    main = open(a.main, "rb").read()
    hdr = parse_header(main, SECTOR)
    ents = parse_entries(main, hdr["ent_lba"], hdr["nents"], hdr["entsz"])
    print(f"main: hdr_ok={check_header_crc(hdr)} cur={hdr['cur_lba']} "
          f"backup={hdr['backup_lba']} first_usable={hdr['first_usable']} "
          f"last_usable={hdr['last_usable']} ent_lba={hdr['ent_lba']} "
          f"nents={hdr['nents']} entsz={hdr['entsz']}")
    entries_block = main[hdr["ent_lba"] * SECTOR:
                         hdr["ent_lba"] * SECTOR + hdr["nents"] * hdr["entsz"]]
    print(f"entries_crc stored={hdr['entries_crc']:#010x} "
          f"calc={binascii.crc32(entries_block) & 0xFFFFFFFF:#010x}")
    for e in ents:
        if e is None:
            continue
        print(f"  [{e['idx']:2d}] {e['name']:20s} first={e['first']:<10d} "
              f"last={e['last']:<10d} sectors={e['last']-e['first']+1:<10d} "
              f"({(e['last']-e['first']+1)*SECTOR/2**30:.1f} GiB) flags={e['flags']:#x}")
    free = [i for i, e in enumerate(ents) if e is None]
    print(f"  free slots: {free}")


def cmd_build(a):
    main = bytearray(open(a.main, "rb").read())
    backup = bytearray(open(a.backup, "rb").read())
    hdr = parse_header(main, SECTOR)
    b_hdr = parse_header(backup, 4 * SECTOR)
    assert check_header_crc(hdr), "primary header CRC invalid"
    assert b_hdr["ent_lba"] == b_hdr["cur_lba"] - 4, "backup layout unexpected"
    # validate stored entries CRC on both sides
    pblock = main[hdr["ent_lba"] * SECTOR: hdr["ent_lba"] * SECTOR + hdr["nents"] * hdr["entsz"]]
    bblock = backup[0: b_hdr["nents"] * b_hdr["entsz"]]
    assert binascii.crc32(pblock) & 0xFFFFFFFF == hdr["entries_crc"], "primary entries CRC mismatch"
    assert binascii.crc32(bblock) & 0xFFFFFFFF == b_hdr["entries_crc"], "backup entries CRC mismatch"

    ents = parse_entries(main, hdr["ent_lba"], hdr["nents"], hdr["entsz"])
    first_usable, last_usable = hdr["first_usable"], hdr["last_usable"]
    free_slot = next(i for i, e in enumerate(ents) if e is None)  # pick BEFORE edits

    # -- shrink userdata --
    ud = next(e for e in ents if e["name"] == "userdata")
    new_ud_last = last_usable - a.linux_gib * (2**30) // SECTOR
    assert new_ud_last > ud["first"], "shrink target smaller than existing data"
    print(f"userdata: {ud['first']}..{ud['last']} -> {ud['first']}..{new_ud_last} "
          f"({(new_ud_last-ud['first']+1)*SECTOR/2**30:.1f} GiB)")
    new_ud = make_entry(ud["idx"], ud["type"], ud["part_guid"], ud["first"], new_ud_last,
                        ud["name"], ud["flags"])
    ents[ud["idx"]] = None  # rebuilt below

    # -- add linux partition at the tail --
    lin_first = new_ud_last + 1
    lin_last = last_usable
    print(f"linux   : slot {free_slot} {lin_first}..{lin_last} "
          f"({(lin_last-lin_first+1)*SECTOR/2**30:.1f} GiB) name='{a.linux_name}'")
    lin = make_entry(free_slot, LINUX_FS_GUID, uuid.uuid4(), lin_first, lin_last, a.linux_name)

    # rebuild entries block
    new_block = bytearray()
    for i in range(hdr["nents"]):
        e = ents[i]
        if e is not None:
            new_block += e["raw"]
        elif i == ud["idx"]:
            new_block += new_ud
        elif i == free_slot:
            new_block += lin
        else:
            new_block += bytes(hdr["entsz"])
    assert len(new_block) == hdr["nents"] * hdr["entsz"]
    entries_crc = binascii.crc32(bytes(new_block)) & 0xFFFFFFFF

    # write primary
    out_main = bytearray(main)
    out_main[hdr["ent_lba"] * SECTOR: hdr["ent_lba"] * SECTOR + len(new_block)] = new_block
    p_new = build_primary_header(1, hdr["backup_lba"], first_usable, last_usable,
                                 hdr["disk_guid"], hdr["ent_lba"], hdr["nents"],
                                 hdr["entsz"], entries_crc)
    out_main[SECTOR:SECTOR + 92] = p_new

    # write backup entries + header
    out_backup = bytearray(backup)
    out_backup[0:len(new_block)] = new_block
    b_cur = b_hdr["cur_lba"]
    b_new = build_primary_header(b_cur, 1, first_usable, last_usable, hdr["disk_guid"],
                                 b_hdr["ent_lba"], b_hdr["nents"], b_hdr["entsz"], entries_crc)
    off = 4 * SECTOR
    out_backup[off:off + 92] = b_new

    open(a.out_prefix + "_main0.bin", "wb").write(out_main)
    open(a.out_prefix + "_backup0.bin", "wb").write(out_backup)
    print(f"wrote {a.out_prefix}_main0.bin ({len(out_main)} B), "
          f"{a.out_prefix}_backup0.bin ({len(out_backup)} B)")
    print(f"new entries_crc={entries_crc:#010x}  primary hdr_crc="
          f"{struct.unpack_from('<I', out_main, SECTOR+16)[0]:#010x}  "
          f"backup hdr_crc={struct.unpack_from('<I', out_backup, off+16)[0]:#010x}")

    # self-verify
    v = parse_header(bytes(out_main), SECTOR)
    assert check_header_crc(v), "new primary header CRC invalid"
    vb = parse_header(bytes(out_backup), off)
    assert check_header_crc(vb), "new backup header CRC invalid"
    print("self-check: both headers CRC OK")



def cmd_shrink_append(a):
    """缩尾部已有分区（默认 linux17）并在腾出的尾部追加一个新分区（默认 linux18）。

    与 cmd_build 的区别：build 是「缩 userdata + 尾部新建」（userdata 不在尾部）；
    本模式针对「目标分区本身就是最后一个分区」的场景（linux17.last == last_usable），
    因此腾出的空间紧跟在它后面，新分区边界 = [new_last+1 .. last_usable]。
    不改 first_usable/last_usable ⇒ 备份表位置不变，只需重写 LBA0..5 与备份表。
    """
    main = bytearray(open(a.main, "rb").read())
    backup = bytearray(open(a.backup, "rb").read())
    hdr = parse_header(main, SECTOR)
    b_hdr = parse_header(backup, 4 * SECTOR)
    assert check_header_crc(hdr), "primary header CRC invalid"
    assert check_header_crc(b_hdr), "backup header CRC invalid"
    pblock = main[hdr["ent_lba"] * SECTOR: hdr["ent_lba"] * SECTOR + hdr["nents"] * hdr["entsz"]]
    assert binascii.crc32(pblock) & 0xFFFFFFFF == hdr["entries_crc"], "primary entries CRC mismatch"
    assert binascii.crc32(backup[0: b_hdr["nents"] * b_hdr["entsz"]]) & 0xFFFFFFFF == b_hdr["entries_crc"], \
        "backup entries CRC mismatch"

    ents = parse_entries(main, hdr["ent_lba"], hdr["nents"], hdr["entsz"])
    first_usable, last_usable = hdr["first_usable"], hdr["last_usable"]
    free_slot = next(i for i, e in enumerate(ents) if e is None)

    tgt = next((e for e in ents if e["name"] == a.shrink_name), None)
    assert tgt, f"找不到分区 {a.shrink_name!r}"
    others = [e for e in ents if e is not None and e is not tgt]
    assert all(e["last"] < tgt["first"] for e in others), \
        f"{a.shrink_name} 不是最后一个分区（后面还有分区），本模式不适用"
    assert tgt["last"] == last_usable, \
        f"{a.shrink_name}.last({tgt['last']}) != last_usable({last_usable})；尾部已有空隙，请用 build"

    keep_sectors = a.keep_gib * (2**30) // SECTOR
    new_last = tgt["first"] + keep_sectors - 1
    assert new_last < tgt["last"], "keep_gib 比现有分区还大"
    # 腾出空间必须能装下新分区
    new_sectors = last_usable - new_last
    assert new_sectors * SECTOR >= a.new_gib * (2**30), "尾部空间不足 new_gib"

    print(f"{a.shrink_name}: {tgt['first']}..{tgt['last']} "
          f"({(tgt['last']-tgt['first']+1)*SECTOR/2**30:.1f} GiB)"
          f" -> ..{new_last} ({keep_sectors*SECTOR/2**30:.1f} GiB)")
    kept = make_entry(tgt["idx"], tgt["type"], tgt["part_guid"], tgt["first"], new_last,
                      tgt["name"], tgt["flags"])

    lin_first = new_last + 1
    lin_last = lin_first + a.new_gib * (2**30) // SECTOR - 1
    assert lin_last <= last_usable
    print(f"{a.new_name}: slot {free_slot} {lin_first}..{lin_last} "
          f"({(lin_last-lin_first+1)*SECTOR/2**30:.1f} GiB) 尾部余量 "
          f"{(last_usable-lin_last)*SECTOR//2**20} MiB")
    newp = make_entry(free_slot, LINUX_FS_GUID, uuid.uuid4(), lin_first, lin_last, a.new_name)

    new_block = bytearray()
    for i in range(hdr["nents"]):
        e = ents[i]
        if i == tgt["idx"]:
            new_block += kept
        elif i == free_slot:
            new_block += newp
        elif e is not None:
            new_block += e["raw"]
        else:
            new_block += bytes(hdr["entsz"])
    assert len(new_block) == hdr["nents"] * hdr["entsz"]
    entries_crc = binascii.crc32(bytes(new_block)) & 0xFFFFFFFF

    out_main = bytearray(main)
    out_main[hdr["ent_lba"] * SECTOR: hdr["ent_lba"] * SECTOR + len(new_block)] = new_block
    out_main[SECTOR:SECTOR + 92] = build_primary_header(
        1, hdr["backup_lba"], first_usable, last_usable, hdr["disk_guid"],
        hdr["ent_lba"], hdr["nents"], hdr["entsz"], entries_crc)
    out_backup = bytearray(backup)
    out_backup[0:len(new_block)] = new_block
    off = 4 * SECTOR
    out_backup[off:off + 92] = build_primary_header(
        b_hdr["cur_lba"], 1, first_usable, last_usable, hdr["disk_guid"],
        b_hdr["ent_lba"], b_hdr["nents"], b_hdr["entsz"], entries_crc)

    open(a.out_prefix + "_main0.bin", "wb").write(out_main)
    open(a.out_prefix + "_backup0.bin", "wb").write(out_backup)
    v = parse_header(bytes(out_main), SECTOR); assert check_header_crc(v)
    vb = parse_header(bytes(out_backup), off); assert check_header_crc(vb)
    print(f"wrote {a.out_prefix}_{{main0,backup0}}.bin  entries_crc={entries_crc:#010x}")
    print("self-check: both headers CRC OK")


def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)
    l = sub.add_parser("list"); l.add_argument("--main", required=True); l.add_argument("--backup"); l.set_defaults(f=cmd_list)
    b = sub.add_parser("build")
    b.add_argument("--main", required=True); b.add_argument("--backup", required=True)
    b.add_argument("--out-prefix", required=True)
    b.add_argument("--linux-gib", type=int, default=65)
    b.add_argument("--linux-name", default="linux")
    sa = sub.add_parser("shrink-append", help="缩最后一个分区并在尾部追加新分区")
    sa.add_argument("--main", required=True); sa.add_argument("--backup", required=True)
    sa.add_argument("--out-prefix", required=True)
    sa.add_argument("--shrink-name", default="linux17")
    sa.add_argument("--new-name", default="linux18")
    sa.add_argument("--keep-gib", type=int, required=True, help="缩后保留 GiB（含分区开销）")
    sa.add_argument("--new-gib", type=int, required=True, help="新分区 GiB")
    sa.set_defaults(f=cmd_shrink_append)
    b.set_defaults(f=cmd_build)
    a = p.parse_args()
    a.f(a)


if __name__ == "__main__":
    main()
