#!/usr/bin/env python3
"""gpt-slot-flip-active.py — 在一对 GPT 表（主表 6 扇区 + 备表 5 扇区）上只改 boot_a/boot_b 的
属性字节 6，把「b 槽 active」写对，并重算条目区 CRC 与表头 CRC。

背景（2026-11-20 实测）：Qualcomm ABL 的 set_active 会把 partition **type GUID**
在两个槽之间搬家；用 fastboot set_active 连做两次会出现「GUID 落在 b 侧、ACTIVE 位却
在 a 侧」的半完成态 ⇒ FindBootableSlot → ValidateSlotGuids 失败 → 直接掉 fastboot
（logfs 原文 `ValidateSlotGuids: BootableSlot _a does not have valid guids` +
`Boot GUID 77036CD4… / abl_a GUID 77036CD4…`）。
本脚本只动属性位，不动 GUID/几何，用来把 ACTIVE 位补到 GUID 已经正确的那个槽。

用法：
  gpt-slot-flip-active.py --main gpt4-primary.bin --backup gpt4-backup.bin \
                 --out-prefix out/x/lun4 --activate b
产出 <prefix>_main.bin / <prefix>_backup.bin，并逐字段打印改动；写盘走
scripts/linux-gpt-apply.sh（它做写前对账 + 写后逐字节读回）。
"""
import argparse
import binascii
import struct
import sys

ESZ = 128
NAME_OFF = 56
ABYTE_ENTRY_OFF = 48 + 6      # attribute 字段的第 6 字节（AOSP/Qualcomm AB_FLAG_OFFSET）
BIT_ACTIVE = 0x04
BIT_LOW = 0x03                # OEM 与 ACTIVE 一起置的 priority 低两位
BIT_RETRY = 0x38
BIT_SUCC = 0x40
BIT_UNBOOT = 0x80


def entries_view(block, base):
    """返回 (offset, name) 列表；block 是原始字节，base 是条目区起点。"""
    out = []
    for i in range(128):
        off = base + i * ESZ
        ent = block[off:off + ESZ]
        if len(ent) < ESZ or ent[0:16] == b"\0" * 16:
            continue
        out.append((off, ent[NAME_OFF:NAME_OFF + 72].decode("utf-16-le").rstrip("\0")))
    return out


def patch(block, base, activate, tag):
    want = "boot_" + activate
    changed = 0
    for off, name in entries_view(block, base):
        a = off + ABYTE_ENTRY_OFF
        old = block[a]
        if name == want:
            new = (old | BIT_ACTIVE | BIT_LOW | BIT_SUCC) & ~BIT_UNBOOT
            new = (new & ~BIT_RETRY) | (7 << 3)
        elif name in ("boot_a", "boot_b"):
            new = old & ~BIT_ACTIVE & ~BIT_LOW
        else:
            continue
        block[a] = new
        changed += 1
        print(f"  {tag:8s} {name:7s} byte6 0x{old:02x} -> 0x{new:02x}")
    return changed


def fix_crc(main, bak):
    """主表: header@4096 entries@8192; 备表: entries@0 header@16384。
    条目区长度 = nent*esize（本机 96*128 = 12288 B，不是 4 扇区的 16384）。"""
    nent, esz = struct.unpack_from("<II", main, 4096 + 80)
    elen = nent * esz
    e_prim = main[8192:8192 + elen]
    struct.pack_into("<I", main, 4096 + 88, binascii.crc32(bytes(e_prim)) & 0xFFFFFFFF)
    struct.pack_into("<I", main, 4096 + 16, 0)
    struct.pack_into("<I", main, 4096 + 16,
                     binascii.crc32(bytes(main[4096:4096 + struct.unpack_from("<I", main, 4096 + 12)[0]])) & 0xFFFFFFFF)
    e_bak = bak[0:elen]
    struct.pack_into("<I", bak, 16384 + 88, binascii.crc32(bytes(e_bak)) & 0xFFFFFFFF)
    struct.pack_into("<I", bak, 16384 + 16, 0)
    struct.pack_into("<I", bak, 16384 + 16,
                     binascii.crc32(bytes(bak[16384:16384 + struct.unpack_from("<I", bak, 16384 + 12)[0]])) & 0xFFFFFFFF)


def verify_crc(main, bak):
    ok = True
    nent, esz = struct.unpack_from("<II", main, 4096 + 80)
    elen = nent * esz
    for tag, blk, hoff, eoff, elen in (("primary", main, 4096, 8192, elen),
                                       ("backup", bak, 16384, 0, elen)):
        hsz = struct.unpack_from("<I", blk, hoff + 12)[0]
        h = bytearray(blk[hoff:hoff + hsz])
        ents_crc = struct.unpack_from("<I", h, 88)[0]
        hdr_crc = struct.unpack_from("<I", h, 16)[0]
        struct.pack_into("<I", h, 16, 0)
        calc = binascii.crc32(bytes(h)) & 0xFFFFFFFF
        ecalc = binascii.crc32(bytes(blk[eoff:eoff + elen])) & 0xFFFFFFFF
        good = (ents_crc == ecalc) and (hdr_crc == calc)
        ok &= good
        print(f"  CRC {tag:8s} entries={'ok' if ents_crc==ecalc else 'BAD'} "
              f"header={'ok' if hdr_crc==calc else 'BAD'}")
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--main", required=True)
    ap.add_argument("--backup", required=True)
    ap.add_argument("--out-prefix", required=True)
    ap.add_argument("--activate", choices=["a", "b"], default="b")
    args = ap.parse_args()

    m = bytearray(open(args.main, "rb").read())
    b = bytearray(open(args.backup, "rb").read())
    if len(m) < 24576 or len(b) < 20480:
        sys.exit("输入尺寸不对：主表需 >=24576 B、备表需 >=20480 B")
    if m[4096:4104] != b"EFI PART" or b[16384:16392] != b"EFI PART":
        sys.exit("输入里没有 GPT 签名（主表头@4096 / 备表头@16384）")

    print(f"[flip] activate=_{args.activate}")
    n = patch(m, 8192, args.activate, "primary")
    n += patch(b, 0, args.activate, "backup")
    if n != 4:
        sys.exit(f"只改了 {n}/4 处 —— 该表不是 A/B 双份 boot 条目，拒绝继续")
    fix_crc(m, b)
    if not verify_crc(m, b):
        sys.exit("CRC 自检失败")
    om, ob = args.out_prefix + "_main.bin", args.out_prefix + "_backup.bin"
    open(om, "wb").write(m)
    open(ob, "wb").write(b)
    print(f"[flip] wrote {om} ({len(m)} B) / {ob} ({len(b)} B)")


if __name__ == "__main__":
    main()
