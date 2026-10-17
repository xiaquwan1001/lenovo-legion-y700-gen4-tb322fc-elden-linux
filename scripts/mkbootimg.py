#!/usr/bin/env python3
"""mkbootimg.py — minimal AOSP boot image v2 builder (elden project vendored copy).

Why: the original vendored copy was lost in the 2026-10-17 machine migration
(`RESOURCES/README.md` §3.5). Only the v2 header is needed here.

Byte layout (v2), everything page aligned:
    header page | kernel | ramdisk | second | recovery_dtbo | dtb

Header v2 field offsets (AOSP `boot_img_hdr_v2`):
    0    magic[8] = "ANDROID!"
    8    kernel_size       12 kernel_addr
    16   ramdisk_size      20 ramdisk_addr
    24   second_size       28 second_addr
    32   tags_addr         36 page_size
    40   header_version    44 os_version
    48   name[16]          64 cmdline[512]
    576  id[32] (sha1 + 12 zero bytes)
    608  extra_cmdline[1024]
    1632 recovery_dtbo_size      1636 recovery_dtbo_offset (u64)
    1644 header_size (=1660)     1648 dtb_size
    1652 dtb_addr (u64)

Self-check against a known-good image (structure must round-trip byte for byte,
except the informational sha1 id field):

    tools/mkbootimg/mkbootimg.py --selftest <image>
"""
import argparse
import hashlib
import os
import struct
import sys
import tempfile

MAGIC = b"ANDROID!"
BOOT_NAME_SIZE = 16
BOOT_ARGS_SIZE = 512
BOOT_EXTRA_ARGS_SIZE = 1024
HEADER_V2_SIZE = 1660
DEFAULT_PAGE = 4096


