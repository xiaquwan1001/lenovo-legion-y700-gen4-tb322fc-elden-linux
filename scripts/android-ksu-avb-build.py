#!/usr/bin/env python3
"""android-ksu-avb-build.py — 造 KernelSU(LKM) 修补的 init_boot + 与之自洽的 vbmeta_a。

纯主机侧，不接触设备。输入 = 官方 259 包里的 init_boot.img / vbmeta.img（或 EDL/设备读回件）
+ KernelSU-Next 的 ksud(x86_64) 与 aarch64 android15-6.6 kernelsu.ko。

流水线（每一步都落盘，便于逐段复核）：
  1. ksud boot-patch        : init_boot.img -> work/init_boot_ksu_raw.img（ksud 自己保留旧 footer，必须先剥）
  2. strip AVB footer       : 取 footer 里的 original_image_size，截出 image-only
  3. avbtool add_hash_footer: 以 stock 相同的 salt / prop / partitionsize 重加 footer（Algorithm NONE，与 stock 一致）
  4. rebuild vbmeta         : 从 base vbmeta 逐条搬描述符，**只替换 init_boot 那条**，用 AOSP testkey(2597c218)
                              重新签名，Flags 由 --flags 决定（默认 1 = HASHTREE_DISABLED，与 2026-11-18 在机实证件一致）
  5. 自检                    : avbtool verify_image(init_boot) + 独立重算 sha256(salt||img) + 描述符逐条比对

用法:
  scripts/android-ksu-avb-build.py --out out/android-root-20261119
  scripts/android-ksu-avb-build.py --flags 0 --out /tmp/ksu-flags0   # 需 stock super 才安全
"""
import argparse
import hashlib
import importlib.util
import os
import shutil
import struct
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AVBTOOL = os.path.join(REPO, 'tools', 'avbtool.py')
def odirect_sha(path):
    """**O_DIRECT 直读** sha256（绕过页缓存）——见 scripts/odirect-sha.py 与
    reports/odirect-sha-gate-20261120.md。页缓存污染时 buffered 连读多次会「稳定但错」，
    所以主机侧文件身份一律走它。工具 O_DIRECT 不可用（tmpfs 等）时自己退回 buffered 并打
    WARN；这里再留一层纯 python buffered 兜底。"""
    tool = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'odirect-sha.py')
    try:
        r = subprocess.run([sys.executable, tool, '--tsv', path],
                           capture_output=True, text=True, timeout=1800, check=True)
        cols = r.stdout.splitlines()[0].split('\t')
        if len(cols) >= 3 and len(cols[2]) == 64:
            return cols[2]
        raise ValueError('unexpected tool output: %r' % r.stdout[:120])
    except Exception as e:  # noqa: BLE001
        sys.stderr.write('WARN odirect-sha: %s 未走 O_DIRECT（%s），退回 buffered\n' % (path, e))
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for b in iter(lambda: f.read(1 << 20), b''):
            h.update(b)
    return h.hexdigest()


# stock 259 vbmeta_a 里 init_boot hash descriptor 的 salt（复用 => 描述符只有 size/digest 变）
INIT_BOOT_SALT = 'eb39718accf62c4b8f0d2af4ce8cc08a8a6b9f2d3ff50606edec597456273761'
INIT_BOOT_PROPS = [
    'com.android.build.init_boot.os_version:15',
    'com.android.build.init_boot.fingerprint:Lenovo/TB322FC_PRC/TB322FC:16/'
    'BQ2A.250610.001-BP2A.250605.031.A3/ZUXOS_1.5.10.259_260611_PRC:user/release-keys',
]
PART_SIZE_INIT_BOOT = 8388608   # GPT: 2048 x 4096
PART_SIZE_VBMETA = 65536        # GPT: 16 x 4096


def load_avbtool():
    spec = importlib.util.spec_from_file_location('avbtool_local', AVBTOOL)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def run(cmd, **kw):
    print('$', ' '.join(cmd), flush=True)
    r = subprocess.run(cmd, capture_output=True, text=True, **kw)
    sys.stdout.write(r.stdout)
    if r.returncode != 0:
        sys.stderr.write(r.stderr)
        raise SystemExit('FAILED: ' + ' '.join(cmd))
    return r.stdout


def strip_footer(path, out_path):
    """按 AVB footer 的 original_image_size 截断，返回 original_image_size。"""
    with open(path, 'rb') as f:
        f.seek(-64, os.SEEK_END)
        footer = f.read(64)
    magic, vmaj, vmin, original, vb_off, vb_size = struct.unpack_from('!4sLLQQQ', footer, 0)
    if magic != b'AVBf':
        raise SystemExit('%s: no AVB footer' % path)
    assert vb_off == original, (vb_off, original)
    with open(path, 'rb') as f:
        img = f.read(original)
    with open(out_path, 'wb') as f:
        f.write(img)
    print('  footer: original_image_size=%d vbmeta_off=%d vbmeta_size=%d -> %s'
          % (original, vb_off, vb_size, out_path))
    return original


