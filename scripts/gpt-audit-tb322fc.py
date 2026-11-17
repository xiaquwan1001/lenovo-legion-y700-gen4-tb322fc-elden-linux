#!/usr/bin/env python3
"""gpt-audit-tb322fc.py — 把设备 GPT 主表 dump（EDL 只读得到）与官方 259 包逐字节对账。

为什么需要它（2026-11-17 的教训）：旧口径「GPT 已排除」实际只验了 **edl.py printgpt 能解析**，
没验 **A/B 属性字节 / 分区条目是否等于原厂**。本次正是靠逐字节对账发现 LUN0 有 4 条差异
（`super`/`userdata` 被改名、多出 `linux17`/`eldenesp`）、LUN4 有 22 个分区属性字节非 stock。

用法：
  python3 scripts/gpt-audit-tb322fc.py \
      --dev reports/artifacts/bl-stuck-20261118/edl-read \
      --stock ~/文档/TB322FC_15.10.259

输入：`--dev` 目录下 `gpt<N>-primary.bin`（每份 24576 B = LUN 的 LBA0..5，4096 B 扇区）；
     `--stock` 目录下 `gpt_main<N>.bin`（官方包原样）。
输出：逐 LUN 的头部/条目 CRC 自检 + 与官方件的逐字节差异 + 属性字节（entry byte[6]）位图解码。

退出码：0 = 全部与官方逐字节相同；1 = 有差异（仍有参考价值，属正常，不代表 GPT 坏）。
"""
import argparse
import os
import struct
import sys
import zlib

AB_BITS = (
    (0x04, "active"),
    (0x40, "successful"),
    (0x80, "unbootable"),
)


def parse(buf):
    """返回 (info, {name: (first_lba, last_lba, attr)})。buf 从 LBA0 开始、4096 B 扇区。"""
    h = buf[4096:4096 + 92]
    if h[:8] != b"EFI PART":
        raise ValueError("no EFI PART signature at LBA1")
    (rev, hsize, hcrc, _res, mylba, alt, first_u, last_u) = struct.unpack_from("<IIIIQQQQ", h, 8)
    entlba, = struct.unpack_from("<Q", h, 72)
    nent, esize, ecrc = struct.unpack_from("<III", h, 80)
    hdr_crc_ok = (zlib.crc32(h[:16] + b"\0\0\0\0" + h[20:92]) & 0xFFFFFFFF) == hcrc
    arr_off = entlba * 4096
    arr = buf[arr_off:arr_off + nent * esize]
    arr_crc_ok = (zlib.crc32(arr) & 0xFFFFFFFF) == ecrc
    parts = {}
    for i in range(nent):
        e = arr[i * esize:(i + 1) * esize]
        if e[:16] == b"\0" * 16:
            continue
        name = e[56:128].decode("utf-16-le", errors="replace").rstrip("\x00").strip()
        fl, ll, attr = struct.unpack_from("<QQQ", e, 32)
        parts[name] = (fl, ll, attr, i)
    info = dict(mylba=mylba, alt=alt, first_u=first_u, last_u=last_u,
                nent=nent, esize=esize, hdr_crc_ok=hdr_crc_ok, arr_crc_ok=arr_crc_ok)
    return info, parts


def ab_byte(attr):
    """entry 的 byte[6]（u64 属性的第 6 号字节，小端序）= 数值高位第 2 字节。"""
    return (attr >> 48) & 0xFF


def decode(byte):
    tries = (byte >> 3) & 0x7
    flags = [n for bit, n in AB_BITS if byte & bit]
    return f"0x{byte:02x} (tries={tries}{'' if not flags else ', ' + '+'.join(flags)})"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dev", required=True, help="含 gpt<N>-primary.bin 的目录")
    ap.add_argument("--stock", required=True, help="含 gpt_main<N>.bin 的官方包目录")
    ap.add_argument("--luns", default="0,1,2,3,4,5")
    ap.add_argument("-v", "--verbose", action="store_true", help="逐分区打印设备值")
    args = ap.parse_args()

    dirty = False
    for lun in [int(x) for x in args.luns.split(",")]:
        dev_f = os.path.join(args.dev, f"gpt{lun}-primary.bin")
        st_f = os.path.join(args.stock, f"gpt_main{lun}.bin")
        if not os.path.exists(dev_f):
            print(f"LUN{lun}: 缺 {dev_f}（跳过）")
            continue
        raw = open(dev_f, "rb").read()
        info, dev = parse(raw)
        print(f"== LUN{lun}: {dev_f}")
        print(f"   头: mylba={info['mylba']} alt_lba={info['alt']} last_usable={info['last_u']} "
              f"entries={info['nent']}x{info['esize']} hdr_crc={'OK' if info['hdr_crc_ok'] else 'BAD'} "
              f"array_crc={'OK' if info['arr_crc_ok'] else 'BAD'} 分区数={len(dev)}")
        if not (info["hdr_crc_ok"] and info["arr_crc_ok"]):
            print("   ⚠ CRC 自检失败：这份 dump 本身不可信，先重取")
            dirty = True
        if not os.path.exists(st_f):
            print(f"   （无官方 {st_f}，只做自检）")
            continue
        st_raw = open(st_f, "rb").read()
        n = min(len(raw), len(st_raw))
        ndiff = sum(1 for i in range(n) if raw[i] != st_raw[i])
        print(f"   逐字节 vs 官方: 长度 dev={len(raw)} stock={len(st_raw)} 差异字节={ndiff}")
        if ndiff:
            dirty = True
        _, st = parse(st_raw)
        missing = [x for x in st if x not in dev]
        extra = [x for x in dev if x not in st]
        for x in missing:
            print(f"   - 设备缺: {x}")
        for x in extra:
            fl, ll, attr, _ = dev[x]
            print(f"   + 设备多: {x}  start={fl} size={(ll - fl + 1) * 4096 / 2**30:.2f} GiB "
                  f"byte6={decode(ab_byte(attr))}")
        resized = [x for x in st if x in dev and dev[x][:2] != st[x][:2]]
        for x in resized:
            print(f"   ~ 几何不同: {x} dev=({dev[x][0]},{dev[x][1]}) stock=({st[x][0]},{st[x][1]})")
        attrdiff = [x for x in st if x in dev and dev[x][2] != st[x][2]]
        if attrdiff:
            print(f"   属性字节不同的分区 {len(attrdiff)} 个（仅 boot_a/boot_b 的计数被 ABL 当真）：")
            for x in attrdiff:
                print(f"     {x:22s} stock={decode(ab_byte(st[x][2])):34s} dev={decode(ab_byte(dev[x][2]))}")
        elif args.verbose:
            for x in sorted(dev):
                print(f"     {x:22s} byte6={decode(ab_byte(dev[x][2]))}")
    print("\n退出码 0 = 全部与官方逐字节相同；1 = 有差异（属常态：自建分区/槽属性）")
    return 0 if not dirty else 1


if __name__ == "__main__":
    sys.exit(main())
