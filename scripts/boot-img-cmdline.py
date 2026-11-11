#!/usr/bin/env python3
"""boot-img-cmdline.py — 从一个已存在的 boot.img 里取出 kernel/ramdisk/dtb，
并生成一份「只改 cmdline、其余载荷逐字节不变」的新 boot.img。

为什么需要它：G1-29 的 EFI-stub 直启掉电定性实验只需要改内核 cmdline
（`efi=noruntime` / `noefi` / `efi=novamap`），不该为此重编内核或重打包全链。
本脚本把「拆 → 换 cmdline → 合」做成可核对的单步，并在末尾自证：
  * 新镜像的 kernel/ramdisk/dtb 三段 sha256 与原件**逐字节相同**；
  * cmdline 只差预期的那个 token。

用法：
    # 只打印（不改任何文件）
    python3 scripts/boot-img-cmdline.py out/boot-elden-vk187b.img --show

    # 生成新镜像（cmdline 在原基础上追加 token）
    python3 scripts/boot-img-cmdline.py out/boot-elden-vk187b.img \
        --append "efi=noruntime" -o out/boot-elden-vk187b-noruntime.img

    # 自检（结构能往返）
    python3 scripts/boot-img-cmdline.py <img> --verify

依赖：scripts/mkbootimg.py（同目录，v2 header 打包器）。

已知边界：
  * 只支持 header v2（本机所有镜像都是 v2；v0/v3 会明确报错）。
  * 不改 AVB：本产物只用于 `fastboot boot`（零写盘），不用于 flash。
"""

import argparse
import hashlib
import os
import struct
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
MAGIC = b"ANDROID!"
HEADER_V2_SIZE = 1660
BOOT_NAME_SIZE = 16
BOOT_ARGS_SIZE = 512
BOOT_EXTRA_ARGS_SIZE = 1024
DEFAULT_PAGE = 4096


def die(msg):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(2)


def sha(b):
    return hashlib.sha256(b).hexdigest()


