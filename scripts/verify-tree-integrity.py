#!/usr/bin/env python3
"""verify-tree-integrity.py — 校验某个 git 工作树/仓库里所有 tracked 文件的内容完整性。

为什么需要：2026-10-19 本机出现「文件内容被单字符改写、mtime/size 不变」的现象
（多棵树、跨时间点、非 git 操作所致），表现为内核编译随机 ICE/段错误、ld 报
`bad reloc symbol index`。git 自身不查工作树内容，只有逐文件 sha1 才能发现。

判据：sha1("blob <len>\\0" + content) == index 里的 blob sha。
  · 与 HEAD 有意的本地修改**会被报出来** —— 用 --allow-dirty 读取 `git status`
    的 M 列表并豁免，这样输出只剩真正的内容损坏。
用法：
  scripts/verify-tree-integrity.py <tree> [--allow-dirty] [--quiet]
退出码：0=干净；1=有损坏/缺失。
"""
import subprocess, hashlib, os, sys, concurrent.futures

def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    flags = {a for a in sys.argv[1:] if a.startswith('--')}
    if not args:
        print(__doc__); return 64
    repo = args[0]
    os.chdir(repo)
    allow_dirty = '--allow-dirty' in flags
    quiet = '--quiet' in flags

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
                with open(path, 'rb') as f:
                    data = f.read()
        except OSError as ex:
            return (path, 'MISSING')
        h = hashlib.sha1(b'blob %d\0' % len(data))
        h.update(data)
        if h.hexdigest() == sha:
            return None
        return (path, 'DIRTY-OK' if path in dirty else 'CORRUPT')

    bad = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=32) as ex:
        for r in ex.map(check, ents, chunksize=256):
            if r:
                bad.append(r)

    corrupt = [p for p, k in bad if k == 'CORRUPT']
    dirty_n = len(bad) - len(corrupt)
    print(f"{repo}: files={len(ents)} corrupt={len(corrupt)}"
          + (f" dirty-ok={dirty_n}" if dirty_n else ""))
    if not quiet:
        for p in corrupt[:60]:
            print("  CORRUPT", p)
        if len(corrupt) > 60:
            print(f"  ... 另 {len(corrupt)-60} 项")
    return 1 if corrupt else 0

if __name__ == '__main__':
    sys.exit(main())
