#!/usr/bin/env python3
"""gpt-preflight.py — 写盘前的 GPT「快照复验」（纯主机、无 USB、不碰设备）。

来源：2026-11-18 LTBox 评估 §1 **P0-5**（`edl.rs:1023 validate_partition_snapshot()`）：
写之前**重读** GPT，逐条比对 start / span / size，不一致即「scan the device again」；
并且拒绝重复选择。我们原来的等价物是 `scripts/linux-gpt-apply.sh` 里那段内联 python
（只比「分区在不在 / 起点动没动」），既没有 CRC/主备一致性，也没有 span/size 与重名判定，
而且不可离线自检 —— 这里把它抽成工具，语义只扩不缩。

三个子命令（全部只吃**文件**，可以在没有任何设备的情况下跑）：

  check    --main gpt_main0.bin --backup gpt_backup0.bin
           主表件自洽性：签名/头 CRC/条目 CRC；给了备表件就**逐字节**比条目区
           （主备不一致 = 表本身坏了，写下去就是把坏表固化）；同表内**重名分区直接拒**
           （qdl/EDL 按 label 找分区时重名 = 写错目标的唯一来源）。

  snapshot --main … [--backup …] -o snap.json
           把当前几何落成快照（每分区 label/start/end/sectors/bytes/guid/attr）。

  verify   --expect snap.json --main … [--backup …] [--strict-attr]
           写前复验：重新读到的表必须与快照**逐条一致**（start/end/sectors/bytes/guid）。
           REMOVED/ADDED/MOVED/RESIZED/GUID 变 ⇒ FAIL；attr 变默认 WARN（`--strict-attr` 升 FAIL）。

  compare  --base-main live.bin [--base-backup …] --main new.bin [--backup …] [--allow-drop]
           「拿新表去写」之前的对照：新表**少掉**基线里还存在的分区 ⇒ 默认拒绝
           （`--allow-drop` 才放过，脚本里对应显式 ALLOW_DROP=1）。

退出码：0 全过 / 1 有 FAIL / 2 用法或解析错误（读不出的表件绝不当作「空表」）。

用法举例：
  scripts/gpt-preflight.py check --main backup/official-rom-15.10.259/gpt_main0.bin \\
                                 --backup backup/official-rom-15.10.259/gpt_backup0.bin
  scripts/gpt-preflight.py snapshot --main $RD/pre-write-primary.bin -o $RD/pre.json
  scripts/gpt-preflight.py verify --expect $RD/pre.json --main gpt_main0.bin
  scripts/gpt-preflight.py compare --base-main $RD/pre-write-primary.bin --main gpt_main0.bin

自检（合成 GPT 对，好件必过 / 每类坏件必被抓，防检查器空转）：
  scripts/gpt-preflight.py --selftest
"""
import argparse
import json
import struct
import sys
import uuid
import zlib

SECT = 4096
SIG = b"EFI PART"


def _u32(b, o):
    return struct.unpack_from("<I", b, o)[0]


def _u64(b, o):
    return struct.unpack_from("<Q", b, o)[0]


def _guid(b, o):
    try:
        return str(uuid.UUID(bytes_le=bytes(b[o:o + 16])))
    except ValueError:
        return "?"


def _header_crc_ok(buf, off, hsize, want):
    h = bytearray(buf[off:off + hsize])
    if len(h) < hsize:
        return False
    struct.pack_into("<I", h, 16, 0)
    return (zlib.crc32(h) & 0xFFFFFFFF) == want


