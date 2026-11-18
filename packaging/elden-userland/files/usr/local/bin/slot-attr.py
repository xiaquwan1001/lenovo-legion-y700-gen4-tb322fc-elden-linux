#!/usr/bin/env python3
"""slot-attr.py — read/patch the A/B slot metadata stored in the GPT
partition-entry attribute field of the TB322FC (Y700 Gen4) UFS LUN0.

Authoritative layout (AOSP/Qualcomm `gpt-utils.h`):

    AB_FLAG_OFFSET = attribute byte 6        (attribute bits 48..55)
    bit 2 (0x04) = SLOT_ACTIVE        AB_PARTITION_ATTR_SLOT_ACTIVE
    bit 6 (0x40) = BOOT_SUCCESSFUL    AB_PARTITION_ATTR_BOOT_SUCCESSFUL
    bit 7 (0x80) = UNBOOTABLE         AB_PARTITION_ATTR_UNBOOTABLE
    bits 3..5 (0x38) = tries_remaining (3-bit, default 7)
    bits 0..1 are set together with ACTIVE by the OEM (AB_SLOT_ACTIVE_VAL=0x3F)

Only `boot_a`/`boot_b` carry a live counter; ABL decrements bits 3..5 of the
*active* slot's `boot_*` entry once per boot attempt unless bit 6 (SUCCESSFUL)
is set, and sets bit 7 (UNBOOTABLE) when the counter hits 0 -> device stops at
fastboot.  Non-boot partitions keep a constant OEM value (a=0x7x, b=0xFx) and
their bit 7 is NOT an unbootable marker.

This device uses 4096-byte logical sectors (gdisk/sgdisk assume 512 and
misread it) — hence a hand-rolled editor.  **The A/B partitions live on
`/dev/sde` (LUN4), NOT `/dev/sda` (LUN0)** — `boot_a`/`boot_b` are sde12/sde45.

Usage (run on the device, root, while Linux boots from slot b):

    ionice -c3 nice -n19 python3 slot-attr.py show
    ionice -c3 nice -n19 python3 slot-attr.py mark-successful b   # <- permanent fix
    ionice -c3 nice -n19 python3 slot-attr.py set b --retry 7     # top-up only

    # dry run, no write:
    python3 slot-attr.py set b --retry 7 --dry-run

    # offline on a full GPT pair taken with dd (sector 0 == LBA0):
    python3 slot-attr.py --image lun0-gpt.bin show

Writes BOTH the primary and the backup GPT (entries + header) and recomputes
the two CRCs.  Always `dd` a backup of LBA0..LBA33 and the last 34 LBAs first.
"""
import argparse
import binascii
import os
import struct
import sys

SECTOR_DEFAULT = 4096
AB_OFF = 6          # attribute byte index
ACTIVE = 0x04
SUCCESSFUL = 0x40
UNBOOTABLE = 0x80
RETRY_MASK = 0x38   # bits 3..5
ENTRY_SIZE = 128
NAME_OFF = 56


def decode(v):
    return {
        "raw": "0x%02x" % v,
        "retry": (v >> 3) & 0x7,
        "active": bool(v & ACTIVE),
        "successful": bool(v & SUCCESSFUL),
        "unbootable": bool(v & UNBOOTABLE),
    }


def encode(v, retry=None, active=None, successful=None, unbootable=None):
    v &= ~0
    if retry is not None:
        v = (v & ~RETRY_MASK) | ((retry & 0x7) << 3)
    if active is not None:
        v = (v | ACTIVE) if active else (v & ~ACTIVE)
        # OEM sets bits 0..1 together with ACTIVE
        if active:
            v |= 0x03
        else:
            v &= ~0x03
    if successful is not None:
        v = (v | SUCCESSFUL) if successful else (v & ~SUCCESSFUL)
    if unbootable is not None:
        v = (v | UNBOOTABLE) if unbootable else (v & ~UNBOOTABLE)
    return v & 0xFF


