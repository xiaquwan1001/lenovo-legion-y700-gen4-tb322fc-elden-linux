#!/usr/bin/env python3
"""uefi-logfs-read.py — 经 fastboot `oem sbread` 读回 UEFI 持久化诊断日志（logfs 尾部 16 KiB 窗口）。

背景（2026-11-06R31/R32）：屏是这条线上唯一会「滚走」的取证通道 —— 输出会被后续内容冲掉、
EB 之后面板还会被驱动退出流程熄掉。所以固件把控制台环形日志写到 `logfs` 分区尾部 16 KiB，
并用 `oem sbread:<off>:<len>` 把该窗口读回宿主。本脚本就是这条通道的宿主侧读端。

用法：
  scripts/uefi-logfs-read.py                 # 读第一条记录（默认 4 KiB，自动在 SBLOG 边界截断）
  scripts/uefi-logfs-read.py --len 8192      # 读更多
  scripts/uefi-logfs-read.py --raw out.bin   # 落原始字节
  scripts/uefi-logfs-read.py --serial 51318dc0

判据：输出里应出现 `SBLOG01 tag=<entry|preeb|posteb>`，其后是完整启动日志。
"""

import argparse
import re
import subprocess
import sys

CHUNK = 20  # 每次 oem 调用回 20 字节（响应缓冲 64 B 的限制）


def fastboot(serial, *args):
    cmd = ["fastboot"]
    if serial:
        cmd += ["-s", serial]
    cmd += list(args)
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    return r.stdout + r.stderr


def read_window(serial, off, length):
    """按 CHUNK 读 [off, off+length) 的十六进制块，返回 bytes。"""
    out = bytearray()
    for base in range(off, off + length, CHUNK):
        n = min(CHUNK, off + length - base)
        text = fastboot(serial, "oem", "sbread:%x:%x" % (base, n))
        m = re.search(r"\(bootloader\)\s+o=[0-9a-f]+\s+([0-9a-f]+)", text)
        if not m:
            if "FAILED" in text:
                sys.exit("sbread 失败（off=%x len=%x）：%s" % (base, n, text.strip()))
            break
        out += bytes.fromhex(m.group(1))
    return bytes(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--serial", default=None)
    ap.add_argument("--off", type=lambda s: int(s, 0), default=0)
    ap.add_argument("--len", type=lambda s: int(s, 0), default=4096)
    ap.add_argument("--raw", default=None)
    a = ap.parse_args()

    if not a.serial:
        dev = fastboot(None, "devices")
        m = re.search(r"^([0-9a-fA-F]+)\s+fastboot", dev, re.M)
        if not m:
            sys.exit("没有 fastboot 设备：\n" + dev)
        a.serial = m.group(1)
        print("# device %s" % a.serial, file=sys.stderr)

    data = read_window(a.serial, a.off, a.len)
    if a.raw:
        open(a.raw, "wb").write(data)
        print("wrote %s (%d B)" % (a.raw, len(data)), file=sys.stderr)

    # 记录头之后是日志正文；按 NUL 截断，控制字符转义后打印。
    txt = data.decode("ascii", "replace")
    txt = txt.split("\x00")[0]
    sys.stdout.write(txt.replace("\r\n", "\n").replace("\r", "\n"))
    if not txt.endswith("\n"):
        sys.stdout.write("\n")


if __name__ == "__main__":
    main()
