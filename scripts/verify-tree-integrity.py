#!/usr/bin/env python3
"""verify-tree-integrity.py — 校验某个 git 工作树/仓库里所有 tracked 文件的内容完整性。

为什么需要：2026-10-19 起本机出现「文件内容被单字符改写、mtime/size 不变」的现象
（多棵树、跨时间点、非 git 操作所致），表现为内核编译随机 ICE/段错误、ld 报
`bad reloc symbol index`。git 自身不查工作树内容，只有逐文件 sha1 才能发现。

★ 2026-10-20 关键修正：**mismatch ≠ 磁盘坏了**。
  实测（build/m1-73）：4/4 报 corrupt 的文件，`dd iflag=direct` 读到的是**正确字节**，
  只有普通读（经页缓存）得到错字节；对同一文件 `posix_fadvise(DONTNEED)` 丢弃页缓存后
  立刻重读即恢复。⇒ 真值是「**内存/页缓存里的副本被翻转**」，磁盘内容完好。
  若不做这层区分，会把内存故障记成「文件损坏」，进而用「重写文件」当修复手段
  （写回的是同样的错字节，还会顺手覆盖掉本来是好的磁盘副本）。

判据：sha1("blob <len>\\0" + content) == index 里的 blob sha，且
  · 与 HEAD 有意的本地修改用 --allow-dirty 豁免（读 `git status` 的 M 列表）；
  · 首次 mismatch 后**丢弃页缓存重读一次**（fadvise DONTNEED，不需 root）：
      - 重读变正确 ⇒ 记 CACHE（页缓存污染，磁盘真值 OK）
      - 重读仍错   ⇒ 再用 O_DIRECT 绕过页缓存复核：正确 ⇒ CACHE；仍错 ⇒ CORRUPT（磁盘真坏）

用法：
  scripts/verify-tree-integrity.py <tree> [--allow-dirty] [--quiet] [--no-cache-retry]
退出码：0=磁盘真值全部正确（CACHE 不算失败）；1=有真损坏/缺失。
"""
import subprocess, hashlib, os, sys, concurrent.futures

def sha_of(data):
    h = hashlib.sha1(b'blob %d\0' % len(data))
    h.update(data)
    return h.hexdigest()

def read_buffered(path):
    with open(path, 'rb') as f:
        return f.read()

def drop_cache(path):
    """丢弃该文件干净的页缓存（不需 root）。"""
    try:
        fd = os.open(path, os.O_RDONLY)
        try:
            os.posix_fadvise(fd, 0, 0, os.POSIX_FADV_DONTNEED)
        finally:
            os.close(fd)
    except OSError:
        pass

def read_odirect(path):
    """用 O_DIRECT 绕过页缓存读全文；失败返回 None（回退到普通读）。"""
    try:
        fd = os.open(path, os.O_RDONLY | getattr(os, 'O_DIRECT', 0))
    except OSError:
        return None
    try:
        size = os.fstat(fd).st_size
        if size == 0:
            return b''
        chunks, off = [], 0
        blk = 4096
        buf = bytearray(blk * 64)
        mv = memoryview(buf)
        aligned = (ctypes_size(buf) // blk) * blk
        while off < size:
            n = min(aligned, size - off)
            got = os.readv(fd, [mv[:n]]) if hasattr(os, 'readv') else os.read(fd, n)
            if not got:
                break
            chunks.append(bytes(got))
            off += len(got)
        return b''.join(chunks)
    except OSError:
        return None
    finally:
        os.close(fd)

def ctypes_size(buf):
    return len(buf) - (len(buf) % 4096)

def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    flags = {a for a in sys.argv[1:] if a.startswith('--')}
    if not args:
        print(__doc__); return 64
    repo = args[0]
    os.chdir(repo)
    allow_dirty = '--allow-dirty' in flags
    quiet = '--quiet' in flags
    cache_retry = '--no-cache-retry' not in flags

    dirty = set()
    if allow_dirty:
        out = subprocess.run(['git', 'status', '--porcelain', '-z'],
                             capture_output=True).stdout.split(b'\0')
        for r in out:
            if len(r) > 3:
                dirty.add(r[3:].decode('utf-8', 'surrogateescape'))

    raw = subprocess.run(['git', 'ls-files', '-s', '-z'],
                         capture_output=True).stdout.split(b'\0')
    ents = []
    for r in raw:
        if not r:
            continue
        meta, path = r.split(b'\t', 1)
        mode, sha, stage = meta.split()
        if stage != b'0':
            continue
        ents.append((mode.decode(), sha.decode(), path.decode('utf-8', 'surrogateescape')))

    def check(e):
        mode, sha, path = e
        try:
            if mode == '120000':
                data = os.readlink(path).encode()
            else:
                data = read_buffered(path)
        except OSError:
            return (path, 'MISSING', None)
        if sha_of(data) == sha:
            return None
        # mismatch：先判「有意修改」，再判「缓存 vs 磁盘真值」
        if path in dirty:
            return (path, 'DIRTY-OK', None)
        if cache_retry:
            drop_cache(path)
            try:
                again = read_buffered(path)
            except OSError:
                return (path, 'MISSING', None)
            if sha_of(again) == sha:
                return (path, 'CACHE', None)
            od = read_odirect(path)
            if od is not None:
                if sha_of(od) == sha:
                    return (path, 'CACHE', None)
                # 绕过页缓存仍错 ⇒ 磁盘真坏
                return (path, 'CORRUPT', None)
        return (path, 'CORRUPT', None)

    bad = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=32) as ex:
        for r in ex.map(check, ents, chunksize=64):
            if r:
                bad.append(r)

    corrupt = [p for p, k, _ in bad if k == 'CORRUPT']
    cache = [p for p, k, _ in bad if k == 'CACHE']
    dirty_n = len([1 for _, k, _ in bad if k == 'DIRTY-OK'])
    missing = [p for p, k, _ in bad if k == 'MISSING']

    line = f"{repo}: files={len(ents)} corrupt={len(corrupt)}"
    if cache:
        line += f" cache={len(cache)}"
    if dirty_n:
        line += f" dirty-ok={dirty_n}"
    if missing:
        line += f" missing={len(missing)}"
    print(line)
    if not quiet:
        for p in corrupt[:60]:
            print("  CORRUPT", p)
        if len(corrupt) > 60:
            print(f"  ... 另 {len(corrupt)-60} 项")
        for p in cache[:20]:
            print("  CACHE  ", p, "（页缓存污染，磁盘真值正确）")
        if len(cache) > 20:
            print(f"  ... 另 {len(cache)-20} 项 CACHE")
        for p in missing[:20]:
            print("  MISSING", p)
    return 1 if (corrupt or missing) else 0

if __name__ == '__main__':
    sys.exit(main())
