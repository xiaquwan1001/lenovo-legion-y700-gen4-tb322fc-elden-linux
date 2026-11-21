#!/usr/bin/env python3
"""gen-scripts-index.py — 生成 scripts/ 索引（scripts/README.md + 机读 TSV），可重跑、可挂门。

背景（arch-audit P1#3，`.pi/reports/cleanup-audit-20261120/arch-audit.md` 风险表第 3 行）：
  scripts/ 有 ~300 个入口，靠命名当代替品，没有地图 ⇒ 重复造轮子 + 派发成本高。
  旧 A3 审计（`reports/audit-20261119/A3-scripts-audit.tsv`）是一次性产物，会过期。

本工具只读：不改任何被索引脚本，只写 `scripts/README.md`。
设计与本轮统计（分组/引用数分布/孤立件判定）：reports/scripts-index-20261120.md。

用法：
  gen-scripts-index.py                 # 重新生成 scripts/README.md
  gen-scripts-index.py --check         # README 过期则 rc=1（不写文件；用于门禁）
  gen-scripts-index.py --tsv           # TSV 打到 stdout（机读）
  gen-scripts-index.py --tsv PATH      # TSV 写到 PATH
  gen-scripts-index.py --diff          # 过期时打印 unified diff（配合 --check 调试）

判据（全部确定性、与 mtime/时钟无关 ⇒ 同输入同输出）：
  · 扫描范围：scripts/ 一层的 *.sh/*.py + 一层子目录（scripts/doctor、scripts/bisect…）
  · 用途：shebang 之后的首个注释块（py 优先取模块 docstring），取首个描述行；
    `名字 — 描述` 形式取破折号之后；无注释块 ⇒ 空（README 里显示 `(无头注释)`）
  · 被引用次数：对**仓库受版本控制的文本文件**做一次全量正则扫描（见 REF_EXT/REF_SKIP），
    按 basename 记「提及行数」；拆成 scripts_refs（其它脚本）与 docs_refs（其余文本）
  · 分组：见 GROUPS（优先序，命中即定组；另见 classify()）
  · 排除自身：本生成器与生成的 README 永不进引用语料（否则计数自增、--check 永不收敛）
"""

import argparse
import ast
import collections
import hashlib
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS = os.path.join(ROOT, "scripts")
OUT_MD = os.path.join(SCRIPTS, "README.md")
SELF = os.path.abspath(__file__)

# 引用语料的扩展名白名单（够用且便宜：md/txt 文档 + 脚本 + 少量配置）
REF_EXT = {".md", ".txt", ".sh", ".py", ".service", ".conf", ".dev", ".tsv"}
# 路径前缀/目录名不进语料（造件区、备份区、git 内部）
REF_SKIP_DIRS = {"out", "backup", "build", ".git", "node_modules", ".venv"}
# 绝对排除的文件（自身产物）
REF_SKIP_FILES = {"scripts/README.md", "scripts/gen-scripts-index.py"}

MAX_HEAD_LINES = 40
DESC_MAX = 110

# 一次性/历史件：仅认「自报」——描述行（首个注释行）或文件名带日期的一次性件。
ONESHOT_PAT = re.compile(r"一次性(脚本|工具|任务|产物)|one-shot|oneshot 脚本|退役|已过期|不再维护"
                         r"|历史遗留|legacy one-off")
ONESHOT_NAME_PAT = re.compile(r"-\d{8}\.(sh|py)$")

# 分组判据：名字优先（按 GROUPS 顺序），名字全不命中才退回头注释。
# 每条 = (组名, 名字正则, 头注释正则)；头注释模式只在前面的名字模式全落空时才用。
GROUPS = [
    ("门禁",
     re.compile(r"(^|[/\-_])(check|verify|preflight|assert|sanity|selfcontained)([\-_.]|$)"
                r"|^test-|-check\.|-verify\.|-selftest\."),
     re.compile(r"退出码|门禁|\bgate\b|pre-commit|FAIL=|自检")),
    ("公共库",
     re.compile(r"^(lib-|_lib)"),
     re.compile(r"\bsource this\b|source 本文件|被 source")),
    ("设备操作",
     re.compile(r"flash|fastboot|edl|qdl|slot|bootctl|device|adb|ssh|deploy|serial|usb|ncm|gpt"
                r"|kexec|unlock|recovery|rootfs|chroot|waydroid|^wd-|^wd\.|net-|bt-|audio|cam"
                r"|camera|charge|sleep|desktop|keep-awake|ath12k|module|haptic|dpms|fstab|power"),
     re.compile(r"设备侧|在设备上|RUN ON DEVICE|on the device|on-device")),
    ("造件",
     re.compile(r"build|^mk|make|gen-|pack|assemble|img|super|bake|compile|install|payload"
                r"|modules|initramfs|rebuild|apply|sign|setup|font|repack|slim|extract|fetch"),
     re.compile(r"生成|造件|打包|构建|rebuild")),
    ("取证",
     re.compile(r"log|probe|dump|scan|audit|evidence|diag|inspect|stat|watch|sample|capture"
                r"|forensic|trace|bench|measure|sweep|stress|spy|collect|survey|diff|triage"),
     re.compile(r"取证|诊断|采样|测量|只读体检")),
]

