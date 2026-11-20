#!/usr/bin/env python3
"""odirect-sha.py — 绕过页缓存（O_DIRECT）算 sha256 的硬门工具。

背景（reports/android-v3-bringup-packet-20261120.md §0.9 / AGENTS 硬规则 12）：
  本机页缓存污染曾使同一文件 buffered 连读 5 次「稳定但错」（v1 件读成 637a9965…，
  O_DIRECT = e3d0d26f… 才对）⇒ 旧「双 sha256 硬门」抓不到，必须 O_DIRECT 直读。

用法：
  odirect-sha.py <file> [<file>...]     # 逐件输出 TSV: path<TAB>bytes<TAB>sha256
  odirect-sha.py --compare <file> [...] # buffered + O_DIRECT 各算一遍；不一致 rc=1
  odirect-sha.py --selftest             # 自建 ≥4 MiB 临时文件断言两口径一致
O_DIRECT 不可用（如某些 tmpfs）时：退回 buffered 并在 stderr 打 WARN。
"""
import sys, os, hashlib, mmap, argparse

CHUNK = 16 * 1024 * 1024  # 16 MiB，4096 对齐


def sha_buffered(path):
    h = hashlib.sha256()
    total = 0
    with open(path, "rb", buffering=0) as f:
        while True:
            b = f.read(CHUNK)
            if not b:
                break
            h.update(b)
            total += len(b)
    return h.hexdigest(), total


def sha_odirect(path):
    """O_DIRECT 分块读 sha256。
    返回 (sha_hex, nbytes, odirect_ok, node_size)。
    缓冲区用匿名 mmap 分配（页对齐）；每次读整块（长度对齐），EOF 处返回短块、
    只哈希实际读到的字节；文件偏移 = os.lseek 起始 0 + 累计读取量。"""
    h = hashlib.sha256()
    try:
        fd = os.open(path, os.O_RDONLY | os.O_DIRECT)
    except OSError as e:
        sys.stderr.write(f"WARN odirect-sha: {path} O_DIRECT 不可用（{e}），退回 buffered\n")
        sha, n = sha_buffered(path)
        return sha, n, False, os.path.getsize(path)
    try:
        buf = mmap.mmap(-1, CHUNK)
        view = memoryview(buf)
        try:
            os.lseek(fd, 0, os.SEEK_SET)
            total = 0
            while True:
                n = os.read(fd, CHUNK)
                if not n:
                    break
                h.update(n)
                total += len(n)
            node_size = os.fstat(fd).st_size
        finally:
            view.release()
            buf.close()
    finally:
        os.close(fd)
    return h.hexdigest(), total, True, node_size


def selftest():
    """自建 ≥4 MiB 临时文件：
    A) 两口径 sha 一致且等于内存内 hashlib 参考值；
    B) 人为 fadvise(DONTNEED) + 缓存干扰（写另一文件并污染性读回）后复测，断言不误报。"""
    import tempfile, shutil, posix
    size = 5 * 1024 * 1024 + 12345  # 非块对齐尾
    data = os.urandom(size)
    ref = hashlib.sha256(data).hexdigest()
    tmpdir = tempfile.mkdtemp(prefix="odirect-selftest-")
    try:
        p = os.path.join(tmpdir, "a.bin")
        decoy = os.path.join(tmpdir, "decoy.bin")
        with open(p, "wb") as f:
            f.write(data)
            f.flush()
            os.fsync(f.fileno())
        with open(decoy, "wb") as f:
            f.write(os.urandom(size))
            f.flush()
            os.fsync(f.fileno())

        osha, on, ok, _ = sha_odirect(p)
        assert ok, "自测文件系统不支持 O_DIRECT，selftest 环境不合格"
        assert on == size, f"字节数 {on} != {size}"
        assert osha == ref, f"O_DIRECT sha 与参考不符: {osha} != {ref}"
        bsha, bn = sha_buffered(p)
        assert bsha == ref and bn == size, "buffered sha 与参考不符"

        # 干扰场景：把 decoy 灌进页缓存、对 a.bin fadvise(DONTNEED)，再各测一遍
        fd = os.open(decoy, os.O_RDONLY)
        os.read(fd, CHUNK)
        os.close(fd)
        fd = os.open(p, os.O_RDONLY)
        posix.posix_fadvise(fd, 0, 0, posix.POSIX_FADV_DONTNEED)
        os.close(fd)
        osha2, _, _, _ = sha_odirect(p)
        bsha2, _ = sha_buffered(p)
        assert osha2 == ref, "干扰后 O_DIRECT sha 漂移（误报）"
        assert bsha2 == ref, "干扰后 buffered sha 漂移（本例应无污染，若漂移说明自测环境本身不稳）"
        print(f"selftest OK: size={size} ref={ref[:16]}… odirect=buffered=ref（含 fadvise 干扰复测）")
        return 0
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--compare", action="store_true",
                    help="同时算 buffered 与 O_DIRECT，报差异（不一致 rc=1）")
    ap.add_argument("--tsv", action="store_true", help="同默认 TSV 输出")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("files", nargs="*")
    a = ap.parse_args()

    if a.selftest:
        sys.exit(selftest())
    if not a.files:
        ap.error("需要至少一个文件（或 --selftest）")

    rc = 0
    for p in a.files:
        sha, n, ok, node = sha_odirect(p)
        if a.compare:
            bsha, bn = sha_buffered(p)
            same = "SAME" if bsha == sha else "DIFF"
            mode = "odirect" if ok else "BUFFERED-FALLBACK"
            print(f"{same}\t{p}\tbytes={n}\tbuffered={bsha}\todirect={sha}\tmode={mode}\tnode_size={node}")
            if bsha != sha:
                rc = 1
        else:
            print(f"{p}\t{n}\t{sha}")
    sys.exit(rc)


if __name__ == "__main__":
    main()
