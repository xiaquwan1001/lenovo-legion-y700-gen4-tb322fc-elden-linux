#!/usr/bin/env python3
"""gpt-slot-swap-guids.py — 把 A/B 槽的 **partition type GUID 侧** 搬到指定槽，并按 MarkPtnActive 语义修属性位。

## 为什么需要它（2026-11-21 晚，源码级定因）

ABL 的 `FindBootableSlot()` → `ValidateSlotGuids()`（`Platforms/QcomModulePkg/Library/BootLib/
PartitionTableUpdate.c:1542-1602`）要求 **`boot_<slot>` 与 `abl_<slot>` 的 `PartitionTypeGUID` 不同**：
b 侧「未开通」的 GPT 里两者都是通用占位 `77036CD4-03D5-42BB-8ED1-37E5A88BAA34`。
合法的 b 槽 = **canonical 那套 GUID 搬到 b 侧**（`boot_b=20117f86…`、`abl_b=bd6928a1…`、其余成对分区同理）。

而 `fastboot --set-active` **无法修复**「GUID 侧 ≠ ACTIVE 侧」：`SwitchPtnSlots()`（`:541-600`）只在
「请求的槽 ≠ 当前 ACTIVE 槽」时才交换 GUID（`:1442-1447`），而交换与 ACTIVE 位是**同时**翻的 ⇒
两者永远同步翻转，`--set-active a` / `--set-active b` 只能把错配保留下来（这正是本轮踩坑的形状）。
⇒ 唯一修法是**直接改表**：对每一对 `X_a`/`X_b` 交换 `PartitionTypeGUID` 16 字节（与 `SwapPtnGuid()` 等价），
再把 ACTIVE 位按 `MarkPtnActive()` 语义写到目标槽，重算双表 CRC。

## 用法

  scripts/gpt-slot-swap-guids.py --main in/gpt4-primary.bin --backup in/gpt4-backup.bin \
      --out-prefix out/x/lun4 --to b [--no-attr] [--dry-run]

  · 默认会先打印「当前判定」：`boot_<slot>` vs `abl_<slot>` 的 type GUID 是否相同（= ABL 会拒的形态）。
  · `--no-attr` 只搬 GUID、不动属性位（用于纯对照实验）。
  · 产物 = `<prefix>_main.bin` / `<prefix>_backup.bin`；写盘走 `scripts/linux-gpt-apply.sh`（写前 dump + 写后读回）。

## 安全边界

- 只交换 **同时存在 `X_a` 与 `X_b`** 的分区（ABL 的 `GetMultiSlotPartsList()` 同口径）；不增删条目、不改几何。
- 交换是自反的：对产物再跑一次 = 回到输入（`--selftest` 用往返验证）。
- 写前自检：交换后 `boot_<to>` 与 `abl_<to>` 必须**不同**，否则退出码 3（拒绝产出）。
"""
import argparse
import binascii
import struct
import sys
import uuid

ESZ = 128
NAME_OFF = 56
BYTE6_OFF = 48 + 6
BIT_ACTIVE = 0x04
BIT_LOW = 0x03
BIT_RETRY = 0x38
BIT_SUCC = 0x40
BIT_UNBOOT = 0x80


def parse(block, hdr_off):
    """返回 [(entry_off, name, type_guid_bytes, byte6_index)]"""
    if block[hdr_off:hdr_off + 8] != b"EFI PART":
        sys.exit("没有 EFI PART 头（offset %d）" % hdr_off)
    nent, esize = struct.unpack_from("<II", block, hdr_off + 80)
    # 主表：entries 紧跟头后一扇区；备表：entries 在头**之前**（本文件把备表头放在末扇区）
    if hdr_off == 4096:
        base = 8192  # 主表：entries 紧跟头后的下一扇区
    else:
        base = 0     # 备表：本机 dump 窗口从 alt_lba-4 起，entries 就在文件偏移 0（hdr 在末尾扇区）
    out = []
    for i in range(nent):
        off = base + i * esize
        ent = block[off:off + esize]
        if len(ent) < esize or ent[0:16] == b"\x00" * 16:
            continue
        name = ent[NAME_OFF:NAME_OFF + 72].decode("utf-16-le").rstrip("\x00")
        out.append((off, name, bytes(ent[0:16]), off + BYTE6_OFF))
    return out


def guid_str(b):
    return str(uuid.UUID(bytes_le=b))


def fix_crc(main, bak):
    nent, esz = struct.unpack_from("<II", main, 4096 + 80)
    elen = nent * esz
    struct.pack_into("<I", main, 4096 + 88, binascii.crc32(bytes(main[8192:8192 + elen])) & 0xFFFFFFFF)
    struct.pack_into("<I", main, 4096 + 16, 0)
    hsz, = struct.unpack_from("<I", main, 4096 + 12)
    struct.pack_into("<I", main, 4096 + 16, binascii.crc32(bytes(main[4096:4096 + hsz])) & 0xFFFFFFFF)

    bstart = 0
    struct.pack_into("<I", bak, len(bak) - 4096 + 88, binascii.crc32(bytes(bak[bstart:bstart + elen])) & 0xFFFFFFFF)
    struct.pack_into("<I", bak, len(bak) - 4096 + 16, 0)
    bhsz, = struct.unpack_from("<I", bak, len(bak) - 4096 + 12)
    struct.pack_into("<I", bak, len(bak) - 4096 + 16,
                     binascii.crc32(bytes(bak[len(bak) - 4096:len(bak) - 4096 + bhsz])) & 0xFFFFFFFF)