GROUP_ORDER = ["门禁", "设备操作", "造件", "取证", "一次性", "公共库", "其它"]


def rel(p):
    return os.path.relpath(p, ROOT)


def is_script(path):
    """*.sh / *.py，或任何带 shebang 的可执行文本（如 eldroid-bootctl、*.initd）。"""
    if path.endswith((".sh", ".py")):
        return True
    return head_text(path).startswith("#!")


def iter_targets():
    """scripts/ 一层 *.sh/*.py/shebang 件 + 子目录一层。排序确定。"""
    found = []
    for name in sorted(os.listdir(SCRIPTS)):
        p = os.path.join(SCRIPTS, name)
        if os.path.isdir(p):
            if name in ("__pycache__",):
                continue
            for sub in sorted(os.listdir(p)):
                q = os.path.join(p, sub)
                if os.path.isfile(q) and is_script(q):
                    found.append(q)
        elif os.path.isfile(p) and is_script(p):
            found.append(p)
    return sorted(found)


def head_text(path):
    """读文件头（≤64 KiB，足够覆盖 shebang + 注释块 + 模块 docstring）。"""
    try:
        with open(path, "rb") as f:
            raw = f.read(64 * 1024)
    except OSError:
        return ""
    return raw.decode("utf-8", "replace")


def head_lines(path):
    return head_text(path).splitlines()[:MAX_HEAD_LINES]


def comment_block(lines):
    """shebang 之后连续注释行；遇首个非注释非空行即止。"""
    i = 0
    if lines and lines[0].startswith("#!"):
        i = 1
    block = []
    for line in lines[i:]:
        s = line.strip()
        if not s:
            if block:
                block.append("")
            continue
        if s.startswith("#"):
            block.append(s.lstrip("#").strip())
            continue
        break
    return [b for b in block if b]


def py_docstring(text):
    src = text
    try:
        mod = ast.parse(src)
    except (SyntaxError, ValueError):
        return []
    doc = ast.get_docstring(mod)
    if not doc:
        return []
    return [ln.strip() for ln in doc.splitlines() if ln.strip()]


def block_of(path):
    lines = head_lines(path)
    if lines and "python" in lines[0]:
        doc = py_docstring(head_text(path))
        if doc:
            return doc
    return comment_block(lines)


def describe(path, block):
    base = os.path.basename(path)
    stem = base.rsplit(".", 1)[0]
    text = ""
    for line in block:
        if not line:
            if text:
                break
            continue
        # 跳过「用法/usage」等小标题行
        low = line.lower()
        if re.match(r"^(usage|用法|运行|示例|example)\b|^(usage|用法)[:：]", low):
            continue
        text = line
        break
    if not text:
        return ""
    # 去掉重复的名字前缀：`foo.sh — desc` / `foo — desc` / `foo.sh: desc`
    for alias in (base, stem):
        m = re.match(r"(?:\./)?(?:scripts/)?" + re.escape(alias) + r"\s*(?:—|–|--|:)\s*", text)
        if m:
            text = text[m.end():]
            break
    return " ".join(text.split())