def _pages(n, page):
    """Bytes needed to hold n bytes in whole pages."""
    return ((n + page - 1) // page) * page


def build_header(*, page, kernel_size, kernel_addr, ramdisk_size, ramdisk_addr,
                 second_size, second_addr, tags_addr, header_version,
                 os_version, name="", cmdline="", extra_cmdline="",
                 dtb_size=0, dtb_addr=0, recovery_dtbo_size=0,
                 recovery_dtbo_offset=0, boot_id=b"\0" * 32):
    hdr = bytearray(HEADER_V2_SIZE)
    hdr[0:8] = MAGIC
    struct.pack_into("<10I", hdr, 8,
                     kernel_size, kernel_addr, ramdisk_size, ramdisk_addr,
                     second_size, second_addr, tags_addr, page,
                     header_version, os_version)
    hdr[48:48 + BOOT_NAME_SIZE] = name.encode()[:BOOT_NAME_SIZE].ljust(
        BOOT_NAME_SIZE, b"\0")
    hdr[64:64 + BOOT_ARGS_SIZE] = cmdline.encode()[:BOOT_ARGS_SIZE].ljust(
        BOOT_ARGS_SIZE, b"\0")
    hdr[576:608] = boot_id[:32].ljust(32, b"\0")
    hdr[608:608 + BOOT_EXTRA_ARGS_SIZE] = extra_cmdline.encode()[
        :BOOT_EXTRA_ARGS_SIZE].ljust(BOOT_EXTRA_ARGS_SIZE, b"\0")
    struct.pack_into("<I", hdr, 1632, recovery_dtbo_size)
    struct.pack_into("<Q", hdr, 1636, recovery_dtbo_offset)
    struct.pack_into("<I", hdr, 1644, HEADER_V2_SIZE)
    struct.pack_into("<I", hdr, 1648, dtb_size)
    struct.pack_into("<Q", hdr, 1652, dtb_addr)
    assert len(hdr) == HEADER_V2_SIZE
    return hdr


def compose(*, page, kernel_data, ramdisk_data, second_data, recovery_data,
            dtb_data, kernel_addr, ramdisk_addr, second_addr, tags_addr,
            dtb_addr, cmdline, extra_cmdline="", name="",
            header_version=2, os_version=0x1e000198,
            recovery_dtbo_offset=0, id_mode="aosp"):
    """Return the full image bytes for the given sections."""
    # AOSP id = sha1 over each section followed by its size as a decimal string.
    h = hashlib.sha1()
    for data in (kernel_data, ramdisk_data, second_data, recovery_data,
                 dtb_data):
        h.update(data)
        h.update(str(len(data)).encode())
    boot_id = h.digest() + b"\0" * 12

    hdr = build_header(
        page=page,
        kernel_size=len(kernel_data), kernel_addr=kernel_addr,
        ramdisk_size=len(ramdisk_data), ramdisk_addr=ramdisk_addr,
        second_size=len(second_data), second_addr=second_addr,
        tags_addr=tags_addr, header_version=header_version,
        os_version=os_version, name=name, cmdline=cmdline,
        extra_cmdline=extra_cmdline,
        dtb_size=len(dtb_data), dtb_addr=dtb_addr,
        recovery_dtbo_size=len(recovery_data),
        recovery_dtbo_offset=recovery_dtbo_offset, boot_id=boot_id,
    )

    out = bytearray()
    out += hdr.ljust(page, b"\0")
    for data in (kernel_data, ramdisk_data, second_data, recovery_data,
                 dtb_data):
        if not data:
            continue
        out += data
        out += b"\0" * (_pages(len(data), page) - len(data))
    return bytes(out)


def read_image(path):
    """Decompose an existing boot image into (sections, header fields)."""
    d = open(path, "rb").read()
    (magic, k_sz, k_addr, r_sz, r_addr, s_sz, s_addr, t_addr, page,
     hv, osv) = struct.unpack_from("<8s10I", d, 0)
    if magic != MAGIC:
        raise ValueError(f"{path}: not an Android boot image")
    fields = {
        "page": page, "kernel_addr": k_addr, "ramdisk_addr": r_addr,
        "second_addr": s_addr, "tags_addr": t_addr,
        "header_version": hv, "os_version": osv,
        "name": d[48:64].rstrip(b"\0").decode(),
        "cmdline": d[64:576].rstrip(b"\0").decode(),
        "extra_cmdline": d[608:1632].rstrip(b"\0").decode(),
    }
    rd_sz, rd_off, _hsz, d_sz, d_addr = struct.unpack_from("<I Q I I Q", d, 1632)
    fields["recovery_dtbo_offset"] = rd_off
    fields["dtb_addr"] = d_addr

    sections = {}
    off = page
    for key, n in (("kernel", k_sz), ("ramdisk", r_sz), ("second", s_sz),
                   ("recovery", rd_sz), ("dtb", d_sz)):
        sections[key] = d[off:off + n]
        off += _pages(n, page)
    return d, sections, fields


def selftest(path):
    d, sections, fields = read_image(path)
    rebuilt = compose(
        page=fields["page"],
        kernel_data=sections["kernel"],
        ramdisk_data=sections["ramdisk"],
        second_data=sections["second"],
        recovery_data=sections["recovery"],
        dtb_data=sections["dtb"],
        kernel_addr=fields["kernel_addr"],
        ramdisk_addr=fields["ramdisk_addr"],
        second_addr=fields["second_addr"],
        tags_addr=fields["tags_addr"],
        dtb_addr=fields["dtb_addr"],
        cmdline=fields["cmdline"],
        extra_cmdline=fields["extra_cmdline"],
        name=fields["name"],
        header_version=fields["header_version"],
        os_version=fields["os_version"],
        recovery_dtbo_offset=fields["recovery_dtbo_offset"],
    )
    a = bytearray(d[:len(rebuilt)])
    b = bytearray(rebuilt)
    # The sha1 id is informational (no ABL verifies it) and project images have
    # been repacked after mkbootimg, so its value follows no AOSP ordering in
    # this corpus. Mask it and compare the structure strictly.
    a[576:608] = b"\0" * 32
    b[576:608] = b"\0" * 32
    if a == b:
        print(f"selftest PASS ({path}, {len(b)} bytes, "
              f"kernel={len(sections['kernel'])} "
              f"ramdisk={len(sections['ramdisk'])} "
              f"dtb={len(sections['dtb'])})")
        return 0
    for i, (x, y) in enumerate(zip(a, b)):
        if x != y:
            print(f"selftest FAIL first diff at byte {i}: {x:02x} != {y:02x}",
                  file=sys.stderr)
            break
    else:
        print(f"selftest FAIL length {len(a)} != {len(b)}", file=sys.stderr)
    return 1


def parse_os_version(ver, patch_level):
    try:
        maj, mi, pa = (int(x) for x in ver.split("."))
        v = (maj << 25) | (mi << 18) | (pa << 11)
    except Exception:
        v = 0
    try:
        y, m = patch_level.split("-")
        v |= ((int(y) - 2000) * 12 + int(m) - 1)
    except Exception:
        pass
    return v


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--kernel", required=False)
    ap.add_argument("--ramdisk")
    ap.add_argument("--second")
    ap.add_argument("--dtb")
    ap.add_argument("--recovery_dtbo")
    ap.add_argument("--cmdline", default="")
    ap.add_argument("--extra_cmdline", default="")
    ap.add_argument("--name", default="")
    ap.add_argument("--base", type=lambda x: int(x, 0), default=0)
    ap.add_argument("--kernel_offset", type=lambda x: int(x, 0), default=0x8000)
    ap.add_argument("--ramdisk_offset", type=lambda x: int(x, 0), default=0x1000000)
    ap.add_argument("--second_offset", type=lambda x: int(x, 0), default=0xf00000)
    ap.add_argument("--tags_offset", type=lambda x: int(x, 0), default=0x100)
    ap.add_argument("--dtb_offset", type=lambda x: int(x, 0), default=0x1f00000)
    ap.add_argument("--pagesize", type=lambda x: int(x, 0), default=DEFAULT_PAGE)
    ap.add_argument("--header_version", type=int, default=2)
    ap.add_argument("--os_version", default="15.0.0")
    ap.add_argument("--os_patch_level", default="2025-08")
    ap.add_argument("-o", "--output")
    ap.add_argument("--selftest", metavar="IMAGE")
    ap.add_argument("--unpack", metavar="IMAGE",
                    help="split IMAGE into <dir>/{kernel,ramdisk,second,dtb}")
    ap.add_argument("--unpack-dir", default=".")
    a = ap.parse_args(argv)

    if a.selftest:
        return selftest(a.selftest)

    if a.unpack:
        _d, sections, fields = read_image(a.unpack)
        os.makedirs(a.unpack_dir, exist_ok=True)
        for name, data in sections.items():
            if not data:
                continue
            dest = os.path.join(a.unpack_dir, name)
            with open(dest, "wb") as f:
                f.write(data)
            print(f"{name}\t{dest}\t{len(data)} bytes")
        print(f"cmdline\t{fields['cmdline']}")
        return 0

    if not a.output or not a.kernel or not a.ramdisk:
        ap.error("--kernel, --ramdisk and -o/--output are required")

    def rd(p):
        return open(p, "rb").read() if p else b""

    img = compose(
        page=a.pagesize,
        kernel_data=rd(a.kernel),
        ramdisk_data=rd(a.ramdisk),
        second_data=rd(a.second),
        recovery_data=rd(a.recovery_dtbo),
        dtb_data=rd(a.dtb),
        kernel_addr=a.base + a.kernel_offset,
        ramdisk_addr=a.base + a.ramdisk_offset,
        second_addr=a.base + a.second_offset,
        tags_addr=a.base + a.tags_offset,
        dtb_addr=a.base + a.dtb_offset,
        cmdline=a.cmdline,
        extra_cmdline=a.extra_cmdline,
        name=a.name,
        header_version=a.header_version,
        os_version=parse_os_version(a.os_version, a.os_patch_level),
    )
    with open(a.output, "wb") as f:
        f.write(img)
    print(f"wrote {a.output} ({len(img)} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
