#!/usr/bin/env python3
"""android-lpdump.py — 只读解析 Qualcomm 线刷包里的「分段 super」（LP metadata + extents）。

背景：backup/official-rom-15.10.259/ 的 super 被拆成 super_1..8.img，每段由
rawprogram_save_persist_unsparse0.xml 给出 (start_sector, num_partition_sectors,
SECTOR_SIZE_IN_BYTES=4096)，写到 physical_partition_number=0、label="super" 的**绝对 LBA**。
段与段之间**不相邻**（有空洞），所以不能 `cat` 拼接，必须按绝对 LBA 映射。

本脚本：解析 LP geometry（offset 4096）+ metadata（offset 8192，slot0；备份 73728/77824），
打印分区表 / 组 / block device / extents，并可选 --extract 指定分区还原成独立镜像。

用法：
  scripts/android-lpdump.py                                  # 打印表
  scripts/android-lpdump.py --verify                         # 顺带核对 geom/metadata checksum
  scripts/android-lpdump.py --extract system product odm ... --outdir out/android-super-20261118/parts
  scripts/android-lpdump.py --probe                          # 每个分区首扇区判文件系统

只读源包；除 --extract 的目标外不写任何东西。
"""
import argparse
import hashlib
import os
import struct
import sys

ROM = "/home/xuqianhui/y700-elden/backup/official-rom-15.10.259"
SECTOR = 4096          # super 分区 / geometry 的 logical_block_size
EXTSEC = 512           # ★ LP extent 的 num_sectors / target_data 单位 = 底层块设备 512B sector
                       #   交叉验证：product_a 首个 extent target_data=6144 ⇒ byte 3 145 728
                       #   = super_3.img 在 super 内的起始偏移（(91272-90504)*4096），而其 +1024
                       #   正是已知的 ext4 superblock（magic 0x53ef）。

# 从 rawprogram_save_persist_unsparse0.xml 原样抄出（脚本：--from-xml 现读，避免手抄漂移）
SEGMENTS = [
    ("super_1.img", 90504, 99),
    ("super_2.img", 90760, 403),
    ("super_3.img", 91272, 254194),
    ("super_4.img", 345480, 2994807),
    ("super_5.img", 3340424, 3060),
    ("super_6.img", 3343496, 146087),
    ("super_7.img", 3489672, 375042),
    ("super_8.img", 3864968, 35982),
]

GEOM_MAGIC = 0x616C4467
META_MAGIC = 0x414C5030
# 实测布局（本包 super_1.img，字节偏移，已 hexdump 核对；与 liblp 常见假设不同！）：
#   0..4095    reserved
#   4096       primary geometry (52 B + padding)
#   8192       backup geometry
#   12288      primary metadata slot0..N-1（每份 metadata_max_size=65536）
#   208896     backup  metadata slot0..N-1
#   405504 = 99*4096 = super_1.img 全长（里面没有空洞）
GEOM_PRIMARY = 4096
GEOM_BACKUP = 8192
META_PRIMARY = 12288
META_BACKUP_BASE = 208896
# 头部：magic(4) major(2) minor(2) header_size(4) header_checksum(32) tables_size(4)
#       tables_checksum(32) 4x LpMetadataTableDescriptor(12)
HDR_MAGIC, HDR_MAJOR, HDR_MINOR, HDR_SIZE = 0, 4, 6, 8
HDR_CSUM, HDR_TABLES_SIZE, HDR_TABLES_CSUM, HDR_DESC = 12, 44, 48, 80


def load_segments_from_xml(xml_path, rom=ROM):
    import re

    txt = open(xml_path, encoding="utf-8", errors="replace").read()
    segs = []
    for m in re.finditer(r"<program\b[^>]*/?>", txt):
        tag = m.group(0)
        if 'label="super"' not in tag:
            continue
        fn = re.search(r'filename="([^"]+)"', tag).group(1)
        start = int(re.search(r'start_sector="(\d+)"', tag).group(1))
        nsec = int(re.search(r'num_partition_sectors="(\d+)"', tag).group(1))
        segs.append((fn, start, nsec))
    segs.sort(key=lambda s: s[1])
    return segs


class SegReader:
    """按 super 内的绝对字节偏移读，跨段自动拼接（段间空洞返回 0）。"""

    def __init__(self, segs, rom=ROM):
        # 段的 start_sector 是 super 的**绝对 LBA**（super 自己的起始 LBA = 最小 start_sector，
        # 本包 = 90504 = GPT 里 super 分区的 first_lba），换算成 super 内的字节偏移要减掉它。
        segs = sorted(segs, key=lambda s: s[1])
        base = segs[0][1] * SECTOR
        self.segs = []
        for fn, start, nsec in segs:
            lo, hi = start * SECTOR - base, (start + nsec) * SECTOR - base
            self.segs.append((lo, hi, os.path.join(rom, fn)))

    _fh = {}

    def _file(self, path):
        f = SegReader._fh.get(path)
        if f is None:
            f = open(path, "rb")
            SegReader._fh[path] = f
        return f

    def read(self, off, n):
        out = bytearray(n)
        for s, e, path in self.segs:
            if off >= e or off + n <= s:
                continue
            lo = max(off, s)
            hi = min(off + n, e)
            f = self._file(path)
            f.seek(lo - s)
            out[lo - off:hi - off] = f.read(hi - lo)
        return bytes(out)

    def total_span(self):
        return max(e for _, e, _ in self.segs)