def parse_table(path):
    """解析一件 GPT 主表件（LBA0..5）或备表件（LBA alt-4..alt）。

    返回 dict（含 header 字段与 entries 原始字节）；读不出/CRC 坏时抛 ValueError ——
    绝不静默返回空表（空表会让「写前复验」变成永远通过）。
    """
    buf = open(path, "rb").read()
    if len(buf) < 2 * SECT:
        raise ValueError(f"{path}: 只有 {len(buf)} B，不是表件")
    hdr_off = None
    for cand in (SECT, len(buf) - SECT):
        if buf[cand:cand + 8] == SIG:
            hdr_off = cand
            break
    if hdr_off is None:
        raise ValueError(f"{path}: LBA1/LBA-1 都没有 'EFI PART'（不是 GPT 表件）")
    hsize = _u32(buf, hdr_off + 12)
    if not (92 <= hsize <= SECT):
        raise ValueError(f"{path}: header_size={hsize} 不合理")
    crc_ok = _header_crc_ok(buf, hdr_off, hsize, _u32(buf, hdr_off + 16))
    cur = _u64(buf, hdr_off + 24)
    alt = _u64(buf, hdr_off + 32)
    first = _u64(buf, hdr_off + 40)
    last = _u64(buf, hdr_off + 48)
    ent_lba = _u64(buf, hdr_off + 72)
    nent = _u32(buf, hdr_off + 80)
    esz = _u32(buf, hdr_off + 84)
    ent_crc = _u32(buf, hdr_off + 88)
    if nent == 0 or esz < 128 or nent * esz > 1024 * 1024:
        raise ValueError(f"{path}: num_entries={nent}/entry_size={esz} 不合理")
    ent_off = hdr_off + (ent_lba - cur) * SECT
    ent = buf[ent_off:ent_off + nent * esz]
    if len(ent) < nent * esz:
        raise ValueError(f"{path}: 条目区被截断（要 {nent * esz} B，只有 {len(ent)} B）")
    return {
        "path": path,
        "header_crc_ok": crc_ok,
        "current_lba": cur,
        "backup_lba": alt,
        "first_usable_lba": first,
        "last_usable_lba": last,
        "disk_guid": _guid(buf, hdr_off + 56),
        "entries_lba": ent_lba,
        "num_entries": nent,
        "entry_size": esz,
        "entries_crc_ok": (zlib.crc32(ent) & 0xFFFFFFFF) == ent_crc,
        "entries": ent,
    }


def table_partitions(t, sector=SECT):
    """条目字节 → [{label,start,end,sectors,bytes,guid,attr}]（保持表中顺序）。"""
    out = []
    esz = t["entry_size"]
    for i in range(t["num_entries"]):
        e = t["entries"][i * esz:(i + 1) * esz]
        if len(e) < 128 or e[0:16] == b"\0" * 16:
            continue
        name = e[56:128].decode("utf-16-le", "replace").split("\x00")[0]
        if not name:
            continue
        start, end = struct.unpack_from("<QQ", e, 32)
        if end < start:
            out.append({"index": i, "label": name, "start": start, "end": end,
                        "sectors": 0, "bytes": 0, "guid": _guid(e, 16),
                        "attr": _u64(e, 48), "bad_range": True})
            continue
        n = end - start + 1
        out.append({"index": i, "label": name, "start": start, "end": end,
                    "sectors": n, "bytes": n * sector, "guid": _guid(e, 16),
                    "attr": _u64(e, 48)})
    return out


def load_pair(main, backup=None):
    """读主表（必需）与备表（可选），返回 (main_table, backup_table, fails)。"""
    fails = []
    try:
        mt = parse_table(main)
    except (OSError, ValueError) as e:
        return None, None, [f"主表读不出：{e}"]
    if not mt["header_crc_ok"]:
        fails.append(f"{main}: GPT 头 CRC 不符（表件损坏）")
    if not mt["entries_crc_ok"]:
        fails.append(f"{main}: GPT 条目 CRC 不符（表件损坏）")
    bt = None
    if backup:
        try:
            bt = parse_table(backup)
        except (OSError, ValueError) as e:
            return mt, None, fails + [f"备表读不出：{e}"]
        if not bt["header_crc_ok"]:
            fails.append(f"{backup}: 备份头 CRC 不符")
        if not bt["entries_crc_ok"]:
            fails.append(f"{backup}: 备份条目 CRC 不符")
        if bt["entries"] != mt["entries"]:
            # 主备条目不一致时不能说「哪一侧对」——只报事实并拒绝。
            d = sum(1 for a, b in zip(mt["entries"], bt["entries"]) if a != b)
            fails.append(f"主备条目区不一致（{d} 个条目字节不同；写下去会把坏表固化成唯一真相）")
        if bt["backup_lba"] not in (0, mt["current_lba"]):
            fails.append(f"备份头 backup_lba={bt['backup_lba']} != 主表 current_lba={mt['current_lba']}")
    return mt, bt, fails


