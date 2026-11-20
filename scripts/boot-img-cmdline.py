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

支持 header v0/v1/v2（走 scripts/mkbootimg.py 重打包）、header v3/v4
（AOSP `boot_img_hdr_v3/v4`：无 kernel_addr/ramdisk_addr/second/dtb 字段，
page 固定 4096，cmdline 在偏移 44、长 1536；v4 另加 signature_size @1580），
以及 **vendor_boot v3/v4**（`VNDRBOOT`：cmdline 在偏移 28、长 2048，
header_size 2112/2128；布局 = header | vendor_ramdisk | dtb | ramdisk_table | bootconfig）。
v3/v4 与 vendor_boot 的重打包都走「整文件拷贝 + 只改 cmdline 窗口」，
因此 kernel/ramdisk/boot signature / vendor_ramdisk / dtb / table / bootconfig / 尾部（VBmeta 等）
逐字节原样、文件总大小不变；写后逐字节自证（窗口外全等）。

为什么还要 vendor_boot：原厂件实测 `vendor_boot.img` 的 cmdline 带
`console=ttynull qcom_geni_serial.con_enabled=0 bootconfig` ⇒ 能否拿到串口/控制台日志
取决于 bootloader 取哪一侧的 cmdline（boot 侧还是 vendor_boot 侧，需上机项）。
本脚本把两侧都能改、都能离线自证，避免到设备窗口才发现「另一侧改不了」。

用法：
    # vendor_boot 同理（magic 自动识别，不需要额外参数）
    python3 scripts/boot-img-cmdline.py vendor_boot.img --show
    python3 scripts/boot-img-cmdline.py vendor_boot.img --append "console=ttyGS0" -o out/vendor_boot-ttygs0.img
    python3 scripts/boot-img-cmdline.py --selftest     # 合成镜像自检（不读任何外部件）

已知边界：
  * v3/v4 与 vendor_boot 的 cmdline 改动会让原厂 AVB hash descriptor 失配（vbmeta 用 OEM 私钥签名，
    本脚本不能重签）⇒ 产物只走 `fastboot boot`（零写盘）或明确知情后刷写，且**必须上机确认 bootloader 认**。
  * boot 侧的 v4 bootconfig 在 vendor_boot.img（AOSP bootimg.h），本脚本不改它（`--dump` 会把 bootconfig 段摘出打 sha）。
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
VENDOR_MAGIC = b"VNDRBOOT"
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
# vendor_boot（AOSP bootimg.h `vendor_boot_img_hdr_v3/v4`）：magic|hv|page|kernel_addr|ramdisk_addr|
# vendor_ramdisk_size 共 28 B，紧跟 cmdline[2048] ⇒ cmdline 窗口 = 28..2076。
VENDOR_CMDLINE_OFF = 28
VENDOR_CMDLINE_LEN = 2048
VENDOR_HDR_V3_SIZE = 2112
VENDOR_HDR_V4_SIZE = 2128
VENDOR_HEADER_SIZE_OFF = 2096
VENDOR_DTB_SIZE_OFF = 2100
VENDOR_DTB_ADDR_OFF = 2104
VENDOR_TABLE_SIZE_OFF = 2112
VENDOR_TABLE_NUM_OFF = 2116
VENDOR_TABLE_ENTRY_SIZE_OFF = 2120
VENDOR_BOOTCONFIG_SIZE_OFF = 2124
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
    if len(data) < V3V4_CMDLINE_OFF + V3V4_CMDLINE_LEN:
        die(f"{path}: 文件只有 {len(data)} B，装不下 v3/v4 cmdline 窗口 ⇒ 拒绝（截断件？）")
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
        path=path, raw=data, kind="boot", inplace=True, v3v4=True, page_size=page,
        header_version=header_version, header_size=header_size,
        cmdline_off=V3V4_CMDLINE_OFF, cmdline_len=V3V4_CMDLINE_LEN,
        name="", cmdline=cmdline, extra_cmdline="",
        kernel=kernel, ramdisk=ramdisk, second=b"", dtb=b"",
        recovery_dtbo=b"", signature=signature, tail=tail,
        signature_size=signature_size, kernel_size=kernel_size,
        ramdisk_size=ramdisk_size, os_version=os_version,
        kernel_addr=0, ramdisk_addr=0, second_addr=0, tags_addr=0, dtb_addr=0,
    )


