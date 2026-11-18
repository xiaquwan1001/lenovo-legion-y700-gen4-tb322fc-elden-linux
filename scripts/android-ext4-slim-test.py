#!/usr/bin/env python3
"""android-ext4-slim-test.py — 在**副本**上删掉指定的 Android 分区子树，量出真实可回收块数。

用途：回答「去预装到底能省多少」而不必挂载（本机无 root）：用 debugfs 只读清单生成 rm/rmdir
命令（深→浅），再 `e2fsck -fy` 回收位图/块组，最后用 dumpe2fs 读 free blocks。

只在 --img 指定的**副本**上写；脚本拒绝在原包/parts 原件上运行（--i-know 跳过检查）。

用法：
  scripts/android-ext4-slim-test.py --img out/android-min-avb-20261118/exp/system-a-debloat-test.img \
      --inv out/android-min-avb-20261118/inv-system.tsv \
      --drop /system/preinstall /system/etc/AI --report out/android-min-avb-20261118/slim-test.txt
"""
import argparse
import os
import re
import subprocess
import sys
from collections import defaultdict


def dumpe2fs(img):
    r = subprocess.run(["dumpe2fs", "-h", img], capture_output=True, text=True)
    out = {}
    for ln in r.stdout.splitlines():
        m = re.match(r"(Block count|Free blocks|Inode count|Free inodes|Block size):\s+(\d+)", ln)
        if m:
            out[m.group(1)] = int(m.group(2))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--img", required=True)
    ap.add_argument("--inv", required=True)
    ap.add_argument("--drop", nargs="+", required=True)
    ap.add_argument("--report")
    ap.add_argument("--i-know", action="store_true")
    a = ap.parse_args()

    if not a.i_know and ("/parts/" in a.img or "/backup/" in a.img):
        raise SystemExit("拒绝在原件上跑（会删文件）；先 cp 一份到 exp/ 再加 --i-know")

    before = dumpe2fs(a.img)
    rows = []
    with open(a.inv) as f:
        next(f)
        for ln in f:
            t, mode, uid, gid, size, path = ln.rstrip("\n").split("\t")
            rows.append((t, int(size), path))

    drop = tuple(p.rstrip("/") for p in a.drop)
    files, dirs = [], []
    drop_bytes = 0
    for t, size, path in rows:
        if not path.startswith(drop):
            continue
        if t == "F":
            files.append(path)
            drop_bytes += size
        elif t == "L":
            files.append(path)         # 符号链接也 unlink
        elif t == "D":
            dirs.append(path)
    dirs.sort(key=lambda p: -p.count("/"))       # 深→浅
    print("[slim] 目标子树 %s：文件/链接 %d，目录 %d，清单内逻辑字节 %.2f MiB"
          % (",".join(drop), len(files), len(dirs), drop_bytes / 2 ** 20))

    cmds = ["rm %s" % p for p in files] + ["rmdir %s" % p for p in dirs]
    script = os.path.join(os.path.dirname(a.img), "debugfs-drop.txt")
    with open(script, "w") as f:
        f.write("\n".join(cmds) + "\n")
    r = subprocess.run(["debugfs", "-w", "-f", script, a.img], capture_output=True, text=True)
    err = [ln for ln in r.stdout.splitlines() if "File not found" in ln or "not a directory" in ln]
    print("[slim] debugfs 执行完毕（stderr %d 行，报错 %d 行）" % (len(r.stderr.splitlines()), len(err)))
    for ln in err[:5]:
        print("      " + ln)

    subprocess.run(["e2fsck", "-fy", a.img], capture_output=True, text=True)
    after = dumpe2fs(a.img)
    bs = before.get("Block size", 4096)
    freed = after["Free blocks"] - before["Free blocks"]
    lines = [
        "== ext4 去预装实测（副本） ==",
        "img=%s" % a.img,
        "drop=%s" % " ".join(drop),
        "block_size=%d" % bs,
        "block_count=%d" % before["Block count"],
        "free_blocks_before=%d (%.2f MiB)" % (before["Free blocks"], before["Free blocks"] * bs / 2 ** 20),
        "free_blocks_after=%d (%.2f MiB)" % (after["Free blocks"], after["Free blocks"] * bs / 2 ** 20),
        "freed_blocks=%d => %.2f MiB (%.2f GiB)" % (freed, freed * bs / 2 ** 20, freed * bs / 2 ** 30),
        "inodes_before_free=%d after_free=%d" % (before["Free inodes"], after["Free inodes"]),
        "清单逻辑字节=%.2f MiB（shared_blocks 去重前）" % (drop_bytes / 2 ** 20),
    ]
    print("\n".join(lines))
    if a.report:
        with open(a.report, "a") as f:
            f.write("\n".join(lines) + "\n\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
