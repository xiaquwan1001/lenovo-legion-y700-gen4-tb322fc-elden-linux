#!/usr/bin/env python3
"""Repack a Magisk/KSU module zip that uses xz (method 95) into deflate,
so KernelSU's Rust zip reader / toybox unzip can install it.
Content of every file is preserved byte-for-byte (sha256 sidecars stay valid)."""
import sys, os, struct, zipfile, lzma, zlib

def local_data(zf, info):
    f = zf.fp
    f.seek(info.header_offset)
    hdr = f.read(30)
    if hdr[:4] != b'PK\x03\x04':
        raise ValueError('bad local header for '+info.filename)
    nlen, xlen = struct.unpack_from('<HH', hdr, 26)
    f.seek(info.header_offset + 30 + nlen + xlen)
    return f.read(info.compress_size)

def read_entry(zf, info):
    raw = local_data(zf, info)
    m = info.compress_type
    if m == zipfile.ZIP_STORED: return raw
    if m == zipfile.ZIP_DEFLATED: return zlib.decompress(raw, -15)
    if m == 95:  # xz
        return lzma.decompress(raw, format=lzma.FORMAT_XZ)
    if m == 14:  # lzma
        return lzma.decompress(raw)
    if m == 93:  # zstd
        import zstandard
        return zstandard.ZstdDecompressor().decompress(raw, max_output_size=info.file_size)
    raise ValueError('unsupported method %d for %s' % (m, info.filename))

def main(src, dst):
    with zipfile.ZipFile(src) as zf:
        with zipfile.ZipFile(dst, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as out:
            for info in zf.infolist():
                data = read_entry(zf, info)
                zi = zipfile.ZipInfo(info.filename, date_time=info.date_time)
                zi.external_attr = info.external_attr
                zi.internal_attr = info.internal_attr
                zi.create_system = 3
                zi.compress_type = zipfile.ZIP_DEFLATED
                out.writestr(zi, data)
    print('%s -> %s' % (src, dst))

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
