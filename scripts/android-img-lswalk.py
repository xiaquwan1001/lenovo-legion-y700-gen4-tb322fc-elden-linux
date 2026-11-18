#!/usr/bin/env python3
"""android-img-lswalk.py — 用 debugfs 只读递归列目录，输出 TSV（type/mode/uid/gid/size/path）。

为什么：本机不 root、不 loop mount；debugfs 纯读 ext4 镜像即可拿全量路径清单。
输入是镜像 + 若干根路径；不读文件内容。

用法:
  scripts/android-img-lswalk.py --img <img> --root /system/etc --root /system/app \
      --out out/<lane>/ls-system.tsv [--jobs 8] [--max-depth 6]
"""
import argparse, os, re, subprocess, sys
from concurrent.futures import ThreadPoolExecutor

LINE = re.compile(
    r"^\s*(?P<ino>\d+)\s+(?P<mode>[0-7]+)\s+\((?P<links>\d+)\)\s+(?P<uid>\d+)\s+(?P<gid>\d+)\s+"
    r"(?P<size>\d+)\s+\S+\s+\S+\s+(?P<name>.+?)\s*$")


def ls(img, path, timeout=180):
    r = subprocess.run(["debugfs", "-R", "ls -l %s" % path, img],
                       capture_output=True, text=True, timeout=timeout,
                       errors="replace")
    rows = []
    for ln in r.stdout.splitlines():
        m = LINE.match(ln.rstrip())
        if not m:
            continue
        name = re.sub(r"\s+\(\d+\)$", "", m.group("name").strip())
        if name in (".", ".."):
            continue
        rows.append((int(m.group("ino")), m.group("mode"), int(m.group("uid")),
                     int(m.group("gid")), int(m.group("size")), name))
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--img", required=True)
    ap.add_argument("--root", action="append", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--jobs", type=int, default=8)
    ap.add_argument("--max-depth", type=int, default=8)
    a = ap.parse_args()

    roots = [r.rstrip("/") or "/" for r in a.root]
    seen = {r for r in roots}
    frontier = list(roots)
    out = []
    depth = 0
    while frontier and depth <= a.max_depth:
        depth += 1
        with ThreadPoolExecutor(max_workers=a.jobs) as ex:
            results = list(ex.map(lambda p: (p, ls(a.img, p)), frontier))
        nxt = []
        for p, rows in results:
            for ino, mode, uid, gid, size, name in rows:
                path = (p.rstrip("/") + "/" + name) if p != "/" else "/" + name
                out.append((mode, uid, gid, size, path))
                if mode.startswith("4") and path not in seen:
                    seen.add(path)
                    nxt.append(path)
        frontier = nxt
    out.sort(key=lambda r: r[4])
    os.makedirs(os.path.dirname(a.out) or ".", exist_ok=True)
    with open(a.out, "w") as f:
        for mode, uid, gid, size, path in out:
            f.write("D" if mode.startswith("4") else ("F" if mode.startswith("10") else "L"))
            f.write("\t%s\t%d\t%d\t%d\t%s\n" % (mode, uid, gid, size, path))
    print("rows=%d out=%s" % (len(out), a.out), file=sys.stderr)


if __name__ == "__main__":
    main()