def parse(path):
    """拆出 header 字段 + 三段载荷（kernel / ramdisk / dtb）。"""
    with open(path, "rb") as f:
        data = f.read()
    if data[:8] != MAGIC:
        die(f"{path}: 不是 Android boot image（magic={data[:8]!r}）")

    (kernel_size, kernel_addr, ramdisk_size, ramdisk_addr, second_size,
     second_addr, tags_addr, page_size, header_version, os_version) = \
        struct.unpack_from("<10I", data, 8)
    name = data[48:48 + BOOT_NAME_SIZE].split(b"\0")[0].decode("utf-8", "replace")
    cmdline = data[64:64 + BOOT_ARGS_SIZE].split(b"\0")[0].decode("utf-8", "replace")
    # 注意：cmdline 之后是 id[8]（32 B，sha1），extra_cmdline 在 608 起。
    extra = data[608:608 + BOOT_EXTRA_ARGS_SIZE]
    extra_cmdline = extra.split(b"\0")[0].decode("utf-8", "replace")
    # v1/v2 追加字段
    recovery_dtbo_size = recovery_dtbo_offset = header_size = dtb_size = dtb_addr = 0
    if header_version >= 1:
        recovery_dtbo_size, recovery_dtbo_offset = struct.unpack_from("<I Q", data, 1632)
        header_size = struct.unpack_from("<I", data, 1644)[0]
        if header_version >= 2:
            dtb_size = struct.unpack_from("<I", data, 1648)[0]
            dtb_addr = struct.unpack_from("<Q", data, 1652)[0]

    if header_version != 2:
        die(f"{path}: 只支持 header v2，实测 v{header_version}")

    off = page_size
    kernel = data[off:off + kernel_size]
    off += ((kernel_size + page_size - 1) // page_size) * page_size
    ramdisk = data[off:off + ramdisk_size]
    off += ((ramdisk_size + page_size - 1) // page_size) * page_size
    second = data[off:off + second_size]
    off += ((second_size + page_size - 1) // page_size) * page_size
    dtb = data[off:off + dtb_size]
    off += ((dtb_size + page_size - 1) // page_size) * page_size
    rec_dtbo = data[off:off + recovery_dtbo_size]

    return dict(
        path=path, raw=data, page_size=page_size, name=name,
        cmdline=cmdline, extra_cmdline=extra_cmdline,
        kernel=kernel, ramdisk=ramdisk, second=second, dtb=dtb,
        recovery_dtbo=rec_dtbo,
        kernel_addr=kernel_addr, ramdisk_addr=ramdisk_addr,
        second_addr=second_addr, tags_addr=tags_addr,
        dtb_addr=dtb_addr, os_version=os_version,
        header_size=header_size,
    )


def verify(path):
    """结构往返自检：用解析结果重新打包，比较除 id 字段外的字节。"""
    p = parse(path)
    tmp = tempfile.mktemp(suffix=".img")
    repack(p, p["cmdline"], tmp)
    a = open(path, "rb").read()
    b = open(tmp, "rb").read()
    os.unlink(tmp)
    if len(a) != len(b):
        die(f"verify FAIL 长度不同 {len(a)} != {len(b)}")
    # id 字段（offset 576..608）是 sha1，重打包会重算，跳过
    diffs = [i for i in range(len(a)) if a[i] != b[i] and not (576 <= i < 608)]
    if diffs:
        die(f"verify FAIL 首个差异 byte {diffs[0]}: {a[diffs[0]]:02x} != {b[diffs[0]]:02x}（共 {len(diffs)}）")
    print(f"verify PASS ({path}, {len(a)} B, page={p['page_size']}, "
          f"kernel={len(p['kernel'])} ramdisk={len(p['ramdisk'])} dtb={len(p['dtb'])})")


def repack(p, cmdline, out):
    """调用 scripts/mkbootimg.py 重打包（不自己实现 header，避免两套代码漂移）。"""
    tmpd = tempfile.mkdtemp(prefix="bootimg-")
    kpath = os.path.join(tmpd, "kernel")
    rpath = os.path.join(tmpd, "ramdisk")
    dpath = os.path.join(tmpd, "dtb")
    open(kpath, "wb").write(p["kernel"])
    open(rpath, "wb").write(p["ramdisk"])
    open(dpath, "wb").write(p["dtb"])

    args = [sys.executable, os.path.join(HERE, "mkbootimg.py"),
            "--kernel", kpath, "--ramdisk", rpath, "--dtb", dpath,
            "--cmdline", cmdline,
            "--name", p["name"],
            "--pagesize", hex(p["page_size"]),
            "--kernel_offset", hex(p["kernel_addr"]),
            "--ramdisk_offset", hex(p["ramdisk_addr"]),
            "--second_offset", hex(p["second_addr"]),
            "--tags_offset", hex(p["tags_addr"]),
            "--dtb_offset", hex(p["dtb_addr"]),
            "--header_version", "2",
            "-o", out]
    if p["extra_cmdline"]:
        args[-2:-2] = ["--extra_cmdline", p["extra_cmdline"]]
    r = subprocess.run(args, capture_output=True, text=True)
    if r.returncode != 0:
        die(f"mkbootimg 失败 rc={r.returncode}\n{r.stdout}\n{r.stderr}")


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("image")
    ap.add_argument("--show", action="store_true", help="只打印 cmdline 与载荷摘要")
    ap.add_argument("--append", help="在现有 cmdline 末尾追加（空格分隔）")
    ap.add_argument("--set", dest="setcmd", help="整体替换 cmdline")
    ap.add_argument("--verify", action="store_true", help="结构往返自检")
    ap.add_argument("-o", "--output")
    a = ap.parse_args()

    if a.verify:
        verify(a.image)
        return 0

    p = parse(a.image)
    if a.show or not (a.append or a.setcmd):
        print(f"image          : {a.image}")
        print(f"page_size      : {p['page_size']}")
        print(f"name           : {p['name']!r}")
        print(f"cmdline ({len(p['cmdline'])}B) : {p['cmdline']}")
        if p["extra_cmdline"]:
            print(f"extra_cmdline  : {p['extra_cmdline']}")
        print(f"kernel         : {len(p['kernel'])} B  sha256 {sha(p['kernel'])[:16]}…")
        print(f"ramdisk        : {len(p['ramdisk'])} B  sha256 {sha(p['ramdisk'])[:16]}…")
        print(f"dtb            : {len(p['dtb'])} B  sha256 {sha(p['dtb'])[:16]}…")
        if not (a.append or a.setcmd):
            return 0

    if not a.output:
        die("需要 -o/--output")
    new = a.setcmd if a.setcmd else (p["cmdline"] + " " + a.append).strip()
    if len(new) > BOOT_ARGS_SIZE - 1:
        die(f"cmdline 超长 {len(new)} > {BOOT_ARGS_SIZE - 1}（v2 header 的 BOOT_ARGS_SIZE）")

    repack(p, new, a.output)
    q = parse(a.output)

    # ---- 自证：三段载荷逐字节不变，cmdline 只差预期 ----
    ok = True
    for k in ("kernel", "ramdisk", "dtb"):
        same = sha(p[k]) == sha(q[k])
        ok &= same
        print(f"{k:8s} {'SAME' if same else 'DIFF'}  {sha(q[k])[:16]}…")
    print(f"cmdline  old: {p['cmdline']}")
    print(f"cmdline  new: {q['cmdline']}")
    if not ok:
        die("载荷与原件不一致，拒绝产出")
    print(f"OK  {a.output}  {os.path.getsize(a.output)} B")
    return 0


if __name__ == "__main__":
    sys.exit(main())