def crc_ok(main, bak):
    nent, esz = struct.unpack_from("<II", main, 4096 + 80)
    elen = nent * esz
    ok = True
    for tag, blk, hoff, eoff in (("primary", main, 4096, 8192),
                                 ("backup", bak, len(bak) - 4096, 0)):
        h = bytearray(blk[hoff:hoff + 92])
        ecrc, = struct.unpack_from("<I", h, 88)
        hcrc, = struct.unpack_from("<I", h, 16)
        h[16:20] = b"\x00" * 4
        ok &= (ecrc == (binascii.crc32(bytes(blk[eoff:eoff + elen])) & 0xFFFFFFFF))
        ok &= (hcrc == (binascii.crc32(bytes(h)) & 0xFFFFFFFF))
        print("  CRC %-8s entries=%s header=%s" % (
            tag, "ok" if ecrc == (binascii.crc32(bytes(blk[eoff:eoff + elen])) & 0xFFFFFFFF) else "BAD",
            "ok" if hcrc == (binascii.crc32(bytes(h)) & 0xFFFFFFFF) else "BAD"))
    return ok


def pair_names(entries):
    names = {n for _, n, _, _ in entries}
    pairs = []
    for n in sorted(names):
        if n.endswith("_a") and (n[:-2] + "_b") in names:
            pairs.append((n, n[:-2] + "_b"))
    return pairs


def swap_guids(block, entries, pairs, tag):
    idx = {n: (off, t, b6) for off, n, t, b6 in entries}
    n = 0
    for a, b in pairs:
        if a not in idx or b not in idx:
            continue
        oa, ta, _ = idx[a]
        ob, tb, _ = idx[b]
        block[oa:oa + 16] = tb
        block[ob:ob + 16] = ta
        n += 1
    print("  %s: 交换 %d 对 type GUID" % (tag, n))
    return n


def mark_active(block, entries, to, tag):
    n = 0
    for off, name, _t, b6 in entries:
        if not (name.endswith("_a") or name.endswith("_b")):
            continue
        old = block[b6]
        if name.endswith("_" + to):
            new = (old | BIT_ACTIVE | BIT_LOW | BIT_RETRY) & ~BIT_UNBOOT
        else:
            new = old & ~BIT_ACTIVE & ~BIT_LOW
        if new != old:
            n += 1
        block[b6] = new
    print("  %s: 属性位改动 %d 条（ACTIVE 侧 = _%s）" % (tag, n, to))
    return n


def report(entries, tag):
    g = {n: t for _, n, t, _ in entries}
    for s in "ab":
        nb, na = "boot_" + s, "abl_" + s
        if nb in g and na in g:
            same = g[nb] == g[na]
            print("  %-7s boot_%s=%s abl_%s=%s  相同=%s" % (tag, s, guid_str(g[nb])[:13], s, guid_str(g[na])[:13], same))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--main", required=True)
    ap.add_argument("--backup", required=True)
    ap.add_argument("--out-prefix", default="")
    ap.add_argument("--to", choices=["a", "b"], required=True)
    ap.add_argument("--no-attr", action="store_true")
    ap.add_argument("--selftest", action="store_true")
    args = ap.parse_args()

    m = bytearray(open(args.main, "rb").read())
    b = bytearray(open(args.backup, "rb").read())
    me = parse(m, 4096)
    be = parse(b, len(b) - 4096)
    print("[swap] 输入：primary %d 条 / backup %d 条" % (len(me), len(be)))
    report(me, "before")

    pairs = pair_names(me)
    print("  成对分区（X_a/X_b 都存在）= %d 对" % len(pairs))

    if args.selftest:
        # ① 单向：每对的 GUID 必须互换（允许两侧本来相同 ⇒ 看不出变化）
        m2 = bytearray(m)
        swap_guids(m2, me, pairs, "one-way")
        after = {n: t for _, n, t, _ in parse(bytes(m2), 4096)}
        before = {n: t for _, n, t, _ in me}
        bad = []
        for a, b in pairs:
            if after[a] != before[b] or after[b] != before[a]:
                bad.append((a, b))
        # ② 往返：交换两次必须逐字节回到原 entries
        m3 = bytearray(m2)
        swap_guids(m3, parse(bytes(m2), 4096), pairs, "back")
        ent = lambda blk: blk[8192:8192 + 96 * 128]
        same = ent(bytes(m3)) == ent(bytes(m))
        print("  selftest: 单向不符的成对数 = %d / %d；往返逐字节复原 = %s" % (len(bad), len(pairs), same))
        return 0 if (not bad and same) else 2

    swap_guids(m, me, pairs, "primary")
    swap_guids(b, be, pairs, "backup")
    if not args.no_attr:
        mark_active(m, parse(bytes(m), 4096), args.to, "primary")
        mark_active(b, parse(bytes(b), len(b) - 4096), args.to, "backup")

    fix_crc(m, b)
    if not crc_ok(m, b):
        sys.exit("CRC 自检失败，拒绝产出")

    after = parse(bytes(m), 4096)
    report(after, "after")
    g = {n: t for _, n, t, _ in after}
    nb, na = "boot_" + args.to, "abl_" + args.to
    if nb in g and na in g and g[nb] == g[na]:
        sys.exit("自检失败：交换后 boot_%s 仍与 abl_%s 同 GUID（备表可能不是同一张表）" % (args.to, args.to))

    if args.out_prefix:
        om, ob = args.out_prefix + "_main.bin", args.out_prefix + "_backup.bin"
        open(om, "wb").write(m)
        open(ob, "wb").write(b)
        print("[swap] wrote %s / %s" % (om, ob))
    else:
        print("（未给 --out-prefix：只做判定，不落盘）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
