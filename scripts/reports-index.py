#!/usr/bin/env python3
"""reports-index.py — 由文件名 + 首个 `# ` 标题生成 `reports/README.md`（只读报告，只写这一个文件）。

2026-11-15 立。动机：`reports/` 有 500+ 篇 md，但**没有 README**，只有 `INDEX.md` 手工点了十来篇；
实测 1060 个报告/台账文件名里有 135 个在全仓 md 语料里只出现 1 次（= 无人引用）。本脚本不改任何报告，
只产出一张「按主题前缀分组 + 首标题 + 日期」的目录，给人/agent 一个不靠猜的入口。

用法：
  scripts/reports-index.py            # 写 reports/README.md
  scripts/reports-index.py --check    # 只比对，不写；过期则 rc=1（可进 check-doctor）
  scripts/reports-index.py --stdout   # 打到标准输出
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RPT = os.path.join(ROOT, "reports")
OUT = os.path.join(RPT, "README.md")

DATE_RE = re.compile(r"(20\d{6})")
HEADER = """# reports/ — 专题报告目录（**机器生成，勿手改**）

> 生成器：`scripts/reports-index.py`（`--check` 只比对）。手改会在下次生成时被覆盖；
> 要改分类/标题请改报告文件自己的首个 `# ` 标题。
> 入口关系：`INDEX.md` 是唯一入口；本文件只做 `reports/` 内部的**查全**用索引，不承载状态结论。

- 报告总数：{total}
- 命名约定：`<主题>-<YYYYMMDD>.md`（无日期的少数为早期件）
- 分组依据：文件名去掉日期后按 `-` 取首段；同组按日期倒序
"""


def first_heading(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            for _ in range(40):
                line = fh.readline()
                if not line:
                    break
                if line.startswith("# "):
                    return line[2:].strip()
    except OSError:
        pass
    return ""


def collect():
    rows = []
    for name in sorted(os.listdir(RPT)):
        if not name.endswith(".md") or name == "README.md":
            continue
        stem = name[:-3]
        m = DATE_RE.search(stem)
        date = m.group(1) if m else ""
        topic = DATE_RE.sub("", stem).strip("-_") or stem
        group = topic.split("-")[0] or "其他"
        rows.append(
            {
                "file": name,
                "group": group,
                "topic": topic,
                "date": date,
                "title": first_heading(os.path.join(RPT, name)),
            }
        )
    return rows


def render(rows):
    groups = {}
    for r in rows:
        groups.setdefault(r["group"], []).append(r)
    out = [HEADER.format(total=len(rows))]
    out.append("| 组 | 篇数 | 最近一篇 |")
    out.append("|---|---|---|")
    for g in sorted(groups, key=lambda k: (-len(groups[k]), k)):
        items = sorted(groups[g], key=lambda r: r["date"], reverse=True)
        out.append("| `%s` | %d | `%s` |" % (g, len(items), items[0]["file"]))
    out.append("")
    for g in sorted(groups, key=lambda k: (-len(groups[k]), k)):
        items = sorted(groups[g], key=lambda r: r["date"], reverse=True)
        out.append("## `%s`（%d）" % (g, len(items)))
        out.append("")
        for r in items:
            title = r["title"] or r["topic"]
            out.append("- `%s` — %s" % (r["file"], title))
        out.append("")
    return "\n".join(out).rstrip() + "\n"


def main():
    rows = collect()
    text = render(rows)
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    if mode == "--stdout":
        sys.stdout.write(text)
        return 0
    old = ""
    if os.path.exists(OUT):
        with open(OUT, "r", encoding="utf-8", errors="replace") as fh:
            old = fh.read()
    if mode == "--check":
        if old == text:
            print("reports/README.md 是最新的（%d 篇）" % len(rows))
            return 0
        print("reports/README.md 过期：重新跑 scripts/reports-index.py")
        return 1
    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(text)
    print("写出 %s（%d 篇 / %d 组）" % (os.path.relpath(OUT, ROOT), len(rows), len(set(r["group"] for r in rows))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
