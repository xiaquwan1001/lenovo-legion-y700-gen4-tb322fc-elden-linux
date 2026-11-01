#!/usr/bin/env python3
"""blackbox.py — UEFI 早期可见性「DDR 黑匣子」读写/解码工具（主机侧，经 ssh 走设备）。

## 为什么不是「写结构体 + 读回来」

2026-11-01 实测（本机两次对照，见 reports/uefi-ddr-blackbox-20261101.md）：**本机 DDR 内容
在热复位后不保真** —— 1 MiB 窗口写满 0xA5，复位后约 26%–32% 的字节出现 1–3 个比特翻转，
且翻转方向几乎全部是 **1→0**（0xA5 的四个 1 位 0x01/0x04/0x20/0x80 占绝对多数），
每次复位坏点集合都不同（越晚读越多）。同一事实的旁证：`/sys/fs/pstore` 在多次复位后始终为空
（内核 ramoops 记录 CRC 不过被丢弃）。反正方向是「只掉 1、不长 1」。

⇒ 判据必须用**单调编码**：
  * 0x00 是稳定态（实测复位后逐字节仍为 0）；
  * 「已到达」= 用 0xFF 填满一整页（4096 B），复位后按 **popcount≥6 的字节占比**判定
    （实测 0xFF 页复位后仍有 81%–86% 的字节 popcount≥7，零页 = 0%）。
  * 数值（ELR/ESR/FAR）= **位平面编码**：一个 64 位值占 64 页，第 i 位为 1 就把第 i 页填 0xFF，
    为 0 就留 0x00。位 1 只会掉成 0（该页占比下降），位 0 不会长成 1 ⇒ 单调可判。

## 布局（1 MiB 窗口，默认 PA 0xE3F00000）

    页  0..15      stage 标记：页 k 被填 0xFF ⇒ 载荷到达过 checkpoint k（k 越大越晚）
    页 16..       位平面字段（每个字段 64 页）：
                    16..79    pc   （fault 的 ELR；无 fault 时为最后一条 checkpoint 的标识地址）
                    80..143   esr
                   144..207   far

## 用法

    scripts/blackbox.py prep          # 清零整窗（触发载荷前跑；0x00 是稳定态）
    scripts/blackbox.py read          # 读回并解码（stage + 位平面数值）
    scripts/blackbox.py raw FILE      # 整窗落盘
    scripts/blackbox.py selftest      # 解码器自测（不碰设备）

设备侧前提：`blackbox.ko` 已 insmod（arm64 上 /dev/mem 对 System RAM 一律 EPERM，
见 probes/blackbox/blackbox.c 头注释），且窗口所在的 1 MiB 已在 cmdline 里
`memmap=1M$<PA>` 保留（防止内核分配/写回干扰）。
"""
import argparse
import subprocess
import sys

PAGE = 4096
STAGE_PAGES = 16
FIELDS = [("pc", 16), ("esr", 80), ("far", 144)]
WINDOW_PAGES = 208          # 16 + 3*64 = 208 页 = 832 KiB（< 1 MiB）

STAGE_NAMES = {
    0: "（未写任何标记）",
    1: "shim:entry（载荷第一条指令开始执行）",
    2: "shim:cold-copy-done（FD 已拷到装载基址）",
    3: "shim:cache-maint-done（dc civac / ic iallu 完成）",
    4: "shim:about-to-jump（即将跳入 FD 入口）",
    5: "prepi:entry（Mu PrePi 已开始执行）",
    6: "prepi:arch-done（PrePi 平台早期初始化返回）",
    7: "dxe:sec-done",
    8: "dxe:after-drivers",
    9: "dxe:before-ebs",
}

SET_FRAC = 0.5      # 页判「已写」的阈值：popcount>=6 的字节占比
POPCOUNT_MIN = 6


def ssh(target, cmd, timeout=120):
    argv = ["ssh", "-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=8",
            "-o", "BatchMode=yes", "-o", "UserKnownHostsFile=/dev/null", target, cmd]
    return subprocess.run(argv, capture_output=True, timeout=timeout, check=True).stdout


def read_window(target, pa, window):
    size = WINDOW_PAGES * PAGE
    cmd = ("rmmod blackbox 2>/dev/null; "
           "insmod /lib/modules/$(uname -r)/extra/blackbox.ko pa=%s size=%d 2>/dev/null; "
           "head -c %d /sys/kernel/debug/blackbox" % (pa, window, size))
    out = ssh(target, cmd)
    if len(out) < size:
        raise SystemExit("短读 %d/%d B —— blackbox.ko 没加载？窗口 PA 与 insmod 参数不一致？"
                         % (len(out), size))
    return out[:size]


def page_ok(pg):
    """这一页是否「被填过 0xFF」：popcount>=6 的字节占比 >= 阈值。"""
    good = sum(1 for b in pg if bin(b).count("1") >= POPCOUNT_MIN)
    return good / PAGE >= SET_FRAC, good / PAGE


def decode(win):
    stages = []
    for k in range(STAGE_PAGES):
        ok, frac = page_ok(win[k * PAGE:(k + 1) * PAGE])
        stages.append((k, ok, frac))
    reached = max((k for k, ok, _ in stages if ok), default=0)
    vals = {}
    for name, first in FIELDS:
        v = 0
        for bit in range(64):
            pg = win[(first + bit) * PAGE:(first + bit + 1) * PAGE]
            ok, _ = page_ok(pg)
            if ok:
                v |= 1 << bit
        vals[name] = v
    return stages, reached, vals


