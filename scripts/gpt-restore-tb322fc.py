#!/usr/bin/env python3
"""gpt-restore-tb322fc.py — REVERSE the dual-boot GPT surgery on TB322FC LUN0:
grow `userdata` back to `last_usable` and delete the `linux` partition.
4 KiB sectors. Does NOT write to the device — produces images for `dd`.

Usage:
  python3 gpt-restore-tb322fc.py build \
      --main env-pass/gpt-20261002/gpt_primary.bin \
      --backup env-pass/gpt-20261002/gpt_backup.bin \
      --out-prefix env-pass/gpt-20261002/restore
Then on device (root):
  dd if=/sdcard/restore_main0.bin   of=/dev/block/sda bs=4096 seek=0          conv=notrunc
  dd if=/sdcard/restore_backup0.bin of=/dev/block/sda bs=4096 seek=<backup_start_lba> conv=notrunc
  sync
Reboot. Android resizes /data (f2fs) at boot.
"""
import argparse, binascii, struct, sys, uuid

SECTOR = 4096

def le_guid(b): return uuid.UUID(bytes_le=bytes(b))
def guid_le(u): return u.bytes_le

def parse_header(buf, offset):
    h = buf[offset:offset+92]
    if h[0:8] != b"EFI PART":
        raise ValueError(f"no GPT header at {offset}")
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

def check_header_crc(hdr):
    h = bytearray(hdr["raw"]); stored = struct.unpack_from("<I", h, 16)[0]
    struct.pack_into("<I", h, 16, 0)
    calc = binascii.crc32(bytes(h[:hdr["hdr_size"]])) & 0xFFFFFFFF
    return stored == calc

def parse_entries(buf, ent_lba, nents, entsz, base=None):
    if base is None:
        base = ent_lba * SECTOR
    out = []
    for i in range(nents):
        e = buf[base + i*entsz: base + (i+1)*entsz]
        if le_guid(e[0:16]).int == 0:
            out.append(None); continue
        out.append({
            "idx": i, "type": le_guid(e[0:16]), "part_guid": le_guid(e[16:32]),
            "first": struct.unpack_from("<Q", e, 32)[0],
            "last": struct.unpack_from("<Q", e, 40)[0],
            "flags": struct.unpack_from("<Q", e, 48)[0],
            "name": e[56:128].decode("utf-16-le").split("\x00")[0],
            "raw": bytes(e),
        })
    return out

def build_header(cur, backup, first_usable, last_usable, disk_guid, ent_lba, nents, entsz, entries_crc):
    h = bytearray(92)
    h[0:8] = b"EFI PART"
    struct.pack_into("<I", h, 8, 0x00010000)
    struct.pack_into("<I", h, 12, 92)
    struct.pack_into("<I", h, 16, 0)
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
    struct.pack_into("<I", h, 16, binascii.crc32(bytes(h)) & 0xFFFFFFFF)
    return bytes(h)

