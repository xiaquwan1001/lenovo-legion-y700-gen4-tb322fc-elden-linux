#!/usr/bin/env python3
# RETIRED 2026-11-27：GRUB LF2 补丁期望值复算器，只服务 elden_lf2_* 补丁当时验证，根因定案在 reports/uefi-grub-initrd-rootcause-20261115.md；可复核：reports/pstore-ram-initrd-guard-20261116.md
"""lf2-expected.py — 复算 GRUB LoadFile2 补丁（elden_lf2_*）对同一份 initrd 的期望值。

抽样规则必须与 /tmp/grub-patch/grub-core/loader/efi/linux.c 里的
  elden_lf2_sampled_sum() / elden_lf2_tail_hex() 逐字一致：
    SAMPLES=8, BLOCK=4096
    blk = min(BLOCK, size)
    off_i = i * (size - blk) // (SAMPLES - 1)
    h = FNV1a-32(0x811c9dc5) 依次吸收 8 个块
    tail = 末 16 字节的大写十六进制

用法：
  scripts/lf2-expected.py <initrd 文件>        # 默认按「原始文件字节」算
  scripts/lf2-expected.py <initrd 文件> --gunzip  # 先 gunzip 再算（GRUB 若透明解压则用这条对照）

判据（上机后读设备 /boot/grub/grubenv）：
  elden_lf2_len    = 期望的 size（64 595 425 = 原始文件；181 832 192 = 解压后）
  elden_lf2_sum    = 期望值 ⇒ buffer 内容正确
  elden_lf2_stable = 1（3 次采样一致）⇒ 填完后没被改
"""
import sys

SAMPLES = 8
BLOCK = 4096
FNV_OFFSET = 0x811C9DC5
FNV_PRIME = 0x01000193


def fnv1a32(h, data):
    for b in data:
        h = ((h ^ b) * FNV_PRIME) & 0xFFFFFFFF
    return h


def sampled_sum(buf):
    size = len(buf)
    blk = min(BLOCK, size)
    h = FNV_OFFSET
    offs = []
    for i in range(SAMPLES):
        off = (i * (size - blk)) // (SAMPLES - 1)
        offs.append(off)
        h = fnv1a32(h, buf[off:off + blk])
    return h, blk, offs


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    path = sys.argv[1]
    gunzip = "--gunzip" in sys.argv[2:]
    data = open(path, "rb").read()
    if gunzip:
        import gzip
        data = gzip.decompress(data)
    s, blk, offs = sampled_sum(data)
    tail = data[-16:].hex().upper() if len(data) >= 16 else data.hex().upper()
    print(f"file      : {path}{' (gunzip)' if gunzip else ''}")
    print(f"size      : {len(data)}")
    print(f"blk/offs  : {blk} / {offs}")
    print(f"sum       : 0x{s:08x}")
    print(f"tail(16B) : {tail}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
