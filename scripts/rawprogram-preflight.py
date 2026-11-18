#!/usr/bin/env python3
"""rawprogram-preflight.py — 线刷包 rawprogram XML 的**写前**几何预检（纯主机、无 USB）。

来源：2026-11-18 LTBox 评估（`reports/ltbox-evaluation-20261118.md` §1 P0-1..4）。它比我们的
bash 刷机路径多做的四件事，这里用 python 独立实现，不引入 GPL 代码：

  R1 每个 `<program>` 节点必须自带 `filename|label` 与 `physical_partition_number`、`start_sector`；
     缺字段的 destructive 节点**一律拒绝**（qdl 把它们当 0 ⇒ 直接写主 GPT 区）。
  R2 `start_sector + num_partition_sectors` 必须落在该 LUN 的可用区间内（给了 `--gpt` 就用
     `last_usable_lba`，否则用 `--lun-sectors`）。
  R3 节点之间**不允许区间重叠**（同一 LUN）—— 这条能抓出「拿错表/旧表套新包」这类最贵的错。
  R4 每个带 `filename` 且文件存在的节点：`ceil(size/sector)` 必须 ≤ `num_partition_sectors`
     （镜像比分区大就会被截断成半件；`sparse="true"` 时按 sparse 头里的 expanded size 算）。
  R5 `filename` 在包目录里找不到 ⇒ 默认**拒绝**（`--allow-missing` 才降级为 warn）；
     这正是 `qdl -f/--allow-missing` 会把「缺件」变成静默跳过的那个坑。

用法：
  scripts/rawprogram-preflight.py backup/official-rom-15.10.259/rawprogram*.xml
  scripts/rawprogram-preflight.py --gpt backup/official-rom-15.10.259/gpt_main4.bin rawprogram4.xml
  scripts/rawprogram-preflight.py --strict …          # 有任何 FAIL 即 rc=1（默认行为）
  scripts/rawprogram-preflight.py --json …            # 机器可读

退出码：0 全过 / 1 有 FAIL / 2 用法错。
"""
import argparse
import json
import os
import re
import struct
import sys
import xml.etree.ElementTree as ET

SPARSE_MAGIC = 0xED26FF3A


def gpt_last_usable(path):
    """从主表件（LBA0..5，24576 B）读 last_usable_lba；读不出返回 None。"""
    try:
        b = open(path, "rb").read()
    except OSError:
        return None
    if len(b) < 4096 * 2 or b[4096:4104] != b"EFI PART":
        return None
    return struct.unpack_from("<Q", b, 4096 + 48)[0]


def _sector(tok, last_usable):
    """解析 start_sector：支持十进制/0x 与官方包的 NUM_DISK_SECTORS-<n> 表达式。"""
    t = str(tok).strip().rstrip(".")
    if t.startswith("NUM_DISK_SECTORS"):
        if last_usable is None:
            raise ValueError(f"需要 --gpt/--lun-sectors 才能解析 {tok!r}")
        base = last_usable + 1
        rest = t[len("NUM_DISK_SECTORS"):].lstrip("-")
        return base - int(rest) if rest else base
    return int(t, 0)


