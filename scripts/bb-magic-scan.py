#!/usr/bin/env python3
"""bb-magic-scan.py — DDR 窗口魔数扫描（0xA5A5A5A5 连续段）。

为什么：整页 0xFF 判据会被 splash/图像/日志数据污染（2026-11-03 15:1x 实测 19%–37%），
魔数是「在整窗任意位置出现 ≥N 个连续 0xA5A5A5A5 字」——图像/日志数据造不出来。

用法：scripts/bb-magic-scan.py [--pa 0xE3F00000 ...] [--min 64] [--target root@192.168.7.1]
"""
import argparse, re, subprocess, sys, tempfile, os

PAT = b"\xa5\xa5\xa5\xa5"

def read_window(target, pa, window=208):
    tmp = tempfile.mktemp(suffix=".bin")
    subprocess.run([os.path.join(os.path.dirname(os.path.abspath(__file__)), "blackbox.py"),
                    "raw", "--pa", pa, tmp],
                   check=True, capture_output=True)
    d = open(tmp, "rb").read(); os.unlink(tmp)
    return d

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pa", action="append")
    ap.add_argument("--min", type=int, default=64)
    ap.add_argument("--target", default="root@192.168.7.1")
    a = ap.parse_args()
    pas = a.pa or ["0xE3F00000", "0x84A00000", "0x9C300000", "0x89300000"]
    verdict = 0
    for pa in pas:
        d = read_window(a.target, pa)
        runs = [m.start() for m in re.finditer(b"(?:" + re.escape(PAT) + b"){%d,}" % a.min, d)]
        words = d.count(PAT)
        hit = bool(runs)
        verdict |= 1 if hit else 0
        print("%-12s magic_words=%-6d runs>=%d=%-3d %s %s" % (
            pa, words, a.min, len(runs), "EXECUTED" if hit else "no-magic",
            ("at " + ", ".join(hex(x) for x in runs[:3])) if hit else ""))
    return 0 if verdict else 1

if __name__ == "__main__":
    sys.exit(main())
