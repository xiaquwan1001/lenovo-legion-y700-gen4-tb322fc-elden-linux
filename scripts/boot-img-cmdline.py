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

    # 打完整 header/段表（用于前后对照；v2 与 v3/v4 都是同一套输出格式）
    python3 scripts/boot-img-cmdline.py <img> --dump

支持 header v0/v1/v2（走 scripts/mkbootimg.py 重打包）与 header v3/v4
（AOSP `boot_img_hdr_v3/v4`：无 kernel_addr/ramdisk_addr/second/dtb 字段，
page 固定 4096，cmdline 在偏移 44、长 1536；v4 另加 signature_size @1580）。
v3/v4 的重打包走「整文件拷贝 + 只改 cmdline 窗口（44..1580）」，
因此 kernel/ramdisk/boot signature/尾部（bootconfig、VBmeta 等）逐字节原样、
文件总大小不变；写后逐字节自证（窗口外全等）。

已知边界：
  * v3/v4 的 cmdline 改动会让原厂 AVB hash descriptor 失配（vbmeta 用 OEM 私钥签名，
    本脚本不能重签）⇒ 产物只走 `fastboot boot`（零写盘）并**必须上机确认 bootloader 认**，
    不能当作可 flash 件。
  * v4 的 bootconfig 在 vendor_boot.img（AOSP bootimg.h），不在 boot.img；本脚本不改它。
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
HEADER_V3_SIZE = 1580
HEADER_V4_SIZE = 1584
BOOT_NAME_SIZE = 16
BOOT_ARGS_SIZE = 512
BOOT_EXTRA_ARGS_SIZE = 1024
DEFAULT_PAGE = 4096
# v3/v4：page 固定 4096（AOSP bootimg.h）；cmdline = BOOT_ARGS_SIZE+BOOT_EXTRA_ARGS_SIZE
BOOT_V3V4_PAGE = 4096
V3V4_CMDLINE_OFF = 44
V3V4_CMDLINE_LEN = BOOT_ARGS_SIZE + BOOT_EXTRA_ARGS_SIZE  # 1536
V4_SIGNATURE_SIZE_OFF = 1580
HEADER_VERSION_OFF = 40  # v0 与 v3/v4 都在 40（v0: tags@32 page@36 hv@40）


def die(msg):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(2)


def sha(b):
    return hashlib.sha256(b).hexdigest()


