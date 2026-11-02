#!/usr/bin/env python3
"""uefi-bootimg-dump-v0.py — dump Android boot image v0 header fields (one line per field) + summary.

Usage: uefi-bootimg-dump-v0.py <img> [--json]
Self-test: uefi-bootimg-dump-v0.py --selftest
"""
import struct, sys, json, hashlib


def dump(d: bytes) -> dict:
    magic = d[0:8]
    f = {
        "magic": magic.decode("ascii", "replace"),
        "kernel_size": struct.unpack_from("<I", d, 8)[0],
        "kernel_addr": struct.unpack_from("<I", d, 12)[0],
        "ramdisk_size": struct.unpack_from("<I", d, 16)[0],
        "ramdisk_addr": struct.unpack_from("<I", d, 20)[0],
        "second_size": struct.unpack_from("<I", d, 24)[0],
        "second_addr": struct.unpack_from("<I", d, 28)[0],
        "tags_addr": struct.unpack_from("<I", d, 32)[0],
        "page_size": struct.unpack_from("<I", d, 36)[0],
        "header_version": struct.unpack_from("<I", d, 40)[0],
        "os_version": struct.unpack_from("<I", d, 44)[0],
        "boot_name": d[48:64].rstrip(b"\x00").decode("ascii", "replace"),
        "cmdline": d[64:64 + 512].rstrip(b"\x00").decode("ascii", "replace"),
        "id_sha1": d[576:576 + 20].hex(),
        "extra_cmdline": d[608:608 + 1024].rstrip(b"\x00").decode("ascii", "replace"),
    }
    return f


def main() -> None:
    a = sys.argv[1:]
    if a and a[0] == "--selftest":
        # 最小自测：构造一个 base 0x10000000 / kernel_offset 0x8000 / pagesize 4096 的 v0 头
        h = bytearray(2112)
        h[0:8] = b"ANDROID!"
        struct.pack_into("<I", h, 8, 1000)
        struct.pack_into("<I", h, 12, 0x10008000)
        struct.pack_into("<I", h, 36, 4096)
        f = dump(bytes(h))
        assert f["magic"] == "ANDROID!" and f["kernel_addr"] == 0x10008000
        assert f["page_size"] == 4096 and f["header_version"] == 0
        assert f["ramdisk_size"] == 0 and f["os_version"] == 0
        print("selftest OK")
        return
    img = a[0]
    as_json = "--json" in a
    d = open(img, "rb").read()
    f = dump(d)
    f["file"] = img
    f["file_size"] = len(d)
    f["sha256"] = hashlib.sha256(d).hexdigest()
    if as_json:
        print(json.dumps(f, indent=1))
    else:
        for k in ("magic", "kernel_size", "kernel_addr", "ramdisk_size", "ramdisk_addr",
                  "second_size", "second_addr", "tags_addr", "page_size",
                  "header_version", "os_version", "boot_name", "cmdline", "id_sha1",
                  "extra_cmdline", "file_size", "sha256"):
            v = f[k]
            if isinstance(v, int) and k != "kernel_size" and k != "file_size" and k != "header_version" and k != "page_size":
                print(f"{k}=0x{v:08x}")
            else:
                print(f"{k}={v}")


if __name__ == "__main__":
    main()