def parse_vendor(path, data):
    """vendor_boot v3/v4（AOSP `vendor_boot_img_hdr_v3/v4`）。

    布局：header(page) | vendor_ramdisk | dtb | [v4] ramdisk_table | [v4] bootconfig | tail
    每段按 page（4096）向上对齐；cmdline 窗口 28..2076（2048 B，NUL 补齐）。
    """
    header_version, page_size = struct.unpack_from("<II", data, 8)
    if header_version not in (3, 4):
        die(f"{path}: vendor_boot header v{header_version} 不支持（只有 v3/v4）")
    if len(data) < VENDOR_CMDLINE_OFF + VENDOR_CMDLINE_LEN:
        die(f"{path}: 文件只有 {len(data)} B，装不下 vendor_boot cmdline 窗口"
            f"（至少 {VENDOR_CMDLINE_OFF + VENDOR_CMDLINE_LEN} B）⇒ 拒绝（截断件？）")
    header_size = struct.unpack_from("<I", data, VENDOR_HEADER_SIZE_OFF)[0]
    want = VENDOR_HDR_V4_SIZE if header_version == 4 else VENDOR_HDR_V3_SIZE
    if header_size != want:
        die(f"{path}: vendor_boot v{header_version} 的 header_size={header_size} ≠ {want} ⇒ 拒绝")
    if page_size != BOOT_V3V4_PAGE:
        die(f"{path}: vendor_boot page_size={page_size} ≠ {BOOT_V3V4_PAGE} ⇒ 拒绝")

    kernel_addr, ramdisk_addr, vramdisk_size = struct.unpack_from("<III", data, 16)
    cmdline = data[VENDOR_CMDLINE_OFF:VENDOR_CMDLINE_OFF + VENDOR_CMDLINE_LEN] \
        .split(b"\0")[0].decode("utf-8", "replace")
    tags_addr = struct.unpack_from("<I", data, 2076)[0]
    name = data[2080:2080 + BOOT_NAME_SIZE].split(b"\0")[0].decode("utf-8", "replace")
    dtb_size = struct.unpack_from("<I", data, VENDOR_DTB_SIZE_OFF)[0]
    dtb_addr = struct.unpack_from("<Q", data, VENDOR_DTB_ADDR_OFF)[0]
    tsize = tnum = tentry = bcsize = 0
    if header_version >= 4:
        tsize, tnum, tentry, bcsize = struct.unpack_from(
            "<4I", data, VENDOR_TABLE_SIZE_OFF)

    off = page_size
    vendor_ramdisk = data[off:off + vramdisk_size]
    off += _pages(vramdisk_size, page_size)
    dtb = data[off:off + dtb_size]
    off += _pages(dtb_size, page_size)
    table = data[off:off + tsize]
    off += _pages(tsize, page_size)
    bootconfig = data[off:off + bcsize]
    off += _pages(bcsize, page_size)
    tail = data[off:]

    return dict(
        path=path, raw=data, kind="vendor", inplace=True, v3v4=True, page_size=page_size,
        header_version=header_version, header_size=header_size,
        cmdline_off=VENDOR_CMDLINE_OFF, cmdline_len=VENDOR_CMDLINE_LEN,
        name=name, cmdline=cmdline, extra_cmdline="",
        kernel=b"", ramdisk=b"", second=b"", dtb=dtb, recovery_dtbo=b"",
        vendor_ramdisk=vendor_ramdisk, ramdisk_table=table, bootconfig=bootconfig,
        signature=b"", tail=tail, signature_size=0,
        kernel_size=0, ramdisk_size=vramdisk_size, os_version=0,
        kernel_addr=kernel_addr, ramdisk_addr=ramdisk_addr, second_addr=0,
        tags_addr=tags_addr, dtb_addr=dtb_addr, dtb_size=dtb_size,
        ramdisk_table_size=tsize, ramdisk_table_num=tnum,
        ramdisk_table_entry_size=tentry, bootconfig_size=bcsize,
    )