def ref_corpus():
    """返回 (scripts_files, docs_files)：受版本控制的文本文件，已剔除跳过项。"""
    try:
        out = subprocess.run(["git", "ls-files"], cwd=ROOT, capture_output=True,
                             text=True, timeout=120, check=True).stdout
        files = out.splitlines()
        tracked = True
    except (OSError, subprocess.SubprocessError):
        files, tracked = [], False
    if not tracked:
        for dirpath, dirnames, filenames in os.walk(ROOT):
            dirnames[:] = [d for d in dirnames if d not in REF_SKIP_DIRS]
            for fn in filenames:
                files.append(rel(os.path.join(dirpath, fn)))
    sel = []
    for f in files:
        if f in REF_SKIP_FILES:
            continue
        parts = f.split("/")
        if len(parts) > 1 and parts[0] in REF_SKIP_DIRS:
            continue
        if os.path.splitext(f)[1] not in REF_EXT:
            continue
        sel.append(f)
    scripts = [f for f in sel if f.startswith("scripts/")]
    docs = [f for f in sel if not f.startswith("scripts/")]
    return sorted(scripts), sorted(docs)


def build_counts(names, files):
    """一次扫描：每个 basename 的「提及行数」。"""
    pats = {n: re.compile(r"(?<![\w.\-])" + re.escape(n) + r"(?![\w\-])") for n in names}
    counts = collections.Counter()
    for f in files:
        p = os.path.join(ROOT, f)
        try:
            if os.path.getsize(p) > 2 * 1024 * 1024:
                continue
            with open(p, "rb") as fh:
                text = fh.read().decode("utf-8", "replace")
        except OSError:
            continue
        if not any(n in text for n in names):
            continue
        for line in text.splitlines():
            if len(line) > 4000:
                continue
            for n, pat in pats.items():
                if n in line and pat.search(line):
                    counts[n] += 1
    return counts


def classify(path, block):
    base = os.path.basename(path)
    head = "\n".join(block[:12])
    if os.sep + "doctor" + os.sep in path:
        return "门禁"
    for group, name_pat, head_pat in GROUPS[:2]:       # 门禁 / 公共库：名字或头注释都算
        if name_pat.search(base) or head_pat.search(head):
            return group
    for group, name_pat, _ in GROUPS[2:]:              # 先只看名字（优先序）
        if name_pat.search(base):
            return group
    for group, _, head_pat in GROUPS[2:]:              # 名字都不中，再看头注释
        if head_pat.search(head):
            return group
    return "其它"


def oneshot_group(path, block):
    """一次性/历史件：只认自报（首个注释行）或文件名带日期，且门禁永不进这组。"""
    g = classify(path, block)
    if g == "门禁" or g == "公共库":
        return g
    if ONESHOT_NAME_PAT.search(os.path.basename(path)) or (block and ONESHOT_PAT.search(block[0])):
        return "一次性"
    return g


def collect(scan_refs=True):
    entries = []
    for p in iter_targets():
        block = block_of(p)
        entries.append({
            "path": rel(p),
            "name": os.path.basename(p),
            "shebang": (head_lines(p) or [""])[0].strip(),
            "desc": describe(p, block) or "(无头注释)",
            "group": oneshot_group(p, block),
        })
    if not scan_refs:
        # 结构指纹模式：不做引用语料扫描（省 ~5 s，且**不把引用计数算进新鲜度判据**）
        for e in entries:
            e["scripts_refs"] = e["docs_refs"] = e["refs"] = 0
        entries.sort(key=lambda e: (GROUP_ORDER.index(e["group"]), e["name"]))
        return entries
    names = sorted({e["name"] for e in entries})
    scripts, docs = ref_corpus()
    sc = build_counts(names, scripts)
    dc = build_counts(names, docs)
    # 自引用不算（脚本自己那行 shebang/注释里写自己名字不算「被别人引用」）
    for e in entries:
        own = e["path"]
        e["scripts_refs"] = sc[e["name"]]
        e["docs_refs"] = dc[e["name"]]
        # 扣掉被引语料里「定义文件自身」的提及：只有当语料里该文件就是本脚本时
        if own in scripts:
            e["scripts_refs"] = max(0, e["scripts_refs"] - _self_mentions(own, e["name"]))
        e["refs"] = e["scripts_refs"] + e["docs_refs"]
    entries.sort(key=lambda e: (GROUP_ORDER.index(e["group"]), e["name"]))
    return entries


def _self_mentions(path, name):
    """定义文件内提及自己 basename 的行数（典型 1–3 行）。"""
    try:
        with open(os.path.join(ROOT, path), "rb") as fh:
            text = fh.read().decode("utf-8", "replace")
    except OSError:
        return 0
    pat = re.compile(r"(?<![\w.\-])" + re.escape(name) + r"(?![\w\-])")
    return sum(1 for ln in text.splitlines() if pat.search(ln))