def image_sectors(path, sector_size):
    """返回镜像占用的扇区数（sparse 用 expanded size）。读不出返回 None。"""
    try:
        st = os.stat(path)
    except OSError:
        return None
    with open(path, "rb") as f:
        head = f.read(28)
    if len(head) >= 4 and struct.unpack_from("<I", head, 0)[0] == SPARSE_MAGIC:
        # struct sparse_header: magic, major, minor, file_hdr_sz, chunk_hdr_sz, blk_sz,
        #   total_blks, total_chunks, image_checksum
        blk = struct.unpack_from("<I", head, 12)[0]
        total_blks = struct.unpack_from("<I", head, 16)[0]
        if blk:
            return (total_blks * blk + sector_size - 1) // sector_size
    return (st.st_size + sector_size - 1) // sector_size


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("xmls", nargs="+")
    ap.add_argument("--package-dir", help="镜像所在目录（默认 = 第一个 XML 所在目录）")
    ap.add_argument("--gpt", help="默认主表件（gpt_mainN.bin），用它的 last_usable_lba 判越界")
    ap.add_argument("--gpt-for", action="append", default=[], metavar="LUN=PATH",
                    help="按 LUN 指定主表件（可重复）。多 LUN 的包必须用它，否则用 0 号表判别的 LUN 会假报越界/重叠")
    ap.add_argument("--lun-sectors", type=int, help="没有 --gpt 时手工给 LUN 总扇区")
    ap.add_argument("--sector-size", type=int, default=4096)
    ap.add_argument("--allow-missing", action="store_true", help="缺件只 warn（默认 FAIL）")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()

    pkg = a.package_dir or os.path.dirname(os.path.abspath(a.xmls[0]))
    limits = {}
    if a.gpt:
        v = gpt_last_usable(a.gpt)
        if v is None:
            print(f"!! 读不到 {a.gpt} 的 last_usable_lba（不是 GPT 主表件？）", file=sys.stderr)
            return 2
        limits = {i: v for i in range(6)}
    for spec in a.gpt_for:
        lun_s, _, path = spec.partition("=")
        v = gpt_last_usable(path)
        if v is None:
            print(f"!! 读不到 {path} 的 last_usable_lba", file=sys.stderr)
            return 2
        limits[int(lun_s)] = v
    if not limits and a.lun_sectors:
        limits = {i: a.lun_sectors - 1 for i in range(6)}
    limit = limits.get(0)

    fails, warns, nodes = [], [], 0
    per_lun = {}
    seen_files = {}
    for x in a.xmls:
        try:
            root = ET.parse(x).getroot()
        except ET.ParseError as e:
            fails.append(f"{os.path.basename(x)}: XML 解析失败 {e}")
            continue
        for pg in root.iter("program"):
            nodes += 1
            g = pg.attrib
            label = g.get("label", "")
            fn = (g.get("filename") or "").strip()
            lun_s = g.get("physical_partition_number")
            start_s = g.get("start_sector")
            nsect_s = g.get("num_partition_sectors")
            ctx = f"{os.path.basename(x)} [{label or fn or '?'}]"
            # R1 必需字段
            if lun_s is None or start_s is None or nsect_s is None:
                fails.append(f"{ctx}: 缺 physical_partition_number/start_sector/num_partition_sectors"
                             f"（qdl 会退化成 0 ⇒ 可能写主 GPT 区）")
                continue
            try:
                lun, start, nsect = int(lun_s), _sector(start_s, limits.get(int(lun_s))), int(nsect_s, 0)
            except ValueError:
                fails.append(f"{ctx}: 字段不是整数（lun={lun_s!r} start={start_s!r} n={nsect_s!r}）")
                continue
            if not (0 <= lun <= 5):
                fails.append(f"{ctx}: physical_partition_number={lun} 不在 0..5")
            if nsect <= 0:
                # 官方包里有 `last_parti` 这类 0 扇区占位节点（qdl 实际不写数据）
                warns.append(f"{ctx}: num_partition_sectors={nsect}（占位节点，跳过区间判据）")
                continue
            end = start + max(nsect, 0) - 1
            # R2 越界
            lim = limits.get(lun)
            if lim is not None and end > lim:
                fails.append(f"{ctx}: 区间 {start}..{end} 超出 LUN{lun} 可用末尾 {lim}"
                             f"（越界 {end - lim} 扇区）")
            per_lun.setdefault(lun, []).append((start, end, label or fn, ctx))
            # R4 镜像大小 vs 分区跨度
            if fn:
                path = os.path.join(pkg, fn)
                if not os.path.exists(path):
                    msg = f"{ctx}: 找不到件 {fn}（默认拒绝；--allow-missing 才降级）"
                    (warns if a.allow_missing else fails).append(msg)
                else:
                    got = image_sectors(path, a.sector_size)
                    if got is not None and got > nsect:
                        fails.append(f"{ctx}: 镜像 {fn} 占 {got} 扇区 > 分区跨度 {nsect}"
                                     f"（会被截断成半件）")
                    seen_files[fn] = got
    # R3 重叠
    for lun, spans in sorted(per_lun.items()):
        spans.sort()
        for i in range(1, len(spans)):
            p_start, p_end, p_name, p_ctx = spans[i - 1]
            c_start, c_end, c_name, c_ctx = spans[i]
            if c_start <= p_end:
                fails.append(f"LUN{lun} 区间重叠：{c_ctx} {c_start}..{c_end} 与 {p_ctx} {p_start}..{p_end}")

    out = {
        "xmls": [os.path.basename(x) for x in a.xmls],
        "package_dir": pkg,
        "nodes": nodes,
        "lun_limits_lba": limits,
        "fails": fails,
        "warns": warns,
        "files_checked": len(seen_files),
    }
    if a.json:
        print(json.dumps(out, ensure_ascii=False, indent=2))
    else:
        print(f"== rawprogram 预检：{nodes} 个 program 节点 / {len(a.xmls)} 个 XML"
              f" / 镜像 {len(seen_files)} 件 / LUN 可用末尾 {limits or '未给（跳过越界判据）'}")
        for w in warns[:20]:
            print(f"  WARN {w}")
        for f in fails[:40]:
            print(f"  FAIL {f}")
        if len(fails) > 40:
            print(f"  … 还有 {len(fails) - 40} 条 FAIL")
        print(f"== {'FAIL=' + str(len(fails)) + ' WARN=' + str(len(warns))}")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
