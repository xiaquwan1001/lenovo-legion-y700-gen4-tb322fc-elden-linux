#!/usr/bin/env python3
"""gpt-restore-tb322fc.py — REVERSE the dual-boot GPT surgery on TB322FC LUN0:
grow `userdata` back to `last_usable` and delete the `linux*` partition.
4 KiB sectors. Does NOT write to the device — produces images for `dd`.

★★ fail-closed 门（审计批 1 + 批 3，2026-11-21 / 2026-11-23）★★
  本脚本的产物是设备侧 `dd ... of=/dev/block/sda` 直接重写 LUN0 主表/备表的镜像
  （恢复 userdata、**删掉 linux 分区**）—— 拿错表 = 抹掉 Linux 根。build 有两道门：
    1. `--expect-fingerprint '<main_sha256>,<backup_sha256>'`（**必填**）：输入件指纹；
    2. **TB322FC 表指纹门**（默认开，2026-11-23 新增）：目标盘表的「分区名/大小/数量」指纹
       必须是本机 TB322FC LUN0 双启表，否则拒绝出件；确要在别的表上跑 = 显式 `--force`
       （会把全部偏差先打印出来）。
  设备侧 dd 步骤**不再内嵌在本 docstring 里**（内嵌 = 绕过门就能直接复制粘贴）：
  两道门都过后 build 会打印 §device 段（含写前读回门 + 写后读回校验），照那段执行。

Usage:
  M=env-pass/gpt-20261002/gpt_primary.bin; B=env-pass/gpt-20261002/gpt_backup.bin
  python3 gpt-restore-tb322fc.py build --main "$M" --backup "$B" \
      --out-prefix env-pass/gpt-20261002/restore \
      --expect-fingerprint "$(sha256sum "$M" | cut -d' ' -f1),$(sha256sum "$B" | cut -d' ' -f1)"
  python3 gpt-restore-tb322fc.py list --main "$M"      # 只读列出分区
"""
import argparse, binascii, hashlib, struct, sys, uuid

SECTOR = 4096

# ---- TB322FC LUN0 期望表指纹（fail-closed 门，审计批 3）-------------------------------
# 实测来源：2026-11-20 EDL 只读 dump
#   backup/HA2EXB0E-16+512/edl-20261120-2235/gpt0-{primary,backup}.bin
# 与另外 5 份 LUN0 dump（uefi-edl-read-20261101 / edl-20261120-2208 / android-slim-v3-20261119 /
# live-gpt0-20261120 / lun0-20261121）的**核心 15 条几何逐条一致**（core_fp 同为 4d00c64e…）。
# 指纹只锁「分区名 / 起始与结束 LBA（=大小）/ 条目数 / 条目区几何」，**不含 A/B 属性字节**
# （tries_remaining / successful 每次开机都会被 ABL 改写，含进去会把好表当成坏表）。
TB_NENTS, TB_ENDSZ, TB_ENT_LBA, TB_FIRST_USABLE = 32, 128, 2, 6
TB_USERDATA_FIRST = 5972392
TB_N_USED = 17          # 15 stock + userdata + 尾部 linux*（现机叫 linux17）
TB_CORE = (             # (条目号, 名字, first_lba, last_lba) —— 名字/大小/序号全锁
    (0,  "proinfo",        6,        773),
    (1,  "lenovolock",     774,      901),
    (2,  "lenovocust",     902,      77701),
    (3,  "lenovoraw",      77702,    81797),
    (4,  "ssd",            81798,    81799),
    (5,  "persist",        81800,    89991),
    (6,  "misc",           89992,    90247),
    (7,  "keystore",       90248,    90375),
    (8,  "frp",            90376,    90503),
    (9,  "super",          90504,    5857671),
    (10, "vbmeta_system_a", 5857672,  5857687),
    (11, "vbmeta_system_b", 5857688,  5857703),
    (12, "metadata",       5857704,  5874087),
    (13, "rawdump",        5874088,  5939623),
    (14, "pstoredump",     5939624,  5972391),
)
# sha256("TB322FC-core|sector=4096|nents=32|entsz=128|ent_lba=2|first_usable=6|count=15\n" + 上面 15 行)
TB_CORE_FP = "4d00c64e28cb37b462dbea73fe1ad4fe7a3fab230d822a17b903c84249ddc1d4"
TB_LAST_USABLE = {
    123871226: "512 GB（现机 HA2EXB0E 16+512）",
    61390842:  "256 GB / 234 GiB 旧布局（2026-10 记录，未在现机复核）",
}