def structural_fp(entries):
    """新鲜度判据 = **结构**（路径/分组/名字/shebang/头注释一句话），**不含引用计数**。
    原因（2026-11-20 grow-loop #4 踩两次）：引用数是「全仓文档提到该 basename 的行数」，
    任何一处文档改动都会让它变 ⇒ 把引用计数算进指纹，等于「改一行文档就要重新生成索引」，
    门禁立刻变成噪声、人会直接绕开。"""
    payload = [
        [e["path"], e["group"], e["name"], e["shebang"], e["desc"]]
        for e in entries
    ]
    blob = json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(blob.encode("utf-8")).hexdigest()[:16]


def render_md(entries):
    total = len(entries)
    per_group = collections.Counter(e["group"] for e in entries)
    orphans = [e for e in entries if e["refs"] == 0]
    L = []
    L.append(f"<!-- 结构指纹 fp={structural_fp(entries)}（--check 只比这个；引用计数不进指纹、随生成刷新） -->")
    L.append("<!-- 本文件由 scripts/gen-scripts-index.py 生成；不要手改。")
    L.append("     重新生成：python3 scripts/gen-scripts-index.py")
    L.append("     过期检查：python3 scripts/gen-scripts-index.py --check   (rc=1 = 需要重新生成) -->")
    L.append("")
    L.append("# scripts/ 索引")
    L.append("")
    L.append("`scripts/` 是「命名即接口」的命令层：**没有统一 dispatch**，每个任务一个脚本。"
             "本索引给地图，不是规范。设计与统计口径见 `reports/scripts-index-20261120.md`"
             "（arch-audit P1#3）。")
    L.append("")
    L.append(f"- 入口总数：**{total}**（`scripts/*.sh|*.py` 或带 shebang 的可执行文本 + 一层子目录 "
             "`scripts/{doctor,bisect,audio-tplg,audio-ucm,wd-audio-test}/*`）")
    L.append("- 分组：" + " / ".join(f"{g} {per_group.get(g, 0)}" for g in GROUP_ORDER if per_group.get(g)))
    L.append(f"- 引用数为 0 的孤立件：**{len(orphans)}**（判定口径见下）")
    L.append("")
    L.append("## 判据（怎么读这张表）")
    L.append("")
    L.append("- **引用数** = 仓库受版本控制文本文件里提到该 basename 的**行**数"
             "（`脚本↔脚本` + `文档↔脚本`，已扣除脚本自身）。"
             "**0 = 没有任何脚本/文档提到它** ⇒ 可疑孤立件（可能是过期一次性工具，也可能是人手跑的入口）。")
    L.append("- **门禁类**：名字或头注释命中 `check-/verify/preflight/assert/sanity`；"
             "聚合门禁 = `scripts/check-doctor.sh`（FAIL=0 才收尾）。")
    L.append("- **一次性**：只认**自报**（首个注释行写「一次性脚本/工具/任务」或 one-shot/退役/已过期）"
             "或**文件名带日期**（`-YYYYMMDD.py` 这类单次产物）；误判率低于按内容猜。")
    L.append("- **其它**：五类都不贴的主机侧杂项（会话检索 `sess.sh`/`recent-sessions.sh`、"
             "并发 `lane.sh`、邮件 `mail-*`、镜像/分区解析小工具 `partlun.py`/`dump-verdict.py` 等）。"
             "「其它」多不等于脚本乱，只说明它不属于设备/造件/取证链。")
    L.append("- **公共库**：`lib-*.sh`，只被 `source`，不单独执行。")
    L.append("- 分组靠名字/头注释正则（`gen-scripts-index.py` 的 `GROUPS`），错组就改那条正则，"
             "别手改本文件。")
    dups = {n: [e["path"] for e in entries if e["name"] == n]
            for n, c in collections.Counter(e["name"] for e in entries).items() if c > 1}
    if dups:
        L.append("- **同名入口**（basename 撞车 ⇒ 引用数是这几条的合计，偏高；别据此判「活」）：")
        for n, paths in sorted(dups.items()):
            L.append("  - `" + n + "`：" + "、".join("`" + x + "`" for x in paths))
    L.append("")
    L.append("> 本文件由生成器重写，**手改会被下一次生成覆盖**；要改内容就改被索引脚本的头注释，"
             "要改分组就改 `gen-scripts-index.py` 的 `GROUPS`。")
    L.append("")
    for g in GROUP_ORDER:
        rows = [e for e in entries if e["group"] == g]
        if not rows:
            continue
        L.append(f"## {g}（{len(rows)}）")
        L.append("")
        L.append("| 入口 | 用途 | 引用 |")
        L.append("|---|---|---|")
        for e in rows:
            desc = e["desc"].replace("|", "\\|")
            L.append(f"| `{e['path']}` | {desc} | {e['refs']} |")
        L.append("")
    if orphans:
        L.append("## 孤立件（引用数 = 0）")
        L.append("")
        L.append("没有脚本、也没有文档提到这些 basename。**不等于可删**：很多是人手跑的入口。"
                 "处置建议 = 要么在 `TASKS/README.md` 或某报告里落一条指针（变活），"
                 "要么标「一次性」并说明留档理由。")
        L.append("")
        for e in sorted(orphans, key=lambda x: (x["group"], x["name"])):
            L.append(f"- `{e['path']}` — {e['desc']}")
        L.append("")
    return "\n".join(L)


