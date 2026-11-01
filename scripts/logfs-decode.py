#!/usr/bin/env python3
"""logfs-decode.py — 解析 `logfs` 分区（8 MiB = 10 × 64 KiB 环形 ABL 日志）。

## 为什么需要它

历史脚本 `scripts/abl-log.sh` 只读**第 1 段**，等于只保留最近一次启动；实测（2026-11-01，
`reports/uefi-observability-pivot-20261101.md` §1.1）该分区是 **10 段 64 KiB 环形**，
每次启动写一段，第 11 次启动才覆盖最早那段 ⇒ 「上一发载荷死在哪」的 ABL 记录其实还在盘上。

## 用法

    scripts/logfs-decode.py FILE                 # 每段一行摘要（推荐）
    scripts/logfs-decode.py FILE --segment 3     # 打印第 3 段的完整可读文本
    scripts/logfs-decode.py FILE --tsv           # 机器可读（一启动一行）
    scripts/logfs-decode.py /dev/stdin < FILE    # 配合 ssh dd 管道

关键字段（Qualcomm ABL / XBL 日志格式）：

    QC_IMAGE_VERSION_STRING=...        段首，标记一段的开头
    PM: Reset by <SRC>                 复位来源（PSHOLD / PMIC / …）
    PM: Reset Type: Hard Reset|Shutdown
    PON by ...                         开机原因（SYSOK / PWR key DEB / …）
    Booting from slot (_a|_b)          ABL 实际启动的槽
    Start EBS [n]                      UEFI Boot Services 起点（正常 ~13400，fastboot 模式 ~4085）
    HW Wdog Setting from PCD : ...     硬件看门狗是否武装

判读要点：
  * 「fastboot 模式段」（`Start EBS [~4085]`）后面紧跟的那一段，`PM: Reset by` /
    `PM: Reset Type` 就是**载荷失败后那次复位**的性质 ⇒ 区分「异常被 XBL 接住」与
    「PMIC/硬件 wdog 直接拉 PS_HOLD」。
  * `Booting from slot` 决定「回落到了哪个槽」：(_a)=stock Android，(_b)=我们的 Linux。
"""
import argparse
import re
import sys

SEG = 64 * 1024
FIELDS = [
    ("qcver", re.compile(r"QC_IMAGE_VERSION_STRING=([^\s\x00]+)")),
    ("reset_by", re.compile(r"PM: Reset by ([^\s\x00]+)")),
    ("reset_type", re.compile(r"PM: Reset Type: ([^\r\n\x00]+)")),
    ("pon", re.compile(r"PON by ([^\r\n\x00]+)")),
    ("slot", re.compile(r"Booting from slot \((_[ab])\)")),
    ("start_ebs", re.compile(r"Start EBS \[(\d+)\]")),
    ("wdog", re.compile(r"HW Wdog Setting from PCD\s*:\s*(\w+)")),
]
ERR = re.compile(r"(ASSERT|Synchronous Exception|Exception|Failed to|ERROR|Panic|panic|Watchdog|Wdog)",
                 re.IGNORECASE)


def decode_segment(raw):
    # 段内是「文本块 + NUL 填充」交替：按 NUL 切开、丢掉空块，比 NUL→空格更可读
    chunks = [c.decode("latin-1") for c in raw.split(b"\x00") if c.strip()]
    txt = "\n".join(chunks)
    out = {}
    for name, rx in FIELDS:
        m = rx.search(txt)
        out[name] = m.group(1).strip() if m else ""
    out["errors"] = [ln.strip() for ln in txt.splitlines() if ERR.search(ln)]
    out["text"] = txt
    out["housekeeping"] = "QC_IMAGE_VERSION_STRING" in txt
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("file")
    ap.add_argument("--segment", type=int, default=None,
                    help="打印该段的完整可读文本（0 起）；默认只打摘要")
    ap.add_argument("--tsv", action="store_true")
    ap.add_argument("--max-errors", type=int, default=6)
    a = ap.parse_args()

    fh = open(a.file, "rb") if a.file != "/dev/stdin" else sys.stdin.buffer
    data = fh.read()
    n = len(data) // SEG
    segs = [decode_segment(data[i * SEG:(i + 1) * SEG]) for i in range(n)]

    if a.segment is not None:
        s = segs[a.segment]
        print(s["text"].rstrip())
        return 0

    if a.tsv:
        print("seg\tqcver\treset_by\treset_type\tpon\tslot\tstart_ebs\twdog\terrors")
        for i, s in enumerate(segs):
            print("\t".join([str(i), s["qcver"], s["reset_by"], s["reset_type"], s["pon"],
                             s["slot"], s["start_ebs"], s["wdog"], str(len(s["errors"]))]))
        return 0

    valid = [i for i, s in enumerate(segs) if s["housekeeping"]]
    print("logfs: %d B = %d × %d KiB；其中**有效启动段 = %d**（有 QC_IMAGE_VERSION_STRING 标记）"
          % (len(data), n, SEG // 1024, len(valid)))
    print("说明：段序 ≠ 时间序（环形缓冲，写指针未知）；同一段内 `[n]` 是 ABL 自身微秒/毫秒计数。")
    print("seg  版本                        reset_by      reset_type       slot  StartEBS  wdog     errs")
    for i, s in enumerate(segs):
        if not s["housekeeping"]:
            continue
        print("%3d  %-26s  %-12s  %-15s  %-4s  %-8s  %-7s  %d" % (
            i, s["qcver"][:26], s["reset_by"][:12], s["reset_type"][:15],
            s["slot"] or "-", s["start_ebs"] or "-", s["wdog"] or "-", len(s["errors"])))
    print()
    for i, s in enumerate(segs):
        if not s["housekeeping"] or not s["errors"]:
            continue
        print("seg %d 前 %d 条可疑行：" % (i, min(a.max_errors, len(s["errors"]))))
        for ln in s["errors"][:a.max_errors]:
            print("    %s" % ln[:160])
    print("\n提示：--segment N 看单段全文；判据见本文件头 docstring。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
