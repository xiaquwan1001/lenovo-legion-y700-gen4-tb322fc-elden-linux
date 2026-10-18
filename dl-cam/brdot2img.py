#!/usr/bin/env python3
"""Minimal OTA block-OTA (*.new.dat.br + *.transfer.list) -> raw ext4 image.

Same layout logic as sdat2img: new.dat is a stream of block payloads consumed in
order by the commands listed in transfer.list; `new` writes the payload blocks at
the given indices, `erase` zero-fills, `zero` writes zeros.

usage: brdot2img.py <transfer.list> <in.dat.br> <out.img>
"""
import sys
import brotli

BLOCK = 4096


def parse_commands(path):
    with open(path) as f:
        lines = [l.strip() for l in f if l.strip()]
    version = int(lines[0])
    total_blocks = int(lines[1])
    cmds = []
    for line in lines[2:]:
        parts = line.split()
        name = parts[0]
        if name in ("erase", "new", "zero"):
            args = parts[1:]
            if name == "new":
                nblocks = int(args[0])
                ranges = []
                for spec in args[1:]:
                    for item in spec.split(","):
                        if item:
                            a, b = item.split("-")
                            ranges.append((int(a), int(b)))
                cmds.append(("new", nblocks, ranges))
            elif name == "erase":
                a, b = args[0].split("-")
                cmds.append(("erase", 0, [(int(a), int(b))]))
            elif name == "zero":
                nblocks = int(args[0])
                a, b = args[1].split("-")
                cmds.append(("zero", nblocks, [(int(a), int(b))]))
    return version, total_blocks, cmds


def main():
    tl, dat, out = sys.argv[1:4]
    version, total_blocks, cmds = parse_commands(tl)
    size = total_blocks * BLOCK
    with brotli.open(dat, "rb") as f, open(out, "wb") as o:
        o.truncate(size)
        pos = 0
        for name, nblocks, ranges in cmds:
            if name == "new":
                for (a, b) in ranges:
                    nb = b - a + 1
                    o.seek(a * BLOCK)
                    o.write(f.read(nb * BLOCK))
                pos += nblocks
            elif name == "zero":
                for (a, b) in ranges:
                    nb = b - a + 1
                    o.seek(a * BLOCK)
                    o.write(b"\0" * (nb * BLOCK))
                pos += nblocks
            # erase: nothing to write (image is already zero/truncated)
    print(f"wrote {out} ({size} bytes, {total_blocks} blocks, version {version})")


if __name__ == "__main__":
    main()