TSV_HEAD = ["path", "group", "name", "refs", "scripts_refs", "docs_refs", "shebang", "用途一句话"]


def render_tsv(entries):
    out = ["\t".join(TSV_HEAD)]
    for e in entries:
        out.append("\t".join([
            e["path"], e["group"], e["name"], str(e["refs"]), str(e["scripts_refs"]),
            str(e["docs_refs"]), e["shebang"], e["desc"].replace("\t", " "),
        ]))
    return "\n".join(out) + "\n"


def main():
    ap = argparse.ArgumentParser(description="生成 scripts/ 索引")
    ap.add_argument("--check", action="store_true", help="README 过期则 rc=1，不写文件")
    ap.add_argument("--tsv", nargs="?", const="-", metavar="PATH", help="输出机读 TSV（默认 stdout）")
    ap.add_argument("--diff", action="store_true", help="--check 时打印 diff")
    ap.add_argument("--quiet", action="store_true")
    ap.add_argument("--readme", metavar="PATH", default=None,
                    help="对账/写入指定的 README（默认 scripts/README.md）。"
                         "2026-11-21 加：医生 §24 的反作弊必须改坏指纹在**副本**上做，"
                         "不能就地改 git 跟踪的真件（就地改 + 进程被 SIGKILL ⇒ 真件停在"
                         "坏指纹，门自己制造假 FAIL，需 git checkout 才能复原）")
    args = ap.parse_args()

    out_md = args.readme or OUT_MD

    entries = collect()
    rendered = render_md(entries)

    if args.tsv is not None:
        data = render_tsv(entries)
        if args.tsv == "-":
            sys.stdout.write(data)
        else:
            with open(args.tsv, "w", encoding="utf-8") as f:
                f.write(data)
            print(f"wrote {args.tsv} ({len(entries)} rows)")
        return 0

    old = ""
    if os.path.exists(out_md):
        with open(out_md, encoding="utf-8") as f:
            old = f.read()

    if args.check:
        want = structural_fp(collect(scan_refs=False))
        have = ""
        m = re.search(r"结构指纹 fp=([0-9a-f]{8,64})", old)
        if m:
            have = m.group(1)
        if have == want:
            extra = "" if old == rendered else "（引用计数已漂移，按设计不判过期；想刷新跑一次生成器）"
            print(f"OK {rel(out_md)} 结构最新（{len(entries)} 个入口）{extra}")
            return 0
        print(f"STALE {rel(out_md)} 过期（结构变了：{len(entries)} 个入口，"
              f"fp {have or '缺失'} → {want}）→ 跑 python3 scripts/gen-scripts-index.py",
              file=sys.stderr)
        if args.diff:
            import difflib
            sys.stdout.writelines(difflib.unified_diff(
                old.splitlines(True), rendered.splitlines(True),
                f"{rel(out_md)} (on disk)", f"{rel(out_md)} (generated)"))
        return 1

    if old != rendered:
        with open(out_md, "w", encoding="utf-8") as f:
            f.write(rendered)
        if not args.quiet:
            print(f"wrote {rel(out_md)}（{len(entries)} 个入口）")
    elif not args.quiet:
        print(f"{rel(out_md)} 已是最新（{len(entries)} 个入口）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
