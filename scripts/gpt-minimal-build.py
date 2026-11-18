#!/usr/bin/env python3
"""gpt-minimal-build.py — 生成「最小可控」GPT（LUN0 减分区 + 单 Linux 大分区；LUN4 只删 Android GKI）。

设计口径（详见 RUNBOOK-BRINGUP/GPT-MINIMAL-DESIGN.md）：
  · **不移动任何保留分区**（absolute LBA 不变 ⇒ 零数据搬迁、零风险）；
  · 只做两件事：把要删的条目**清零**、（仅 LUN0）在尾部空闲区新建一个 `linux` 分区；
  · 保留分区**一个都不重新排序**（GPT 条目顺序无语义，重排只会增加风险）；
  · 删条目 ≠ 删数据：旧 GPT 备份在手就能原样退回去（实验因此可逆）。

用法：
  # 只看计划（不写文件）——LUN0
  python3 scripts/gpt-minimal-build.py --main D/gpt_main0.bin --backup D/gpt_backup0.bin --dry-run
  # 产出 LUN0 新表
  python3 scripts/gpt-minimal-build.py --main D/gpt_main0.bin --backup D/gpt_backup0.bin \
        --out-prefix /tmp/gpt-min --linux-name linux          # 默认吃满 last_usable
  # LUN4（只删 vendor_boot_*/init_boot_*）
  python3 scripts/gpt-minimal-build.py --lun 4 --main D/gpt_main4.bin --backup D/gpt_backup4.bin \
        --out-prefix /tmp/gpt4-min
  # 激进档（LUN4 再删 modem/qmcs/spunvm/...）：显式 --drop-extra，默认一个都不删
  python3 scripts/gpt-minimal-build.py --lun 4 --main ... --backup ... \
        --drop-extra modem_a,modem_b,qmcs,spunvm,mdcompress --dry-run
  # 没有备表 dump 时由主表合成（写后**必须**与设备实际备表读回逐字节比对）
  python3 scripts/gpt-minimal-build.py --main D/gpt0-primary.bin --synth-backup --dry-run

产出：<prefix>_main<lun>.bin（24576 B = LBA0..5）、<prefix>_backup<lun>.bin（20480 B = 备条目+备头）。
写入：主表 seek=0（6 扇区）；备表 seek=<backup_lba-4>（5 扇区）。
之后必须读回对账：scripts/gpt-audit-tb322fc.py --dev <新dump> --stock <官方包>

退出码：0 成功；2 参数/校验失败（保留项缺失、区间重叠、CRC 不符等）。
"""
import argparse
import binascii
import importlib.util
import os
import sys
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
SECTOR = 4096

# ---- 分类表（真源；RUNBOOK-BRINGUP/GPT-MINIMAL-DESIGN.md §2 与之逐条对应）----
# LUN0 必留：固件/引导链/TEE/设备身份/Lenovo 元数据（逐条理由见文档 §2.2）
LUN0_KEEP_CRITICAL = ["proinfo", "lenovolock", "lenovocust", "lenovoraw", "ssd",
                      "persist", "misc", "keystore", "frp"]
# LUN0 删除：Android 专属 / 我方历史产物（删条目；数据留在盘上直到被覆盖）
LUN0_DROP = ["super", "elden-super", "userdata", "elden-data",
             "vbmeta_system_a", "vbmeta_system_b", "metadata",
             "rawdump", "pstoredump", "pstoredu",
             "linux17", "eldenesp", "elden-su"]
# LUN4 删除：Android GKI 专用（A/B 各一套）；其余 74 项全留（文档 §2.3）
LUN4_DROP = ["vendor_boot_a", "vendor_boot_b", "init_boot_a", "init_boot_b"]
# LUN4 「理论上可删但未验证」——只作提示，必须 --drop-extra 显式点名才删
LUN4_LV2_CANDIDATES = ["modem_a", "modem_b", "qmcs", "spunvm", "mdcompress",
                       "xbl_ramdump_a", "xbl_ramdump_b", "soccp_debug_a", "soccp_debug_b",
                       "pdp_a", "pdp_b", "pdp_cdb_a", "pdp_cdb_b",
                       "spuservice_a", "spuservice_b", "qweslicstore_a", "qweslicstore_b"]


