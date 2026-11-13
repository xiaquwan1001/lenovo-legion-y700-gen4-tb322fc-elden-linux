#!/usr/bin/env python3
"""B1 实证：daily 树的 lane_regs_2_4_0 vs vendor camera.ko 的 csiphy_2ph_v2_4_0_reg。
用法：在仓库根跑 `python3 reports/artifacts/b1-csiphy-20261113/diff.py`
输出：条数、地址集合是否相同、数据分歧地址清单（当前应为 4 条 SKEW_CAL 0x005c/0x045c/0x085c/0x0c5c）。"""
import re, struct, subprocess
from collections import defaultdict

REPO = subprocess.run(['git','rev-parse','--show-toplevel'],capture_output=True,text=True).stdout.strip()
KO = f'{REPO}/backup/stock-elden/vendor_dlkm/camera.ko'
SRC = f'{REPO}/build/daily/drivers/media/platform/qcom/camss/camss-csiphy-3ph-1-0.c'

txt = open(SRC).read()
body = re.search(r'csiphy_lane_regs lane_regs_2_4_0\[\]\s*=\s*\{(.*?)\n\};', txt, re.S).group(1)
ours = [(int(m.group(1),16), int(m.group(2),16), int(m.group(3),16), m.group(4))
        for m in re.finditer(r'\{\s*(0x[0-9A-Fa-f]+)\s*,\s*(0x[0-9A-Fa-f]+)\s*,\s*(0x[0-9A-Fa-f]+)\s*,\s*CSIPHY_(\w+)\s*\}', body)]

sym = subprocess.run(['readelf','-sW',KO],capture_output=True,text=True).stdout
val = size = None
for line in sym.splitlines():
    if 'csiphy_2ph_v2_4_0_reg' in line:
        p = line.split(); val = int(p[1],16); size = int(p[2]); break
if val is None: raise SystemExit('找不到符号 csiphy_2ph_v2_4_0_reg')

secs = subprocess.run(['readelf','-SW',KO],capture_output=True,text=True).stdout
for line in secs.splitlines():
    if ' .data ' in line:
        p = line.split(); i = p.index('.data'); addr = int(p[i+2],16); off = int(p[i+3],16); break
f = open(KO,'rb').read(); base = off + (val - addr)
vend = [struct.unpack('<4I', f[base+k*16:base+k*16+16]) for k in range(size//16)]

def grp(rows):
    d = defaultdict(list)
    for r in rows: d[r[0]].append(r[1])
    return {k: sorted(v) for k, v in d.items()}

go, gv = grp(ours), grp(vend)
print(f"ours: {len(ours)} 条 / {len(go)} 地址     vendor: {len(vend)} 条 / {len(gv)} 地址")
print("地址集合相同:", set(go) == set(gv))
diffs = [(a, go[a], gv[a]) for a in sorted(set(go) & set(gv)) if go[a] != gv[a]]
print(f"数据分歧地址数 = {len(diffs)}")
for a, o, v in diffs:
    print(f"  addr=0x{a:04x}: ours={[hex(x) for x in o]} vendor={[hex(x) for x in v]}")