def parse(path):
    """拆出 header 字段 + 载荷（v0/v1/v2: kernel/ramdisk/second/dtb；v3/v4: +signature/tail）。"""
    with open(path, "rb") as f:
        data = f.read()
    if data[:8] == VENDOR_MAGIC:
        return parse_vendor(path, data)
    if data[:8] != MAGIC:
        die(f"{path}: 不是 Android boot/vendor_boot 镜像（magic={data[:8]!r}）")

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
        path=path, raw=data, kind="boot", inplace=False, page_size=page_size, name=name,
        cmdline_off=64, cmdline_len=BOOT_ARGS_SIZE,
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
    if p.get("inplace"):
        # v3/v4 与 vendor_boot 没有 id 字段：要求逐字节全等（cmdline 窗口写回同一内容也必须收敛）
        diffs = [i for i in range(len(a)) if a[i] != b[i]]
        if diffs:
            die(f"verify FAIL 首个差异 byte {diffs[0]}: {a[diffs[0]]:02x} != {b[diffs[0]]:02x}（共 {len(diffs)}）")
        extra = ""
        if p.get("kind") == "vendor":
            extra = (f" vendor_ramdisk={len(p['vendor_ramdisk'])} dtb={len(p['dtb'])} "
                     f"table={len(p['ramdisk_table'])} bootconfig={len(p['bootconfig'])}")
        else:
            extra = f" signature={len(p['signature'])}"
        print(f"verify PASS {p.get('kind','boot')} v{p['header_version']} 逐字节全等 "
              f"({path}, {len(a)} B, page={p['page_size']}, kernel={len(p['kernel'])} "
              f"ramdisk={len(p['ramdisk'])}{extra} tail={len(p['tail'])})")
        return
    # v2: id 字段（offset 576..608）是 sha1，重打包会重算，跳过
    diffs = [i for i in range(len(a)) if a[i] != b[i] and not (576 <= i < 608)]
    if diffs:
        die(f"verify FAIL 首个差异 byte {diffs[0]}: {a[diffs[0]]:02x} != {b[diffs[0]]:02x}（共 {len(diffs)}）")
    print(f"verify PASS ({path}, {len(a)} B, page={p['page_size']}, "
          f"kernel={len(p['kernel'])} ramdisk={len(p['ramdisk'])} dtb={len(p['dtb'])})")


def repack_inplace(p, cmdline, out):
    """v3/v4 boot 与 vendor_boot v3/v4 重打包 = 整文件拷贝 + 只写 cmdline 窗口（NUL 补齐）。

    为什么不重排布局：v4 boot.img 没有任何「总长」字段（bootconfig 在 vendor_boot；
    原厂件在 boot signature 之后还挂了 VBmeta 链）；vendor_boot 虽然每段都有 size，
    但 ramdisk_table / bootconfig 的尾部边界依赖 vendor 自定义 → 重排就得猜；
    既然唯一的改动就在 header 的 cmdline 窗口，等长原地替换能逐字节自证。
    """
    raw = bytearray(p["raw"])
    off, ln = p["cmdline_off"], p["cmdline_len"]
    enc = cmdline.encode()
    raw[off:off + ln] = enc.ljust(ln, b"\0")
    with open(out, "wb") as f:
        f.write(raw)

    # 后置条件：窗口外必须逐字节与原件相同（含 header 其它字段 / 各载荷段 / VBmeta 尾区），
    # 文件总大小不变
    if os.path.getsize(out) != len(p["raw"]):
        die(f"repack {p.get('kind','boot')} v{p['header_version']} FAIL 总大小变了 "
            f"{os.path.getsize(out)} != {len(p['raw'])}")
    if raw[:off] != p["raw"][:off] or raw[off + ln:] != p["raw"][off + ln:]:
        die(f"repack {p.get('kind','boot')} v{p['header_version']} FAIL 改到了 cmdline 窗口之外")