def bootimg_ramdisk_size(path):
    with open(path, 'rb') as f:
        hdr = f.read(1600)
    assert hdr[:8] == b'ANDROID!', 'not an Android boot image'
    kernel_size, ramdisk_size = struct.unpack_from('<II', hdr, 8)
    return kernel_size, ramdisk_size


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default=os.path.join(REPO, 'out', 'android-root-20261119'))
    ap.add_argument('--stock-init-boot',
                    default=os.path.join(REPO, 'backup/official-rom-15.10.259/init_boot.img'))
    ap.add_argument('--base-vbmeta',
                    default=os.path.join(REPO, 'backup/official-rom-15.10.259/vbmeta.img'))
    ap.add_argument('--ksud', default=None, help='default: <out>/tools/ksud-x86_64-unknown-linux-musl')
    ap.add_argument('--ko', default=None, help='default: <out>/tools/aarch64_android15-6.6_kernelsu.ko')
    ap.add_argument('--kmi', default='android15-6.6')
    ap.add_argument('--key', default=None,
                    help='default: <out>/keys/testkey_rsa4096.pem (AOSP testkey, pubkey sha1 2597c218)')
    ap.add_argument('--flags', type=int, default=1, help='top-level vbmeta flags (1=hashtree disabled)')
    ap.add_argument('--rollback-index', type=int, default=0,
                    help='top-level vbmeta rollback index (stock 259 = 0; 不要乱填非零值)')
    args = ap.parse_args()

    out = os.path.abspath(args.out)
    work = os.path.join(out, 'work')
    tools = os.path.join(out, 'tools')
    ksud = args.ksud or os.path.join(tools, 'ksud-x86_64-unknown-linux-musl')
    ko = args.ko or os.path.join(tools, 'aarch64_android15-6.6_kernelsu.ko')
    key = args.key or os.path.join(out, 'keys', 'testkey_rsa4096.pem')

    for p in (args.stock_init_boot, args.base_vbmeta, ksud, ko, key):
        if not os.path.exists(p):
            raise SystemExit('missing input: ' + p)
    os.makedirs(work, exist_ok=True)

    # 0) 输入指纹
    print('== inputs')
    for p in (args.stock_init_boot, args.base_vbmeta, ksud, ko, key):
        h = odirect_sha(p)
        print('  %-64s %s' % (os.path.relpath(p, REPO), h))
    ks, rs = bootimg_ramdisk_size(args.stock_init_boot)
    print('  stock init_boot: kernel_size=%d ramdisk_size=%d (kernel=0 => ramdisk-only GKI init_boot)' % (ks, rs))

    # 1) ksud 打补丁
    print('== 1) ksud boot-patch (kmi %s)' % args.kmi)
    raw = os.path.join(work, 'init_boot_ksu_raw.img')
    if os.path.exists(raw):
        os.unlink(raw)
    run([ksud, 'boot-patch', '-b', args.stock_init_boot, '-m', ko, '--kmi', args.kmi,
         '-o', work, '--out-name', os.path.basename(raw)])
    ks2, rs2 = bootimg_ramdisk_size(raw)
    print('  patched ramdisk_size=%d (delta %+d)' % (rs2, rs2 - rs))

    # 2) 剥掉 ksud 留下的旧 footer
    print('== 2) strip stale AVB footer')
    img_only = os.path.join(work, 'init_boot_ksu_img_only.img')
    strip_footer(raw, img_only)

    # 3) 重加 hash footer（与 stock 同 salt / prop / Algorithm NONE）
    print('== 3) avbtool add_hash_footer (Algorithm NONE, 与 stock 一致)')
    final_init_boot = os.path.join(out, 'init_boot_ksu.img')
    shutil.copyfile(img_only, final_init_boot)
    run([sys.executable, AVBTOOL, 'add_hash_footer',
         '--image', final_init_boot,
         '--partition_size', str(PART_SIZE_INIT_BOOT),
         '--partition_name', 'init_boot',
         '--hash_algorithm', 'sha256',
         '--salt', INIT_BOOT_SALT,
         '--algorithm', 'NONE',
         '--rollback_index', '0',
         '--flags', '0'] +
        sum([['--prop', p] for p in INIT_BOOT_PROPS], []))

    # 4) 重建 vbmeta：只替换 init_boot 描述符
    print('== 4) rebuild vbmeta_a (key=%s, flags=%d)' %
          (os.path.basename(key), args.flags))
    avbmod = load_avbtool()
    avb = avbmod.Avb()
    _, _h0, base_descs, _ = avb._parse_image(avbmod.ImageHandler(args.base_vbmeta, read_only=True))
    _, _h1, new_descs, _ = avb._parse_image(avbmod.ImageHandler(final_init_boot, read_only=True))
    new_ib = [d for d in new_descs
              if isinstance(d, avbmod.AvbHashDescriptor) and d.partition_name == 'init_boot']
    if len(new_ib) != 1:
        raise SystemExit('expected exactly one init_boot hash descriptor in new image')
    idx = [i for i, d in enumerate(base_descs)
           if isinstance(d, avbmod.AvbHashDescriptor) and d.partition_name == 'init_boot']
    if len(idx) != 1:
        raise SystemExit('expected exactly one init_boot hash descriptor in base vbmeta')
    print('  base descriptors=%d, replacing idx %d: size %d -> %d, digest %s -> %s'
          % (len(base_descs), idx[0], base_descs[idx[0]].image_size, new_ib[0].image_size,
             base_descs[idx[0]].digest.hex()[:16], new_ib[0].digest.hex()[:16]))
    base_descs[idx[0]] = new_ib[0]
    blob = avb._generate_vbmeta_blob(
        'SHA256_RSA4096', key, None, base_descs,
        None, None,                      # chain_partitions_use_ab / do_not_use_ab
        args.rollback_index, args.flags, 0,
        None, None, None, None, None, None, None, None, None, None,
        0)
    final_vbmeta = os.path.join(out, 'vbmeta_a_root.img')
    with open(final_vbmeta, 'wb') as f:
        f.write(blob + b'\0' * (PART_SIZE_VBMETA - len(blob)))

    # 5) 自检
    print('== 5) self-check')
    chk = os.path.join(work, 'chk')
    os.makedirs(chk, exist_ok=True)
    chk_img = os.path.join(chk, 'init_boot.img')
    if os.path.lexists(chk_img):
        os.unlink(chk_img)
    os.symlink(final_init_boot, chk_img)
    # avbtool 会按 <partition_name>.img 在同目录找分区 -> 必须先做成 init_boot.img 再验
    run([sys.executable, AVBTOOL, 'verify_image', '--image', chk_img])
    digest = hashlib.sha256(bytes.fromhex(INIT_BOOT_SALT) +
                            open(final_init_boot, 'rb').read(new_ib[0].image_size)).hexdigest()
    print('  independent sha256(salt||img[:%d]) = %s' % (new_ib[0].image_size, digest))
    _, h2, descs2, _ = avb._parse_image(avbmod.ImageHandler(final_vbmeta, read_only=True))
    _, h3, base2, _ = avb._parse_image(avbmod.ImageHandler(args.base_vbmeta, read_only=True))
    raw_a = [d.encode() for d in base2]
    raw_b = [d.encode() for d in descs2]
    diff = [i for i in range(len(raw_a)) if raw_a[i] != raw_b[i]] if len(raw_a) == len(raw_b) else 'length-diff'
    print('  descriptors=%d differing indices=%s (expect [%d])' % (len(raw_b), diff, idx[0]))
    print('  top-level: flags=%d rollback=%d required_libavb=%d.%d'
          % (h2.flags, h2.rollback_index, h2.required_libavb_version_major,
             h2.required_libavb_version_minor))
    print(run([sys.executable, AVBTOOL, 'info_image', '--image', final_vbmeta]))
    if digest != new_ib[0].digest.hex():
        raise SystemExit('DIGEST MISMATCH')

    # 6) 全链核对目录（软链；avbtool verify_image --follow_chain_partitions 用）
    ver = os.path.join(out, 'verify')
    os.makedirs(ver, exist_ok=True)
    rom = os.path.join(REPO, 'backup', 'official-rom-15.10.259')
    parts = os.path.join(REPO, 'out', 'android-min-avb-20261118', 'parts')
    links = {
        'init_boot.img': final_init_boot,
        'vbmeta.img': final_vbmeta,
        'boot.img': os.path.join(rom, 'boot.img'),
        'recovery.img': os.path.join(rom, 'recovery.img'),
        'vbmeta_system.img': os.path.join(rom, 'vbmeta_system.img'),
        'dtbo.img': os.path.join(rom, 'dtbo.img'),
        'vendor_boot.img': os.path.join(rom, 'vendor_boot.img'),
        'pvmfw.img': os.path.join(rom, 'pvmfw.img'),
    }
    for n in ('odm', 'system_dlkm', 'vendor', 'vendor_dlkm', 'product', 'system', 'system_ext'):
        links[n + '.img'] = os.path.join(parts, n + '_a.img')
    for n, target in links.items():
        dst = os.path.join(ver, n)
        if os.path.lexists(dst):
            os.unlink(dst)
        if os.path.exists(target):
            os.symlink(target, dst)
        else:
            print('  (verify link skipped, missing target: %s)' % target)
    print('verify/ -> %s' % ver)

    print('\n== outputs')
    shipped = ['init_boot_ksu.img', 'vbmeta_a_root.img',
               'revert/init_boot_a_259stock.img', 'revert/vbmeta_a_259stock.img',
               'revert/vbmeta_a_flags1_selfsigned_20261118.img',
               'tools/ksud-x86_64-unknown-linux-musl',
               'tools/aarch64_android15-6.6_kernelsu.ko',
               'input/init_boot_stock259.img']
    with open(os.path.join(out, 'SHA256SUMS'), 'w') as f:
        for n in shipped:
            fp = os.path.join(out, n)
            if not os.path.exists(fp):
                print('  (skip missing %s)' % n)
                continue
            h = odirect_sha(fp)
            print('  %s  %s' % (h, n))
            f.write('%s  %s\n' % (h, n))
    print('SHA256SUMS -> %s' % os.path.join(out, 'SHA256SUMS'))


if __name__ == '__main__':
    main()
