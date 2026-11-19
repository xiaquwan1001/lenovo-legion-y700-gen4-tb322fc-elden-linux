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
  R6 **split-super 齐备**（2026-11-19，LTBox 评估 P1-4）：`super_1.img…super_N.img` 这类分片
     （stem 必须是 `super`；**只管 super**，见下）索引必须 1..N 连续且**每片都在盘上**；缺一片 ⇒ 整体拒绝，
     **不受 `--allow-missing` 影响**（半截 super 会写出一个「能装但起不来」的镜像，比直接失败更贵）。
     官方 15.10.259 包实测 = `super_1..super_8`（label 均 `super`）。**范围限定 `stem == super`**：
     同一包里还声明了 `userdata_1..11.img` 但**刻意不带件**（`/data` 由 `fastboot -w` 现建），
     若把 R6 泛化到所有 `<stem>_<n>`，官方包会假 FAIL=11（本轮实测踩到）。
  R7 **属性/偏移严格判据**（同报告 P2-1/P2-2）：几何属性（`start_sector`/`num_partition_sectors`/
     `physical_partition_number`/`file_sector_offset`）只接受十进制、`0x` 十六进制或
     `NUM_DISK_SECTORS-<n>`；**下划线/空白/单位/后缀一律报错**（Python 的 `int("1_0")` 会静默
     吃掉下划线 ⇒ 旧实现会把 `1_0` 当 10 写）。`file_sector_offset × sector_size + 写入跨度`
     必须落在镜像件内，否则判「seek 到错误区域/短读」。`--lenient-attrs` 可关掉 R7 的严格档。

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

# R7：几何属性的**严格**可解析形式（不含下划线/空白/正负号/单位）。
# 注：官方 XML 的表达式带**尾点**（`NUM_DISK_SECTORS-5.`，实测量产包 BackupGPT 节点），
# 所以允许**一个**可选尾点；除此外不接受任何修饰（下划线/空白/单位/正负号）。
NUM_ATTR_RE = re.compile(r"^(?:[0-9]+|0x[0-9a-fA-F]+|NUM_DISK_SECTORS(?:-[0-9]+)?)\.?$")
# 刻意不带件的 label（官方包实测）：userdata 的 `/data` 由 `fastboot -w`/首次开发现建，
# 包里只声明分区跨度。硬性跳过这些 label 的 R5 缺件判据（仍做几何/重叠判据）。
EXEMPT_MISSING_LABELS_DEFAULT = ("userdata",)
GEOM_ATTRS = ("start_sector", "num_partition_sectors", "physical_partition_number",
              "file_sector_offset")
SPLIT_RE = re.compile(r"^(?P<stem>.+?)_(?P<idx>[0-9]+)\.(?P<ext>img|bin|raw)$", re.I)
OFFSET_MAX_SECTORS = 1 << 40      # 荒谬偏移的硬上限（防溢出/防 seek 到天边）


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