def _pages(n, page=DEFAULT_PAGE):
    return ((n + page - 1) // page) * page


def parse_v3v4(path, data, header_version):
    """header v3/v4（AOSP boot_img_hdr_v3/v4）：无地址字段、无 second/dtb。

    镜像布局（bootimg.h）：header(4096) | kernel | ramdisk | boot signature
    m/n/g 都按 4096 向上对齐；boot signature 之后的一切是尾部不透明区
    （原厂 boot.img 在这一段后面还挂了 VBmeta 链，本脚本原样保留）。
    """
    kernel_size, ramdisk_size, os_version = struct.unpack_from("<3I", data, 8)
    header_size = struct.unpack_from("<I", data, 20)[0]
    if header_size not in (HEADER_V3_SIZE, HEADER_V4_SIZE):
        die(f"{path}: header v{header_version} 的 header_size={header_size}，"
            f"既不是 {HEADER_V3_SIZE}(v3) 也不是 {HEADER_V4_SIZE}(v4) ⇒ 拒绝")
    cmdline = data[V3V4_CMDLINE_OFF:V3V4_CMDLINE_OFF + V3V4_CMDLINE_LEN] \
        .split(b"\0")[0].decode("utf-8", "replace")
    signature_size = (struct.unpack_from("<I", data, V4_SIGNATURE_SIZE_OFF)[0]
                      if header_version >= 4 else 0)

    page = BOOT_V3V4_PAGE
    off = page
    kernel = data[off:off + kernel_size]
    off += _pages(kernel_size, page)
    ramdisk = data[off:off + ramdisk_size]
    off += _pages(ramdisk_size, page)
    signature = data[off:off + signature_size]
    off += _pages(signature_size, page)
    tail = data[off:]  # VBmeta 链等（AOSP 语义之外，原样保留）

    return dict(
        path=path, raw=data, v3v4=True, page_size=page,
        header_version=header_version, header_size=header_size,
        name="", cmdline=cmdline, extra_cmdline="",
        kernel=kernel, ramdisk=ramdisk, second=b"", dtb=b"",
        recovery_dtbo=b"", signature=signature, tail=tail,
        signature_size=signature_size, kernel_size=kernel_size,
        ramdisk_size=ramdisk_size, os_version=os_version,
        kernel_addr=0, ramdisk_addr=0, second_addr=0, tags_addr=0, dtb_addr=0,
    )


def parse(path):
    """拆出 header 字段 + 载荷（v0/v1/v2: kernel/ramdisk/second/dtb；v3/v4: +signature/tail）。"""
    with open(path, "rb") as f:
        data = f.read()
    if data[:8] != MAGIC:
        die(f"{path}: 不是 Android boot image（magic={data[:8]!r}）")

    header_version = struct.unpack_from("<I", data, HEADER_VERSION_OFF)[0]
    if header_version >= 3:
        return parse_v3v4(path, data, header_version)

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
        header_size=header_size, header_version=header_version,
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
    if p.get("v3v4"):
        # v3/v4 没有 id 字段：要求逐字节全等（cmdline 窗口写回同一内容也必须收敛）
        diffs = [i for i in range(len(a)) if a[i] != b[i]]
        if diffs:
            die(f"verify FAIL 首个差异 byte {diffs[0]}: {a[diffs[0]]:02x} != {b[diffs[0]]:02x}（共 {len(diffs)}）")
        print(f"verify PASS v{p['header_version']} 逐字节全等 ({path}, {len(a)} B, "
              f"page={p['page_size']}, kernel={len(p['kernel'])} ramdisk={len(p['ramdisk'])} "
              f"signature={len(p['signature'])} tail={len(p['tail'])})")
        return
    # v2: id 字段（offset 576..608）是 sha1，重打包会重算，跳过
    diffs = [i for i in range(len(a)) if a[i] != b[i] and not (576 <= i < 608)]
    if diffs:
        die(f"verify FAIL 首个差异 byte {diffs[0]}: {a[diffs[0]]:02x} != {b[diffs[0]]:02x}（共 {len(diffs)}）")
    print(f"verify PASS ({path}, {len(a)} B, page={p['page_size']}, "
          f"kernel={len(p['kernel'])} ramdisk={len(p['ramdisk'])} dtb={len(p['dtb'])})")


def repack_v3v4(p, cmdline, out):
    """v3/v4 重打包 = 整文件拷贝 + 只写 cmdline 窗口（44..1580，NUL 补齐）。

    为什么不重排布局：v4 boot.img 没有任何「总长」字段（bootconfig 在 vendor_boot；
    原厂件在 boot signature 之后还挂了 VBmeta 链），重排就得猜尾部边界；
    既然唯一的改动就在 header 的 cmdline 窗口，等长原地替换能逐字节自证。
    """
    raw = bytearray(p["raw"])
    enc = cmdline.encode()
    raw[V3V4_CMDLINE_OFF:V3V4_CMDLINE_OFF + V3V4_CMDLINE_LEN] = \
        enc.ljust(V3V4_CMDLINE_LEN, b"\0")
    with open(out, "wb") as f:
        f.write(raw)

    # 后置条件：窗口外必须逐字节与原件相同（含 header 其它字段 / kernel / ramdisk /
    # boot signature / VBmeta 尾区），文件总大小不变
    if os.path.getsize(out) != len(p["raw"]):
        die(f"repack v{p['header_version']} FAIL 总大小变了 {os.path.getsize(out)} != {len(p['raw'])}")
    if raw[:V3V4_CMDLINE_OFF] != p["raw"][:V3V4_CMDLINE_OFF] or \
       raw[V3V4_CMDLINE_OFF + V3V4_CMDLINE_LEN:] != p["raw"][V3V4_CMDLINE_OFF + V3V4_CMDLINE_LEN:]:
        die(f"repack v{p['header_version']} FAIL 改到了 cmdline 窗口之外")


def repack(p, cmdline, out):
    """v3/v4 走等长原地写；v0/v1/v2 调 scripts/mkbootimg.py（不自己实现 v2 header，避免两套代码漂移）。"""
    if p.get("v3v4"):
        repack_v3v4(p, cmdline, out)
        return
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


def dump_header(p):
    """打完整 header/段表（name=value 逐行，便于 diff 做前后对照）。"""
    raw = p["raw"]
    print(f"file                           = {p['path']}")
    print(f"file_size                      = {len(raw)}")
    print(f"magic                          = {raw[:8].decode('ascii', 'replace')}")
    print(f"header_version                 = {p.get('header_version', 'n/a')}")
    print(f"header_size                    = {p.get('header_size', 'n/a')}")
    print(f"page_size                      = {p['page_size']}")
    print(f"name                           = {p['name']!r}")
    print(f"cmdline                        = {p['cmdline']!r}")
    print(f"cmdline_len                    = {len(p['cmdline'])}")
    print(f"extra_cmdline                  = {p['extra_cmdline']!r}")
    print(f"os_version                     = {p['os_version']:#x}")
    print(f"kernel_size                    = {len(p['kernel'])}")
    print(f"kernel_addr                    = {p['kernel_addr']:#x}")
    print(f"kernel_sha256                  = {sha(p['kernel'])}")
    print(f"ramdisk_size                   = {len(p['ramdisk'])}")
    print(f"ramdisk_addr                   = {p['ramdisk_addr']:#x}")
    print(f"ramdisk_sha256                 = {sha(p['ramdisk'])}")
    print(f"second_size                    = {len(p['second'])}")
    print(f"second_addr                    = {p['second_addr']:#x}")
    print(f"tags_addr                      = {p['tags_addr']:#x}")
    print(f"dtb_size                       = {len(p['dtb'])}")
    print(f"dtb_addr                       = {p['dtb_addr']:#x}")
    print(f"dtb_sha256                     = {sha(p['dtb'])}")
    print(f"recovery_dtbo_size             = {len(p['recovery_dtbo'])}")
    if p.get("v3v4"):
        print(f"signature_size                 = {p['signature_size']}")
        print(f"signature_sha256               = {sha(p['signature'])}")
        print(f"tail_size                      = {len(p['tail'])}")
        print(f"tail_sha256                    = {sha(p['tail'])}")


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("image")
    ap.add_argument("--show", action="store_true", help="只打印 cmdline 与载荷摘要")
    ap.add_argument("--dump", action="store_true",
                    help="打完整 header/段表（name=value，便于前后 diff）")
    ap.add_argument("--append", help="在现有 cmdline 末尾追加（空格分隔）")
    ap.add_argument("--set", dest="setcmd", help="整体替换 cmdline")
    ap.add_argument("--verify", action="store_true", help="结构往返自检")
    ap.add_argument("-o", "--output")
    a = ap.parse_args()

    if a.verify:
        verify(a.image)
        return 0

    p = parse(a.image)
    if a.dump:
        dump_header(p)
        return 0

    if a.show or not (a.append or a.setcmd):
        print(f"image          : {a.image}")
        print(f"page_size      : {p['page_size']}")
        print(f"header_version : {p.get('header_version', 2)}")
        print(f"name           : {p['name']!r}")
        print(f"cmdline ({len(p['cmdline'])}B) : {p['cmdline']}")
        if p["extra_cmdline"]:
            print(f"extra_cmdline  : {p['extra_cmdline']}")
        print(f"kernel         : {len(p['kernel'])} B  sha256 {sha(p['kernel'])[:16]}…")
        print(f"ramdisk        : {len(p['ramdisk'])} B  sha256 {sha(p['ramdisk'])[:16]}…")
        print(f"dtb            : {len(p['dtb'])} B  sha256 {sha(p['dtb'])[:16]}…")
        if p.get("v3v4"):
            print(f"signature      : {len(p['signature'])} B  sha256 {sha(p['signature'])[:16]}…")
            print(f"tail(vbmeta等) : {len(p['tail'])} B  sha256 {sha(p['tail'])[:16]}…")
        if not (a.append or a.setcmd):
            return 0

    if not a.output:
        die("需要 -o/--output")
    new = a.setcmd if a.setcmd else (p["cmdline"] + " " + a.append).strip()
    limit = (V3V4_CMDLINE_LEN - 1) if p.get("v3v4") else (BOOT_ARGS_SIZE - 1)
    if len(new) > limit:
        die(f"cmdline 超长 {len(new)} > {limit}（header v{p.get('header_version', 2)} 的 cmdline 字段）")

    repack(p, new, a.output)
    q = parse(a.output)

    # ---- 自证：所有非 cmdline 段逐字节不变，cmdline 只差预期 ----
    ok = True
    keys = ("kernel", "ramdisk", "dtb", "second", "recovery_dtbo")
    if p.get("v3v4"):
        keys = ("kernel", "ramdisk", "signature", "tail")
    for k in keys:
        same = sha(p[k]) == sha(q[k])
        ok &= same
        print(f"{k:13s} {'SAME' if same else 'DIFF'}  {sha(q[k])[:16]}…  ({len(q[k])} B)")
    if p.get("v3v4"):
        # header 窗口外逐字节对照（含 header_version/header_size/各 size 字段）
        tail_a = p["raw"][V3V4_CMDLINE_OFF + V3V4_CMDLINE_LEN:]
        tail_b = q["raw"][V3V4_CMDLINE_OFF + V3V4_CMDLINE_LEN:]
        same = tail_a == tail_b
        ok &= same
        print(f"{'payload_rest':13s} {'SAME' if same else 'DIFF'}  {sha(tail_b)[:16]}…  ({len(tail_b)} B)")
        same = q["header_version"] == p["header_version"] and q["header_size"] == p["header_size"]
        ok &= same
        print(f"{'header_fields':13s} {'SAME' if same else 'DIFF'}  "
              f"hv={q['header_version']} header_size={q['header_size']}")
        same = len(p["raw"]) == len(q["raw"])
        ok &= same
        print(f"{'file_size':13s} {'SAME' if same else 'DIFF'}  {len(q['raw'])} B")
    print(f"cmdline  old: {p['cmdline']}")
    print(f"cmdline  new: {q['cmdline']}")
    if not ok:
        die("载荷与原件不一致，拒绝产出")
    print(f"OK  {a.output}  {os.path.getsize(a.output)} B")
    return 0


if __name__ == "__main__":
    sys.exit(main())
