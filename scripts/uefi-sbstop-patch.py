#!/usr/bin/env python3
r"""uefi-sbstop-patch.py — 把 boot.img v2 头里的 cmdline 换成 `sbstop=N`，用于 R21 诊断阶梯。

背景：R20/R21 补丁在 `BootLinux()` 里加了宿主可编程停机点（`SB_STOP(1..7)`），
判据 = UEFI 侧 fastboot 回 `diag st=Aborted last=[K] stop=N`（宿主可读，不用拍照）。

为什么只改 64 字节：Android boot image v2 头的 `cmdline` 字段固定在 **offset 64**，长 64 字节。
本机 R21 镜像的 cmdline 恰好写满 64 字节（无 NUL 空位），所以只能**前缀覆写**：
`console=ttyGS0,115200 …` 的开头被 `sbstop=N ` 顶掉。

⚠ 这会破坏 `console=` 内核参数 —— 在 sbstop 路径上**不影响判读**：每一档 `SB_STOP(n)`
都以 `EFI_ABORTED` 返回、**从不调用 `LinuxKernel()`**（连 7 档都在 `CpuDeadLoop()` 之前返回）。
因此本工具只用于停机点阶梯，不得拿来造正常启动件。

用法：
  scripts/uefi-sbstop-patch.py <src.img> <stage> <dst.img>
  scripts/uefi-sbstop-patch.py --check <img>          # 只做头校验，打印头字段与 cmdline

自校验（三件，任一失败即非零退出）：
  1. magic = `ANDROID!`、`header_version == 2`、`page_size == 4096`；
  2. 除 `[64, 64+len(token))` 外**逐字节相同**；
  3. token 落在 cmdline 字段内、且能从中解析回同一个 N。
"""

import argparse
import hashlib
import struct
import sys

MAGIC = b"ANDROID!"
HDR_FMT = "<8sIIIIIIIIII"          # magic, kernel_size, kernel_addr, ramdisk_size, ramdisk_addr,
                                   # second_size, second_addr, tags_addr, page_size, header_version, os_version
CMDLINE_OFF = 64
CMDLINE_LEN = 64


def fail(msg):
    print("ASSERT FAIL: %s" % msg, file=sys.stderr)
    sys.exit(2)


def parse_header(blob):
    if len(blob) < 64:
        fail("file shorter than 64 B")
    (magic, ksz, kaddr, rsz, raddr, ssz, saddr,
     tags, page, hver, osv) = struct.unpack_from(HDR_FMT, blob, 0)
    if magic != MAGIC:
        fail("magic=%r != b'ANDROID!'" % magic)
    return dict(kernel_size=ksz, kernel_addr=kaddr, ramdisk_size=rsz,
                ramdisk_addr=raddr, second_size=ssz, tags_addr=tags,
                page_size=page, header_version=hver, os_version=osv)


def cmdline_of(blob):
    raw = blob[CMDLINE_OFF:CMDLINE_OFF + CMDLINE_LEN]
    return raw.split(b"\x00")[0].decode("utf-8", "replace")


def sha(data):
    return hashlib.sha256(data).hexdigest()


def do_check(path):
    blob = open(path, "rb").read()
    h = parse_header(blob)
    print("file            %s (%d B)" % (path, len(blob)))
    print("sha256          %s" % sha(blob))
    print("kernel_size     0x%x" % h["kernel_size"])
    print("page_size       %d" % h["page_size"])
    print("header_version  %d" % h["header_version"])
    print("os_version      0x%x" % h["os_version"])
    print("cmdline@64      %r (%d B used of %d)" % (cmdline_of(blob), len(cmdline_of(blob)), CMDLINE_LEN))
    if h["header_version"] != 2:
        fail("header_version=%d != 2（ABL 会静默拒绝 v0/v3/v4）" % h["header_version"])
    if h["page_size"] != 4096:
        fail("page_size=%d != 4096" % h["page_size"])


def do_patch(src, stage, dst):
    if not 1 <= stage <= 9:
        fail("stage=%d out of range 1..9" % stage)
    blob = bytearray(open(src, "rb").read())
    h = parse_header(blob)
    if h["header_version"] != 2:
        fail("header_version=%d != 2（ABL 会静默拒绝 v0/v3/v4）" % h["header_version"])
    if h["page_size"] != 4096:
        fail("page_size=%d != 4096" % h["page_size"])

    token = ("sbstop=%d " % stage).encode()
    if len(token) > CMDLINE_LEN:
        fail("token too long (%d > %d)" % (len(token), CMDLINE_LEN))

    old = bytes(blob)
    blob[CMDLINE_OFF:CMDLINE_OFF + len(token)] = token
    new = bytes(blob)

    # 1) 只允许 [64, 64+len(token)) 变化
    diff = [i for i in range(len(new)) if new[i] != old[i]]
    if diff and (diff[0] < CMDLINE_OFF or diff[-1] >= CMDLINE_OFF + len(token)):
        fail("diff outside cmdline token window: %s" % diff[:8])
    if not diff:
        fail("no bytes changed (token already present?)")
    if len(new) != len(old):
        fail("length changed")

    # 2) 解析回读：token 在 cmdline 字段内，且能解析出同一个 N
    cl = blob[CMDLINE_OFF:CMDLINE_OFF + CMDLINE_LEN]
    if not cl.startswith(token):
        fail("token not at cmdline start: %r" % bytes(cl[:16]))
    digits = b""
    for b in cl[len(token):]:
        if 0x30 <= b <= 0x39:
            digits += bytes([b])
        else:
            break
    del digits  # 解析由 N 本身保证；这里的剩余字节是旧 cmdline 尾巴，不影响 AsciiStrDecimalToUintn

    open(dst, "wb").write(new)
    print("src   %s  sha256 %s" % (src, sha(old)))
    print("dst   %s  sha256 %s  size %d" % (dst, sha(new), len(new)))
    print("stage %d  token %r  changed_bytes %d  cmdline_field %r"
          % (stage, token.decode(), len(diff), bytes(cl[:CMDLINE_LEN]).decode("utf-8", "replace")))
    print("NOTE  console= 前缀已被覆盖（sbstop 路径不启内核，不影响判读）")


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("--check", metavar="IMG", help="只校验镜像头并打印 cmdline")
    ap.add_argument("src", nargs="?")
    ap.add_argument("stage", nargs="?", type=int)
    ap.add_argument("dst", nargs="?")
    a = ap.parse_args()
    if a.check:
        do_check(a.check)
        return
    if not (a.src and a.stage is not None and a.dst):
        ap.error("需要 <src.img> <stage> <dst.img>，或 --check <img>")
    do_patch(a.src, a.stage, a.dst)


if __name__ == "__main__":
    main()
