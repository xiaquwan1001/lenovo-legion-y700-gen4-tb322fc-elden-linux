#!/usr/bin/env python3
"""manifest-from-image.py — 从**镜像本身**重建 `.manifest`（源树已删/丢失时用）。

为什么需要它
------------
`scripts/build-manifest.sh` 是正规出口，但它要读**构建时那棵树**（`make kernelrelease`、
`KDIR/.config`、`KDIR/.../Image.gz`）。树被删/换过之后（本例：vk183-fastrpc 的源树
`build/vk151` 已不存在），硬跑它会把当前树的 config/kernel 哈希写进去 ⇒ 造出**假身份**，
正是 `PITFALLS #131`/#162 那类事故。

本脚本只写「镜像里客观存在」的字段（解出的内核 UTS/载荷 sha、ramdisk/dtb sha、cmdline、
mkbootimg 地址栏），树侧字段一律写成 `(absent:…)` 并在文件头声明 `reconstructed_from=image`。
它不是旁路：`check-doctor §5e` 仍要求 `config_sha256`，缺号必须登记进
`versions/manifest-incomplete-allowlist.txt`（本脚本会自动提醒）。

用法
----
  scripts/manifest-from-image.py out/boot-elden-<vk>.img --note "源树 build/vk151 已删"
  scripts/manifest-from-image.py <img> --dry-run         # 只打印，不写

判据（跑完自己验）
------------------
  python3 scripts/vk-identity.py --gate     # 该镜像不得新增 tree_drift/dirty_drift/mismatch
  bash scripts/check-doctor.sh --only 5     # §5d 新鲜度不变、§5e 只有已登记的缺 config
"""
import argparse
import hashlib
import os
import re
import sys
import zlib
from importlib.machinery import SourceFileLoader
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
mk = SourceFileLoader('mkbootimg', str(ROOT / 'scripts' / 'mkbootimg.py')).load_module()


def sha(b):
    return hashlib.sha256(b).hexdigest()


def kernel_identity(kernel_bytes):
    """内核段 → (UTS 串, 解压后内核 sha256)。兼容 gz / 未压缩 Image。"""
    data = kernel_bytes
    for cand in (data, data.find(b'\x1f\x8b\x08') if b'\x1f\x8b\x08' in data else -1):
        if isinstance(cand, bytes):
            blob = cand
        elif cand >= 0:
            try:
                blob = zlib.decompressobj(16 + zlib.MAX_WBITS).decompress(data[cand:], 128 << 20)
            except Exception:
                continue
        else:
            continue
        m = re.search(rb'Linux version (\S+)', blob)
        if m:
            return m.group(1).decode(), sha(blob)
    return '(unknown)', '(unknown)'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('image')
    ap.add_argument('--note', default='', help='重建原因（写进 manifest 的 reconstructed_note）')
    ap.add_argument('--dry-run', action='store_true')
    a = ap.parse_args()

    img = Path(a.image)
    if not img.is_absolute():
        img = (Path.cwd() / img).resolve()
    raw = img.read_bytes()
    data, sections, f = mk.read_image(str(img))

    kern = sections['kernel']
    uts, kpayload = kernel_identity(kern)
    base = img.name[:-len('.img')]
    version = base[len('boot-elden-'):] if base.startswith('boot-elden-') else base

    argv = ('--kernel <image:kern> --ramdisk <image:ramdisk> --dtb <image:dtb> '
            '--kernel_offset %s --ramdisk_offset %s --tags_offset %s --dtb_offset %s '
            '--cmdline %r --header_version %s --pagesize %s'
            % (hex(f['kernel_addr']), hex(f['ramdisk_addr']), hex(f['tags_addr']),
               hex(f['dtb_addr']), f['cmdline'], f['header_version'], f['page']))

    lines = [
        '# boot image manifest — reconstructed by scripts/manifest-from-image.py',
        '# 只含镜像内客观字段；树侧字段标 (absent:…)，见文件头 reconstructed_* 三行。',
        'version=%s' % version,
        'generated=%s' % __import__('datetime').datetime.now(__import__('datetime').timezone.utc)
                                                .strftime('%Y-%m-%dT%H:%M:%SZ'),
        'reconstructed_from=image',
        'reconstructed_note=%s' % (a.note or '(未注明)'),
        'image=%s' % img,
        'image_sha256=%s' % sha(raw),
        'image_size=%d' % len(raw),
        'kernel_uts=Linux version %s' % uts,
        'kernel_release=(absent:source tree removed — 用 kernel_uts 作身份锚)',
        'kernel_release_matches_image=unknown',
        'kernel_payload_sha256=%s' % kpayload,
        'kernel_image_sha256=%s' % kpayload,
        'kernel_identity_source=image',
        'kernel_sha256=%s' % sha(kern),
        'kernel_packed_sha256=%s' % sha(kern),
        'ramdisk_sha256=%s' % sha(sections['ramdisk']),
        'ramdisk_size=%d' % len(sections['ramdisk']),
        'dtb_sha256=%s' % sha(sections['dtb']),
        'dtb_size=%d' % len(sections['dtb']),
        'config_sha256=(absent:source tree removed)',
        'cmdline=%s' % f['cmdline'],
        'mkbootimg_args=%s' % argv,
        'kernel_git_head=(absent)',
        'kernel_git_state=(absent)',
        'project_git_head=(absent)',
        'verification=NOT_TESTED_ON_DEVICE',
    ]
    text = '\n'.join(lines) + '\n'
    out = img.with_suffix('.manifest')
    if a.dry_run:
        print(text)
        return 0
    out.write_text(text)
    print('[manifest] %s' % out)
    print('  kernel_uts=%s' % uts)
    print('  kernel_payload_sha256=%s' % kpayload)
    print('  ⚠ 缺 config_sha256 ⇒ 若该构建晚于 2026-10-10，须登记 '
          'versions/manifest-incomplete-allowlist.txt（check-doctor §5e）')
    return 0


if __name__ == '__main__':
    sys.exit(main())