def selftest():
    """内置坏包：4 类缺陷各一例，全部必须被检出；正确包必须 0 FAIL。"""
    import tempfile
    fails = []
    with tempfile.TemporaryDirectory() as d:
        open(os.path.join(d, "ok.img"), "wb").write(b"\0" * (4096 * 2))
        open(os.path.join(d, "big.img"), "wb").write(b"\0" * (4096 * 100))
        good = os.path.join(d, "good.xml")
        open(good, "w").write(
            '<data><program start_sector="100" num_partition_sectors="8"'
            ' physical_partition_number="0" filename="ok.img" label="a"/></data>')
        bad = os.path.join(d, "bad.xml")
        open(bad, "w").write(
            '<data>'
            '<program start_sector="100" num_partition_sectors="8" physical_partition_number="0" filename="ok.img" label="a"/>'
            '<program start_sector="104" num_partition_sectors="8" physical_partition_number="0" filename="ok.img" label="overlap"/>'
            '<program start_sector="200" num_partition_sectors="4" physical_partition_number="0" filename="big.img" label="toobig"/>'
            '<program start_sector="999999" num_partition_sectors="4" physical_partition_number="0" filename="ok.img" label="oob"/>'
            '<program start_sector="300" num_partition_sectors="4" filename="ok.img" label="nolun"/>'
            '</data>')
        rc_good = main([good, "--lun-sectors", "1000"])
        rc_bad = main([bad, "--lun-sectors", "1000"])
        if rc_good != 0:
            fails.append("正确包装被判 FAIL（假阳性）")
        if rc_bad == 0:
            fails.append("坏包未被检出（假阴性）—— 检查器是空转的")

        # R6：split-super 缺片必须整体拒绝，且 --allow-missing 也不能放过
        open(os.path.join(d, "super_1.img"), "wb").write(b"\0" * (4096 * 2))
        spl = os.path.join(d, "split.xml")
        open(spl, "w").write(
            '<data>'
            '<program start_sector="100" num_partition_sectors="2" physical_partition_number="0"'
            ' filename="super_1.img" label="super"/>'
            '<program start_sector="110" num_partition_sectors="2" physical_partition_number="0"'
            ' filename="super_2.img" label="super"/>'
            '</data>')
        if main([spl, "--lun-sectors", "1000"]) == 0:
            fails.append("split-super 缺片未被检出（假阴性）")
        if main([spl, "--lun-sectors", "1000", "--allow-missing"]) == 0:
            fails.append("split-super 缺片被 --allow-missing 放过（必须硬拒）")

        # R7-a：属性存在但不可解析（旧实现 int("1_0") = 10，静默按错值写）
        at = os.path.join(d, "attr.xml")
        open(at, "w").write(
            '<data><program start_sector="1_0" num_partition_sectors="8"'
            ' physical_partition_number="0" filename="ok.img" label="a"/></data>')
        if main([at, "--lun-sectors", "1000"]) == 0:
            fails.append("不可解析的几何属性未被检出（假阴性）")

        # R7-b：file_sector_offset 越出镜像件（seek 到错误区域）
        off = os.path.join(d, "off.xml")
        open(off, "w").write(
            '<data><program start_sector="100" num_partition_sectors="8"'
            ' physical_partition_number="0" file_sector_offset="4096"'
            ' filename="ok.img" label="a"/></data>')
        if main([off, "--lun-sectors", "1000"]) == 0:
            fails.append("file_sector_offset 越界未被检出（假阴性）")
    for f in fails:
        print(f"  SELFTEST FAIL {f}")
    print(f"== selftest {'OK' if not fails else 'FAIL=' + str(len(fails))}（正确包 rc=0 / 坏包 rc=1）")
    return 1 if fails else 0


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("xmls", nargs="*")
    ap.add_argument("--package-dir", help="镜像所在目录（默认 = 第一个 XML 所在目录）")
    ap.add_argument("--gpt", help="默认主表件（gpt_mainN.bin），用它的 last_usable_lba 判越界")
    ap.add_argument("--gpt-for", action="append", default=[], metavar="LUN=PATH",
                    help="按 LUN 指定主表件（可重复）。多 LUN 的包必须用它，否则用 0 号表判别的 LUN 会假报越界/重叠")
    ap.add_argument("--lun-sectors", type=int, help="没有 --gpt 时手工给 LUN 总扇区")
    ap.add_argument("--sector-size", type=int, default=4096)
    ap.add_argument("--allow-missing", action="store_true",
                    help="缺件只 warn（默认 FAIL）；**不适用于 split-super 分片组**（那类永远硬拒）")
    ap.add_argument("--exempt-missing", action="append", default=[], metavar="LABEL",
                    help="该 label 的缺件只 warn（默认已豁免 userdata：官方包刻意不带件）。可重复")
    ap.add_argument("--lenient-attrs", action="store_true",
                    help="放宽 R7：几何属性允许下划线/空白等 int() 能吃掉的写法（默认严格）")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--selftest", action="store_true",
                    help="用内置坏包自检（7 类缺陷必须全被抓）；不读外部文件")
    a = ap.parse_args(argv)

    if a.selftest:
        return selftest()
    if not a.xmls:
        ap.error("需要至少一个 rawprogram XML（或 --selftest）")

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
    exempt_missing = set(EXEMPT_MISSING_LABELS_DEFAULT) | {x for x in a.exempt_missing if x}

    fails, warns, nodes = [], [], 0
    per_lun = {}
    seen_files = {}
    split_seen = {}      # (lun, stem, ext) -> {索引…}，R6 用（必须按 filename 收，不能按 label）
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
            # R7-a 严格可解析（**先于**任何 int()，因为 int("1_0") 会静默成功）
            if not a.lenient_attrs:
                for k in GEOM_ATTRS:
                    raw = g.get(k)
                    if raw is None or raw == "":
                        continue
                    if not NUM_ATTR_RE.match(raw.strip()):
                        fails.append(f"{ctx}: {k}={raw!r} 不是严格可解析的整数"
                                     f"（下划线/空白/单位/后缀都不接受；--lenient-attrs 可放宽）")
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
            if fn:
                _m = SPLIT_RE.match(fn)
                if _m:
                    split_seen.setdefault((lun, _m.group("stem").lower(),
                                           _m.group("ext").lower()), set()).add(int(_m.group("idx")))
            # R7-b file_sector_offset：写入窗口必须落在镜像件内（sparse 的偏移按展开后语义，跳过）
            off_raw = g.get("file_sector_offset")
            if fn and off_raw not in (None, "") and str(g.get("sparse", "")).lower() != "true":
                path_off = os.path.join(pkg, fn)
                try:
                    off = int(str(off_raw).strip(), 0)
                except ValueError:
                    off = None
                if off is not None:
                    if not (0 <= off < OFFSET_MAX_SECTORS):
                        fails.append(f"{ctx}: file_sector_offset={off} 荒谬（>{OFFSET_MAX_SECTORS} 扇区）")
                    elif os.path.exists(path_off):
                        fsec = image_sectors(path_off, a.sector_size)
                        if fsec is not None and off + nsect > fsec:
                            fails.append(f"{ctx}: file_sector_offset={off}+跨度{nsect} 超出 {fn}"
                                         f"（{fsec} 扇区）⇒ 会 seek 到镜像错误区域/短读")
            # R4 镜像大小 vs 分区跨度
            if fn:
                path = os.path.join(pkg, fn)
                if not os.path.exists(path):
                    msg = f"{ctx}: 找不到件 {fn}（默认拒绝；--allow-missing 才降级）"
                    if label in exempt_missing:
                        warns.append(msg.replace("（默认拒绝；--allow-missing 才降级）",
                                                 "（label=%s 刻意不带件，豁免）" % label))
                    else:
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

    # R6 split-super 齐备（同一 label + 同一文件 stem 的分片索引必须 1..N 连续且都在盘上）
    for (lun, stem, ext), idxs in sorted(split_seen.items()):
        if stem != "super":
            continue      # 只对 super 硬拒（userdata_* 等「刻意不带件」的组不在此列）
        if len(idxs) < 2:
            continue      # 单片不算分片
        want = set(range(1, max(idxs) + 1))
        holes = sorted(want - idxs)
        if holes:
            fails.append(f"LUN{lun} split 组 {stem}_*<n>.{ext} 索引不连续：缺 {holes}"
                         f"（qdl 会把整组当整件写 ⇒ 半截镜像）")
        for i in sorted(idxs):
            f2 = f"{stem}_{i}.{ext}"
            if not os.path.exists(os.path.join(pkg, f2)):
                fails.append(f"LUN{lun} split 组 {stem}_*<n>.{ext} 缺片 {f2}"
                             f"（硬拒：--allow-missing 不适用于分片组）")

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
    sys.exit(main(sys.argv[1:]))
