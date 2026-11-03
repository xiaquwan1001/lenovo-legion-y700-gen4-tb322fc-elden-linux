#!/usr/bin/env python3
"""fb-survey.py — 事后从 DRAM 读回 splash_region，还原 shim 的「整屏纯色」执行轨迹。

背景（2026-11-04）：BootShim 在每个里程碑把整块 `splash_region`（DT 里
`reserved-memory/splash_region` = 0xFC800000 / 0x02B00000，no-map）填成一种纯色：

    红 0x00FF0000 = M1 shim 第一条指令已执行
    绿 0x0000FF00 = M2 FD 已拷到 UEFI_BASE(0xFF300000)
    蓝 0x000000FF = M3 cache 维护完、即将 br 进 UEFI
    黄 0x00FFFF00 = MD 落进 _Dead（不该出现）

所以「填到哪个偏移、最后一种颜色是什么」直接给出执行到哪一步 —— 不依赖肉眼、也不依赖
DPU 当时扫的是哪块 buffer。本脚本按 1 MiB 分块统计主色，并给出「颜色边界」。

用法：
    scripts/fb-survey.py [--base 0xfc800000] [--size 0x2b00000] [--chunk 0x100000]
"""
import argparse
import collections
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
COLORS = {
    0x00FF0000: "红 M1 shim 入口",
    0x0000FF00: "绿 M2 FD 拷完",
    0x000000FF: "蓝 M3 即将跳入",
    0x00FFFF00: "黄 MD _Dead",
    0x00000000: "黑/未写",
    0xFFFFFFFF: "白 0xFF",
}


def read_pa(target, pa, size):
    cmd = ("rmmod blackbox 2>/dev/null; "
           "insmod /lib/modules/$(uname -r)/extra/blackbox.ko pa=%d size=%d 2>/dev/null; "
           "head -c %d /sys/kernel/debug/blackbox" % (pa, size, size))
    out = subprocess.run(["ssh", "-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=8",
                          "-o", "BatchMode=yes", "-o", "UserKnownHostsFile=/dev/null", target, cmd],
                         capture_output=True, timeout=180).stdout
    if len(out) < size:
        raise SystemExit("短读 %d/%d @ %#x（blackbox.ko 未加载？PA 不在 DRAM？）" % (len(out), size, pa))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--target", default="root@192.168.7.1")
    ap.add_argument("--base", type=lambda s: int(s, 0), default=0xFC800000)
    ap.add_argument("--size", type=lambda s: int(s, 0), default=0x02B00000)
    ap.add_argument("--chunk", type=lambda s: int(s, 0), default=0x100000)
    a = ap.parse_args()

    n = a.size // a.chunk
    print("splash_region %#x + %#x，按 %#x 分块统计主色" % (a.base, a.size, a.chunk))
    print("%-14s %-22s %s" % ("offset", "主色", "前 3 色占比"))
    last = None
    for i in range(n):
        pa = a.base + i * a.chunk
        buf = read_pa(a.target, pa, a.chunk)
        words = collections.Counter()
        # 4 B 像素：只看低 24 位
        for off in range(0, len(buf) - 3, 4):
            words[int.from_bytes(buf[off:off + 4], "little") & 0xFFFFFF] += 1
        tot = sum(words.values())
        top = words.most_common(3)
        dom = top[0][0]
        name = COLORS.get(dom, "其他 %#08x" % dom)
        frac = " ".join("%s=%.0f%%" % (COLORS.get(c, "%#08x" % c).split()[0], 100.0 * k / tot)
                        for c, k in top)
        if dom != last:
            print("%#-14x %-22s %s" % (i * a.chunk, name, frac))
            last = dom


if __name__ == "__main__":
    main()