def parse_geometry(r):
    g = r.read(GEOM_PRIMARY, 52)
    magic, ssz = struct.unpack("<II", g[:8])
    if magic != GEOM_MAGIC:
        raise SystemExit("geometry magic 不对: %08x" % magic)
    csum = g[8:40]
    maxsz, slots, lb = struct.unpack("<III", g[40:52])
    zeroed = g[:8] + b"\0" * 32 + g[40:52]
    calc = hashlib.sha256(zeroed).digest()
    return dict(magic=magic, struct_size=ssz, checksum=csum, checksum_ok=(calc == csum),
                metadata_max_size=maxsz, metadata_slot_count=slots, logical_block_size=lb)

class Table:
    def __init__(self, raw, off):
        self.offset, self.num_entries, self.entry_size = struct.unpack("<III", raw[off:off + 12])

    def __repr__(self):
        return "off=%d n=%d esz=%d" % (self.offset, self.num_entries, self.entry_size)


def parse_metadata(raw, maxsz):
    magic, major, minor = struct.unpack("<IHH", raw[0:8])
    if magic != META_MAGIC:
        raise SystemExit("metadata magic 不对: %08x" % magic)
    header_size = struct.unpack("<I", raw[HDR_SIZE:HDR_SIZE + 4])[0]
    header_csum = raw[HDR_CSUM:HDR_CSUM + 32]
    tables_size = struct.unpack("<I", raw[HDR_TABLES_SIZE:HDR_TABLES_SIZE + 4])[0]
    tables_csum = raw[HDR_TABLES_CSUM:HDR_TABLES_CSUM + 32]
    descs = [Table(raw, HDR_DESC + 12 * i) for i in range(4)]
    tables = raw[header_size:header_size + tables_size]
    zeroed_hdr = raw[:HDR_CSUM] + b"\0" * 32 + raw[HDR_CSUM + 32:header_size]
    calc_h = hashlib.sha256(zeroed_hdr).digest()
    calc_t = hashlib.sha256(tables).digest()
    meta = dict(magic=magic, major=major, minor=minor, header_size=header_size,
                header_checksum_ok=(calc_h == header_csum),
                tables_checksum_ok=(calc_t == tables_csum),
                tables_size=tables_size, metadata_max_size=maxsz, descs=descs,
                tables_len_ok=(header_size + tables_size <= maxsz))

    def entries(d):
        base = d.offset
        return [tables[base + i * d.entry_size:base + (i + 1) * d.entry_size]
                for i in range(d.num_entries)]

    # partitions
    parts = []
    for e in entries(descs[0]):
        name = e[:36].split(b"\0")[0].decode(errors="replace")
        attrs, first, num, grp = struct.unpack("<IIII", e[36:52])
        parts.append(dict(name=name, attributes=attrs, first_extent_index=first,
                          num_extents=num, group_index=grp))
    extents = []
    for e in entries(descs[1]):
        num_sectors, target_type, target_data, target_source = struct.unpack("<QIIQ", e[:24])
        extents.append(dict(num_sectors=num_sectors, target_type=target_type,
                            target_data=target_data, target_source=target_source))
    groups = []
    for e in entries(descs[2]):
        nm = e[:36].split(b"\0")[0].decode(errors="replace")
        flags, maxsz_ = struct.unpack("<IQ", e[36:48])
        groups.append(dict(name=nm, flags=flags, max_size=maxsz_))
    devices = []
    for e in entries(descs[3]):
        # v10.2: first_logical_sector(8) alignment(4) alignment_offset(4) size(8) name[36] flags(4)
        off, align, align_off, sz = struct.unpack("<QIIQ", e[0:24])
        name = e[24:60].split(b"\0")[0].decode(errors="replace")
        flags = struct.unpack("<I", e[60:64])[0]
        devices.append(dict(first_logical_sector=off, alignment=align, alignment_offset=align_off,
                            size=sz, name=name, flags=flags))
    meta.update(partitions=parts, extents=extents, groups=groups, block_devices=devices)
    return meta