def dup_labels(parts):
    """同名分区（忽略大小写）出现 >1 次 = EDL 按 label 定位时的歧义源。"""
    seen = {}
    for p in parts:
        seen.setdefault(p["label"].lower(), []).append(p)
    return {k: v for k, v in seen.items() if len(v) > 1}


def cmd_check(a):
    mt, bt, fails = load_pair(a.main, a.backup)
    if mt is None:
        _emit(a, {"fails": fails})
        return 2
    parts = table_partitions(mt, a.sector_size)
    for p in parts:
        if p.get("bad_range"):
            fails.append(f"分区 {p['label']}: end < start（{p['start']}..{p['end']}）")
        if a.lun is not None and (p["start"] < mt["first_usable_lba"]
                                  and p["label"] not in a.allow_overlap_prefix):
            pass  # 只记录，不判 FAIL：官方包里确有落在 first_usable 前的分区
    dups = dup_labels(parts)
    for k, v in sorted(dups.items()):
        fails.append(f"重名分区 {k!r} 出现 {len(v)} 次（start={[p['start'] for p in v]}）"
                     f" ⇒ 按 label 定位会写错目标")
    if a.expect_partitions is not None and len(parts) != a.expect_partitions:
        fails.append(f"分区数 {len(parts)} != 预期 {a.expect_partitions}")
    _emit(a, {
        "kind": "check",
        "main": a.main, "backup": a.backup,
        "header_crc_ok": mt["header_crc_ok"], "entries_crc_ok": mt["entries_crc_ok"],
        "pair_consistent": (bt["entries"] == mt["entries"]) if bt else None,
        "partitions": len(parts),
        "first_usable_lba": mt["first_usable_lba"], "last_usable_lba": mt["last_usable_lba"],
        "fails": fails,
    })
    if not a.json:
        print(f"== GPT check：{len(parts)} 分区 / 头CRC {_y(mt['header_crc_ok'])}"
              f" / 条目CRC {_y(mt['entries_crc_ok'])}"
              f" / 主备一致 {_y(None if bt is None else bt['entries'] == mt['entries'])}")
        for f in fails:
            print(f"  FAIL {f}")
        print(f"== {'FAIL=' + str(len(fails)) if fails else 'OK'}")
    return 1 if fails else 0


def _y(v):
    return "n/a" if v is None else ("ok" if v else "BAD")


def snapshot_of(mt, sector=SECT):
    parts = table_partitions(mt, sector)
    return {
        "sector_size": sector,
        "num_entries": mt["num_entries"],
        "first_usable_lba": mt["first_usable_lba"],
        "last_usable_lba": mt["last_usable_lba"],
        "disk_guid": mt["disk_guid"],
        "partitions": [{k: p[k] for k in ("label", "start", "end", "sectors", "bytes", "guid", "attr")}
                       for p in sorted(parts, key=lambda x: (x["start"], x["label"]))],
    }


def cmd_snapshot(a):
    mt, bt, fails = load_pair(a.main, a.backup)
    if mt is None or fails:
        # 快照必须建立在「表本身可信」之上；带 FAIL 也写出文件，但 rc=1，调用方不会用它。
        if mt is not None:
            json.dump(snapshot_of(mt, a.sector_size), open(a.out, "w"), ensure_ascii=False, indent=1)
        _emit(a, {"fails": fails}, raw=True)
        for f in fails:
            print(f"  FAIL {f}", file=sys.stderr)
        return 2 if mt is None else 1
    snap = snapshot_of(mt, a.sector_size)
    txt = json.dumps(snap, ensure_ascii=False, indent=1)
    if a.out == "-":
        print(txt)
    else:
        open(a.out, "w").write(txt + "\n")
    if not a.json:
        dups = dup_labels(snap["partitions"])
        print(f"== GPT snapshot：{len(snap['partitions'])} 分区 → {a.out}"
              f"（重名 {len(dups)} 组）")
    return 1 if dup_labels(snap["partitions"]) else 0