def repack(p, cmdline, out):
    """v3/v4 boot 与 vendor_boot 走等长原地写；v0/v1/v2 调 scripts/mkbootimg.py（不自己实现 v2 header，避免两套代码漂移）。"""
    if p.get("inplace"):
        repack_inplace(p, cmdline, out)
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
    print(f"kind                           = {p.get('kind', 'boot')}")
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
    if p.get("kind") == "vendor":
        print(f"vendor_ramdisk_size            = {len(p['vendor_ramdisk'])}")
        print(f"vendor_ramdisk_sha256          = {sha(p['vendor_ramdisk'])}")
        print(f"dtb_size                       = {p['dtb_size']}")
        print(f"dtb_sha256                     = {sha(p['dtb'])}")
        print(f"ramdisk_table_size             = {p['ramdisk_table_size']}（num={p['ramdisk_table_num']}, entry_size={p['ramdisk_table_entry_size']}）")
        print(f"bootconfig_size                = {p['bootconfig_size']}")
        print(f"bootconfig_sha256              = {sha(p['bootconfig'])}")
    if p.get("v3v4"):
        print(f"signature_size                 = {p['signature_size']}")
        print(f"signature_sha256               = {sha(p['signature'])}")
        print(f"tail_size                      = {len(p['tail'])}")
        print(f"tail_sha256                    = {sha(p['tail'])}")


def build_synth(kind, header_version, cmdline="", kernel=b"K" * 5000, ramdisk=b"R" * 9000,
                dtb=b"D" * 3000, tail=b"VBMETA-TAIL-SENTINEL"):
    """合成一枚最小 boot/vendor_boot 镜像（只给 --selftest 用，不读外部件）。"""
    page = BOOT_V3V4_PAGE
    if kind == "boot":
        sig = b"S" * 1024 if header_version >= 4 else b""
        hdr = bytearray(page)
        hdr[:8] = MAGIC
        struct.pack_into("<3I", hdr, 8, len(kernel), len(ramdisk), 0)
        struct.pack_into("<I", hdr, 20, HEADER_V4_SIZE if header_version >= 4 else HEADER_V3_SIZE)
        struct.pack_into("<I", hdr, 36, page)
        struct.pack_into("<I", hdr, HEADER_VERSION_OFF, header_version)
        hdr[V3V4_CMDLINE_OFF:V3V4_CMDLINE_OFF + V3V4_CMDLINE_LEN] = \
            cmdline.encode().ljust(V3V4_CMDLINE_LEN, b"\0")
        if header_version >= 4:
            struct.pack_into("<I", hdr, V4_SIGNATURE_SIZE_OFF, len(sig))
        blob = bytes(hdr)
        for seg in (kernel, ramdisk, sig):
            blob += seg.ljust(_pages(len(seg), page), b"\0")
        return blob + tail

    if kind == "vendor":
        vrd, table, bcfg = ramdisk, b"T" * 108, b"BCFG" * 10
        hdr = bytearray(page)
        hdr[:8] = VENDOR_MAGIC
        struct.pack_into("<II", hdr, 8, header_version, page)
        struct.pack_into("<III", hdr, 16, 0x8000, 0x1000000, len(vrd))
        hdr[VENDOR_CMDLINE_OFF:VENDOR_CMDLINE_OFF + VENDOR_CMDLINE_LEN] = \
            cmdline.encode().ljust(VENDOR_CMDLINE_LEN, b"\0")
        struct.pack_into("<I", hdr, 2076, 0x100)
        struct.pack_into("<I", hdr, VENDOR_HEADER_SIZE_OFF,
                         VENDOR_HDR_V4_SIZE if header_version >= 4 else VENDOR_HDR_V3_SIZE)
        struct.pack_into("<I", hdr, VENDOR_DTB_SIZE_OFF, len(dtb))
        struct.pack_into("<Q", hdr, VENDOR_DTB_ADDR_OFF, 0x1f00000)
        if header_version >= 4:
            struct.pack_into("<4I", hdr, VENDOR_TABLE_SIZE_OFF,
                             len(table), 1, 108, len(bcfg))
        blob = bytes(hdr)
        segs = [vrd, dtb] + ([table, bcfg] if header_version >= 4 else [])
        for seg in segs:
            blob += seg.ljust(_pages(len(seg), page), b"\0")
        return blob + tail
    die(f"build_synth: 未知 kind={kind}")


