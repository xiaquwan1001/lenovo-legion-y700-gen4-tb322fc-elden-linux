#!/usr/bin/env python3
"""make-gpt-only-xml.py — 从官方 rawprogram*.xml 里**只保留 GPT 两行**，生成「只改分区表」的 xml。

为什么需要它：真正的 `qdl rawprogram*.xml` 会连数据分区一起写（super/userdata 十几 GiB、
`logfs` 被官方模板覆盖）。而「GPT 回原厂」这个对照只需要 PrimaryGPT/BackupGPT 两条 —— 写 ~50 KB、
不动任何数据，失败后可原样退回（本仓已有六 LUN 主表 dump + LUN0/LUN4 备表 dump）。

用法：
  python3 scripts/make-gpt-only-xml.py ~/文档/TB322FC_15.10.259/rawprogram4.xml -o /tmp/gpt-only4.xml
  python3 scripts/make-gpt-only-xml.py ~/文档/TB322FC_15.10.259/rawprogram_save_persist_unsparse0.xml -o /tmp/gpt-only0.xml

配合 patchN.xml 使用（patch 负责 NUM_DISK_SECTORS 替换与 CRC 重算）：
  qdl --dry-run -f -s ufs "$LOADER" gpt-only4.xml patch4.xml
  qdl           -f -s ufs "$LOADER" gpt-only4.xml patch4.xml

判据（2026-11-17 实测）：生成物只含 2 个 <program>，qdl dry-run 应打印 2 个分区、几十 KiB。
"""
import argparse
import sys
import xml.etree.ElementTree as ET

KEEP = ("PrimaryGPT", "BackupGPT")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("rawprogram")
    ap.add_argument("-o", "--out", required=True)
    ap.add_argument("--keep-extra", default="",
                    help="额外保留的 label，逗号分隔（一般不需要）")
    args = ap.parse_args()

    keep = set(KEEP) | {x for x in args.keep_extra.split(",") if x}
    tree = ET.parse(args.rawprogram)
    root = tree.getroot()
    rows = list(root.iter("program"))
    kept = [r for r in rows if r.get("label") in keep]
    if len(kept) < 2:
        print(f"[gpt-only] 警告：只匹配到 {len(kept)} 行（期望 PrimaryGPT+BackupGPT）", file=sys.stderr)
    for r in rows:
        if r.get("label") not in keep:
            root.remove(r)
    missing = sorted({r.get("filename") for r in kept
                      if r.get("filename") and not __import__("os").path.exists(r.get("filename"))})
    tree.write(args.out, encoding="utf-8", xml_declaration=True)
    luns = sorted({r.get("physical_partition_number") for r in kept})
    print(f"[gpt-only] {args.rawprogram} → {args.out}")
    print(f"[gpt-only] 保留 {len(kept)} 行 / 丢弃 {len(rows) - len(kept)} 行；LUN={luns}")
    print(f"[gpt-only] 件：{[r.get('filename') for r in kept]}")
    if missing:
        print(f"[gpt-only] ⚠ 当前目录下找不到：{missing}（请在官方包目录内执行 qdl）", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