def _diff(expected, got, strict_attr):
    """返回 (fails, warns)：expected/got 都是 load 出来的 partition 列表。"""
    fails, warns = [], []
    em = {p["label"]: p for p in expected}
    gm = {p["label"]: p for p in got}
    for lab in sorted(em.keys() - gm.keys()):
        fails.append(f"REMOVED {lab}（快照里有，现表里没了）")
    for lab in sorted(gm.keys() - em.keys()):
        fails.append(f"ADDED {lab} start={gm[lab]['start']}（快照里没有，现表里多出来）")
    for lab in sorted(em.keys() & gm.keys()):
        e, g = em[lab], gm[lab]
        if e["start"] != g["start"] or e["end"] != g["end"]:
            fails.append(f"MOVED {lab}: {e['start']}..{e['end']} -> {g['start']}..{g['end']}")
        elif e["sectors"] != g["sectors"] or e["bytes"] != g["bytes"]:
            fails.append(f"RESIZED {lab}: {e['sectors']} 扇区 -> {g['sectors']} 扇区")
        if e["guid"] != g["guid"]:
            fails.append(f"GUID-CHANGED {lab}: {e['guid']} -> {g['guid']}")
        if e.get("attr") != g.get("attr"):
            msg = f"ATTR-CHANGED {lab}: 0x{e.get('attr', 0):x} -> 0x{g.get('attr', 0):x}"
            (fails if strict_attr else warns).append(msg)
    dups = dup_labels(got)
    for k, v in sorted(dups.items()):
        fails.append(f"重名分区 {k!r} 出现 {len(v)} 次（现表按 label 定位有歧义）")
    return fails, warns


def cmd_verify(a):
    try:
        exp = json.load(open(a.expect))
    except (OSError, ValueError) as e:
        print(f"!! 读不出快照 {a.expect}: {e}", file=sys.stderr)
        return 2
    mt, bt, fails = load_pair(a.main, a.backup)
    if mt is None:
        for f in fails:
            print(f"  FAIL {f}")
        return 2
    if exp.get("sector_size") not in (None, a.sector_size):
        fails.append(f"扇区尺寸变了：快照 {exp['sector_size']} -> 现在 {a.sector_size}"
                     f"（整张表的字节偏移都不同了，不能比）")
        got, warns = [], []
    else:
        got = table_partitions(mt, a.sector_size)
        dfails, warns = _diff(exp.get("partitions", []), got, a.strict_attr)
        fails += dfails
    _emit(a, {"kind": "verify", "expect": a.expect, "partitions": len(got),
              "fails": fails, "warns": warns})
    if not a.json:
        print(f"== GPT verify：快照 {os_path(a.expect)} vs {os_path(a.main)}"
              f"（{len(got)} 分区）")
        for w in warns:
            print(f"  WARN {w}")
        for f in fails:
            print(f"  FAIL {f}")
        print(f"== {'FAIL=' + str(len(fails)) if fails else 'OK（写前复验与快照逐条一致）'}"
              f"{'' if not warns else ' WARN=' + str(len(warns))}")
    return 1 if fails else 0


def os_path(p):
    import os
    return os.path.basename(p)


def cmd_compare(a):
    bt, bbt, fails0 = load_pair(a.base_main, a.base_backup)
    nt, nbt, fails1 = load_pair(a.main, a.backup)
    fails = fails0 + fails1
    if bt is None or nt is None:
        for f in fails:
            print(f"  FAIL {f}")
        return 2
    base = table_partitions(bt, a.sector_size)
    new = table_partitions(nt, a.sector_size)
    bm = {p["label"]: p for p in base}
    nm = {p["label"]: p for p in new}
    gone = [n for n in bm if n not in nm]
    added = [n for n in nm if n not in bm]
    moved = [(n, bm[n], nm[n]) for n in bm if n in nm
             and (bm[n]["start"], bm[n]["end"]) != (nm[n]["start"], nm[n]["end"])]
    dups = dup_labels(new)
    for k, v in sorted(dups.items()):
        fails.append(f"重名分区 {k!r} 出现 {len(v)} 次")
    if gone and not a.allow_drop:
        fails.append(f"新表会删掉现表里仍存在的分区 {len(gone)} 个："
                     f"{', '.join(gone[:8])}{' …' if len(gone) > 8 else ''}"
                     f"（确认要删请 --allow-drop / ALLOW_DROP=1）")
    _emit(a, {"kind": "compare", "base": a.base_main, "new": a.main,
              "base_partitions": len(base), "new_partitions": len(new),
              "added": added, "dropped": gone,
              "moved": [{"label": n, "from": [b["start"], b["end"]],
                         "to": [c["start"], c["end"]]} for n, b, c in moved],
              "fails": fails})
    if not a.json:
        print(f"[live-check] 现表 {len(base)} 分区 / 新表 {len(new)}；"
              f"新增 {len(added)}，几何变化 {len(moved)}，将消失 {len(gone)}")
        for n, b, c in moved[:8]:
            print(f"  ~ {n}: {b['start']}..{b['end']} -> {c['start']}..{c['end']}")
        if added[:6]:
            print(f"  + 新增: {', '.join(added[:6])}")
        if gone:
            print(f"  - 将消失: {', '.join(gone[:8])}{' …' if len(gone) > 8 else ''}")
        for f in fails:
            print(f"  FAIL {f}")
        print(f"== {'FAIL=' + str(len(fails)) if fails else 'OK（写前对照通过）'}")
    return 1 if fails else 0


