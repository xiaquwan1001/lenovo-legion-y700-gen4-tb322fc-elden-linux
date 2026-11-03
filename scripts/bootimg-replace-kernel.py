#!/usr/bin/env python3
"""bootimg-replace-kernel.py — 只替换 Android boot image 的内核段，其余逐字节保留。

用途（2026-11-03 UEFI 正控）：把注入了 DDR 标记的 `Image.gz` 塞进**设备当前在用的
boot_b 原件**，得到「除内核段外与在机件逐字节相同」的实验件 —— 单变量、可回退。

用法：
    scripts/bootimg-replace-kernel.py <src.img> <new-Image.gz> -o <out.img>
    scripts/bootimg-replace-kernel.py --verify <out.img> <src.img>   # 结构对账

判据：`--verify` 必须报 `only-kernel-differs`（除 header 的 kernel_size/id 与内核段外全同）。
"""
import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from importlib.machinery import SourceFileLoader

mk = SourceFileLoader("mkbootimg", str(Path(__file__).resolve().parent / "mkbootimg.py")).load_module()


def rebuild(src, new_kernel, out):
    d, sections, f = mk.read_image(src)
    img = mk.compose(
        page=f["page"],
        kernel_data=new_kernel,
        ramdisk_data=sections["ramdisk"],
        second_data=sections["second"],
        recovery_data=sections["recovery"],
        dtb_data=sections["dtb"],
        kernel_addr=f["kernel_addr"],
        ramdisk_addr=f["ramdisk_addr"],
        second_addr=f["second_addr"],
        tags_addr=f["tags_addr"],
        dtb_addr=f["dtb_addr"],
        cmdline=f["cmdline"],
        extra_cmdline=f["extra_cmdline"],
        name=f["name"],
        header_version=f["header_version"],
        os_version=f["os_version"],
        recovery_dtbo_offset=f["recovery_dtbo_offset"],
    )
    Path(out).write_bytes(img)
    return sections, f, img


def verify(out, src):
    d0, s0, f0 = mk.read_image(src)
    d1, s1, f1 = mk.read_image(out)
    for k in ("ramdisk", "second", "recovery", "dtb"):
        if s0[k] != s1[k]:
            print(f"MISMATCH section={k}")
            return 1
    for k in ("page", "kernel_addr", "ramdisk_addr", "second_addr",
              "tags_addr", "header_version", "os_version", "name",
              "cmdline", "extra_cmdline", "dtb_addr",
              "recovery_dtbo_offset"):
        if f0[k] != f1[k]:
            print(f"MISMATCH header.{k}: {f0[k]!r} vs {f1[k]!r}")
            return 1
    print(f"only-kernel-differs (kernel {len(s0['kernel'])} -> {len(s1['kernel'])} B; "
          f"ramdisk {len(s1['ramdisk'])}; dtb {len(s1['dtb'])}; cmdline 逐字相同)")
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--verify", nargs=2, metavar=("OUT", "SRC"))
    ap.add_argument("src", nargs="?")
    ap.add_argument("kernel", nargs="?")
    ap.add_argument("-o", "--out")
    a = ap.parse_args()
    if a.verify:
        return verify(*a.verify)
    if not (a.src and a.kernel and a.out):
        ap.error("need <src.img> <new-Image.gz> -o <out.img>")
    sections, f, img = rebuild(a.src, Path(a.kernel).read_bytes(), a.out)
    print(f"wrote {a.out} ({len(img)} B); header_version={f['header_version']} "
          f"cmdline={f['cmdline'][:60]}…")
    return verify(a.out, a.src)


if __name__ == "__main__":
    sys.exit(main())
