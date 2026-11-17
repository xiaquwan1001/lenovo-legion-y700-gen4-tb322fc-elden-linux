#!/usr/bin/env python3
"""gpt-minimal-build.py — 生成「最小可控」LUN0 GPT：删掉 Android 专属分区，整块盘给一个 Linux 分区。

设计口径（详见 RUNBOOK-BRINGUP/GPT-MINIMAL-DESIGN.md）：
  · **不移动任何保留分区**（absolute LBA 不变 ⇒ 零数据搬迁、零风险）；
  · 只做两件事：把 Android 专属条目**清零**、在尾部空闲区新建一个 `linux` 分区；
  · 保留分区**一个都不重新排序**（GPT 条目顺序无语义，重排只会增加风险）；
  · 删条目 ≠ 删数据：旧 GPT 备份在手就能原样退回去（实验因此可逆）。

用法：
  # 只看计划（不写文件）
  python3 scripts/gpt-minimal-build.py --main D/gpt_main0.bin --backup D/gpt_backup0.bin --dry-run
  # 产出新表（写主表 seek=0、备表 seek=<backup_lba>）
  python3 scripts/gpt-minimal-build.py --main D/gpt_main0.bin --backup D/gpt_backup0.bin \
        --out-prefix /tmp/gpt-min --linux-name linux --linux-gib 0     # 0 = 吃满剩余空间

产出：<prefix>_main0.bin（24576 B = LBA0..5）、<prefix>_backup0.bin（20480 B = 备条目+备头）。
写入（Linux 侧）：dd if=main of=/dev/sdX bs=4096 seek=0 conv=notrunc
                  dd if=backup of=/dev/sdX bs=4096 seek=<backup_lba-4> conv=notrunc
写入（EDL）：qdl ... write 0/0+6 <main> ; qdl ... write 0/<backup_lba-4>+5 <backup>
之后必须读回对账：scripts/gpt-audit-tb322fc.py --dev <新dump> --stock <官方包>

退出码：0 成功；2 参数/校验失败（保留项缺失、区间重叠等）。
"""
import argparse
import binascii
import importlib.util
import os
import sys
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
SECTOR = 4096

# ---- 分类表（真源；文档 §2 与之逐条对应）------------------------------------
# KEEP: 必须保留（固件/引导链/TEE/设备身份/Lenovo 元数据）
KEEP_CRITICAL = [
    "proinfo", "lenovolock", "lenovocust", "lenovoraw", "ssd", "persist",
    "misc", "keystore", "frp",
]
# DROP: Android 专属 / 我方历史产物（删条目；数据留在盘上，直到被覆盖）
DROP_ANDROID = [
    "super", "elden-super", "userdata", "elden-data",
    "vbmeta_system_a", "vbmeta_system_b", "metadata",
    "rawdump", "pstoredump", "pstoredu",          # Android ramdump 区；Linux 用 ramoops 保留内存
    "linux17", "eldenesp", "elden-su",            # 我方旧布局（由新的单个 linux 取代；--keep-esp 可留 ESP）
]
# LUN4 的可删项（Android GKI 专用；A/B 各一套）
LUN4_DROP = ["vendor_boot_a", "vendor_boot_b", "init_boot_a", "init_boot_b"]


