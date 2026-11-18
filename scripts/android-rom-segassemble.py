#!/usr/bin/env python3
"""android-rom-segassemble.py — 把线刷包里「一个分区被拆成多段」的 img 按 XML 拼回整分区镜像。

典型用途：`metadata`（/metadata，f2fs）在 rawprogram_save_persist_unsparse0.xml 里被拆成
metadata_1..8.img 写在递增 LBA 上；拼回来才能 dump.f2fs 看里面有没有未完成的更新/快照状态。

只读 XML 与包内 img；只写 --out 指定的一个文件（默认 out/android-min-avb-20261118/）。
空洞（段与段之间的 LBA 间隔）按 0 填充（用 truncate 保持稀疏）。

用法：
  scripts/android-rom-segassemble.py --xml backup/official-rom-15.10.259/rawprogram_save_persist_unsparse0.xml \
      --label metadata --out out/android-min-avb-20261118/metadata.img
  scripts/android-rom-segassemble.py --xml ...xml --list          # 列出该 XML 里所有 label 及其段
"""
import argparse
import os
import re
import shutil
import subprocess
import sys

ROM = "/home/xuqianhui/y700-elden/backup/official-rom-15.10.259"


def parse(xml_path, label=None):
    txt = open(xml_path, encoding="utf-8", errors="replace").read()
    rows = []
    for m in re.finditer(r"<program\b[^>]*/?>", txt):
        t = m.group(0)

        def g(k):
            mm = re.search(k + r'="([^"]*)"', t)
            return mm.group(1) if mm else ""

        lab = g("label")
        if label is not None and lab != label:
            continue
        rows.append(dict(label=lab, filename=g("filename"),
                         start=int(g("start_sector") or 0),
                         nsec=int(g("num_partition_sectors") or 0),
                         lun=g("physical_partition_number"),
                         ssz=int(g("SECTOR_SIZE_IN_BYTES") or 4096)))
    rows.sort(key=lambda r: r["start"])
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--xml", default=os.path.join(ROM, "rawprogram_save_persist_unsparse0.xml"))
    ap.add_argument("--label")
    ap.add_argument("--out")
    ap.add_argument("--rom", default=ROM)
    ap.add_argument("--list", action="store_true")
    a = ap.parse_args()

    rows = parse(a.xml, a.label)
    if not rows:
        raise SystemExit("没有匹配的 program 条目")
    if a.list:
        for r in rows:
            print("%-18s %-20s start=%-10d nsec=%-8d ssz=%d lun=%s"
                  % (r["label"], r["filename"] or "(空)", r["start"], r["nsec"], r["ssz"], r["lun"]))
        return 0
    if not a.out:
        raise SystemExit("需要 --out")
    start0 = rows[0]["start"]
    ssz = rows[0]["ssz"]
    size = (rows[-1]["start"] + rows[-1]["nsec"] - start0) * ssz
    os.makedirs(os.path.dirname(a.out) or ".", exist_ok=True)
    with open(a.out, "wb") as out:
        out.truncate(size)          # 稀疏文件，空洞读完就是 0
    for r in rows:
        if not r["filename"]:
            print("  [skip] start=%d 无文件名（该段不上写）" % r["start"])
            continue
        src = os.path.join(a.rom, r["filename"])
        off = (r["start"] - start0) * r["ssz"]
        n = r["nsec"] * r["ssz"]
        with open(src, "rb") as f:
            data = f.read()
        with open(a.out, "r+b") as out:
            out.seek(off)
            out.write(data[:n])
        print("  [ok] %-20s -> off=%9d len=%9d (file %d)" % (r["filename"], off, min(n, len(data)), len(data)))
    print("[assemble] %s  size=%d (%.2f MiB) sparse=%s"
          % (a.out, size, size / 2 ** 20,
             subprocess.run(["du", "-h", "--apparent-size", a.out],
                            capture_output=True, text=True).stdout.split("\t")[0]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
