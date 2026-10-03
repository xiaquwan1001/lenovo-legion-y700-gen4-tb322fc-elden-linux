#!/usr/bin/env python3
"""Unpack an Android boot image v3/v4 (init_boot) to a directory.
Handles gzip and LZ4-legacy compressed ramdisks (Magisk-style)."""
import sys, os, struct, subprocess, gzip

def lz4_legacy_decompress(raw):
    import lz4.block
    o=4; out=bytearray()
    while o < len(raw):
        sz=struct.unpack_from('<I',raw,o)[0]; o+=4
        if sz==0: break
        out += lz4.block.decompress(raw[o:o+sz], uncompressed_size=1<<26)
        o+=sz
    return bytes(out)

def main(img, outdir):
    f=open(img,'rb').read()
    assert f[:8]==b'ANDROID!'
    G=lambda o: struct.unpack_from('<I',f,o)[0]
    ks=G(8); rs=G(12); hv=G(40)
    page=4096
    off=page+((ks+page-1)//page)*page
    ram=f[off:off+rs]
    os.makedirs(outdir, exist_ok=True)
    open(os.path.join(outdir,'_header.bin'),'wb').write(f[:page])
    if ram[:2]==b'\x1f\x8b':
        cpio=gzip.decompress(ram)
    elif ram[:4]==bytes.fromhex('02214c18'):
        cpio=lz4_legacy_decompress(ram)
    else:
        raise SystemExit('unknown ramdisk magic %r'%ram[:4])
    open(os.path.join(outdir,'_ramdisk.cpio'),'wb').write(cpio)
    subprocess.run(['cpio','-idm','--quiet'], cwd=outdir, input=cpio, check=True)
    print('unpacked %s -> %s (kernel=%d ramdisk=%d hdr=%d)'%(img,outdir,ks,rs,hv))

if __name__=='__main__':
    main(sys.argv[1], sys.argv[2])