def probe_fs(r, byte_off, n=8192):
    """在 logical partition 的绝对字节偏移处判文件系统（ext4 / erofs / sparse）。"""
    head = r.read(byte_off, n)
    if len(head) < 2048:
        return "short"
    if head[1080:1082] == b"\x53\xef":   # ext4: superblock@1024, s_magic@+56 = 0xEF53（字节序 53 ef）
        return "ext4"
    if head[1024:1028] == b"\xe2\xe1\xf5\xe0":
        return "erofs"
    if head[:4] == b"\x3a\xff\x26\xed":
        return "sparse"
    if head[0:4] == b"\0\0\0\0" and head[4096:4100]:
        return "zeros+hdr?"
    return "unknown(%s)" % head[:4].hex()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--from-xml", default=os.path.join(ROM, "rawprogram_save_persist_unsparse0.xml"))
    ap.add_argument("--verify", action="store_true")
    ap.add_argument("--probe", action="store_true")
    ap.add_argument("--backup-slot", action="store_true", help="用 backup metadata region（208896+）")
    ap.add_argument("--slot", type=int, default=0, help="metadata slot 号（0..N-1）")
    ap.add_argument("--extract", nargs="*", default=None)
    ap.add_argument("--outdir", default="/home/xuqianhui/y700-elden/out/android-min-avb-20261118/parts")
    a = ap.parse_args()

    segs = load_segments_from_xml(a.from_xml) if os.path.exists(a.from_xml) else SEGMENTS
    r = SegReader(segs)
    geom = parse_geometry(r)
    print("== LP geometry (slot0 @4096) ==")
    for k, v in geom.items():
        print("  %-22s %s" % (k, v.hex() if isinstance(v, bytes) else v))
    off = (META_BACKUP_BASE if a.backup_slot else META_PRIMARY) + geom["metadata_max_size"] * a.slot
    raw = r.read(off, geom["metadata_max_size"])
    md = parse_metadata(raw, geom["metadata_max_size"])
    print("== LP metadata @%d ==" % off)
    print("  magic=%08x v%d.%d header_size=%d tables_size=%d" % (md["magic"], md["major"], md["minor"],
                                                               md["header_size"], md["tables_size"]))
    print("  tables: partitions=%r extents=%r groups=%r block_devices=%r" %
          tuple(md["descs"]))
    if a.verify:
        print("  geom_checksum_ok=%s metadata_header_checksum_ok=%s tables_checksum_ok=%s tables_fit=%s"
              % (geom["checksum_ok"], md["header_checksum_ok"], md["tables_checksum_ok"],
                 md["tables_len_ok"]))
        # 已知事实 2 复核：用「校验字段清零」的几种长度重算 header sha256
        for zlen, name in ((32, "csum32"), (36, "csum32+size"), (48, "csum32+size32"),
                           (52, "csum32+size32+4"), (56, "csum56"), (64, "csum64")):
            cand = hashlib.sha256(raw[:HDR_CSUM] + b"\0" * zlen + raw[HDR_CSUM + zlen:md["header_size"]]).digest()
            print("    清零 %-12s -> %s" % (name, cand.hex()[:16]))

    print("== groups ==")
    for i, g in enumerate(md["groups"]):
        print("  [%d] %-24s flags=%#x max_size=%d" % (i, g["name"], g["flags"], g["max_size"]))
    print("== block devices ==")
    for i, d in enumerate(md["block_devices"]):
        print("  [%d] %-16s first_logical_sector=%d alignment=%d align_off=%d size=%d "
              "(logical-block 单位 = %.2f GiB) flags=%#x"
              % (i, d["name"], d["first_logical_sector"], d["alignment"], d["alignment_offset"],
                 d["size"], d["size"] * SECTOR / 2**30, d["flags"]))

    print("== partitions (%d) ==" % len(md["partitions"]))
    print("  %-18s %-10s %-10s %-6s %s" % ("name", "size", "GiB", "attrs", "extents"))
    total = 0
    layout = []
    for p in md["partitions"]:
        exts = md["extents"][p["first_extent_index"]:p["first_extent_index"] + p["num_extents"]]
        ns = sum(e["num_sectors"] for e in exts)
        total += ns
        desc = ", ".join("%d@%d" % (e["num_sectors"], e["target_data"]) for e in exts)
        print("  %-18s %-12d %-8.3f %-6s %s" % (p["name"], ns * EXTSEC, ns * EXTSEC / 2**30,
                                                hex(p["attributes"]), desc))
        layout.append((p["name"], exts, ns))
    print("  --- 合计 %d 个 512B sector = %.3f GiB（各分区已分配量之和）"
          % (total, total * EXTSEC / 2**30))

    if a.probe:
        print("== filesystem probe (first extent, logical sector -> abs byte) ==")
        for name, exts, ns in layout:
            if not exts:
                print("  %-18s (no extent)" % name)
                continue
            e = exts[0]
            absb = e["target_data"] * EXTSEC
            print("  %-18s abs=0x%x  %s" % (name, absb, probe_fs(r, absb)))

    if a.extract:
        os.makedirs(a.outdir, exist_ok=True)
        want = set(a.extract) if a.extract else {p["name"] for p in md["partitions"]}
        for name, exts, ns in layout:
            if name not in want:
                continue
            dst = os.path.join(a.outdir, name + ".img")
            chunk = 1 << 20
            pos = 0
            with open(dst, "wb") as f:
                for e in exts:
                    src = e["target_data"] * EXTSEC
                    left = e["num_sectors"] * EXTSEC
                    while left:
                        n = min(chunk, left)
                        f.write(r.read(src, n))
                        src += n
                        left -= n
                        pos += n
            print("[extract] %-18s %12d B -> %s" % (name, pos, dst))


if __name__ == "__main__":
    sys.exit(main())