def _emit(a, obj, raw=False):
    if getattr(a, "json", False):
        if raw:
            obj = {"fails": obj.get("fails", [])}
        print(json.dumps(obj, ensure_ascii=False, indent=1))


# ─────────────────────────── 自检（合成 GPT 对） ───────────────────────────
def _build_pair(dirpath, parts, *, total=2048, nent=32, esz=128, sector=SECT,
                name="disk", bad_entries_crc=False):
    """写一对 (main, backup) 表件；parts = [(label, start, end, guid_uuid_str)]。"""
    import os
    alt = total - 1
    first, last = 6, alt - 34
    ents = bytearray(nent * esz)
    for i, (label, start, end, guid) in enumerate(parts):
        o = i * esz
        ents[o:o + 16] = uuid.UUID(guid).bytes_le
        struct.pack_into("<QQ", ents, o + 32, start, end)
        nm = label.encode("utf-16-le")[:72]
        # 切片赋值给更短的 bytes 会**缩短** bytearray（把条目区挤掉）；必须补齐到 72 B
        ents[o + 56:o + 128] = nm + b"\0" * (72 - len(nm))
    disk_guid = str(uuid.UUID(int=0x1234567890ABCDEF1234567890ABCDEF))
    ecrc = zlib.crc32(bytes(ents)) & 0xFFFFFFFF

    def hdr(cur, alt_lba, ent_lba, crc_bad=False):
        h = bytearray(sector)
        h[0:8] = SIG
        struct.pack_into("<I", h, 8, 0x00010000)
        struct.pack_into("<I", h, 12, 92)
        struct.pack_into("<Q", h, 24, cur)
        struct.pack_into("<Q", h, 32, alt_lba)
        struct.pack_into("<Q", h, 40, first)
        struct.pack_into("<Q", h, 48, last)
        h[56:72] = uuid.UUID(disk_guid).bytes_le
        struct.pack_into("<Q", h, 72, ent_lba)
        struct.pack_into("<I", h, 80, nent)
        struct.pack_into("<I", h, 84, esz)
        struct.pack_into("<I", h, 88, (ecrc ^ 0xDEAD if bad_entries_crc else ecrc))
        tmp = bytearray(h[:92])
        struct.pack_into("<I", tmp, 16, 0)
        struct.pack_into("<I", h, 16, zlib.crc32(bytes(tmp)) & 0xFFFFFFFF)
        return h

    # 主表件 = LBA0..5：LBA0（MBR 留空）/ LBA1 头 / LBA2.. 条目
    main = bytearray(6 * sector)
    main[sector:2 * sector] = hdr(1, alt, 2)
    main[2 * sector:2 * sector + len(ents)] = ents
    mp = os.path.join(dirpath, f"{name}-main.bin")
    open(mp, "wb").write(main)
    # 备表件 = LBA (alt-4)..alt：前 4 扇区条目 + 末扇区头
    bkp = bytearray(5 * sector)
    bkp[0:len(ents)] = ents
    bkp[4 * sector:5 * sector] = hdr(alt, 1, alt - 4)
    bp = os.path.join(dirpath, f"{name}-backup.bin")
    open(bp, "wb").write(bkp)
    return mp, bp