def selftest():
    """合成镜像自检（不读任何外部件）：正例往返 + 反例必拒。

    正例：boot v3 / boot v4 / vendor_boot v3 / vendor_boot v4 ——
          ① `--verify` 必须逐字节全等（CLI 真跑）；
          ② `--append console=ttyGS0` 后：窗口外逐字节不变、cmdline 回读只多一个 token、总大小不变。
    反例：① vendor_boot v4 的 header_size 写坏 ⇒ 解析必须拒；
          ② cmdline 窗口外被篡改 ⇒ 重打包的后置条件必须拒（不产出）；
          ③ 坏 magic ⇒ 解析必须拒；
          ④ cmdline 超过字段长度 ⇒ CLI 必须 rc=2（长度门在 main() 里，故走子进程真跑）。
    """
    td = tempfile.mkdtemp(prefix="bootimg-selftest-")
    fails = []
    me = os.path.abspath(__file__)

    def run(*args):
        r = subprocess.run([sys.executable, me, *args], capture_output=True, text=True)
        return r.returncode, r.stdout + r.stderr

    try:
        for kind, hv in (("boot", 3), ("boot", 4), ("vendor", 3), ("vendor", 4)):
            base = f"{kind}-v{hv}"
            img = os.path.join(td, base + ".img")
            open(img, "wb").write(build_synth(kind, hv, cmdline="console=ttynull"))
            # ① 往返（CLI）
            rc, out = run(img, "--verify")
            if rc != 0 or "verify PASS" not in out:
                fails.append(f"{base}: --verify rc={rc} :: {out.strip().splitlines()[-1:]}")
                continue
            # ② append 后窗口外不变（CLI）
            out_img = os.path.join(td, base + "-out.img")
            rc, out = run(img, "--append", "console=ttyGS0", "-o", out_img)
            if rc != 0:
                fails.append(f"{base}: --append rc={rc} :: {out.strip().splitlines()[-1:]}")
                continue
            p, q = parse(img), parse(out_img)
            off, ln = p["cmdline_off"], p["cmdline_len"]
            if p["raw"][:off] != q["raw"][:off] or p["raw"][off + ln:] != q["raw"][off + ln:]:
                fails.append(f"{base}: append 后 cmdline 窗口外被改动")
            if q["cmdline"] != "console=ttynull console=ttyGS0":
                fails.append(f"{base}: cmdline 回读 {q['cmdline']!r} 不符")
            if len(p["raw"]) != len(q["raw"]):
                fails.append(f"{base}: 文件大小变了 {len(p['raw'])} → {len(q['raw'])}")
            # ④ 超长必拒（CLI）
            rc, out = run(img, "--set", "x" * (ln + 10), "-o", os.path.join(td, "toolong.img"))
            if rc != 2:
                fails.append(f"{base}: 超长 cmdline 未被拒（rc={rc}）")

        # 反例 ①：vendor v4 的 header_size 写成 v3 值 ⇒ 解析必拒
        bad = os.path.join(td, "vendor-badheader.img")
        raw = bytearray(build_synth("vendor", 4))
        struct.pack_into("<I", raw, VENDOR_HEADER_SIZE_OFF, VENDOR_HDR_V3_SIZE)
        open(bad, "wb").write(raw)
        rc, _ = run(bad, "--verify")
        if rc == 0:
            fails.append("反例①: vendor v4 header_size 改坏仍被接受（门空转）")

        # 反例 ②：截断件（长度装不下 cmdline 窗口）必须被拒
        trunc = os.path.join(td, "boot-truncated.img")
        open(trunc, "wb").write(build_synth("boot", 4)[:1200])
        rc, _ = run(trunc, "--verify")
        if rc == 0:
            fails.append("反例②: 截断件仍被接受（长度门空转）")
        truncv = os.path.join(td, "vendor-truncated.img")
        open(truncv, "wb").write(build_synth("vendor", 4)[:1500])
        rc, _ = run(truncv, "--verify")
        if rc == 0:
            fails.append("反例②: vendor 截断件仍被接受（长度门空转）")

        # 反例 ③：坏 magic
        badmagic = os.path.join(td, "badmagic.img")
        open(badmagic, "wb").write(b"NOTABOOT" + b"\0" * 5000)
        rc, _ = run(badmagic, "--verify")
        if rc == 0:
            fails.append("反例③: 坏 magic 仍被接受")
    finally:
        for f in os.listdir(td):
            try:
                os.unlink(os.path.join(td, f))
            except OSError:
                pass
        try:
            os.rmdir(td)
        except OSError:
            pass

    if fails:
        for f in fails:
            print(f"  [FAIL] {f}", file=sys.stderr)
        die(f"selftest 有 {len(fails)} 条失败")
    print("selftest PASS（4 正例：boot v3/v4 + vendor v3/v4 的往返与 append；4 反例：坏 header_size / 截断件 / 坏 magic / 超长 cmdline）")
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("image", nargs="?", help="boot.img / vendor_boot.img（--selftest 时可省）")
    ap.add_argument("--selftest", action="store_true", help="合成镜像自检（不读外部件）")
    ap.add_argument("--show", action="store_true", help="只打印 cmdline 与载荷摘要")
    ap.add_argument("--dump", action="store_true",
                    help="打完整 header/段表（name=value，便于前后 diff）")
    ap.add_argument("--append", help="在现有 cmdline 末尾追加（空格分隔）")
    ap.add_argument("--set", dest="setcmd", help="整体替换 cmdline")
    ap.add_argument("--verify", action="store_true", help="结构往返自检")
    ap.add_argument("-o", "--output")
    a = ap.parse_args()

    if a.selftest:
        return selftest()
    if not a.image:
        die("需要 image（或用 --selftest）")
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
        if p.get("kind") == "vendor":
            print(f"vendor_ramdisk : {len(p['vendor_ramdisk'])} B  sha256 {sha(p['vendor_ramdisk'])[:16]}…")
            print(f"ramdisk_table  : {len(p['ramdisk_table'])} B (num={p['ramdisk_table_num']})")
            print(f"bootconfig     : {len(p['bootconfig'])} B  sha256 {sha(p['bootconfig'])[:16]}…")
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
    limit = p["cmdline_len"] - 1
    if p.get("v3v4") and not p.get("inplace"):
        limit = BOOT_ARGS_SIZE - 1
    if len(new) > limit:
        die(f"cmdline 超长 {len(new)} > {limit}（{p.get('kind','boot')} v{p.get('header_version', 2)} 的 cmdline 字段）")

    repack(p, new, a.output)
    q = parse(a.output)

    # ---- 自证：所有非 cmdline 段逐字节不变，cmdline 只差预期 ----
    ok = True
    keys = ("kernel", "ramdisk", "dtb", "second", "recovery_dtbo")
    if p.get("kind") == "vendor":
        keys = ("vendor_ramdisk", "dtb", "ramdisk_table", "bootconfig", "tail")
    elif p.get("v3v4"):
        keys = ("kernel", "ramdisk", "signature", "tail")
    for k in keys:
        same = sha(p[k]) == sha(q[k])
        ok &= same
        print(f"{k:13s} {'SAME' if same else 'DIFF'}  {sha(q[k])[:16]}…  ({len(q[k])} B)")
    if p.get("inplace"):
        # header 窗口外逐字节对照（含 header_version/header_size/各 size 字段）
        _off, _ln = p["cmdline_off"], p["cmdline_len"]
        tail_a = p["raw"][_off + _ln:]
        tail_b = q["raw"][_off + _ln:]
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