def cmd_build(a):
    main = bytearray(open(a.main, "rb").read())
    backup = bytearray(open(a.backup, "rb").read())
    hdr = parse_header(main, SECTOR)
    # backup image = 34 sectors starting at backup_start_lba; header at offset (backup_lba - start)
    b_start = a.backup_start_lba
    b_off = (hdr["backup_lba"] - b_start) * SECTOR
    b_hdr = parse_header(backup, b_off)
    assert check_header_crc(hdr), "primary header CRC invalid"
    assert check_header_crc(b_hdr), "backup header CRC invalid"

    pblock = main[hdr["ent_lba"]*SECTOR: hdr["ent_lba"]*SECTOR + hdr["nents"]*hdr["entsz"]]
    assert (binascii.crc32(pblock) & 0xFFFFFFFF) == hdr["entries_crc"], "primary entries CRC mismatch"
    bblock = backup[(b_hdr["ent_lba"]-b_start)*SECTOR: (b_hdr["ent_lba"]-b_start)*SECTOR + b_hdr["nents"]*b_hdr["entsz"]]
    assert (binascii.crc32(bblock) & 0xFFFFFFFF) == b_hdr["entries_crc"], "backup entries CRC mismatch"

    ents = parse_entries(main, hdr["ent_lba"], hdr["nents"], hdr["entsz"])
    first_usable, last_usable = hdr["first_usable"], hdr["last_usable"]

    ud = next(e for e in ents if e and e["name"] == "userdata")
    lin = next((e for e in ents if e and e["name"] == a.linux_name), None)
    assert lin is not None, "linux partition not found"
    assert lin["last"] == last_usable, f"linux not last partition ({lin['last']} != {last_usable})"

    print(f"userdata: {ud['first']}..{ud['last']} ({(ud['last']-ud['first']+1)*SECTOR/2**30:.1f} GiB)")
    print(f"linux   : idx {lin['idx']} {lin['first']}..{lin['last']} -> REMOVED")
    print(f"new userdata last = {last_usable} ({(last_usable-ud['first']+1)*SECTOR/2**30:.1f} GiB)")

    # rebuild entries: grow userdata, drop linux
    new_block = bytearray()
    for i in range(hdr["nents"]):
        e = ents[i]
        if i == ud["idx"]:
            b = bytearray(e["raw"])
            struct.pack_into("<Q", b, 40, last_usable)   # last_lba
            new_block += b
        elif e is None:
            new_block += bytes(hdr["entsz"])
        elif i == lin["idx"]:
            new_block += bytes(hdr["entsz"])             # free the slot
        else:
            new_block += e["raw"]
    assert len(new_block) == hdr["nents"]*hdr["entsz"]
    entries_crc = binascii.crc32(bytes(new_block)) & 0xFFFFFFFF

    out_main = bytearray(main)
    out_main[hdr["ent_lba"]*SECTOR: hdr["ent_lba"]*SECTOR+len(new_block)] = new_block
    out_main[SECTOR:SECTOR+92] = build_header(1, hdr["backup_lba"], first_usable, last_usable,
                                              hdr["disk_guid"], hdr["ent_lba"], hdr["nents"], hdr["entsz"], entries_crc)
    out_backup = bytearray(backup)
    off_e = (b_hdr["ent_lba"]-b_start)*SECTOR
    out_backup[off_e:off_e+len(new_block)] = new_block
    out_backup[b_off:b_off+92] = build_header(b_hdr["cur_lba"], 1, first_usable, last_usable,
                                              hdr["disk_guid"], b_hdr["ent_lba"], b_hdr["nents"], b_hdr["entsz"], entries_crc)

    open(a.out_prefix+"_main0.bin", "wb").write(out_main)
    open(a.out_prefix+"_backup0.bin", "wb").write(out_backup)
    print(f"wrote {a.out_prefix}_main0.bin ({len(out_main)} B), {a.out_prefix}_backup0.bin ({len(out_backup)} B)")
    print(f"entries_crc={entries_crc:#010x}")
    # self-verify
    v = parse_header(bytes(out_main), SECTOR); assert check_header_crc(v)
    vb = parse_header(bytes(out_backup), b_off); assert check_header_crc(vb)
    print("self-check OK; backup write offset (4096 sectors) =", b_start)

def cmd_list(a):
    main = open(a.main, "rb").read()
    hdr = parse_header(main, SECTOR)
    for e in parse_entries(main, hdr["ent_lba"], hdr["nents"], hdr["entsz"]):
        if e: print(f"  [{e['idx']:2d}] {e['name']:20s} first={e['first']} last={e['last']} ({(e['last']-e['first']+1)*SECTOR/2**30:.1f} GiB)")

def main():
    p = argparse.ArgumentParser(); sub = p.add_subparsers(dest="cmd", required=True)
    b = sub.add_parser("build")
    b.add_argument("--main", required=True); b.add_argument("--backup", required=True)
    b.add_argument("--out-prefix", required=True)
    b.add_argument("--linux-name", default="linux")
    b.add_argument("--backup-start-lba", type=int, default=61390814)
    b.set_defaults(f=cmd_build)
    l = sub.add_parser("list"); l.add_argument("--main", required=True); l.set_defaults(f=cmd_list)
    a = p.parse_args(); a.f(a)

if __name__ == "__main__":
    main()