def cmd_prep(args):
    size = WINDOW_PAGES * PAGE
    cmd = ("rmmod blackbox 2>/dev/null; insmod /lib/modules/$(uname -r)/extra/blackbox.ko "
           "pa=%s size=%d && dd if=/dev/zero of=/sys/kernel/debug/blackbox bs=4096 count=%d 2>/dev/null"
           % (args.pa, args.window, WINDOW_PAGES))
    ssh(args.target, cmd)
    print("已清零 %d 页（%.0f KiB）@ %s —— 0x00 是稳定态，等载荷填 0xFF" % (
        WINDOW_PAGES, size / 1024, args.pa))


def cmd_read(args):
    win = read_window(args.target, args.pa, args.window)
    stages, reached, vals = decode(win)
    print("stage 页判读（阈值：popcount>=6 的字节占比 >= %.0f%%）:" % (SET_FRAC * 100))
    for k, ok, frac in stages:
        if ok or frac > 0.05:
            print("  %2d  %-46s %5.1f%% %s" % (k, STAGE_NAMES.get(k, "stage%d" % k), frac * 100,
                                               "REACHED" if ok else ""))
    print("→ 最后到达：stage %d = %s" % (reached, STAGE_NAMES.get(reached, "?")))
    if reached == 0:
        print("  （连 stage1 都没有：载荷第一条指令就没跑到，或窗口不可写/被挡）")
    if any(vals.values()):
        for name, _ in FIELDS:
            print("  %-4s = 0x%016x" % (name, vals[name]))
        print("  说明：pc = fault 的 ELR（若 shim/FD 内，减装载基址即偏移）；esr 为异常原因；")
        print("       若 pc/esr 全 0 而 stage 有值 ⇒ 不是异常，更像看门狗超时复位。")
    else:
        print("  位平面字段全 0 ⇒ 没有 fault 记录（更支持看门狗/超时复位）")


def cmd_poke(args):
    """把选定的 stage 页从 Linux 侧填成 0xFF（对照实验用：证明「marker 会不会被回落启动清掉」）。"""
    stages = [int(x) for x in args.stages.split(",")]
    skip = 0
    script = []
    for k in stages:
        script.append("dd if=/dev/zero bs=4096 count=1 seek=%d conv=notrunc 2>/dev/null" % (k + skip))
    # 直接在设备上生成 0xFF 页并写到对应偏移
    cmd = ("rmmod blackbox 2>/dev/null; insmod /lib/modules/$(uname -r)/extra/blackbox.ko pa=%s size=%d 2>/dev/null; "
           "tr '\\0' '\\377' < /dev/zero | dd of=/tmp/ffpage bs=4096 count=1 2>/dev/null; "
           % (args.pa, args.window))
    for k in stages:
        cmd += ("dd if=/tmp/ffpage of=/sys/kernel/debug/blackbox bs=4096 seek=%d conv=notrunc 2>/dev/null; " % k)
    cmd += "rm -f /tmp/ffpage; echo poked"
    print(ssh(args.target, cmd).decode().strip())
    print("已把 stage %s 页填 0xFF（对照用）" % stages)


def cmd_raw(args):
    win = read_window(args.target, args.pa, args.window)
    open(args.path, "wb").write(win)
    print("wrote %s (%d B)" % (args.path, len(win)))


def cmd_selftest(args):
    win = bytearray(WINDOW_PAGES * PAGE)
    for k in (1, 2, 3):                      # 到达 stage3
        win[k * PAGE:(k + 1) * PAGE] = b"\xff" * PAGE
    # 模拟衰减：stage3 页有 10% 的字节掉 1 位
    seg = win[3 * PAGE:4 * PAGE]
    win[3 * PAGE:4 * PAGE] = bytes((b & 0xFE) if i % 10 == 0 else b for i, b in enumerate(seg))
    val = 0xFF3001A8
    for bit in range(64):
        if val >> bit & 1:
            off = (16 + bit) * PAGE
            win[off:off + PAGE] = b"\xff" * PAGE
    stages, reached, vals = decode(bytes(win))
    assert reached == 3, reached
    assert vals["pc"] == val, hex(vals["pc"])
    assert vals["esr"] == 0
    print("selftest OK（stage=%d pc=0x%x，10%% 单比特衰减下仍正确）" % (reached, vals["pc"]))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--target", default="root@192.168.7.1")
    ap.add_argument("--pa", default="0xF7D00000")
    ap.add_argument("--window", type=int, default=1 << 20)
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name, fn in (("prep", cmd_prep), ("read", cmd_read), ("selftest", cmd_selftest)):
        sp = sub.add_parser(name)
        sp.add_argument("--pa", default=argparse.SUPPRESS)      # 允许写在子命令后
        sp.set_defaults(fn=fn)
    sp = sub.add_parser("poke")
    sp.add_argument("--stages", default="1,2,4")
    sp.add_argument("--pa", default=argparse.SUPPRESS)
    sp.set_defaults(fn=cmd_poke)
    p = sub.add_parser("raw")
    p.add_argument("path")
    p.add_argument("--pa", default=argparse.SUPPRESS)
    p.set_defaults(fn=cmd_raw)
    a = ap.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