def load_gpt_surgery():
    p = os.path.join(HERE, "gpt-surgery-tb322fc.py")
    spec = importlib.util.spec_from_file_location("gptsurg", p)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def synth_backup(g, main_buf, hdr):
    """由主表 dump 合成备表镜像（备条目 + 备头）：4 扇区 entries + 1 扇区 header。"""
    nents, entsz = hdr["nents"], hdr["entsz"]
    blk = bytes(main_buf[hdr["ent_lba"] * SECTOR: hdr["ent_lba"] * SECTOR + nents * entsz])
    crc = binascii.crc32(blk) & 0xFFFFFFFF
    out = bytearray(5 * SECTOR)
    out[0:len(blk)] = blk
    cur = hdr["backup_lba"]
    off = 4 * SECTOR
    out[off:off + 92] = g.build_primary_header(cur, 1, hdr["first_usable"], hdr["last_usable"],
                                               hdr["disk_guid"], cur - 4, nents, entsz, crc)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lun", type=int, default=0, choices=(0, 4),
                    help="0 = LUN0（除删条目外还新建 linux 分区）；4 = LUN4（只删条目）")
    ap.add_argument("--main", required=True, help="主表镜像（24576 B，含 LBA0..5）")
    ap.add_argument("--backup", help="备表镜像（20480 B）；省略时需 --synth-backup")
    ap.add_argument("--synth-backup", action="store_true", help="由主表合成备表（写后必须与实际备表比对）")
    ap.add_argument("--out-prefix", help="输出前缀（省略 = 只打印计划）")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--linux-name", default="linux")
    ap.add_argument("--linux-gib", type=int, default=0, help="0 = 吃满 last_usable 之前所有空闲")
    ap.add_argument("--keep-esp-gib", type=float, default=0.0, help=">0 时在尾部再留一个 ESP（FAT32）")
    ap.add_argument("--drop-extra", default="", help="额外要删的 label（逗号分隔）")
    ap.add_argument("--keep-extra", default="", help="额外要保的 label（逗号分隔，优先于 drop）")
    ap.add_argument("--allow-drop-live", action="store_true",
                    help="允许删掉本机正在用的分区（elden-*/linux17/eldenesp）；默认拒绝")
    a = ap.parse_args()

    g = load_gpt_surgery()
    main_buf = bytearray(open(a.main, "rb").read())
    if len(main_buf) < 6 * SECTOR:
        sys.exit("主表镜像太短（需 ≥24576 B，含 LBA0..5）")
    hdr = g.parse_header(main_buf, SECTOR)
    if not g.check_header_crc(hdr):
        sys.exit("主表头部 CRC 无效（dump 不可信，先重取）")

    if a.backup:
        back_buf = bytearray(open(a.backup, "rb").read())
        b_hdr = g.parse_header(back_buf, 4 * SECTOR)
        if b_hdr["ent_lba"] != b_hdr["cur_lba"] - 4:
            sys.exit("备表布局意外（ent_lba != cur_lba-4）")
    elif a.synth_backup:
        back_buf = synth_backup(g, main_buf, hdr)
        b_hdr = g.parse_header(back_buf, 4 * SECTOR)
        print(f"  note     备表由主表合成（cur_lba={b_hdr['cur_lba']} ent_lba={b_hdr['ent_lba']}）"
              f"——写后必须与设备实际备表逐字节比对")
    else:
        sys.exit("需要 --backup 或 --synth-backup")

    ents = g.parse_entries(main_buf, hdr["ent_lba"], hdr["nents"], hdr["entsz"])
    names = [e["name"] for e in ents if e]
    if len(set(names)) != len(names):
        dup = sorted({n for n in names if names.count(n) > 1})
        sys.exit(f"✗ dump 里有重名分区：{dup}")

    if a.lun == 0:
        keep_critical, base_drop = LUN0_KEEP_CRITICAL, LUN0_DROP
    else:
        keep_critical, base_drop = [], LUN4_DROP
        cand = [n for n in LUN4_LV2_CANDIDATES if n in names]
        if cand:
            print(f"  note     LUN4 激进候选（默认保留，需 --drop-extra 才删）：{', '.join(cand)}")

    # 防「对本机现表误跑」：现表里有我们的活分区时，默认拒绝 —— 旧行为会静默把
    # elden-super/elden-data/linux17/eldenesp 四条删掉（数据留在盘上，但系统立刻失联），
    # 且新 linux 区间会盖住这些分区的数据（#675 同类）。
    LIVE_OURS = ("elden-super", "elden-data", "linux17", "eldenesp", "elden-su")
    live = [n for n in LIVE_OURS if n in names]
    if live and not a.allow_drop_live:
        sys.exit(f"✗ 输入表里有本机在用分区 {live} ⇒ 默认拒绝（这是「现表」不是「原厂表」）。\n"
                 f"  只想要计划看效果：加 --allow-drop-live 并先确认这次不用回退。")

    keep = set(keep_critical) | {x for x in a.keep_extra.split(",") if x}
    drop = (set(base_drop) | {x for x in a.drop_extra.split(",") if x}) - keep
    keep |= {n for n in names if n not in drop}      # 未列出的（如将来新增）默认保留

    missing = [k for k in keep_critical if k not in names]
    if missing:
        sys.exit(f"✗ 保留项缺失：{missing} —— 这份 dump 不含必需分区（是不是拿错了 LUN？）")

    kept = [e for e in ents if e and e["name"] in keep]
    dropped = [e for e in ents if e and e["name"] not in keep]
    first_usable, last_usable = hdr["first_usable"], hdr["last_usable"]
    tot = lambda lst: sum(e["last"] - e["first"] + 1 for e in lst) * SECTOR

    lin_first = lin_last = esp = None
    if a.lun == 0:
        lin_first = max(e["last"] for e in kept) + 1
        lin_last = (min(last_usable, lin_first + a.linux_gib * (2 ** 30) // SECTOR - 1)
                    if a.linux_gib else last_usable)
        if a.keep_esp_gib:
            n = int(a.keep_esp_gib * (2 ** 30)) // SECTOR
            esp = (lin_last - n + 1, lin_last)
            lin_last = esp[0] - 1
        if lin_last <= lin_first:
            sys.exit("✗ 尾部没有足够空闲（linux 分区长度为 0）")
        for e in kept:
            if e["first"] >= lin_first:
                sys.exit(f"✗ 保留分区 {e['name']} 落在新 linux 区间内（{e['first']}..{e['last']}）")

    print(f"== LUN{a.lun} 计划 ==")
    print(f"  保留 {len(kept):2d} 项 / {tot(kept)/2**20:8.1f} MiB：{', '.join(sorted(e['name'] for e in kept))}")
    if dropped:
        print(f"  删除 {len(dropped):2d} 项 / {tot(dropped)/2**30:8.2f} GiB：{', '.join(sorted(e['name'] for e in dropped))}")
    else:
        print("  删除 0 项")
    if lin_first:
        print(f"  {a.linux_name:>10s}: {lin_first}..{lin_last}  ({(lin_last-lin_first+1)*SECTOR/2**30:.2f} GiB)"
              + (f"   [ESP {esp[0]}..{esp[1]} {a.keep_esp_gib} GiB]" if esp else ""))
        # 覆盖冲突报告：新分区区间会物理盖掉哪些**被删条目**指向的数据（删条目 ≠ 删数据，
        # 但新分区的数据一旦写进去就真没了 —— 这是 #675 的原始事故形态）
        clob = [e["name"] for e in dropped
                if e["first"] <= lin_last and lin_first <= e["last"]]
        if clob:
            print(f"  ⚠ 新 {a.linux_name} 区间覆盖以下被删分区**原有的数据区**"
                  f"（写这个分区就会毁掉它们，回退表也救不回来）：{clob}")
        print(f"  last_usable={last_usable}（未用尾部 {(last_usable-lin_last)*SECTOR/2**20:.2f} MiB）")
    else:
        print(f"  （LUN{a.lun} 不新建分区：firmware-only LUN，腾出的空间留作空洞）")

    if a.dry_run or not a.out_prefix:
        print("（dry-run：未写文件）")
        return 0

    lin_slot = esp_slot = None
    if lin_first:
        lin_slot = next((e["idx"] for e in dropped if e["name"] in ("super", "elden-super")),
                        dropped[0]["idx"] if dropped else
                        next(i for i in range(hdr["nents"]) if ents[i] is None))
    if esp:
        used = {lin_slot} | {e["idx"] for e in kept}
        esp_slot = next(i for i in range(hdr["nents"]) if i not in used)
    new_block = bytearray()
    for i in range(hdr["nents"]):
        e = ents[i]
        if e is not None and e["name"] in keep:
            new_block += e["raw"]
        elif lin_first and i == lin_slot:
            new_block += g.make_entry(i, g.LINUX_FS_GUID, uuid.uuid4(), lin_first, lin_last, a.linux_name)
        elif esp and i == esp_slot:
            new_block += g.make_entry(i, g.EFI_SYS_GUID, uuid.uuid4(), esp[0], esp[1], "eldenesp")
        else:
            new_block += bytes(hdr["entsz"])
    assert len(new_block) == hdr["nents"] * hdr["entsz"]
    entries_crc = binascii.crc32(bytes(new_block)) & 0xFFFFFFFF

    out_main = bytearray(main_buf)
    out_main[hdr["ent_lba"] * SECTOR: hdr["ent_lba"] * SECTOR + len(new_block)] = new_block
    out_main[SECTOR:SECTOR + 92] = g.build_primary_header(
        1, hdr["backup_lba"], first_usable, last_usable, hdr["disk_guid"],
        hdr["ent_lba"], hdr["nents"], hdr["entsz"], entries_crc)
    out_backup = bytearray(back_buf)
    out_backup[0:len(new_block)] = new_block
    out_backup[4 * SECTOR:4 * SECTOR + 92] = g.build_primary_header(
        b_hdr["cur_lba"], 1, first_usable, last_usable, hdr["disk_guid"],
        b_hdr["ent_lba"], b_hdr["nents"], b_hdr["entsz"], entries_crc)

    m_p, b_p = a.out_prefix + f"_main{a.lun}.bin", a.out_prefix + f"_backup{a.lun}.bin"
    open(m_p, "wb").write(out_main)
    open(b_p, "wb").write(out_backup)

    v = g.parse_header(bytes(out_main), SECTOR)
    vb = g.parse_header(bytes(out_backup), 4 * SECTOR)
    assert g.check_header_crc(v) and g.check_header_crc(vb), "新表头 CRC 失败"
    p_blk = bytes(out_main[hdr["ent_lba"] * SECTOR:][:len(new_block)])
    b_blk = bytes(out_backup[:len(new_block)])
    for blk, h in ((p_blk, v), (b_blk, vb)):
        if binascii.crc32(blk) & 0xFFFFFFFF != h["entries_crc"]:
            sys.exit("✗ 条目 CRC 自检失败")
    new_ents = [e for e in g.parse_entries(bytes(out_main), hdr["ent_lba"], hdr["nents"], hdr["entsz"]) if e]
    print(f"写入 {m_p} ({len(out_main)} B) / {b_p} ({len(out_backup)} B)")
    print(f"自检：双表头 CRC OK、条目 CRC OK；新表 {len(new_ents)} 项")
    print(f"写入位置：主表 seek=0（6 扇区）  备表 seek={hdr['backup_lba']-4}（5 扇区）")
    print(f"回退：写回旧表 —— 主表 seek=0、备表 seek=<旧 backup_lba-4>（旧 backup_lba={hdr['backup_lba']}）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
