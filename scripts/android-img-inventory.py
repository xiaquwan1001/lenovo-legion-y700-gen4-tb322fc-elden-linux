#!/usr/bin/env python3
"""android-img-inventory.py — 只读遍历 Android ext4 分区镜像，输出 TSV 清单（路径/类型/权限/大小）。

为什么用 debugfs 而不是挂载：本机不 root、镜像带 hashtree/FEC 尾巴、部分件 e2fsck 有警告；
debugfs 纯读、不需要 loop 设备，也不会碰 source 包。

用法：
  scripts/android-img-inventory.py --img out/android-min-avb-20261118/parts/system_a.img \
      --out out/android-min-avb-20261118/inv-system.tsv [--max-depth 6] [--jobs 4]

输出列：type(F=file,D=dir,L=symlink)  mode  uid  gid  size  path
附带的 --summary 会在 stderr 打印：按目录聚合的体积 Top、按类型统计、最大文件 Top。
"""
import argparse
import os
import re
import subprocess
import sys
from collections import defaultdict

LINE = re.compile(
    r"^\s*(?P<ino>\d+)\s+(?P<mode>[0-7]+)\s+\((?P<links>\d+)\)\s+(?P<uid>\d+)\s+(?P<gid>\d+)\s+"
    r"(?P<size>\d+)\s+\S+\s+\S+\s+(?P<name>.+?)\s*$")


def ls(img, path):
    # debugfs -R "ls -l <dir>"；注意路径里若有空格需引号，Android 镜像里正常没有
    cmd = ["debugfs", "-R", "ls -l %s" % path, img]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    except subprocess.TimeoutExpired:
        return []
    out = []
    for ln in r.stdout.splitlines():
        ln = ln.rstrip()
        if not ln or ln.startswith("debugfs"):
            continue
        m = LINE.match(ln)
        if not m:
            continue
        name = m.group("name").strip()
        # debugfs 把 (12)/(20) 这类 htree 标记放在名字后
        name = re.sub(r"\s+\(\d+\)$", "", name)
        if name in (".", ".."):
            continue
        out.append(dict(ino=int(m.group("ino")), mode=m.group("mode"), uid=m.group("uid"),
                        gid=m.group("gid"), size=int(m.group("size")), name=name))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--img", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--max-depth", type=int, default=8)
    ap.add_argument("--summary", action="store_true")
    a = ap.parse_args()

    rows = []
    queue = [("", "/")]
    seen = set()
    while queue:
        rel, path = queue.pop(0)
        if path in seen:
            continue
        seen.add(path)
        for e in ls(a.img, path):
            p = path.rstrip("/") + "/" + e["name"]
            mode = int(e["mode"], 8)
            typ = "D" if (mode & 0o170000) == 0o040000 else (
                "L" if (mode & 0o170000) == 0o120000 else "F")
            rows.append((typ, e["mode"], e["uid"], e["gid"], e["size"], p))
            if typ == "D" and rel.count("/") < a.max_depth:
                queue.append((rel + "/x", p))

    os.makedirs(os.path.dirname(a.out) or ".", exist_ok=True)
    with open(a.out, "w") as f:
        f.write("type\tmode\tuid\tgid\tsize\tpath\n")
        for r in rows:
            f.write("%s\t%s\t%s\t%s\t%d\t%s\n" % r)

    nfile = sum(1 for r in rows if r[0] == "F")
    nlink = sum(1 for r in rows if r[0] == "L")
    ndir = sum(1 for r in rows if r[0] == "D")
    total = sum(r[4] for r in rows if r[0] == "F")
    print("[inv] %-24s files=%d dirs=%d links=%d  bytes=%d (%.2f MiB) -> %s"
          % (os.path.basename(a.img), nfile, ndir, nlink, total, total / 2 ** 20, a.out))

    if a.summary:
        agg = defaultdict(int)
        for typ, _m, _u, _g, size, p in rows:
            if typ != "F":
                continue
            parts = p.strip("/").split("/")
            if len(parts) >= 2:
                key = "/" + "/".join(parts[:2])
            else:
                key = "/" + "/".join(parts)
            agg[key] += size
        print("[inv] Top 25 dirs (2 levels):")
        for k, v in sorted(agg.items(), key=lambda kv: -kv[1])[:25]:
            print("      %10.2f MiB  %s" % (v / 2 ** 20, k))
        print("[inv] Top 20 files:")
        for typ, _m, _u, _g, size, p in sorted([r for r in rows if r[0] == "F"],
                                              key=lambda r: -r[4])[:20]:
            print("      %10.2f MiB  %s" % (size / 2 ** 20, p))
    return 0


if __name__ == "__main__":
    sys.exit(main())
