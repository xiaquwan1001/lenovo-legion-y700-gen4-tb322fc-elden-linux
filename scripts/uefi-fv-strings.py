#!/usr/bin/env python3
"""uefi-fv-strings.py — 在 UEFI FD 的**内层（LZMA 压缩的）FVMAIN** 里搜 ASCII 字串。

为什么需要它：本树的 FD 只有 4 MiB，真正的内层 FVMAIN 12.8 MiB 被 LZMA 包在外层 FV 的
GUIDed section 里（`grep -a`/`strings` 直接搜 FD 必然 0 命中 —— 2026-11-09 踩过）。
判据「补丁是否进了被执行的那份二进制」必须先解压再搜。

用法：
  scripts/uefi-fv-strings.py <fd> <pattern> [pattern ...]      # 逐条打印命中数（0/1），有命中则退出码 0
  scripts/uefi-fv-strings.py <fd> --dump <out.bin>             # 只写出解压后的内层 FV

复算口径见 reports/uefi-espboot-recursive-dump-rootcause-20261108.md §3。
"""
import lzma
import struct
import sys


def lz_guid():
    mix = lambda b: b[3::-1] + b[5:3:-1] + b[7:5:-1] + b[8:]
    return mix(bytes.fromhex('EE4E5898391442599D6EDC7BD79403CF'))


def _try_alone(payload: bytes):
    d = lzma.LZMADecompressor(format=lzma.FORMAT_ALONE)
    try:
        return d.decompress(payload)
    except lzma.LZMAError:
        return None


def _try_raw(payload: bytes, props_off: int, probe: bytes):
    """EFI_LZMA 自定义头：每 0x10000 字节一个 (packed, unpacked) 对。"""
    import io
    props = probe[props_off:props_off + 5]
    filters = [lzma._decode_filter_properties(lzma.FILTER_LZMA1, props)]
    d = lzma.LZMADecompressor(format=lzma.FORMAT_RAW, filters=filters)
    try:
        return d.decompress(payload)
    except lzma.LZMAError:
        return None


def inner_fv(fd: bytes) -> bytes:
    """扫所有 LZMA GUIDed section，取能解压成功且最大的那份（= 内层 FVMAIN）。"""
    lz = lz_guid()
    best = b''
    off = -1
    while True:
        off = fd.find(lz, off + 1)
        if off < 0:
            break
        # GUID(16) + DataOffset(2) + Attributes(2) => payload starts at off+20
        payload = fd[off + 20:]
        for cand in (_try_alone(payload), _try_raw(payload, 0, payload)):
            if cand and len(cand) > len(best):
                best = cand
    if not best:
        raise SystemExit('no decodable LZMA section found in this FD')
    return best


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    fd = open(sys.argv[1], 'rb').read()
    inner = inner_fv(fd)
    # 解压后的内层 FV 里可能还有第二层压缩（FVMAIN_COMPACT）；再试一次无害。
    if b'\x00\x00\x00\x00' not in inner[:64]:
        pass
    if sys.argv[2] == '--dump':
        open(sys.argv[3], 'wb').write(inner)
        print(f'inner FVMAIN {len(inner)} B -> {sys.argv[3]}')
        return 0
    rc = 0
    for pat in sys.argv[2:]:
        n = inner.count(pat.encode())
        print(f'{n:3d}  {pat}')
        if n == 0:
            rc = 1
    return rc


if __name__ == '__main__':
    sys.exit(main())
