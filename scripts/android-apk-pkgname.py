#!/usr/bin/env python3
"""android-apk-pkgname.py — 从 apk 里读 package 名（纯主机侧，无 aapt/jadx 依赖）。

为什么需要它：裁 launcher.db 的默认布局必须按「包名」删行；本机没有 aapt/aapt2/apkanalyzer，
而目录名（ZuiCamera）≠ 包名（com.zui.camera）。本脚本自己解二进制 AndroidManifest.xml
（AXML）根元素 <manifest package="...">，只用标准库。

用法：
  scripts/android-apk-pkgname.py <a.apk> [b.apk ...]     # 每行: <pkg>\t<path>
  scripts/android-apk-pkgname.py --dir <目录>...          # 递归找 *.apk
退出码 0 = 全部解析成功；1 = 有失败（失败行打印到 stderr，仍输出已成功的）。
"""
import os
import struct
import sys
import zipfile

RES_XML_TYPE, RES_STRING_POOL_TYPE, RES_XML_START_ELEMENT_TYPE = 0x0003, 0x0001, 0x0102
UTF8_FLAG = 0x100


class BadAXML(Exception):
    pass


def _read_pool(data, off):
    typ, hsz, sz = struct.unpack_from('<HHI', data, off)
    if typ != RES_STRING_POOL_TYPE:
        raise BadAXML('chunk @%d type 0x%04x != string pool' % (off, typ))
    count, style_count, flags, strings_start, _styles_start = struct.unpack_from('<IIIII', data, off + 8)
    utf8 = bool(flags & UTF8_FLAG)
    base = off + strings_start
    out = []
    for i in range(count):
        o = struct.unpack_from('<I', data, off + 28 + 4 * i)[0]
        p = base + o
        try:
            if utf8:
                n = data[p]
                p += 1
                if n & 0x80:
                    n = ((n & 0x7f) << 8) | data[p]
                    p += 1
                n2 = data[p]
                p += 1
                if n2 & 0x80:
                    p += 1
                out.append(data[p:p + n].decode('utf-8', 'replace'))
            else:
                n = struct.unpack_from('<H', data, p)[0]
                p += 2
                if n & 0x8000:
                    n = ((n & 0x7fff) << 16) | struct.unpack_from('<H', data, p)[0]
                    p += 2
                out.append(data[p:p + 2 * n].decode('utf-16-le', 'replace'))
        except (IndexError, struct.error):
            out.append('')
    return out


def pkgname_of_manifest(data):
    if len(data) < 8 or struct.unpack_from('<H', data, 0)[0] != RES_XML_TYPE:
        raise BadAXML('not axml')
    off = 8  # ResXMLTree header = chunk header (8 B)
    strings = None
    while off + 8 <= len(data):
        typ, hsz, sz = struct.unpack_from('<HHI', data, off)
        if sz < 8:
            raise BadAXML('bad chunk size')
        if typ == RES_STRING_POOL_TYPE and strings is None:
            strings = _read_pool(data, off)
        elif typ == RES_XML_START_ELEMENT_TYPE:
            if strings is None:
                raise BadAXML('start element before string pool')
            name_idx = struct.unpack_from('<I', data, off + 20)[0]
            attr_start, attr_size, attr_count = struct.unpack_from('<HHH', data, off + 24)
            if name_idx >= len(strings) or strings[name_idx] != 'manifest':
                raise BadAXML('first element is %r, not manifest'
                              % (strings[name_idx] if name_idx < len(strings) else None))
            abase = off + 16 + attr_start
            for j in range(attr_count):
                a = abase + j * attr_size
                aname = struct.unpack_from('<I', data, a + 4)[0]
                if aname >= len(strings) or strings[aname] != 'package':
                    continue
                raw = struct.unpack_from('<I', data, a + 8)[0]
                dtype = data[a + 15]
                adata = struct.unpack_from('<I', data, a + 16)[0]
                if raw:
                    return strings[raw]
                if dtype == 0x03 and adata < len(strings):
                    return strings[adata]
                raise BadAXML('package attr has no string value')
            raise BadAXML('manifest has no package attr')
        off += sz
    raise BadAXML('no start element')


def pkgname_of_apk(path):
    with zipfile.ZipFile(path) as z:
        return pkgname_of_manifest(z.read('AndroidManifest.xml'))


def main(argv):
    args = argv[1:]
    if not args or args[0] in ('-h', '--help'):
        print(__doc__.strip())
        return 2
    targets = []
    if args[0] == '--dir':
        for d in args[1:]:
            for root, _dirs, files in os.walk(d):
                targets += [os.path.join(root, f) for f in files if f.endswith('.apk')]
    else:
        targets = args
    bad = 0
    for p in sorted(targets):
        try:
            print('%s\t%s' % (pkgname_of_apk(p), p))
        except Exception as e:  # noqa: BLE001 — 逐件容错，坏一件不中断整批
            bad += 1
            print('FAIL %s: %s' % (p, e), file=sys.stderr)
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))