#!/usr/bin/env python3
"""Cross-check the SM8750 lane table in 0002 against (a) the vendor
csiphy_2ph_v2_4_0_reg blob and (b) lane_regs_x1e80100 in gh/master.

Usage: verify-table.py <patched phy-qcom-mipi-csi2-3ph-dphy.c> <base 3ph.c> <camera.ko>
"""
import re
import struct
import subprocess
import sys

PT = {'CSIPHY_DEFAULT_PARAMS': 'DEFAULT',
      'CSIPHY_SETTLE_CNT_LOWER_BYTE': 'SETTLE',
      'CSIPHY_SKEW_CAL': 'SKEW'}


def parse_table(text, name):
    m = re.search(r'mipi_csi2phy_lane_regs %s\[\] = \{\n(.*?)\n\};' % name, text, re.S)
    out = []
    for body in re.findall(r'\{(.*?)\}', m.group(1), re.S):
        d = dict(re.findall(r'\.(reg_addr|reg_data|delay_us|param_type)\s*=\s*'
                            r'(0x[0-9a-fA-F]+|CSIPHY_\w+)', body))
        out.append((int(d['reg_addr'], 16), int(d['reg_data'], 16),
                    int(d.get('delay_us', '0x0'), 16), PT[d['param_type']]))
    return out


def main():
    new = open(sys.argv[1]).read()
    base = open(sys.argv[2]).read()
    ko = sys.argv[3]

    sm8750 = parse_table(new, 'lane_regs_sm8750')
    x1e = parse_table(base, 'lane_regs_x1e80100')
    print('lane_regs_sm8750 entries: %d (2ph power-up %d + data/clock lanes %d)' % (
        len(sm8750), sum(1 for e in sm8750 if e[0] in (0x1018, 0x101c)),
        sum(1 for e in sm8750 if e[0] not in (0x1018, 0x101c))))
    print('lane_regs_x1e80100 entries: %d' % len(x1e))

    x1e_rest = [e for e in x1e if e[0] not in (0x1018, 0x101c)]
    sm_rest = [e for e in sm8750 if e[0] not in (0x1018, 0x101c)]

    print('\n-- sm8750 vs x1e80100 (ordered) --')
    same_addr = [a[0] for a in x1e_rest] == [a[0] for a in sm_rest]
    print('address sequence identical: %s' % same_addr)
    diffs = [(a, b) for a, b in zip(x1e_rest, sm_rest) if a != b]
    for a, b in diffs:
        print('  %#06x  x1e=%#04x/%-8s delay=%d -> sm8750=%#04x/%-8s delay=%d' % (
            a[0], a[1], a[3], a[2], b[1], b[3], b[2]))
    print('differing entries: %d' % len(diffs))

    # vendor blob
    sym = subprocess.run(['readelf', '-sW', ko], capture_output=True, text=True).stdout
    sec = subprocess.run(['readelf', '-SW', ko], capture_output=True, text=True).stdout
    addr = size = None
    for line in sym.splitlines():
        f = line.split()
        if f and f[-1] == 'csiphy_2ph_v2_4_0_reg':
            addr, size = int(f[1], 16), int(f[2])
    off = int([l for l in sec.splitlines() if ' .data ' in l][0].split()[4], 16)
    with open(ko, 'rb') as fh:
        fh.seek(off + addr)
        raw = fh.read(size)
    vendor = [struct.unpack_from('<4I', raw, i * 16) for i in range(size // 16)]
    print('\n-- vendor csiphy_2ph_v2_4_0_reg: %d entries, .data file offset %#x, vaddr %#x --'
          % (len(vendor), off + addr, addr))

    # map vendor param_type ids: 1 = DEFAULT, 2 = SETTLE_CNT_LOWER_BYTE, 7 = SKEW_CAL
    idmap = {1: 'DEFAULT', 2: 'SETTLE', 7: 'SKEW', 64: 'SKEW', 4: 'SETTLE'}
    vend = [(v[0], v[1], ('SKEW' if idmap.get(v[3]) == 'SKEW' else idmap.get(v[3])),
             v[2]) for v in vendor]
    sm_set = sorted((e[0], e[1], e[3]) for e in sm_rest)
    vd_set = sorted((e[0], e[1], e[2]) for e in vend)
    print('address set equal (sm8750 vs vendor): %s'
          % (sorted(e[0] for e in sm_rest) == sorted(e[0] for e in vend)))
    print('(addr,data,type) multiset equal: %s' % (sm_set == vd_set))
    for a, b in zip(vd_set, sm_set):
        if a != b:
            print('  vendor %#06x=%#04x/%-8s  sm8750 %#06x=%#04x/%-8s'
                  % (a[0], a[1], a[2], b[0], b[1], b[2]))
    # delay/mask field: vendor mask of the delayed entry must be 0xd1 -> delay_us 1
    print('vendor entries with non-zero mask field: %s'
          % ['%#06x->%#x' % (v[0], v[2]) for v in vendor if v[2]])
    print('sm8750 entries with non-zero delay_us: %s'
          % ['%#06x->%#x' % (e[0], e[2]) for e in sm_rest if e[2]])


main()
