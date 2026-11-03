#!/usr/bin/env python3
r"""uefi-repack-v2aligned.py — 把 UEFI payload（BootShim + FD）打成一个 **ABL 会真跳进去** 的 boot.img。

## 为什么需要这个脚本（2026-11-03/04 定论）

ABL 对 `fastboot boot` 的镜像有两条完全不同的结局（`reports/uefi-posctrl-20261103-summary.md` §2）：

  * **0.056 s + `usb_read failed`**  = 头校验阶段就被否掉，载荷从未执行（我们 11-01 起那批 v0 件）；
  * **Sending 1.4–1.9 s + `Booting OKAY ~10.1 s` + DRAM 被改写** = ABL 真的跳进去了。

差别**全在头这一层**，不在代码内容：

| 层 | 旧（被拒） | 现在（被执行） |
|---|---|---|
| boot.img 打包头 | v0，base 0x10000000 | **v2，base 0**（和能正常启动的 Linux 同一条路径） |
| payload `Image` 头 offset 8 | `text_offset = UEFI_BASE`（跳到野地址） | **`text_offset = 0`** |
| offset 16 `image_size` | `0x400000`（窗口大小，不是真实长度） | **解压后真实长度** |
| offset 24 `flags` | `0x0` | **`0xa`**（PAGE_SIZE_4K \| LE） |

## 用法

    scripts/uefi-repack-v2aligned.py --build-dir <变体目录> [--base <在机 boot_b 原件>] -o out/xxx.img

`--build-dir` 是 `scripts/uefi-build-variant.sh` 的产物目录（需含 `BootShim.bin` + `SM8750_EFI.fd`）。
默认 `--base` 用 `reports/artifacts/uefi-posctrl-20261103/boot_b-live.img`（在机 `boot_b` 原件，
sha256 `fb55997c…c35169`）：**只换内核段**，ramdisk/dtb/cmdline 逐字节保留，并用
`bootimg-replace-kernel.py --verify` 断言 `only-kernel-differs`。
"""
import argparse
import gzip
import hashlib
import os
import struct
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_BASE = os.path.join(ROOT, "reports/artifacts/uefi-posctrl-20261103/boot_b-live.img")


def align_payload(shim: bytes, fd: bytes) -> bytes:
    p = bytearray(shim + fd)
    code0, code1 = struct.unpack_from("<II", p, 0)
    magic = bytes(p[56:60])
    text_off = struct.unpack_from("<Q", p, 8)[0]
    image_size = struct.unpack_from("<Q", p, 16)[0]
    flags = struct.unpack_from("<Q", p, 24)[0]
    print("before: code0=%08x code1=%08x text_offset=%#x image_size=%#x flags=%#x magic=%r"
          % (code0, code1, text_off, image_size, flags, magic))
    if magic != b"ARM\x64":
        sys.exit("payload 没有 arm64 Image 魔数（offset 56 应为 'ARM\\x64'）")
    if text_off != 0:
        print("warning: text_offset=%#x != 0（应为 0，见脚本头注释）" % text_off)
    struct.pack_into("<Q", p, 16, len(p))    # image_size = 解压后真实长度
    struct.pack_into("<Q", p, 24, 0xA)       # flags = PAGE_SIZE_4K | LE
    print("after : text_offset=%#x image_size=%#x flags=%#x"
          % (struct.unpack_from("<Q", p, 8)[0], struct.unpack_from("<Q", p, 16)[0],
             struct.unpack_from("<Q", p, 24)[0]))
    return bytes(p)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--build-dir", required=True)
    ap.add_argument("--base", default=DEFAULT_BASE)
    ap.add_argument("-o", "--out", required=True)
    a = ap.parse_args()

    shim = open(os.path.join(a.build_dir, "BootShim.bin"), "rb").read()
    fd = open(os.path.join(a.build_dir, "SM8750_EFI.fd"), "rb").read()
    payload = align_payload(shim, fd)
    open(os.path.join(a.build_dir, "payload-v2aligned.bin"), "wb").write(payload)
    gz = gzip.compress(payload, 9, mtime=0)
    gzpath = os.path.join(a.build_dir, "payload-v2aligned.bin.gz")
    open(gzpath, "wb").write(gz)
    print("shim %d + fd %d = payload %d ; gz %d sha256 %s"
          % (len(shim), len(fd), len(payload), len(gz), hashlib.sha256(gz).hexdigest()[:16]))

    subprocess.run([sys.executable, os.path.join(ROOT, "scripts/bootimg-replace-kernel.py"),
                    a.base, gzpath, "-o", a.out], check=True)
    subprocess.run([sys.executable, os.path.join(ROOT, "scripts/bootimg-replace-kernel.py"),
                    "--verify", a.out, a.base], check=True)
    print("image %s %d B sha256 %s"
          % (a.out, os.path.getsize(a.out), hashlib.sha256(open(a.out, "rb").read()).hexdigest()))


if __name__ == "__main__":
    main()
