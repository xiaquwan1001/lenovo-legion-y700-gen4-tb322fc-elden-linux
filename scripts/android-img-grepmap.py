#!/usr/bin/env python3
"""android-img-grepmap.py — 在 ext4 镜像里按字面串定位「哪个文件含有它」，不需要 root/loop。

做法：一遍 `grep -abo` 得到字节偏移 → 换算成 fs 块号 → `debugfs icheck` 得 inode →
`debugfs ncheck` 得路径。命中落在目录块/元数据里的会标成 <dir> 或 ?，不影响判读。

用法:
  scripts/android-img-grepmap.py --img out/.../system_a.img --pattern-file /tmp/pat.txt \
      [--out out/<lane>/grepmap.tsv] [--max-hits 4000]

--pattern-file 每行一个固定串（会被 re.escape 后合成一个 alternation 正则，单遍扫描）。
输出列：pattern <TAB> byte_offset <TAB> path
"""
import argparse, os, re, subprocess, sys, tempfile


def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, errors="replace", **kw)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--img", required=True)
    ap.add_argument("--pattern-file", required=True)
    ap.add_argument("--out")
    ap.add_argument("--max-hits", type=int, default=4000)
    a = ap.parse_args()

    pats = [l.rstrip("\n") for l in open(a.pattern_file) if l.strip()]
    rx = "|".join(re.escape(p) for p in pats)
    r = run(["grep", "-abo", "-E", "-m", str(a.max_hits), rx, a.img],
            env=dict(os.environ, LC_ALL="C"), timeout=1800)
    hits = []
    for ln in r.stdout.splitlines():
        off, rest = ln.split(":", 1)
        hits.append((int(off), rest))
    if not hits:
        print("no hits", file=sys.stderr)
        return
    blk_of = lambda off: off // 4096          # 本仓所有 Android 镜像块大小都是 4096
    blocks = sorted({blk_of(o) for o, _ in hits})
    cmds = "".join("icheck %d\n" % b for b in blocks)
    with tempfile.NamedTemporaryFile("w", delete=False) as f:
        f.write(cmds); cf = f.name
    ic = run(["debugfs", "-f", cf, a.img], timeout=1800)
    os.unlink(cf)
    blk2ino = {}
    for ln in ic.stdout.splitlines():
        p = ln.split()
        if len(p) == 2 and p[0].isdigit() and p[1].isdigit():
            blk2ino[int(p[0])] = int(p[1])
    inos = sorted(set(blk2ino.values()))
    cmds = "".join("ncheck %d\n" % i for i in inos)
    with tempfile.NamedTemporaryFile("w", delete=False) as f:
        f.write(cmds); cf = f.name
    nc = run(["debugfs", "-f", cf, a.img], timeout=1800)
    os.unlink(cf)
    ino2path = {}
    for ln in nc.stdout.splitlines():
        p = ln.split(None, 1)
        if len(p) == 2 and p[0].isdigit():
            ino2path[int(p[0])] = p[1].strip()

    out = []
    for off, pat in hits:
        ino = blk2ino.get(blk_of(off))
        out.append((pat, off, ino2path.get(ino, "?") if ino else "?"))
    if a.out:
        os.makedirs(os.path.dirname(a.out) or ".", exist_ok=True)
        with open(a.out, "w") as f:
            for p, o, path in out:
                f.write("%s\t%d\t%s\n" % (p, o, path))
    print("hits=%d blocks=%d inodes=%d out=%s" % (len(out), len(blocks), len(inos), a.out or "-"),
          file=sys.stderr)


if __name__ == "__main__":
    main()