def selftest():
    import os
    import tempfile
    ok = True

    def bad(msg):
        nonlocal ok
        ok = False
        print(f"  SELFTEST FAIL {msg}")

    G1 = "11111111-2222-3333-4444-555555555555"
    G2 = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    G3 = "99999999-8888-7777-6666-555555555555"
    with tempfile.TemporaryDirectory() as d:
        base = [("boot_a", 100, 163, G1), ("boot_b", 200, 263, G2), ("super", 300, 999, G3)]
        mp, bp = _build_pair(d, base, name="good")
        snap = os.path.join(d, "snap.json")

        # ① 好件：check 通过、snapshot 成功、verify 与自身快照一致
        r = _run(["check", mp, "--backup", bp])
        if r[0] != 0:
            bad(f"好件 check 判 FAIL：{r[1]}")
        r = _run(["snapshot", mp, "--backup", bp, "-o", snap])
        if r[0] != 0:
            bad(f"好件 snapshot 失败：{r[1]}")
        r = _run(["verify", mp, "--backup", bp, "--expect", snap])
        if r[0] != 0:
            bad(f"好件 verify（快照=现表）判 FAIL：{r[1]}")

        # ② 起点移动（P0-5 的核心：写前重读发现几何漂移）
        m2, b2 = _build_pair(d, [("boot_a", 101, 163, G1), ("boot_b", 200, 263, G2),
                                 ("super", 300, 999, G3)], name="moved")
        r = _run(["verify", m2, "--backup", b2, "--expect", snap])
        if r[0] == 0 or "MOVED boot_a" not in r[1]:
            bad("起点漂移未被 verify 抓到")

        # ③ 跨度变化（end 变，sectors/bytes 也要变）
        m3, b3 = _build_pair(d, [("boot_a", 100, 200, G1), ("boot_b", 200, 263, G2),
                                 ("super", 300, 999, G3)], name="resized")
        r = _run(["verify", m3, "--backup", b3, "--expect", snap])
        if r[0] == 0 or "MOVED boot_a" not in r[1]:
            bad("跨度变化未被 verify 抓到")

        # ④ 分区消失 / ⑤ 分区新增
        m4, b4 = _build_pair(d, [("boot_a", 100, 163, G1), ("boot_b", 200, 263, G2)], name="dropped")
        r = _run(["verify", m4, "--backup", b4, "--expect", snap])
        if r[0] == 0 or "REMOVED super" not in r[1]:
            bad("分区消失未被 verify 抓到")
        r = _run(["compare", m4, "--backup", b4, "--base-main", mp, "--base-backup", bp])
        if r[0] == 0 or "将消失" not in r[1]:
            bad("compare 未拒绝「新表删掉现表分区」")
        r = _run(["compare", m4, "--backup", b4, "--base-main", mp, "--base-backup", bp,
                  "--allow-drop"])
        if r[0] != 0:
            bad(f"compare --allow-drop 仍判 FAIL（应显式放过）：{r[1]}")
        m5, b5 = _build_pair(d, base + [("extra", 1000, 1100, G1)], name="added")
        r = _run(["verify", m5, "--backup", b5, "--expect", snap])
        if r[0] == 0 or "ADDED extra" not in r[1]:
            bad("分区新增未被 verify 抓到")

        # ⑥ 主备不一致（写下去会把坏表固化成唯一真相）
        m6, b6 = _build_pair(d, base, name="badbak")
        raw = bytearray(open(b6, "rb").read())
        raw[56:72] = uuid.UUID(G1).bytes_le          # 只改备表条目区里的一个 label
        open(b6, "wb").write(raw)
        r = _run(["check", m6, "--backup", b6])
        if r[0] == 0 or "主备条目区不一致" not in r[1]:
            bad("主备不一致未被 check 抓到")

        # ⑦ 条目 CRC 坏
        m7, b7 = _build_pair(d, base, name="badcrc", bad_entries_crc=True)
        r = _run(["check", m7, "--backup", b7])
        if r[0] == 0 or "条目 CRC" not in r[1]:
            bad("条目 CRC 损坏未被 check 抓到")

        # ⑧ 重名分区（按 label 定位的歧义源）
        m8, b8 = _build_pair(d, base + [("boot_a", 1200, 1263, G2)], name="dup")
        r = _run(["check", m8, "--backup", b8])
        if r[0] == 0 or "重名分区" not in r[1]:
            bad("重名分区未被 check 抓到")

        # ⑨ 不是表件 ⇒ 必须 rc!=0，绝不能当「空表通过」
        junk = os.path.join(d, "junk.bin")
        open(junk, "wb").write(b"\0" * 8192)
        r = _run(["check", junk])
        if r[0] == 0:
            bad("非 GPT 文件被判通过（会退化成「空表永远通过」）")

        # ⑩ 反作弊：恒返回 0 的 stub 检查器在坏件上也「通过」⇒ 说明上面的断言有牙齿
        stub = os.path.join(d, "stub.py")
        open(stub, "w").write("import sys\nsys.exit(0)\n")
        import subprocess
        p = subprocess.run([sys.executable, stub, "check", "--main", m6], capture_output=True)
        if p.returncode != 0:
            bad("stub 检查器没有恒返回 0（自检的反作弊前提不成立）")

    print(f"== selftest {'OK' if ok else 'FAIL'}（好件必过 / 移动·跨度·消失·新增·主备不一致·CRC 坏·重名·非表件 必被抓）")
    return 0 if ok else 1


