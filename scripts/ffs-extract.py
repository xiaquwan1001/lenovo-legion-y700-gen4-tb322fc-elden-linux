#!/usr/bin/env python3
"""ffs-extract.py — 解厂商 UEFI 固件（FV/FFS/section 递归 + LZMA/GUID 段）

用法:
  scripts/ffs-extract.py <file> [--out DIR] [--grep STR] [--list]

做三件事（纯只读，纯 stdlib）:
  1. 找 FV（`_FVH` 签名 → base = sig-0x28），按 HeaderLength/ExtHeader 跳过头部，线性遍历 FFS。
  2. 每个 FFS 的 section 流递归：支持 `0x01` 压缩段、`0x02` GUID-defined 段（LZMA `EE4E5898…`），
     Tiano（`D42AE6BD…`）无解压器 ⇒ 如实报 unsupported。
  3. 解出的 PE32 落盘并可按字符串过滤（如 UFS.c / ufs_error_log），用于定位厂商 DXE 模块。

背景: `reports/uefi-gunyah-reassess-20261024.md` §1.3 —— 厂商 blob 里 UFS.c 0 命中，因为模块压缩存放。
"""
import sys, os, struct, uuid, lzma, argparse

LZMA_GUID = uuid.UUID('EE4E5898-3914-4259-9D6E-DC7BD79403CF')
TIANO_GUID = uuid.UUID('D42AE6BD-1352-4BFB-909A-CA72A6EAE889')
BROTLI_GUID = uuid.UUID('3D532050-5CDA-4FD0-879E-0F7F630D5AFB')
SECTION_NAMES = {0x01: 'COMPRESSION', 0x02: 'GUID_DEFINED', 0x10: 'PE32', 0x11: 'PIC',
                 0x12: 'TE', 0x13: 'DXE_DEPEX', 0x14: 'VERSION', 0x15: 'UI',
                 0x16: 'COMPAT16', 0x17: 'FV_IMAGE', 0x18: 'FREEFORM', 0x19: 'RAW',
                 0x1b: 'PEI_DEPEX', 0x1c: 'SMM_DEPEX'}
FFS_TYPES = {0x01: 'RAW', 0x02: 'FREEFORM', 0x03: 'SEC', 0x04: 'PEI_CORE', 0x05: 'PEIM',
             0x06: 'DXE_CORE', 0x07: 'DXE_DRIVER', 0x08: 'DXE_RUNTIME', 0x09: 'DXE_SAL',
             0x0a: 'DXE_SMM', 0x0b: 'SMM_CORE', 0x0c: 'MM_STANDALONE', 0x0d: 'MM_CORE',
             0x0e: 'COMBINED_PEIM', 0x0f: 'COMBINED_MM'}
results = []


def u16(b, o): return struct.unpack_from('<H', b, o)[0]
def u32(b, o): return struct.unpack_from('<I', b, o)[0]
def u64(b, o): return struct.unpack_from('<Q', b, o)[0]


def ffs_type_raw(buf, off):
    return buf[off + 0x12]


def walk_sections(buf, start, end, depth, tag, outdir):
    off = start
    while off + 4 <= end:
        size = buf[off] | (buf[off + 1] << 8) | (buf[off + 2] << 16)
        stype = buf[off + 3]
        if size < 4 or off + size > end:
            return
        body = buf[off + 4:off + size]
        name = SECTION_NAMES.get(stype, hex(stype))
        if stype == 0x02 and len(body) >= 20:
            guid = uuid.UUID(bytes_le=body[:16])
            data_off = u16(body, 16)
            attrs = u16(body, 18)
            comp = body[data_off:]
            print(f'{"  "*depth}[sect] {tag} GUID_DEFINED {guid} attr=0x{attrs:04x} payload={len(comp)}')
            inner = None
            if guid == LZMA_GUID:
                try:
                    inner = lzma.decompress(comp, format=lzma.FORMAT_ALONE)
                except Exception as e:
                    print(f'{"  "*depth}  ! lzma fail {type(e).__name__}')
            elif guid == TIANO_GUID:
                print(f'{"  "*depth}  ! Tiano 压缩无纯 py 解压器，跳过')
            elif guid == BROTLI_GUID:
                print(f'{"  "*depth}  ! Brotli 跳过')
            if inner:
                print(f'{"  "*depth}  -> {len(inner)} B')
                sub = os.path.join(outdir, f'{tag}-gdef-{len(inner)}')
                if inner[:4] == b'_FVH' or inner[0x28:0x2c] == b'_FVH':
                    parse_fv(inner, os.path.dirname(sub) or outdir, depth + 1)
                else:
                    walk_sections(inner, 0, len(inner), depth + 1, tag, outdir)
        elif stype == 0x01 and len(body) >= 5:
            ulen = u32(body, 0)
            ctype = body[4]
            print(f'{"  "*depth}[sect] {tag} COMPRESSION ulen={ulen} ctype={ctype}')
        elif stype in (0x10, 0x11, 0x12):
            fn = os.path.join(outdir, f'{tag}-{name}.bin')
            with open(fn, 'wb') as f:
                f.write(body)
            hits = [s for s in (b'UFS.c', b'ufs_error_log', b'UFSSmmuConfig') if s in body]
            print(f'{"  "*depth}[sect] {tag} {name} {len(body)} B -> {fn}' + (f'  HITS={hits}' if hits else ''))
            results.append((tag, name, fn, hits))
        elif stype == 0x15:
            try:
                txt = body.decode('utf-16-le', 'ignore').strip('\x00')
            except Exception:
                txt = ''
            if txt:
                print(f'{"  "*depth}[sect] {tag} UI "{txt}"')
        off += (size + 3) & ~3