class Gpt:
    """Edit the GPT of a block device or a full-image file."""

    def __init__(self, src, sector=None, writable=False):
        self.src = src
        self.image_mode = os.path.isfile(src)
        self.fd = os.open(src, os.O_RDWR if writable else os.O_RDONLY)
        self.size = self._dev_size()
        self.sector = sector or SECTOR_DEFAULT
        self._read_headers()

    def _dev_size(self):
        """st_size is 0 for block devices -> use BLKGETSIZE64, else fstat."""
        try:
            import fcntl
            BLKGETSIZE64 = 0x80081272
            buf = fcntl.ioctl(self.fd, BLKGETSIZE64, struct.pack("Q", 0))
            sz = struct.unpack("Q", buf)[0]
            if sz:
                return sz
        except OSError:
            pass
        return os.fstat(self.fd).st_size

    # ---- low level -------------------------------------------------
    def _pread(self, off, ln):
        os.lseek(self.fd, off, os.SEEK_SET)
        return os.read(self.fd, ln)

    def _pwrite(self, off, data):
        os.lseek(self.fd, off, os.SEEK_SET)
        view = memoryview(data)
        while len(view):          # 块设备 write 可能短写，不循环就会静默丢尾部
            n = os.write(self.fd, view)
            if n <= 0:
                raise OSError(f"{self.src}: short write at {off}")
            view = view[n:]

    def _hdr_off(self, which):
        # 备表头位置 = 主表头自述的 alt_lba（不是 size-sector）：整盘镜像/设备两者都对，
        # 且主备不一致时能暴露出来而不是「读了个别处的 4096 B」。
        return self.sector if which == "primary" else self.alt_lba * self.sector

    def _read_headers(self):
        self.hdr = {}
        # 先读主表头拿到 alt_lba，才能定位备表（2026-11-18 审计 R1 P0-④）
        raw = self._pread(self.sector, 92)
        if raw[:8] != b"EFI PART":
            raise SystemExit(f"{self.src}: no GPT signature at primary header (LBA1)")
        self.alt_lba = struct.unpack_from("<Q", raw, 32)[0]
        if self.alt_lba * self.sector + self.sector > self.size:
            raise SystemExit(
                f"{self.src}: 主表自述 alt_lba={self.alt_lba} 超出末尾 (size={self.size} B)\n"
                "  这份 dump 不是整盘视图：只给「主表+备表拼件」会让备表条目落在 EOF 之外，\n"
                "  旧版本于是静默只改主表。请用整盘镜像，或走 linux-gpt-apply.sh --gpt/--backup。")
        if self.image_mode:
            # 绝对 LBA 定位要求镜像就是整盘视图，否则一律拒绘（避免主备不一致）。
            need = (self.alt_lba + 1) * self.sector
            if self.size != need:
                raise SystemExit(
                    f"{self.src}: 镜像尺寸 {self.size} B != (alt_lba+1)*{self.sector} = {need} B。\n"
                    "  --image 只接受整盘镜像；只有主备表拼件时请走设备路径（/dev/sde）\n"
                    "  或 linux-gpt-apply.sh --lun 4 --gpt <main> --backup <backup> --apply。")
        for which in ("primary", "backup"):
            raw = self._pread(self._hdr_off(which), 92)
            if raw[:8] != b"EFI PART":
                raise SystemExit(f"{self.src}: no GPT signature at {which} header "
                                 f"(offset {self._hdr_off(which)})")
            self.hdr[which] = bytearray(raw)
        h = self.hdr["primary"]
        hdr_size = struct.unpack("<I", h[12:16])[0]
        if hdr_size > 92:
            # re-read using declared header size
            self.hdr["primary"] = bytearray(self._pread(self._hdr_off("primary"), hdr_size))
            self.hdr["backup"] = bytearray(self._pread(self._hdr_off("backup"), hdr_size))
        h = self.hdr["primary"]
        self.hdr_size = struct.unpack("<I", h[12:16])[0]
        self.nent = struct.unpack("<I", h[80:84])[0]
        self.entsz = struct.unpack("<I", h[84:88])[0]
        self.p_lba = struct.unpack("<Q", h[72:80])[0]
        self.b_lba = struct.unpack("<Q", self.hdr["backup"][72:80])[0]

    def _entries_off(self, which):
        lba = self.p_lba if which == "primary" else self.b_lba
        return lba * self.sector

    def _read_entries(self, which):
        return bytearray(self._pread(self._entries_off(which), self.nent * self.entsz))

    def _read_entries_before(self):
        self._ents_before = {w: self._read_entries(w) for w in ("primary", "backup")}

    # ---- entries ---------------------------------------------------
    @staticmethod
    def entry_info(ent):
        name = ent[NAME_OFF:NAME_OFF + 72].decode("utf-16-le", "replace").split("\0")[0]
        return name, ent[48 + AB_OFF]

    def iter_entries(self, which="primary"):
        block = self._read_entries(which)
        for k in range(self.nent):
            ent = block[k * self.entsz:(k + 1) * self.entsz]
            if len(ent) < ENTRY_SIZE:
                break
            name, ab = self.entry_info(ent)
            if name:
                yield k, name, block, ent, ab

    def find(self, name, which="primary"):
        block = self._read_entries(which)
        for k in range(self.nent):
            ent = block[k * self.entsz:(k + 1) * self.entsz]
            if len(ent) < ENTRY_SIZE:
                return None, None
            n, ab = self.entry_info(ent)
            if n == name:
                return block, k
        return None, None

    # ---- write -----------------------------------------------------
    @staticmethod
    def _fix_header(h, ents_crc):
        struct.pack_into("<I", h, 88, ents_crc)          # entries CRC
        struct.pack_into("<I", h, 16, 0)                 # zero own CRC
        crc = binascii.crc32(bytes(h)) & 0xFFFFFFFF
        struct.pack_into("<I", h, 16, crc)

    def write_entries(self, which, block):
        self._pwrite(self._entries_off(which), bytes(block))
        ents_crc = binascii.crc32(bytes(block)) & 0xFFFFFFFF
        h = self.hdr[which]
        self._fix_header(h, ents_crc)
        self._pwrite(self._hdr_off(which), bytes(h))

    def fsync(self):
        os.fsync(self.fd)

    def close(self):
        os.close(self.fd)

    # ---- high level ------------------------------------------------
    def cmd_show(self):
        print(f"{self.src}: sector={self.sector} nent={self.nent} esz={self.entsz} "
              f"prim_entries_lba={self.p_lba} backup_entries_lba={self.b_lba}")
        for k, name, block, ent, ab in self.iter_entries():
            if name.endswith("_a") or name.endswith("_b"):
                d = decode(ab)
                print(f"  {name:18s} byte6={d['raw']:>4s} retry={d['retry']} "
                      f"active={int(d['active'])} succ={int(d['successful'])} "
                      f"unbootable={int(d['unbootable'])}")

    def patch_slot(self, slot, retry, active, successful, unbootable, dry_run):
        name = "boot_" + slot
        changed = {}
        for which in ("primary", "backup"):
            block, k = self.find(name, which)
            if k is None:
                print(f"  ! {name} not found in {which} GPT", file=sys.stderr)
                continue
            off = k * self.entsz + 48 + AB_OFF
            old = block[off]
            new = encode(old, retry, active, successful, unbootable)
            block[off] = new
            changed[which] = (block, old, new)
            print(f"  {which:7s} {name} byte6: 0x{old:02x} -> 0x{new:02x}")
        if not changed:
            # 旧行为：静默 rc=0 并打印「written」——分区名/LUN 选错时等于什么都没做。
            raise SystemExit(f"{name}: 主备两表都没有该条目 —— 拒绝静默成功"
                             f"（默认 --device /dev/sde = LUN4；用 show 核对）")
        if len(changed) != 2:
            raise SystemExit(f"{name}: 只有 {'/'.join(sorted(changed))} 表有该条目 —— "
                             f"主备表不成对，拒绝写入")
        if dry_run:
            print("  (dry-run: nothing written)")
            return
        # 写序：先备表后主表。断电窗口里至少还剩一张自洽的表可被 ABL 使用。
        for which in ("backup", "primary"):
            self.write_entries(which, changed[which][0])
        self.fsync()
        self._verify(changed)
        print("  written + CRCs fixed + read-back verified (primary & backup)")

    def _verify(self, changed):
        """写后读回（P0）：entries 逐字节 + header 里的 entries CRC。"""
        for which, (block, _old, _new) in changed.items():
            cur = self._pread(self._entries_off(which), self.nent * self.entsz)
            if cur != bytes(block):
                raise SystemExit(f"{self.src}: {which} entries 读回不一致（写丢/被内核改？）")
            h = self._pread(self._hdr_off(which), self.hdr_size)
            if h[:8] != b"EFI PART":
                raise SystemExit(f"{self.src}: {which} header 读回无 GPT 签名")
            if struct.unpack("<I", h[88:92])[0] != binascii.crc32(bytes(block)) & 0xFFFFFFFF:
                raise SystemExit(f"{self.src}: {which} header 的 entries CRC 读回不符")
            # header CRC 自验（R1）：crc 域自身置 0 后整体算。
            hdr_crc = binascii.crc32(bytes(h[:16]) + b"\0\0\0\0" + bytes(h[20:])) & 0xFFFFFFFF
            if struct.unpack_from("<I", h, 16)[0] != hdr_crc:
                raise SystemExit(f"{self.src}: {which} header CRC 读回不符（表头被写坏）")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--image", help="full GPT image file (LBA0-based) instead of a device")
    ap.add_argument("--device", default="/dev/sde", help="device node (default /dev/sde = LUN4 boot LUN)")
    ap.add_argument("--sector", type=int, default=SECTOR_DEFAULT)
    common = argparse.ArgumentParser(add_help=False)
    # default=SUPPRESS so the subparser copy does not override the global flag
    common.add_argument("--dry-run", action="store_true", default=argparse.SUPPRESS)
    ap.add_argument("--dry-run", action="store_true")
    sub = ap.add_subparsers(dest="cmd", required=True)

    sub.add_parser("show", parents=[common])

    p_set = sub.add_parser("set", help="patch the slot's boot_* attribute byte",
                           parents=[common])
    p_set.add_argument("slot", choices=["a", "b"])
    p_set.add_argument("--retry", type=int, choices=range(0, 8))
    p_set.add_argument("--active", dest="active", action="store_true", default=None)
    p_set.add_argument("--no-active", dest="active", action="store_false")
    p_set.add_argument("--successful", dest="succ", action="store_true", default=None)
    p_set.add_argument("--no-successful", dest="succ", action="store_false")
    p_set.add_argument("--unbootable", dest="unb", action="store_true", default=None)
    p_set.add_argument("--no-unbootable", dest="unb", action="store_false")

    p_ok = sub.add_parser("mark-successful", help="active + successful + retry=7",
                          parents=[common])
    p_ok.add_argument("slot", choices=["a", "b"])

    a = ap.parse_args()
    src = a.image or a.device
    g = Gpt(src, sector=a.sector, writable=(a.cmd != "show" and not a.dry_run))
    try:
        if a.cmd == "show":
            g.cmd_show()
        elif a.cmd == "set":
            g.patch_slot(a.slot, a.retry, a.active, a.succ, a.unb, a.dry_run)
        elif a.cmd == "mark-successful":
            g.patch_slot(a.slot, retry=7, active=True, successful=True,
                         unbootable=False, dry_run=a.dry_run)
    finally:
        g.close()


if __name__ == "__main__":
    main()
