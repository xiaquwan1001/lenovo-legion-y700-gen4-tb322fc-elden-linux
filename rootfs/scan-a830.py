#!/usr/bin/env python3
"""Count the A830 chip-id patterns the Mesa device table can contain.

Mainline DRM reports 0x0000ffff44050001 for the Adreno 830 in this tablet,
while Mesa ships either the KGSL id (26.0) or the wildcard-without-patchid
id (26.1). Report which of them a given library carries.
"""
import sys

PATTERNS = {
    "26.0 kgsl   0x0000000044050000": bytes.fromhex("0000054400000000"),
    "26.1 wild   0x0000ffff44050000": bytes.fromhex("00000544ffff0000"),
    "target      0x0000ffff44050001": bytes.fromhex("01000544ffff0000"),
}

for path in sys.argv[1:]:
    try:
        data = open(path, "rb").read()
    except OSError as err:
        print(f"{path}: {err}")
        continue
    print(f"== {path} ({len(data)} bytes)")
    for name, pat in PATTERNS.items():
        hits = []
        start = 0
        while True:
            i = data.find(pat, start)
            if i < 0:
                break
            hits.append(i)
            start = i + 1
        print(f"   {name}: {len(hits)} {[hex(h) for h in hits[:6]]}")