def parse_ffs(buf, start, end, polarity, outdir, depth):
    off = start
    n = 0
    free = 0xff if polarity else 0x00
    while off + 24 <= end:
        gname = buf[off:off + 16]
        if gname == bytes([free]) * 16:
            return n
        size = buf[off + 0x14] | (buf[off + 0x15] << 8) | (buf[off + 0x16] << 16)
        ftype = buf[off + 0x12]
        state = buf[off + 0x17]
        if size < 24 or off + size > end or ftype not in FFS_TYPES:
            print(f'{"  "*depth}[ffs] stop @0x{off:x} size={size} type=0x{ffs_type_raw(buf, off):02x}')
            return n
        try:
            u = uuid.UUID(bytes_le=gname)
        except Exception:
            return n
        tag = f'{str(u)[:8]}-{FFS_TYPES[ftype]}'
        print(f'{"  "*depth}[ffs] {tag} {str(u)} type={FFS_TYPES[ftype]} size={size} state=0x{state:02x}')
        walk_sections(buf, off + 24, off + size, depth + 1, tag, outdir)
        n += 1
        off += (size + 7) & ~7
    return n


def parse_fv(buf, outdir, depth=0):
    sig = buf.find(b'_FVH', 0, 0x200) if not (buf[0x28:0x2c] == b'_FVH') else 0x28
    if sig < 0:
        sig = buf.find(b'_FVH')
    if sig < 0:
        print(f'{"  "*depth}! no _FVH')
        return
    base = sig - 0x28
    fvlen = u64(buf, base + 0x20)
    hlen = u16(buf, base + 0x30)
    attr = u32(buf, base + 0x2c)
    ext_off = u16(buf, base + 0x34)
    polarity = bool(attr & 0x800)
    fsguid = uuid.UUID(bytes_le=buf[base + 0x10:base + 0x20])
    print(f'{"  "*depth}[fv] base=0x{base:x} len=0x{fvlen:x} hdr=0x{hlen:x} attr=0x{attr:08x} '
          f'ext=0x{ext_off:x} fsguid={fsguid}')
    # 找到文件区起点：跳 header + ext header 链（若 ext_off 有效）
    start = base + hlen
    if ext_off:
        eo = base + ext_off
        guard = 0
        while eo + 4 <= base + fvlen and guard < 8:
            # 结束标记是单个 u32 0xFFFFFFFF（不是 16 字节）
            if u32(buf, eo) == 0xFFFFFFFF:
                eo += 4
                break
            if eo + 20 > base + fvlen:
                break
            g = buf[eo:eo + 16]
            esz = u32(buf, eo + 16)
            print(f'{"  "*depth}[ext] @0x{eo:x} guid={uuid.UUID(bytes_le=g)} size=0x{esz:x}')
            if esz < 20:
                break
            eo += esz
            guard += 1
        start = max(start, eo)
    # 起点对齐后若仍不是文件头，向前扫描首个可解析的 FFS 头
    if parse_ffs(buf, start, base + fvlen, polarity, outdir, depth) == 0:
        for probe in range(start, min(start + 0x1000, base + fvlen - 24), 4):
            sz = buf[probe + 0x14] | (buf[probe + 0x15] << 8) | (buf[probe + 0x16] << 16)
            if buf[probe + 0x12] in FFS_TYPES and 24 < sz <= base + fvlen - probe:
                g = buf[probe:probe + 16]
                if g not in (b'\xff' * 16, b'\x00' * 16):
                    print(f'{"  "*depth}[fv] resync at 0x{probe:x} (+0x{probe-start:x})')
                    if parse_ffs(buf, probe, base + fvlen, polarity, outdir, depth):
                        break


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('file')
    ap.add_argument('--out', default='/tmp/ffs-out')
    ap.add_argument('--grep', default=None)
    ap.add_argument('--list', action='store_true')
    a = ap.parse_args()
    data = open(a.file, 'rb').read()
    os.makedirs(a.out, exist_ok=True)
    print(f'== {a.file} ({len(data)} B)')
    if data.find(b'_FVH') < 0:
        # 可能是内层单个 LZMA 段（GUID 在 0x1064 之类）：全局扫描 GUID
        hits = []
        i = data.find(LZMA_GUID.bytes_le)
        while i >= 0:
            hits.append(i)
            i = data.find(LZMA_GUID.bytes_le, i + 1)
        print(f'== no FV; LZMA guid at {[hex(h) for h in hits]}')
        for h in hits:
            doff = u16(data, h + 16)
            blob = data[h + doff:]
            try:
                inner = lzma.decompress(blob, format=lzma.FORMAT_ALONE)
            except Exception as e:
                print(f'   @0x{h:x} lzma fail {type(e).__name__}')
                continue
            print(f'   @0x{h:x} -> {len(inner)} B')
            d = os.path.join(a.out, f'lzma-{h:x}')
            os.makedirs(d, exist_ok=True)
            open(os.path.join(d, 'inner.bin'), 'wb').write(inner)
            if inner.find(b'_FVH') >= 0:
                parse_fv(inner, d)
            else:
                print('   inner 无 FV，仅落盘')
        return
    parse_fv(data, a.out)
    print(f'== {len(results)} PE section(s) extracted to {a.out}')
    if a.grep:
        pat = a.grep.encode()
        print(f'== grep "{a.grep}"')
        for tag, name, fn, _ in results:
            body = open(fn, 'rb').read()
            if pat in body:
                print(f'   HIT {tag} {name} {fn} ({len(body)} B)')


if __name__ == '__main__':
    main()
