#!/usr/bin/env python3
"""detect-memory-corruption.py — 找出「页缓存里的内容 ≠ 磁盘上的内容」的文件。

★ 为什么需要（2026-10-20 实测定性）：
  本机（PRIME Z790-P D4 / i7-14700KF / 无 ECC）出现「文件内容被单字符改写、
  mtime 与 size 不变」的现象。用 `dd iflag=direct`（绕过页缓存）复核后确认：
    · **磁盘上的字节是正确的**（与 git index / dpkg md5sums 逐字一致）
    · 错的是**内核页缓存里的副本**，`posix_fadvise(DONTNEED)` 丢弃后重读即恢复
  ⇒ 根因是**内存/CPU 侧位翻转**，不是磁盘损坏、不是文件系统、不是 git。
  后果：任何「读文件」的进程都可能拿到错字节 —— 编译器（cc1）读源码翻位 ⇒
  随机 ICE/段错误；链接器读 .o 翻位 ⇒ `bad reloc symbol index`。这正是
  2026-10-19/20 那串「构建随机崩」的真因。

判据（三读法，不需要 root）：
  1. buffered 读 → sha256
  2. posix_fadvise(DONTNEED) 丢页缓存 → buffered 再读 → sha256
  3. O_DIRECT 读（完全绕过页缓存）→ sha256
  · 三者一致                         ⇒ OK
  · 1≠2 或 1≠3，而 2==3              ⇒ **MEMORY**（页缓存被翻转，磁盘真值正确）
  · 2≠3 且 3 也不同于前次基线         ⇒ 需再判（可能磁盘真坏或持续翻转）
  · 与 --expect（dpkg/git 记录的哈希）比对可定位到底哪一层错

用法：
  scripts/detect-memory-corruption.py <路径…> [--min-size 256K] [--limit N] [--quiet]
  scripts/detect-memory-corruption.py --tree <git树> [--allow-dirty]
  scripts/detect-memory-corruption.py <文件> --expect <sha256|md5>:<值> …

退出码：0=全部一致；1=发现 MEMORY；2=发现 DISK（疑似磁盘真坏）；64=用法错误。

★ 用途：构建前后 mandatory 健康检查（见 scripts/kbuild-sanity.sh）。发现 MEMORY
  时不要「重写文件当修复」——重写同样经过内存，且可能覆盖掉本来正确的磁盘副本；
  正确动作 = 丢弃页缓存（本工具已做）或换机器/修硬件。
"""
import os
import sys
import hashlib
import argparse
import concurrent.futures
import subprocess

BLK = 4096

def _sha_chunks(fd, size):
    h = hashlib.sha256()
    off = 0
    buf = bytearray(BLK * 256)
    mv = memoryview(buf)
    while off < size:
        n = min(len(buf), size - off)
        got = os.preadv(fd, [mv[:n]], off)
        if got <= 0:
            break
        h.update(mv[:got])
        off += got
    return h.hexdigest()

def read_buffered(path):
    with open(path, 'rb') as f:
        return f.read()