def _run(argv):
    """自检里调用本工具本体，捕获 stdout。"""
    import io
    import contextlib
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        rc = main(argv)
    return rc, buf.getvalue()


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    if "--selftest" in argv:
        return selftest()

    ap = argparse.ArgumentParser(description="写前 GPT 快照复验（P0-5）",
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    # 全局旗标可在子命令前后都写（默认 SUPARSE 避免子 parser 覆盖）
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--main", help="主表件（LBA0..5）")
    common.add_argument("--backup", help="备表件（LBA alt-4..alt）")
    common.add_argument("--sector-size", type=int, default=SECT)
    common.add_argument("--json", action="store_true")

    sub = ap.add_subparsers(dest="cmd")
    p_check = sub.add_parser("check", parents=[common], help="主备自洽 + 重名判定")
    p_check.add_argument("--lun", type=int, help="只用于日志标注")
    p_check.add_argument("--expect-partitions", type=int, help="预期分区数（可空）")
    p_check.add_argument("--allow-overlap-prefix", action="append", default=[])

    p_snap = sub.add_parser("snapshot", parents=[common], help="落快照 JSON")
    p_snap.add_argument("-o", "--out", required=True, help="输出快照路径（- = stdout）")

    p_ver = sub.add_parser("verify", parents=[common], help="写前复验：现表 vs 快照")
    p_ver.add_argument("--expect", required=True, help="snapshot 产出的 JSON")
    p_ver.add_argument("--strict-attr", action="store_true", help="attr 变化也判 FAIL")

    p_cmp = sub.add_parser("compare", parents=[common], help="新表 vs 现表（掉落即拒）")
    p_cmp.add_argument("--base-main", required=True)
    p_cmp.add_argument("--base-backup")
    p_cmp.add_argument("--allow-drop", action="store_true")

    # 兼容旧式写法：`gpt-preflight.py main.bin --backup bk.bin`（无子命令 = check，且
    # `main.bin` 当 --main）；`gpt-preflight.py --json check …` / `check --json …` 都接受。
    subs = ("check", "snapshot", "verify", "compare")
    leading_json = False
    while argv and argv[0].startswith("-"):
        if argv[0] == "--json":
            leading_json = True
            argv = argv[1:]
        elif argv[0] == "--sector-size":
            argv = ["--sector-size", argv[1]] + argv[2:]
            break
        else:
            break
    if not argv or argv[0] not in subs:
        argv = ["check"] + argv
    if leading_json:
        argv = [argv[0], "--json"] + argv[1:]
    head, rest = argv[0], argv[1:]
    if rest and not rest[0].startswith("-"):
        rest = ["--main", rest[0]] + rest[1:]
    a = ap.parse_args([head] + rest)
    if not getattr(a, "main", None):
        ap.error("需要 --main <主表件>")
    return {"check": cmd_check, "snapshot": cmd_snapshot,
            "verify": cmd_verify, "compare": cmd_compare}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
