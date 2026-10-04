#!/usr/bin/env bash
# grubfat-inspect.sh — 引导链取证（四代 TB322FC / 三代 TB321FU 通用，可参考 BOOTCHAIN-2026-10-05）
#
# 用法:
#   scripts/grubfat-inspect.sh <boot.img>            # 解析 Android boot 头 + UEFI 载荷
#   scripts/grubfat-inspect.sh <abl.elf|uefi.elf|...># 解 FV / LZMA 段并 grep 引导关键字
#   scripts/grubfat-inspect.sh <firmware-dir>        # 遍历目录里的 abl*/uefi*/imagefv*/boot.img
#
# 纯主机侧、只读。依赖: python3（stdlib: struct/lzma）+ strings。
# 结论口径见 archive/topics/BOOTCHAIN-2026-10-05.md（只增不改）。
set -euo pipefail

usage() { sed -n '2,12p' "$0"; exit 1; }
[ $# -ge 1 ] || usage
TARGET=$1

PY=$(command -v python3) || { echo "need python3" >&2; exit 1; }

inspect_one() {
  local f=$1
  [ -f "$f" ] || return 0
  echo "==================================================================="
  echo "FILE: $f  ($(stat -c%s "$f") B)"
  sha256sum "$f" 2>/dev/null | sed 's/^/  sha256 /'
  "$PY" - "$f" <<'PYEOF'
import sys, struct, gzip, lzma, re, os
fn=sys.argv[1]
d=open(fn,'rb').read()

def peek_boot(d):
    if d[:8]!=b'ANDROID!':
        return False
    hv=struct.unpack('<I',d[0x28:0x2c])[0]
    print(f"  [Android boot] magic=ANDROID! header_version={hv}")
    if hv>=3:
        ks=struct.unpack('<I',d[8:12])[0]; rs=struct.unpack('<I',d[12:16])[0]
        hsz=struct.unpack('<I',d[20:24])[0]
        cmd=d[0x2c:0x2c+1536].split(b'\0')[0]
        koff=((hsz+4095)//4096)*4096
    else:
        ks=struct.unpack('<I',d[8:12])[0]; rs=struct.unpack('<I',d[16:20])[0]
        ps=struct.unpack('<I',d[36:40])[0] or 4096
        cmd=d[64:64+512].split(b'\0')[0]; koff=ps
    print(f"    kernel_size={ks} ramdisk_size={rs} cmdline={cmd[:160]!r}")
    k=d[koff:koff+ks]
    print(f"    kernel first bytes={k[:8].hex()} gzip={k[:2]==b'\\x1f\\x8b'}")
    dec=k
    if k[:2]==b'\x1f\x8b':
        try: dec=gzip.decompress(k); print(f"    -> gzip decompressed {len(dec)} B")
        except Exception as e: print("    gzip err",e)
    if len(dec)>=64:
        code0=struct.unpack('<I',dec[0:4])[0]
        magic=struct.unpack('<I',dec[56:60])[0]
        print(f"    code0=0x{code0:x}  magic@56=0x{magic:x} "
              f"({'arm64 Image (ARMd)' if magic==0x644d5241 else 'NOT arm64 Image'})")
    idx=dec.find(b'_FVH')
    print(f"    UEFI FV '_FVH'@ payload {idx}  (PE/MZ count {dec.count(b'MZ')})")
    if magic==0x644d5241 and idx>=0:
        print("    => [判定] 该 boot.img 内核段是一个'arm64 壳 + 内嵌 UEFI 卷'（三代 GUF296 同构）")
    return True

LZMA_GUID=bytes.fromhex('98584eee143959429d6edc7bd79403cf')

def lzma_try(data):
    # data should begin at the LZMA stream header. Try alone-format then raw;
    # pick the candidate that actually looks like firmware (not a fill run).
    cands=[]
    try:
        cands.append(lzma.LZMADecompressor(format=lzma.FORMAT_ALONE).decompress(data[:8_000_000]))
    except Exception: pass
    if len(data)>=13:
        p=data[0:5]
        p0=p[0]; lc=p0%9; p0//=9; lp=p0%5; pb=p0//5
        ds=struct.unpack('<I',p[1:5])[0]
        filt=[{'id':lzma.FILTER_LZMA1,'lc':lc,'lp':lp,'pb':pb,'dict_size':max(ds,4096)}]
        try:
            cands.append(lzma.LZMADecompressor(format=lzma.FORMAT_RAW,filters=filt).decompress(data[13:13+8_000_000]))
        except Exception: pass
    best=None; bs=-1
    for dec in cands:
        if not dec or len(dec)<=512: continue
        # plausibility: fraction of the single most-common byte must be < 0.5
        from collections import Counter
        top=Counter(dec).most_common(1)[0][1]/len(dec)
        score=(dec.count(b'MZ')+5*dec.count(b'_FVH'))*(1 if top<0.5 else 0)
        if score>bs: bs=score; best=dec
    return best if best and bs>0 else None
def walk_sections(fv, base, size, out_parts, depth):
    so=base; end=base+size
    while so+4<=end:
        ssz=fv[so]|(fv[so+1]<<8)|(fv[so+2]<<16); st=fv[so+3]
        if ssz<4 or so+ssz>end: break
        if st==0x02:  # GUID_DEFINED
            guid=fv[so+4:so+20]
            if len(guid)==16 and guid==LZMA_GUID:
                doff=struct.unpack('<H',fv[so+20:so+22])[0]
                for c in (so+doff, so+doff-4, so+24, so+4):
                    if c<so or c>=so+ssz: continue
                    dec=lzma_try(fv[c:so+ssz])
                    if dec:
                        print("  "*depth+f"      [LZMA] GUID section -> {len(dec)} B")
                        out_parts.append(dec); walk_fv(dec, out_parts, depth+1)
                        break
        elif st==0x1b:  # nested FV image
            sub=fv[so+4:so+ssz]
            print("  "*depth+f"      [nested FV section {len(sub)} B]")
            out_parts.append(sub); walk_fv(sub, out_parts, depth+1)
        so+=(ssz+3)&~3

def walk_fv(fv, out_parts, depth=0):
    if len(fv)<56 or fv[40:44]!=b'_FVH':
        return
    FvLength=struct.unpack('<Q',fv[32:40])[0]
    hdrlen=struct.unpack('<H',fv[48:50])[0]
    if FvLength>len(fv): FvLength=len(fv)
    off=hdrlen; n=0
    while off+24<=FvLength:
        g=fv[off:off+16]
        if g in (b'\xff'*16,b'\x00'*16): break
        ft=fv[off+18]; sz=fv[off+20]|(fv[off+21]<<8)|(fv[off+22]<<16)
        if sz<24 or off+sz>FvLength: break
        print("  "*depth+f"    FFS[type {ft:#x} size {sz}]")
        walk_sections(fv, off+24, sz-24, out_parts, depth)
        n+=1; off+=(sz+7)&~7

parts=[]
if peek_boot(d):
    pass
# FV discovery anywhere in file
i=d.find(b'_FVH')
if i>=0:
    start=i-40
    print(f"  [FV] '_FVH'@file {i}; parsing from {start}")
    out=[]
    walk_fv(d[start:], out)
    parts=out
if parts:
    blob=b''.join(parts)
    print(f"  [decoded {len(blob)} B] grep boot keywords:")
    kws=[b'LinuxLoader',b'Bds',b'BDS',b'SimpleFileSystem',b'PartitionDxe',b'Fat',
         b'UFSDxe',b'Boot Manager',b'Boot0000',b'DefaultBDSBootApp',
         b'KERNEL64_HDR_MAGIC',b'LoadImageFromPartition',b'RAMPARTITION',
         b'Android!',b'ANDROID!',b'EFI/BOOT',b'BOOTAA64',b'grub']
    for kw in kws:
        c=blob.count(kw)
        if c: print(f"      {c:>4}  {kw.decode(errors='replace')}")
    if b'0x10000381' in blob or bytes.fromhex('81030010') in blob:
        print("      [note] 0x10000381 字面量存在")
PYEOF
}

if [ -d "$TARGET" ]; then
  for f in "$TARGET"/abl*.elf "$TARGET"/uefi*.elf "$TARGET"/imagefv*.elf \
           "$TARGET"/tools.fv "$TARGET"/boot.img; do
    [ -f "$f" ] && inspect_one "$f"
  done
else
  inspect_one "$TARGET"
fi