def read_buffered_sha(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        while True:
            b = f.read(1 << 20)
            if not b:
                break
            h.update(b)
    return h.hexdigest()

def drop_cache(path):
    try:
        fd = os.open(path, os.O_RDONLY)
        try:
            os.posix_fadvise(fd, 0, 0, os.POSIX_FADV_DONTNEED)
        finally:
            os.close(fd)
    except OSError:
        pass

def read_odirect(path):
    """O_DIRECT 读全文（绕页缓存）。失败返回 None。"""
    odir = getattr(os, 'O_DIRECT', 0)
    if not odir:
        return None
    try:
        fd = os.open(path, os.O_RDONLY | odir)
    except OSError:
        return None
    try:
        size = os.fstat(fd).st_size
        out = bytearray()
        off = 0
        buf = bytearray(BLK * 256)
        mv = memoryview(buf)
        while off < size:
            n = min(len(buf), size - off)
            got = os.preadv(fd, [mv[:n]], off)
            if got <= 0:
                break
            out += mv[:got]
            off += got
        return bytes(out)
    except OSError:
        return None
    finally:
        os.close(fd)


def read_odirect_sha(path):
    """O_DIRECT 读（绕页缓存）。返回 sha256 或 None（不支持则 None）。"""
    odir = getattr(os, 'O_DIRECT', 0)
    if not odir:
        return None
    try:
        fd = os.open(path, os.O_RDONLY | odir)
    except OSError:
        return None
    try:
        size = os.fstat(fd).st_size
        return _sha_chunks(fd, size)
    except OSError:
        return None
    finally:
        os.close(fd)

def classify(path, expect_sha1=None):
    """expect_sha1 = git blob sha1（十六进制），给定时额外判「磁盘真值是否等于基线」。"""
    try:
        st = os.stat(path)
    except OSError:
        return (path, 'MISSING', {})
    if not os.path.isfile(path) or st.st_size == 0:
        return None
    try:
        a = read_buffered_sha(path)
        drop_cache(path)
        b = read_buffered_sha(path)
        c = read_odirect_sha(path)
    except OSError:
        return (path, 'IOERR', {})
    shas = {'first': a, 'after_drop': b, 'odirect': c}
    # 先判一致性（页缓存 vs 磁盘）
    if c is None:
        consistent = (a == b)
        disk_sha256 = b
    else:
        consistent = (a == b == c)
        disk_sha256 = c
    if not consistent:
        # 三读互不相同 = 扫描期间又被翻转（同一文件同一内容是内存不干净的强证据）
        if c is not None and b == c:
            return (path, 'MEMORY', shas)
        return (path, 'UNSTABLE', shas)
    # 一致 ⇒ 再与基线比（若给了基线）
    if expect_sha1:
        try:
            data = read_odirect(path) if c is not None else read_buffered(path)
        except OSError:
            return (path, 'IOERR', shas)
        real = hashlib.sha1(b'blob %d\0' % len(data) + data).hexdigest()
        if real != expect_sha1:
            return (path, 'DISK-BAD', dict(shas, expected=expect_sha1, actual=real))
    return None

def expand(paths, min_size):
    out = []
    for p in paths:
        if os.path.isdir(p):
            for root, dirs, files in os.walk(p):
                dirs[:] = [d for d in dirs if d not in ('.git',)]
                for f in files:
                    fp = os.path.join(root, f)
                    try:
                        if os.path.getsize(fp) >= min_size:
                            out.append(fp)
                    except OSError:
                        pass
        elif os.path.isfile(p):
            out.append(p)
    return out

def parse_size(s):
    s = s.strip().upper()
    mult = 1
    for suf, m in (('K', 1024), ('M', 1024**2), ('G', 1024**3)):
        if s.endswith(suf):
            mult, s = m, s[:-1]
            break
    return int(float(s) * mult)

def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument('paths', nargs='*')
    ap.add_argument('--min-size', default='256K')
    ap.add_argument('--limit', type=int, default=0)
    ap.add_argument('--quiet', action='store_true')
    ap.add_argument('--tree', default=None, help='用 git 树的 index 作为期望值')
    ap.add_argument('--allow-dirty', action='store_true')
    ap.add_argument('--workers', type=int, default=16)
    a = ap.parse_args()

    if a.tree:
        repo = a.tree
        raw = subprocess.run(['git', '-C', repo, 'ls-files', '-s', '-z'],
                             capture_output=True).stdout.split(b'\0')
        files = []
        for r in raw:
            if not r:
                continue
            meta, path = r.split(b'\t', 1)
            mode, sha, stage = meta.split()
            if stage != b'0' or mode == b'120000':
                continue
            files.append((os.path.join(repo, path.decode('utf-8', 'surrogateescape')),
                          sha.decode()))
        if a.limit:
            files = files[:a.limit]
        label = 'tree:' + repo
    else:
        if not a.paths:
            print(__doc__)
            return 64
        files = [(f, None) for f in expand(a.paths, parse_size(a.min_size))]
        if a.limit:
            files = files[:a.limit]
        label = ','.join(a.paths)

    results = []
    dirty = set()
    if a.allow_dirty and a.tree:
        out = subprocess.run(['git', '-C', a.tree, 'status', '--porcelain', '-z'],
                             capture_output=True).stdout.split(b'\0')
        for r in out:
            if len(r) > 3:
                dirty.add(os.path.join(a.tree, r[3:].decode('utf-8', 'surrogateescape')))

    def work(item):
        path, expect = item
        if path in dirty:
            return None
        return classify(path, expect)

    with concurrent.futures.ThreadPoolExecutor(max_workers=a.workers) as ex:
        for r in ex.map(work, files, chunksize=16):
            if r:
                results.append(r)

    mem = [r for r in results if r[1] in ('MEMORY', 'UNSTABLE')]
    disk = [r for r in results if r[1] == 'DISK-BAD']
    other = [r for r in results if r[1] in ('MISSING', 'IOERR')]

    print(f"{label}: scanned={len(files)} page_cache_corrupt={len(mem)} "
          f"disk_suspect={len(disk)} other={len(other)}")
    if not a.quiet:
        for p, k, s in mem[:40]:
            print(f"  MEMORY {p}")
            print(f"         first={s['first'][:16]} after_drop={s['after_drop'][:16]} "
                  f"odirect={s['odirect'][:16]}")
        if len(mem) > 40:
            print(f"  ... 另 {len(mem)-40} 项")
        for p, k, s in disk[:40]:
            print(f"  {k} {p}")
            if k == 'DISK-BAD':
                print(f"         expected={s.get('expected','')[:16]} actual={s.get('actual','')[:16]}")
    if mem:
        print("⇒ 判定：**内存/页缓存位翻转**（磁盘真值正确）。"
              "构建前请重跑；持续出现需修硬件（ECC/内存条/BIOS 内存参数）。")
        return 1
    if disk:
        print("⇒ 判定：**疑似磁盘真坏**（绕过页缓存后内容仍不一致）。")
        return 2
    return 0

if __name__ == '__main__':
    sys.exit(main())