def load_gpt_surgery():
    p = os.path.join(HERE, "gpt-surgery-tb322fc.py")
    spec = importlib.util.spec_from_file_location("gptsurg", p)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--main", required=True, help="LUN0 主表镜像（24576 B，LBA0..5）或设备 dump")
    ap.add_argument("--backup", required=True, help="LUN0 备表镜像（20480 B，备条目+备头）")
    ap.add_argument("--out-prefix", help="输出前缀（省略 = 只打印计划）")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--linux-name", default="linux")
    ap.add_argument("--linux-gib", type=int, default=0, help="0 = 吃满 last_usable 之前的所有空闲")
    ap.add_argument("--keep-esp-gib", type=float, default=0.0, help=">0 时在尾部保留一个 ESP（FAT32）")
    ap.add_argument("--drop-extra", default="", help="额外要删的 label（逗号分隔）")
    ap.add_argument("--keep-extra", default="", help="额外要保的 label（逗号分隔，优先于 drop）")
    a = ap.parse_args()

    g = load_gpt_surgery()
    main_buf = bytearray(open(a.main, "rb").read())
    back_buf = bytearray(open(a.backup, "rb").read())
    if len(main_buf) < 6 * SECTOR:
        sys.exit("主表镜像太短（需 ≥24576 B）")
    hdr = g.parse_header(main_buf, SECTOR)
    if not g.check_header_crc(hdr):
        sys.exit("主表头部 CRC 无效（dump 不可信，先重取）")
    b_hdr = g.parse_header(back_buf, 4 * SECTOR)
    if b_hdr["ent_lba"] != b_hdr["cur_lba"] - 4:
        sys.exit("备表布局意外（ent_lba != cur_lba-4）")
    ents = g.parse_entries(main_buf, hdr["ent_lba"], hdr["nents"], hdr["entsz"])
    b_ents = g.parse_entries(back_buf, 0, b_hdr["nents"], b_hdr["entsz"])
    names = [e["name"] for e in ents if e]
    b_names = [e["name"] for e in b_ents if e]
    if set(names) != set(b_names):
        print(f"  ⚠ 主/备条目集合不一致（主 {len(names)} / 备 {len(b_names)}）——请确认这对镜像是同一次 dump",
              file=sys.stderr)

    keep = set(KEEP_CRITICAL) | {x for x in a.keep_extra.split(",") if x}
    drop = (set(DROP_ANDROID) | {x for x in a.drop_extra.split(",") if x}) - keep
    keep |= {n for n in names if n not in drop}          # 表里没列出的（如将来新增）默认保留

    missing = [k for k in KEEP_CRITICAL if k not in names]
    if missing:
        sys.exit(f"✗ 保留项缺失：{missing} —— 这份 dump 不含必需分区（是不是拿错了 LUN？）")

    # 计算范围
    first_usable, last_usable = hdr["first_usable"], hdr["last_usable"]
    kept = [e for e in ents if e and e["name"] in keep]
    dropped = [e for e in ents if e and e["name"] not in keep]
    tail_kept_last = max(e["last"] for e in kept)
    lin_first = tail_kept_last + 1
    if a.linux_gib:
        lin_last = min(last_usable, lin_first + a.linux_gib * (2 ** 30) // SECTOR - 1)
    else:
        lin_last = last_usable
    esp_first = None
    if a.keep_esp_gib:
        esp_n = int(a.keep_esp_gib * (2 ** 30)) // SECTOR
        esp_first, esp_last = lin_last - esp_n + 1, lin_last
        lin_last = esp_first - 1
    if lin_last <= lin_first:
        sys.exit("✗ 尾部没有足够空闲（linux 分区长度为 0）")
    for e in kept:
        if e["first"] >= lin_first:
            sys.exit(f"✗ 保留分区 {e['name']} 落在新 linux 区间内（{e['first']}..{e['last']}）")

    # 计划输出
    tot = lambda lst: sum(e["last"] - e["first"] + 1 for e in lst) * SECTOR
    print(f"== LUN0 计划（{a.linux_name}）==")
    print(f"  保留 {len(kept):2d} 项 / {tot(kept)/2**20:8.1f} MiB：{', '.join(sorted(e['name'] for e in kept))}")
    print(f"  删除 {len(dropped):2d} 项 / {tot(dropped)/2**30:8.1f} GiB：{', '.join(sorted(e['name'] for e in dropped))}")
    print(f"  {a.linux_name:>10s}: {lin_first}..{lin_last}  ({(lin_last-lin_first+1)*SECTOR/2**30:.1f} GiB)"
          + (f"   [ESP {esp_first}..{esp_first+int(a.keep_esp_gib*(2**30))//SECTOR-1} {a.keep_esp_gib} GiB]" if esp_first else ""))
    print(f"  last_usable={last_usable}（未用尾部 {(last_usable-lin_last)*SECTOR/2**20:.1f} MiB）")

    if a.dry_run or not a.out_prefix:
        print("（dry-run：未写文件）")
        return 0

    # 重建条目块：保留项原样；删除项清零；linux 放进第一个被删 Android 分区的槽位
    slot = next((e["idx"] for e in dropped if e["name"] in ("super", "elden-super")),
                next(e["idx"] for e in dropped))
    new_block = bytearray()
    for i in range(hdr["nents"]):
        e = ents[i]
        if e is not None and e["name"] in keep:
            new_block += e["raw"]
        elif i == slot:
            new_block += g.make_entry(i, g.LINUX_FS_GUID, uuid.uuid4(), lin_first, lin_last, a.linux_name)
        elif esp_first and i == next(x["idx"] for x in dropped):
            new_block += g.make_entry(i, g.EFI_SYS_GUID, uuid.uuid4(), esp_first,
                                      esp_first + int(a.keep_esp_gib * (2 ** 30)) // SECTOR - 1, "eldenesp")
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

    m_p, b_p = a.out_prefix + "_main0.bin", a.out_prefix + "_backup0.bin"
    open(m_p, "wb").write(out_main)
    open(b_p, "wb").write(out_backup)

    # 自检
    v = g.parse_header(bytes(out_main), SECTOR)
    vb = g.parse_header(bytes(out_backup), 4 * SECTOR)
    assert g.check_header_crc(v) and g.check_header_crc(vb), "新表头 CRC 失败"
    p_blk = bytes(out_main[hdr["ent_lba"] * SECTOR:][:len(new_block)])
    b_blk = bytes(out_backup[:len(new_block)])
    for blk, h in ((p_blk, v), (b_blk, vb)):
        if binascii.crc32(blk) & 0xFFFFFFFF != h["entries_crc"]:
            sys.exit("✗ 条目 CRC 自检失败")
    kept_new = [e for e in g.parse_entries(bytes(out_main), hdr["ent_lba"], hdr["nents"], hdr["entsz"]) if e]
    print(f"写入 {m_p} ({len(out_main)} B) / {b_p} ({len(out_backup)} B)")
    print(f"自检：双表头 CRC OK、条目 CRC OK；新表 {len(kept_new)} 项 "
          f"({', '.join(sorted(e['name'] for e in kept_new))})")
    print(f"写入位置：主表 seek=0（6 扇区）  备表 seek={hdr['backup_lba']-4}（5 扇区）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
