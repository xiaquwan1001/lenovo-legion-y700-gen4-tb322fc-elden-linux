#!/usr/bin/env python3
"""android-linux-coexist-check.py — 安卓/Linux「共存分区契约」核对（纯主机侧，只读 GPT 主表 dump）。

背景（2026-11-19 定）：这台机器上 Android 与主线 Linux **必须分住两段**，谁也别写谁——
2026-11-17 那次事故就是「单个 `linux` 分区从 LBA 90504（= super 起点）开始」⇒ 写 Linux 根
必然覆盖 Android super，a 槽从此起不来。现态（11-18 20:09 EDL 读回的主备表）是双轨：

    super       90504 .. 5857671   22.00 GiB   Android 动态分区（a 槽 system/vendor/…）
    vbmeta_system_a/b, metadata, rawdump, pstoredump    Android 专用
    userdata    5972392 .. 73277434 256.75 GiB  Android /data
    linux17     73277435 .. 123871226 193.00 GiB  Linux 根（b 槽 boot_b 带着 LABEL=linux 引导）

契约（本脚本判据）：
  1. 三个关键段 LBA 必须与上表逐字节一致；
  2. 全部条目两两不重叠；
  3. 不存在旧破坏设计的 `linux` / `elden-super` / `elden-data` 单分区；
  4. 若给 --super-img：镜像字节数必须 ≤ super 分区字节数（EDL 写 90504 不会越界到 vbmeta_system_a）。

用法：
  python3 scripts/android-linux-coexist-check.py --gpt <gpt0-primary.bin> [--super-img <img>]
退出码：0 = 契约成立；1 = 违反（逐条打印）。
"""
import argparse
import struct
import sys

EXPECTED = {
    'super':    (90504, 5857671),
    'userdata': (5972392, 73277434),
    'linux17':  (73277435, 123871226),
}
FORBIDDEN = ('linux', 'elden-super', 'elden-data', 'eldenesp')
SECTOR = 4096


def parse_gpt(path, sector=SECTOR):
    d = open(path, 'rb').read()
    h = d[sector:sector + 92]
    if h[:8] != b'EFI PART':
        raise SystemExit('不是 GPT 头：%s' % path)
    ent_lba, nent, entsz, _crc = struct.unpack_from('<QIII', h, 72)
    entries = d[ent_lba * sector: ent_lba * sector + nent * entsz]
    out = []
    for i in range(nent):
        e = entries[i * entsz:(i + 1) * entsz]
        if e[:16] == b'\0' * 16:
            continue
        name = e[56:128].decode('utf-16-le').rstrip('\0')
        a, b = struct.unpack_from('<QQ', e, 32)
        if a:
            out.append((a, b, name))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--gpt', required=True)
    ap.add_argument('--super-img')
    a = ap.parse_args()
    ents = parse_gpt(a.gpt)
    by = {n: (s, e) for s, e, n in ents}
    bad = []

    for n, (s, e) in EXPECTED.items():
        if n not in by:
            bad.append('缺分区 %s（期望 LBA %d..%d）' % (n, s, e))
        elif by[n] != (s, e):
            bad.append('%s 位不一致：现 %d..%d / 契约 %d..%d' % (n, by[n][0], by[n][1], s, e))
        else:
            print('OK  %-10s %9d..%-9d %8.2f GiB' % (n, s, e, (e - s + 1) * SECTOR / 1024**3))

    for n in FORBIDDEN:
        if n in by:
            bad.append('存在旧破坏设计分区 %r（%d..%d）——写 Linux 会覆盖 Android' % (n, *by[n]))

    srt = sorted((s, e, n) for s, e, n in ents)
    for (s1, e1, n1), (s2, e2, n2) in zip(srt, srt[1:]):
        if s2 <= e1:
            bad.append('重叠：%s(%d..%d) ∩ %s(%d..%d)' % (n1, s1, e1, n2, s2, e2))
    if not bad:
        print('OK  16 条目两两不重叠；linux17 与 super/userdata 物理隔离')

    if a.super_img:
        import os
        sz = os.path.getsize(a.super_img)
        cap = (EXPECTED['super'][1] - EXPECTED['super'][0] + 1) * SECTOR
        if sz > cap:
            bad.append('super 镜像 %d B > super 分区 %d B' % (sz, cap))
        else:
            print('OK  super 镜像 %d B ≤ 分区 %d B（写入 90504 起不越界）' % (sz, cap))

    for b in bad:
        print('VIOLATION ' + b)
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())