def sha256_file(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()

def le_guid(b): return uuid.UUID(bytes_le=bytes(b))
def guid_le(u): return u.bytes_le

def parse_header(buf, offset):
    h = buf[offset:offset+92]
    if h[0:8] != b"EFI PART":
        raise ValueError(f"no GPT header at {offset}")
    return {
        "raw": bytearray(h),
        "hdr_size": struct.unpack_from("<I", h, 12)[0],
        "hdr_crc": struct.unpack_from("<I", h, 16)[0],
        "cur_lba": struct.unpack_from("<Q", h, 24)[0],
        "backup_lba": struct.unpack_from("<Q", h, 32)[0],
        "first_usable": struct.unpack_from("<Q", h, 40)[0],
        "last_usable": struct.unpack_from("<Q", h, 48)[0],
        "disk_guid": h[56:72],
        "ent_lba": struct.unpack_from("<Q", h, 72)[0],
        "nents": struct.unpack_from("<I", h, 80)[0],
        "entsz": struct.unpack_from("<I", h, 84)[0],
        "entries_crc": struct.unpack_from("<I", h, 88)[0],
    }

def check_header_crc(hdr):
    h = bytearray(hdr["raw"]); stored = struct.unpack_from("<I", h, 16)[0]
    struct.pack_into("<I", h, 16, 0)
    calc = binascii.crc32(bytes(h[:hdr["hdr_size"]])) & 0xFFFFFFFF
    return stored == calc

def parse_entries(buf, ent_lba, nents, entsz, base=None):
    if base is None:
        base = ent_lba * SECTOR
    out = []
    for i in range(nents):
        e = buf[base + i*entsz: base + (i+1)*entsz]
        if le_guid(e[0:16]).int == 0:
            out.append(None); continue
        out.append({
            "idx": i, "type": le_guid(e[0:16]), "part_guid": le_guid(e[16:32]),
            "first": struct.unpack_from("<Q", e, 32)[0],
            "last": struct.unpack_from("<Q", e, 40)[0],
            "flags": struct.unpack_from("<Q", e, 48)[0],
            "name": e[56:128].decode("utf-16-le").split("\x00")[0],
            "raw": bytes(e),
        })
    return out

def build_header(cur, backup, first_usable, last_usable, disk_guid, ent_lba, nents, entsz, entries_crc):
    h = bytearray(92)
    h[0:8] = b"EFI PART"
    struct.pack_into("<I", h, 8, 0x00010000)
    struct.pack_into("<I", h, 12, 92)
    struct.pack_into("<I", h, 16, 0)
    struct.pack_into("<I", h, 20, 0)
    struct.pack_into("<Q", h, 24, cur)
    struct.pack_into("<Q", h, 32, backup)
    struct.pack_into("<Q", h, 40, first_usable)
    struct.pack_into("<Q", h, 48, last_usable)
    h[56:72] = disk_guid
    struct.pack_into("<Q", h, 72, ent_lba)
    struct.pack_into("<I", h, 80, nents)
    struct.pack_into("<I", h, 84, entsz)
    struct.pack_into("<I", h, 88, entries_crc)
    struct.pack_into("<I", h, 16, binascii.crc32(bytes(h)) & 0xFFFFFFFF)
    return bytes(h)

def tb322fc_core_fp(hdr, by_name):
    """核心 15 条（名字/序号/大小）指纹；不符 TB_CORE_FP 即不是 TB322FC 期望表。"""
    lines = []
    for idx, name, _f, _l in TB_CORE:
        got = by_name.get(name)
        lines.append(f"{idx}:{name}:MISSING" if got is None
                     else f"{idx}:{name}:{got['first']}-{got['last']}")
    blob = ("TB322FC-core|sector=%d|nents=%d|entsz=%d|ent_lba=%d|first_usable=%d|count=%d\n"
            % (SECTOR, hdr["nents"], hdr["entsz"], hdr["ent_lba"], hdr["first_usable"], len(TB_CORE))
            + "\n".join(lines))
    return hashlib.sha256(blob.encode()).hexdigest(), lines


def table_fingerprint(hdr, ents):
    """全表（分区名/大小/数量）指纹，作为产出件可追溯的"这张表"戳。"""
    used = [e for e in ents if e]
    blob = ("TB322FC-full|sector=%d|nents=%d|entsz=%d|first_usable=%d|last_usable=%d|used=%d\n"
            % (SECTOR, hdr["nents"], hdr["entsz"], hdr["first_usable"], hdr["last_usable"], len(used))
            + "\n".join(f"{e['idx']}:{e['name']}:{e['first']}-{e['last']}" for e in used))
    return hashlib.sha256(blob.encode()).hexdigest()


def tb322fc_table_gate(hdr, ents, linux_name, force):
    """★ 表指纹门：目标盘分区表不符 TB322FC 期望 ⇒ 无 --force 就拒绝执行（rc≠0，不出镜像）。

    判据 = 分区名 / 大小（first..last LBA）/ 数量 三层指纹 + 尾部 linux 关系；
    返回 (userdata 条目, 待删尾部条目, 全表指纹)。
    """
    used = [e for e in ents if e]
    by_name = {e["name"]: e for e in used}
    problems = []
    for key, want, what in (("nents", TB_NENTS, "条目区条目数"),
                            ("entsz", TB_ENDSZ, "条目尺寸"),
                            ("ent_lba", TB_ENT_LBA, "条目区起始 LBA"),
                            ("first_usable", TB_FIRST_USABLE, "first_usable")):
        if hdr[key] != want:
            problems.append(f"{what} hdr.{key}={hdr[key]} != 期望 {want}")
    if hdr["last_usable"] not in TB_LAST_USABLE:
        problems.append(f"last_usable={hdr['last_usable']} 不在已知 TB322FC 容量集合 "
                        f"{sorted(TB_LAST_USABLE)}（不是这台机器的 LUN0 表）")
    if len(by_name) != len(used):
        dup = sorted({n for n in by_name if [e["name"] for e in used].count(n) > 1})
        problems.append(f"分区名重复：{dup}")
    core_fp, core_lines = tb322fc_core_fp(hdr, by_name)
    if core_fp != TB_CORE_FP:
        want_lines = [f"{i}:{n}:{f}-{l}" for i, n, f, l in TB_CORE]
        missing = [ln.split(":")[1] for ln in core_lines if ln.endswith("MISSING")]
        if missing:
            problems.append("核心分区缺/改名：" + ", ".join(missing))
        diff = [f"{w} → {got}" for w, got in zip(want_lines, core_lines) if w != got]
        if diff:
            problems.append("核心分区起始/大小不符（期望 → 实算）：" + "; ".join(diff))
    if len(used) != TB_N_USED:
        problems.append(f"在用分区数 {len(used)} != 期望 {TB_N_USED}（分区数量指纹不符）"
                        f"：{[e['name'] for e in used]}")
    ud, lin = by_name.get("userdata"), None
    if ud is None:
        problems.append("没有 userdata 分区（多半拿错了 LUN —— 本脚本针对 LUN0 主表）")
    else:
        if ud["first"] != TB_USERDATA_FIRST:
            problems.append(f"userdata.first={ud['first']} != 期望 {TB_USERDATA_FIRST}")
        trail = [e for e in used if e["idx"] != ud["idx"] and e["first"] > ud["last"]]
        if len(trail) != 1:
            problems.append("userdata 之后应恰有 1 条待删分区（本次手术的 linux*），实有 "
                            f"{len(trail)}：{[e['name'] for e in trail]}")
        else:
            lin = trail[0]
            if lin["first"] != ud["last"] + 1:
                problems.append(f"待删分区 {lin['name']}.first={lin['first']} != userdata.last+1="
                                f"{ud['last'] + 1}（中间有空洞/夹着别的分区）")
            if lin["last"] != hdr["last_usable"]:
                problems.append(f"待删分区 {lin['name']}.last={lin['last']} != "
                                f"last_usable={hdr['last_usable']}")
            if linux_name and lin["name"] != linux_name:
                problems.append(f"--linux-name={linux_name} 指的不是尾部那条（尾部是 {lin['name']}）")
    fp = table_fingerprint(hdr, ents)
    head = ("目标盘分区表**不符 TB322FC 期望**（fail-closed 表指纹门）\n"
            f"  实算全表指纹 {fp}\n"
            f"  核心指纹 期望 {TB_CORE_FP}\n"
            f"            实算 {core_fp}\n"
            "  偏差：\n    - " + "\n    - ".join(problems) + "\n")
    if problems:
        if not force:
            sys.exit("FAIL: " + head +
                     "  本脚本的产物会重写 LUN0 主/备表并**删掉 linux 分区**；拿错表 = 抹 Linux 根。\n"
                     "  确认真要在非 TB322FC 期望表上跑：加 --force（后果自负）")
        print("[force] WARN: " + head.rstrip())
        print("[force] --force 已给：忽略上面全部偏差继续；表指纹已记入产出说明")
    else:
        print(f"[table-gate] TB322FC 表指纹通过：核心 {len(TB_CORE)} 条名字/大小/序号一致，"
              f"在用 {len(used)} 条，last_usable={hdr['last_usable']}"
              f"（{TB_LAST_USABLE[hdr['last_usable']]}）")
        print(f"[table-gate] 表指纹 {fp}（核心指纹 {core_fp}）")
    return ud, lin, fp


def print_device_procedure(out_prefix, b_start, main_sha, tbl_fp):
    """两道门都过后才打印设备侧步骤（写前读回门 + 写后读回校验）。"""
    mb = out_prefix.rsplit("/", 1)[-1]
    print("\n== 设备侧步骤（§device）—— 只有上面两道门都通过的本次 build 才会打印这一段 ==")
    print(f"  门印：表指纹 {tbl_fp}")
    print(f"        输入主表 sha256 {main_sha}")
    print(f"  〇 把 {mb}_main0.bin / {mb}_backup0.bin 推到设备 /sdcard/（adb push 或已在那里）")
    print("  ① 写前门（必须先过；不过就停手 —— 现表已与本次输入不同，镜像作废）：")
    print("     dd if=/dev/block/sda bs=4096 count=6 | sha256sum")
    print(f"     必须 == {main_sha}")
    print("  ② 写（删 linux 分区 + userdata 扩回 last_usable）：")
    print(f"     dd if=/sdcard/{mb}_main0.bin   of=/dev/block/sda bs=4096 seek=0 conv=notrunc")
    print(f"     dd if=/sdcard/{mb}_backup0.bin of=/dev/block/sda bs=4096 seek={b_start} conv=notrunc")
    print("     sync")
    print("  ③ 写后读回（两发都必须与产出件 sha256 一致，否则立即停手报障，不要再重启）：")
    print("     dd if=/dev/block/sda bs=4096 count=6 | sha256sum")
    print(f"     dd if=/dev/block/sda bs=4096 skip={b_start} count=5 | sha256sum")
    print("  ④ 重启；Android 首次开机自动 resize.f2fs 把 /data 扩回 last_usable。")


def cmd_build(a):
    # ★ fail-closed 门（审计批 1，2026-11-22）：本脚本的产物是设备侧 dd 直接重写 LUN0 主表
    #   的镜像（恢复 userdata、删 linux 分区）——拿错表 = 抹掉 Linux 根。
    #   ⇒ 必须显式提供 --expect-fingerprint "<main的sha256>,<backup的sha256>"，
    #   与输入实算值比对，不符（或未提供）一律拒绝产出。查值命令：
    #     sha256sum <main> <backup>
    if not a.expect_fingerprint:
        sys.exit("FAIL: 缺 --expect-fingerprint。先算指纹再跑：\n"
                 f"  sha256sum {a.main} {a.backup}\n"
                 "  然后传 --expect-fingerprint '<main_sha>,<backup_sha>'。拿错表 = 抹 Linux 根，不指纹不出镜像")
    want = [w.strip().lower() for w in a.expect_fingerprint.split(",")]
    if len(want) != 2 or any(len(w) != 64 for w in want):
        sys.exit("FAIL: --expect-fingerprint 格式应为 '<main_sha256>,<backup_sha256>'（两个 64 位 hex，逗号分隔）")
    got_main, got_backup = sha256_file(a.main), sha256_file(a.backup)
    if got_main != want[0] or got_backup != want[1]:
        sys.exit("FAIL: 表指纹不符 —— 拿错表/表已变，拒绝生成恢复镜像\n"
                 f"  main   实算 {got_main}\n  期望   {want[0]}\n"
                 f"  backup 实算 {got_backup}\n  期望   {want[1]}\n"
                 "  若确是新表：重算 sha256sum 后显式传入新指纹（别图省事直接换旧指纹）")
    print(f"[fingerprint] main={got_main[:16]}… backup={got_backup[:16]}… 与 --expect-fingerprint 一致")
    main = bytearray(open(a.main, "rb").read())
    backup = bytearray(open(a.backup, "rb").read())
    hdr = parse_header(main, SECTOR)
    # backup image = 34 sectors starting at backup_start_lba; header at offset (backup_lba - start)
    # 备表起点默认**从主表头现算**（alt_lba-4），不再写死 61390814 ——
    # 那个常数属旧 234 GiB 布局，现表 alt_lba=123871231，写死会让 b_off 跑到镜像外，
    # 报「no GPT header at 501...」（用户完全看不出是常数过期）。
    b_start = (a.backup_start_lba if a.backup_start_lba is not None
               else hdr["backup_lba"] - 4)
    b_off = (hdr["backup_lba"] - b_start) * SECTOR
    if b_off < 0 or b_off + 92 > len(backup):
        sys.exit(f"备表镜像里找不到备表头：backup_lba={hdr['backup_lba']} b_start={b_start} "
                 f"b_off={b_off} len={len(backup)}（--backup-start-lba 给错了？）")
    b_hdr = parse_header(backup, b_off)
    assert check_header_crc(hdr), "primary header CRC invalid"
    assert check_header_crc(b_hdr), "backup header CRC invalid"

    pblock = main[hdr["ent_lba"]*SECTOR: hdr["ent_lba"]*SECTOR + hdr["nents"]*hdr["entsz"]]
    assert (binascii.crc32(pblock) & 0xFFFFFFFF) == hdr["entries_crc"], "primary entries CRC mismatch"
    bblock = backup[(b_hdr["ent_lba"]-b_start)*SECTOR: (b_hdr["ent_lba"]-b_start)*SECTOR + b_hdr["nents"]*b_hdr["entsz"]]
    assert (binascii.crc32(bblock) & 0xFFFFFFFF) == b_hdr["entries_crc"], "backup entries CRC mismatch"

    ents = parse_entries(main, hdr["ent_lba"], hdr["nents"], hdr["entsz"])
    first_usable, last_usable = hdr["first_usable"], hdr["last_usable"]

    # ★ 表指纹门（审计批 3，2026-11-23）：不符 TB322FC 期望 ⇒ 无 --force 拒绕执行。
    #   待删分区默认 = userdata 之后的那条（本机现表叫 linux17，旧默认 "linux" 在本机永远 assert）；
    #   --linux-name 仍可点名复核（指的不是尾部那条 ⇒ 拒）。
    ud, lin, tbl_fp = tb322fc_table_gate(hdr, ents, a.linux_name, a.force)
    if lin is None or ud is None:
        sys.exit("FAIL: 表门没给出可用的 userdata/尾部待删分区（--force 也救不了）；"
                 "先 python3 gpt-restore-tb322fc.py list --main <main> 看表，或 --linux-name 点名")

    # 覆盖检查：userdata 拉长到 last_usable 会盖掉它和末尾之间的所有分区条目指向的数据。
    # 只允许「中间只有要被删的 linux」这一种情况（其它情况 = 真盖别人）。
    between = [e["name"] for e in ents
               if e is not None and e is not ud and e is not lin
               and e["first"] <= last_usable and ud["last"] + 1 <= e["last"]]
    if between:
        sys.exit(f"userdata 拉长到 {last_usable} 会压到这些在用分区：{between} ⇒ 拒绝生成")
    print(f"userdata: {ud['first']}..{ud['last']} ({(ud['last']-ud['first']+1)*SECTOR/2**30:.1f} GiB)")
    print(f"linux   : idx {lin['idx']} {lin['first']}..{lin['last']} -> REMOVED")
    print(f"new userdata last = {last_usable} ({(last_usable-ud['first']+1)*SECTOR/2**30:.1f} GiB)")

    # rebuild entries: grow userdata, drop linux
    new_block = bytearray()
    for i in range(hdr["nents"]):
        e = ents[i]
        if i == ud["idx"]:
            b = bytearray(e["raw"])
            struct.pack_into("<Q", b, 40, last_usable)   # last_lba
            new_block += b
        elif e is None:
            new_block += bytes(hdr["entsz"])
        elif i == lin["idx"]:
            new_block += bytes(hdr["entsz"])             # free the slot
        else:
            new_block += e["raw"]
    assert len(new_block) == hdr["nents"]*hdr["entsz"]
    entries_crc = binascii.crc32(bytes(new_block)) & 0xFFFFFFFF

    out_main = bytearray(main)
    out_main[hdr["ent_lba"]*SECTOR: hdr["ent_lba"]*SECTOR+len(new_block)] = new_block
    out_main[SECTOR:SECTOR+92] = build_header(1, hdr["backup_lba"], first_usable, last_usable,
                                              hdr["disk_guid"], hdr["ent_lba"], hdr["nents"], hdr["entsz"], entries_crc)
    out_backup = bytearray(backup)
    off_e = (b_hdr["ent_lba"]-b_start)*SECTOR
    out_backup[off_e:off_e+len(new_block)] = new_block
    out_backup[b_off:b_off+92] = build_header(b_hdr["cur_lba"], 1, first_usable, last_usable,
                                              hdr["disk_guid"], b_hdr["ent_lba"], b_hdr["nents"], b_hdr["entsz"], entries_crc)

    open(a.out_prefix+"_main0.bin", "wb").write(out_main)
    open(a.out_prefix+"_backup0.bin", "wb").write(out_backup)
    print(f"wrote {a.out_prefix}_main0.bin ({len(out_main)} B), {a.out_prefix}_backup0.bin ({len(out_backup)} B)")
    print(f"entries_crc={entries_crc:#010x}")
    # self-verify
    v = parse_header(bytes(out_main), SECTOR); assert check_header_crc(v)
    vb = parse_header(bytes(out_backup), b_off); assert check_header_crc(vb)
    print("self-check OK; backup write offset (4096 sectors) =", b_start)
    print_device_procedure(a.out_prefix, b_start, got_main, tbl_fp)

def cmd_list(a):
    main = open(a.main, "rb").read()
    hdr = parse_header(main, SECTOR)
    for e in parse_entries(main, hdr["ent_lba"], hdr["nents"], hdr["entsz"]):
        if e: print(f"  [{e['idx']:2d}] {e['name']:20s} first={e['first']} last={e['last']} ({(e['last']-e['first']+1)*SECTOR/2**30:.1f} GiB)")

def main():
    p = argparse.ArgumentParser(); sub = p.add_subparsers(dest="cmd", required=True)
    b = sub.add_parser("build")
    b.add_argument("--main", required=True); b.add_argument("--backup", required=True)
    b.add_argument("--out-prefix", required=True)
    b.add_argument("--linux-name", default=None,
                   help="待删分区名（默认 = userdata 之后的那条，本机现表为 linux17）；给名字则额外复核")
    b.add_argument("--backup-start-lba", type=int, default=None,
                   help="备表镜像首扇区 LBA（默认由主表 alt_lba 现算 = backup_lba-4）")
    b.add_argument("--expect-fingerprint", default=None,
                   help="fail-closed 门 1：'<main_sha256>,<backup_sha256>'（sha256sum 实算），不符即拒绝产出")
    b.add_argument("--force", action="store_true",
                   help="fail-closed 门 2 的旁路：跳过 TB322FC 表指纹门（非本机表/被改表也会出件，后果自负）")
    b.set_defaults(f=cmd_build)
    l = sub.add_parser("list"); l.add_argument("--main", required=True); l.set_defaults(f=cmd_list)
    a = p.parse_args(); a.f(a)

if __name__ == "__main__":
    main()
