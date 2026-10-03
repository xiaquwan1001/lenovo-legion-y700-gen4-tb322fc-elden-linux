#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""elden 项目知识库构建器：把仓库里的 markdown/JSONL 源解析进 SQLite。

用法:  python3 db/build.py          # 生成 db/elden.db
        python3 db/build.py --lessons   # 另生成 LESSONS.md 统一入口
        python3 db/build.py --check     # 只校验 db 是否与文本源同步（不重建）

源（都是 git 纳管的文本）:
  PITFALLS.md                              -> pitfalls
  TASKS.md                                 -> tasks
  RESOURCES.md                             -> references_ (外部参考 + 本地资源)
  archive/sessions-catalog-*.jsonl         -> sessions
  <所有 tracked *.md 里的 URL>             -> references_ (kind=url)

设计: 数据库是「结构化、可查询」的进度/知识索引；markdown 是视图。
      重新运行即可从源重建，故 db 可随时丢弃重生成。
"""
import json, os, re, sqlite3, subprocess, sys, glob

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(ROOT, "db", "elden.db")
SCHEMA_FILE = os.path.join(ROOT, "db", "schema.sql")

URL_RE = re.compile(r'https?://[^\s)`>"\']+')
NOISE_URL = re.compile(r'^https?://(127\.|localhost|192\.168\.|10\.|172\.(1[6-9]|2\d|3[01])\.)')
ID_RE = re.compile(r'^(G1-\d+|C\d+|A\d+|T\d+|task-\d+)$')


def sh(*a):
    return subprocess.run(a, cwd=ROOT, capture_output=True, text=True).stdout


def tracked_md():
    return [p for p in sh("git", "ls-files", "*.md").splitlines() if p]


def split_cells(line):
    return [c.strip() for c in line.strip().strip("|").split("|")]


def clean(s):
    s = re.sub(r'\[([^\]]+)\]\([^)]*\)', r'\1', s or "")   # [txt](url) -> txt
    s = s.replace("**", "").replace("`", "").replace("\\|", "|")
    return re.sub(r'\s+', ' ', s).strip()


# ---------------------------------------------------------------- sessions
def load_sessions(cur):
    n = 0
    for f in sorted(glob.glob(os.path.join(ROOT, "archive", "sessions-catalog-*.jsonl"))):
        for line in open(f, encoding="utf-8"):
            line = line.strip()
            if not line:
                continue
            o = json.loads(line)
            cur.execute("""INSERT OR REPLACE INTO sessions
              (id,start,name,topic,goal,outcome,hardware_verified,device_evidence,
               kernel_versions,status,risks,file,size)
              VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)""",
              (o.get("id"), o.get("start"), o.get("name"), o.get("topic"),
               o.get("goal"), o.get("outcome"), o.get("hardware_verified"),
               o.get("device_evidence"), o.get("kernel_versions"), o.get("status"),
               o.get("risks"), o.get("file"), o.get("size") or 0))
            n += 1
    return n


# ---------------------------------------------------------------- pitfalls
ENTRY_RE = re.compile(r'^(\d+[a-z]?)\.\s+(.*)$')


def load_pitfalls(cur):
    n = 0
    section = ""
    num = title = None
    body = []
    def flush():
        nonlocal n, num, title, body
        if num is not None:
            cur.execute("""INSERT INTO pitfalls(num,section,title,body,source_doc)
                           VALUES (?,?,?,?,?)""",
                        (num, section, clean(title), "\n".join(body).strip(), "PITFALLS.md"))
            n += 1
        num = title = None
        body = []
    for line in open(os.path.join(ROOT, "PITFALLS.md"), encoding="utf-8"):
        if line.startswith("## "):
            flush()
            section = clean(line[3:])
            continue
        m = ENTRY_RE.match(line)
        if m:
            flush()
            num = m.group(1)
            title = m.group(2)
            continue
        if num is not None:
            body.append(line.rstrip())
    flush()
    return n


# ---------------------------------------------------------------- tasks
def load_tasks(cur):
    n = 0
    area = ""
    for line in open(os.path.join(ROOT, "TASKS.md"), encoding="utf-8"):
        if line.startswith("## "):
            area = clean(line[3:])
        if not line.lstrip().startswith("|"):
            continue
        cells = split_cells(line)
        if len(cells) < 3:
            continue
        first = clean(cells[0])
        m = ID_RE.match(first)
        if not m:
            continue
        cur.execute("""INSERT OR REPLACE INTO tasks(id,area,title,status,evidence,source_doc)
                       VALUES (?,?,?,?,?,?)""",
                    (first, area, clean(cells[1])[:400],
                     clean(cells[2])[:200], clean(" | ".join(cells[3:]))[:800], "TASKS.md"))
        n += 1
    return n


# ---------------------------------------------------------------- references
def is_sep(line):
    return set(line.replace("|", "").replace(":", "").replace("-", "").strip()) == set()


def load_resources(cur):
    n = 0
    topic = ""
    for line in open(os.path.join(ROOT, "RESOURCES.md"), encoding="utf-8"):
        if line.startswith("### "):
            topic = clean(line[4:])
            continue
        if line.startswith("## "):
            topic = clean(line[3:])
            continue
        if line.lstrip().startswith("|"):
            if is_sep(line.split("|")[1] if "|" in line else ""):
                continue
            cells = split_cells(line)
            if not cells or cells[0] in ("", "资源", "项目", "项", "ID") or set(cells[0]) <= set("-: "):
                continue
            title = clean(cells[0])
            if not title:
                continue
            kind = "local" if topic.startswith("2") else "ext"
            loc = ""
            u = URL_RE.search(line)
            if u:
                loc = u.group(0)
            cur.execute("""INSERT INTO references_(kind,title,locator,topic,source_doc,status,notes)
                           VALUES (?,?,?,?,?,?,?)""",
                        (kind, title[:300], loc, topic, "RESOURCES.md",
                         clean(cells[2])[:200] if len(cells) > 2 else "",
                         clean(" / ".join(cells[1:]))[:800]))
            n += 1
        elif re.match(r'^-\s+', line) and topic.startswith("1.4"):
            txt = clean(line)
            u = URL_RE.search(line)
            cur.execute("""INSERT INTO references_(kind,title,locator,topic,source_doc,status,notes)
                           VALUES (?,?,?,?,?,?,?)""",
                        ("doc", txt[:300], u.group(0) if u else "", topic, "RESOURCES.md", "", txt[:800]))
            n += 1
    return n


def load_urls(cur):
    seen = set()
    n = 0
    for p in tracked_md():
        try:
            text = open(os.path.join(ROOT, p), encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        for i, line in enumerate(text.splitlines(), 1):
            for u in URL_RE.findall(line):
                u = u.rstrip('.,;')
                if '<' in u or NOISE_URL.match(u) or u.rstrip('/') in ('https://github.com', 'https://www.google.com'):
                    continue
                key = (u, p)
                if key in seen:
                    continue
                seen.add(key)
                cur.execute("""INSERT INTO references_(kind,title,locator,topic,source_doc,status,notes)
                               VALUES (?,?,?,?,?,?,?)""",
                            ("url", clean(line)[:300], u, "", p, "", "L%d" % i))
                n += 1
    return n


def load_docs(cur):
    n = 0
    for p in tracked_md():
        base = os.path.basename(p)
        cur.execute("INSERT OR REPLACE INTO docs(path,kind,title) VALUES (?,?,?)",
                    (p, "doc", base))
        n += 1
    return n


# ---------------------------------------------------------------- lessons view
def gen_lessons(con):
    rows = con.execute("SELECT num,section,title,body FROM pitfalls ORDER BY id").fetchall()
    by = {}
    for num, section, title, body in rows:
        by.setdefault(section, []).append((num, title, body))
    out = ["# 经验总入口（LESSONS）", "",
           "> ⚠️ **本文件是生成物，禁止手改**（`python3 db/build.py --lessons` 重建）。经验正文改 `PITFALLS.md`。",
           "> 新会话**动手前先读本文件**；它是散落在 `PITFALLS.md`、`.pi/memory/*`、`archive/topics/复盘-*`、",
           "> `GAPS.md` 风险登记、`.pi/skills/*/references/` 里的踩坑经验的**统一入口**。",
           "> 由 `db/build.py --lessons` 从 `PITFALLS.md` 生成索引；正文与细节仍以原文为准。", "",
           "---", "", "## 0. 零号纪律（先做这三件事）", "",
           "1. **先查本地既有结论再取证**：`grep -rn -iE \"unlock|解锁|rollback|testkey|GPT|EDL\" ~/y700-elden/*.md archive/topics/*.md .pi/skills/*/references/*.md`（`PITFALLS` #87）。",
           "2. **动分区/刷写前备份**：`fastboot fetch <分区>` + GPT 双表 dump；**写后读回校验**（不看\"传输完成\"）。",
           "3. **单一远程通道的持久系统上不做自锁式实验**（电源/熄屏/网络）；先 RAM 引导验证（`PITFALLS` #87、复盘-持久化与睡眠）。", "",
           "## 1. 其他经验来源（一并扫）", "",
           "| 来源 | 内容 |", "|---|---|",
           "| `PITFALLS.md` | 本文件索引的正文（#1–#87，按主题） |",
           "| `.pi/memory/FAILURES.md` | 反复踩的环境/工具类坑（pgrep 自杀、adb root 吞命令…） |",
           "| `.pi/memory/HINDSIGHT.md` | 阶段性 hindsight 与决策（含 API 限流、swarm 补丁） |",
           "| `GAPS.md` §4 风险登记 | 高影响风险与缓解 |",
           "| `archive/topics/复盘-*.md` | 逐轮操作史与根因 |",
           "| `.pi/skills/*/references/*.md` | 机型/刷写专项经验（正文不入上下文，需 grep） |", "",
           "## 2. PITFALLS 分类索引", ""]
    for section in by:
        out.append("### " + section)
        out.append("")
        for num, title, body in by[section]:
            out.append("- **#%s** %s" % (num, title or clean(body.splitlines()[0] if body else "")))
        out.append("")
    out.append("> 查询：`sqlite3 db/elden.db \"SELECT num,title FROM pitfalls WHERE body LIKE '%关键词%'\"`")
    open(os.path.join(ROOT, "LESSONS.md"), "w", encoding="utf-8").write("\n".join(out) + "\n")
    return len(rows)


def cmd_check():
    """校验 db 是否与文本源同步（不重建）。退出码 0=同步，1=过期/缺失。"""
    if not os.path.exists(DB):
        print("FAIL: db/elden.db 不存在 → python3 db/build.py --lessons")
        return 1
    srcs = [os.path.join(ROOT, f) for f in ("PITFALLS.md", "TASKS.md", "RESOURCES.md")]
    srcs += sorted(glob.glob(os.path.join(ROOT, "archive", "sessions-catalog-*.jsonl")))
    dbt = os.path.getmtime(DB)
    stale = [os.path.relpath(s, ROOT) for s in srcs if os.path.exists(s) and os.path.getmtime(s) > dbt]
    con = sqlite3.connect(DB)
    counts = {t: con.execute("select count(*) from %s" % t).fetchone()[0]
              for t in ("sessions", "pitfalls", "tasks", "references_", "docs")}
    con.close()
    if stale:
        print("STALE: db 比以下源旧 → python3 db/build.py --lessons")
        for s in stale:
            print("  - " + s)
        return 1
    print("OK: db 与文本源同步  " + "  ".join("%s=%d" % kv for kv in counts.items()))
    return 0


def main():
    if "--check" in sys.argv:
        sys.exit(cmd_check())
    os.makedirs(os.path.dirname(DB), exist_ok=True)
    if os.path.exists(DB):
        os.remove(DB)
    con = sqlite3.connect(DB)
    cur = con.cursor()
    cur.executescript(open(SCHEMA_FILE, encoding="utf-8").read())
    stats = {
        "sessions": load_sessions(cur),
        "pitfalls": load_pitfalls(cur),
        "tasks": load_tasks(cur),
        "refs(RESOURCES)": load_resources(cur),
        "refs(url)": load_urls(cur),
        "docs": load_docs(cur),
    }
    con.commit()
    if "--lessons" in sys.argv:
        stats["lessons"] = gen_lessons(con)
    con.close()
    print("built", DB)
    for k, v in stats.items():
        print("  %-18s %d" % (k, v))
    print("  size               %d bytes" % os.path.getsize(DB))


if __name__ == "__main__":
    main()
