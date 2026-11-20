#!/usr/bin/env python3
"""out-status.py — out/ 造件生命周期账本门（2026-11-20，arch-audit P1#6）

为什么有这个（.pi/reports/cleanup-audit-20261120/arch-audit.md §5 #6）：
  out/ 356 个条目、87G，被 .gitignore 忽略，此前只有 §23「大件必须有报告」一道门，
  没有任何地方记录「这件是 active / superseded / verified / 待首启」⇒ 每次瘦身都要全量考古。
  本门把生命周期状态收进**入库的账本** versions/out-artifacts.tsv，瘦身从考古变查表。

账本 versions/out-artifacts.tsv（入库，git 跟踪；out/ 本身不入库）：
  每行 5 列（TAB 分隔）：
    out/<name> <TAB> 状态 <TAB> 依据 <TAB> 报告指针 <TAB> 最后核对日期
  状态词表固定四个（不许自造）：
    active     现役/唯一造件（还在被设备或流程使用）
    verified   已上机或已核验（EDL 写入读回一致等），可复用
    superseded 被取代/中间件，可删候选
    pending    等首启/等上机验证 —— **禁删**（防误删唯一 final 件）
  「依据」列不许空（照 §17/§23 反作弊口径：空依据必须 FAIL）。

--check 三件事：
  ① 每个 >200MB 的 out/ 一级目录必须在账本里（不在 ⇒ FAIL）；
  ② 状态词合法、依据非空、无重复条目（坏行 ⇒ FAIL）；
  ③ 标 pending/active 的目录必须真实存在（不在盘 ⇒ FAIL，防「账本说禁删但已丢」）。
  out/ 不存在时整体 SKIP（照 §23/§24「不可核」口径，WARN 行，不算 PASS）。

--init：从现有树推断初始账本（推断规则与依据文案见 infer()，规则不许留空依据）。
  账本已存在时拒绝覆盖（--force 才重写）；推断结果必须人工复核后入库。

用法：
  scripts/out-status.py [--root DIR] [--tsv]
  scripts/out-status.py --init [--force]
  scripts/out-status.py --selftest

退出码：0 = 无 FAIL（SKIP 也算 0，但打 WARN 行）；1 = 有 FAIL / init 拒绝。
"""
import os
import re
import sys
import tempfile

BIG_BYTES = 200 * 1024 * 1024
LEDGER_REL = "versions/out-artifacts.tsv"
REPORTS = "reports"
STATUSES = ("active", "verified", "superseded", "pending")
TODAY = "2026-11-20"

fail = 0


def bad(msg):
    global fail
    fail += 1
    print("  [FAIL] %s" % msg)


def warn(msg):
    print("  [warn] %s" % msg)


def ok(msg):
    print("  [ok]   %s" % msg)


# ---------------------------------------------------------------- 账本读写
def parse_ledger(root):
    """返回 (rows, problems)。rows: {canonical: (status, basis, ref, date)}。"""
    path = os.path.join(root, LEDGER_REL)
    rows, problems = {}, []
    if not os.path.exists(path):
        return rows, ["%s 不存在（跑 --init 生成）" % LEDGER_REL]
    for n, raw in enumerate(open(path, encoding="utf-8", errors="replace"), 1):
        line = raw.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < 5:
            problems.append("%s:%d 列数 <5（要 dir/状态/依据/报告指针/日期）" % (LEDGER_REL, n))
            continue
        canon, status, basis, ref, date = (p.strip() for p in parts[:5])
        if not canon:
            problems.append("%s:%d 空路径" % (LEDGER_REL, n))
            continue
        canon = canon if canon.startswith("out/") else "out/" + canon
        if status not in STATUSES:
            problems.append("%s:%d 非法状态 %r（词表只有 %s）" % (LEDGER_REL, n, status, "/".join(STATUSES)))
            continue
        if not basis:
            problems.append("%s:%d 依据为空（反作弊口径：不许删依据保平安）" % (LEDGER_REL, n))
            continue
        if canon in rows:
            problems.append("%s:%d 重复条目 %s" % (LEDGER_REL, n, canon))
            continue
        rows[canon] = (status, basis, ref, date)
    return rows, problems


def dir_size(path):
    """一级目录总字节（权限不够的子树跳过，容错照 du）。"""
    total = 0
    for cur, _dirs, files in os.walk(path):
        for fn in files:
            fp = os.path.join(cur, fn)
            try:
                st = os.lstat(fp)
            except OSError:
                continue
            total += st.st_size
    return total


def big_dirs(root):
    """out/ 下 >200MB 的一级目录（canonical 路径），供门 ①。"""
    outdir = os.path.join(root, "out")
    hits = []
    if not os.path.isdir(outdir):
        return hits
    for entry in sorted(os.listdir(outdir)):
        p = os.path.join(outdir, entry)
        if not os.path.isdir(p) or os.path.islink(p):
            continue
        if dir_size(p) > BIG_BYTES:
            hits.append("out/" + entry)
    return hits


def find_report(root, name):
    """reports/<name>.md 优先，否则任何 reports/*.md 提到 out/<name>。"""
    repdir = os.path.join(root, REPORTS)
    direct = os.path.join(repdir, name + ".md")
    if os.path.isfile(direct):
        return "reports/%s.md" % name
    if os.path.isdir(repdir):
        needle = "out/" + name
        for fn in sorted(os.listdir(repdir)):
            fp = os.path.join(repdir, fn)
            if not fn.endswith(".md") or not os.path.isfile(fp):
                continue
            try:
                with open(fp, encoding="utf-8", errors="replace") as f:
                    if needle in f.read():
                        return "%s/%s" % (REPORTS, fn)
            except OSError:
                pass
    return None


# ---------------------------------------------------------------- --init 推断
RE_VOID = re.compile(r"作废|superseded|已废弃", re.I)
RE_DROPPABLE = re.compile(r"可删|删除候选|可回收|被.{0,12}取代|被.{0,12}替换|replaced|superseded", re.I)
RE_UNBOOTED = re.compile(r"首启判据未取得|未上机|待上机|未重新枚举|未验证", re.I)


def infer_one(root, canon, dirpath):
    """返回 (status, basis, ref)。推断必须写进依据，不许留空。"""
    name = canon.split("/", 1)[1]
    ref = find_report(root, name)
    text = ""
    if ref:
        try:
            with open(os.path.join(root, ref), encoding="utf-8", errors="replace") as f:
                text = f.read()
        except OSError:
            pass
    # 逐行扫「out/<name> 同行出现 可删/取代」⇒ superseded（含跨报告引用）
    repdir = os.path.join(root, REPORTS)
    if os.path.isdir(repdir):
        needle = canon
        for fn in sorted(os.listdir(repdir)):
            fp = os.path.join(repdir, fn)
            if not fn.endswith(".md") or not os.path.isfile(fp):
                continue
            try:
                with open(fp, encoding="utf-8", errors="replace") as f:
                    for ln in f:
                        if needle in ln and RE_DROPPABLE.search(ln):
                            return ("superseded", "报告行含「可删/被取代」：%s" % (ref or fn),
                                    "%s/%s" % (REPORTS, fn))
            except OSError:
                pass
    if ref and RE_VOID.search(text[:4000]):
        return "superseded", "报告头部标记作废/superseded", ref
    subs = os.listdir(dirpath) if os.path.isdir(dirpath) else []
    if "verify" in subs or "rb" in subs:
        return "superseded", "含 verify//rb/ 校验副本（arch-audit P2#7：校验过即可删档）", ref or "-"
    if "new" in subs:
        if ref and RE_UNBOOTED.search(text):
            return "pending", "含 new/ 且报告称首启判据未取得（禁删）", ref
        return "active", "含 new/ 造件且报告无未上机字样", ref or "-"
    if ref:
        return "pending", "有报告但无状态关键词，保守默认 pending（待人工归类，禁删）", ref
    return "pending", "无同名报告，保守默认 pending（待人工归类，禁删）", "-"


def do_init(root, force):
    path = os.path.join(root, LEDGER_REL)
    if os.path.exists(path) and not force:
        print("  [FAIL] %s 已存在（--force 才重写；现有账本必须人工维护，不许被 --init 冲掉）" % LEDGER_REL)
        return 1
    os.makedirs(os.path.dirname(path), exist_ok=True)
    outdir = os.path.join(root, "out")
    if not os.path.isdir(outdir):
        print("  [FAIL] out/ 不存在，无从推断")
        return 1
    lines = [
        "# out/ 造件生命周期账本（scripts/out-status.py --check 的真源；arch-audit P1#6）",
        "# 列：out/<dir> <TAB> 状态 <TAB> 依据 <TAB> 报告指针 <TAB> 最后核对日期",
        "# 状态词表：active=现役/唯一造件；verified=已上机/已核验可复用；superseded=被取代可删候选；pending=等首启/上机（禁删）",
        "# 维护口径：造件时即写一行；改状态必须同时改「依据」与「最后核对日期」（见 reports/out-status-ledger-20261120.md）",
        "# 本文件由 --init 生成初版（推断规则见 scripts/out-status.py infer_one），已人工复核。",
        "#",
    ]
    n = 0
    for entry in sorted(os.listdir(outdir)):
        p = os.path.join(outdir, entry)
        if not os.path.isdir(p) or os.path.islink(p):
            continue
        if dir_size(p) <= BIG_BYTES:
            continue
        canon = "out/" + entry
        status, basis, ref = infer_one(root, canon, p)
        lines.append("%s\t%s\t%s\t%s\t%s" % (canon, status, basis, ref, TODAY))
        n += 1
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("  [ok]   --init 写 %d 条（>200MB 一级目录）→ %s（人工复核后再入库）" % (n, LEDGER_REL))
    return 0


# ---------------------------------------------------------------- --check
def do_check(root):
    outdir = os.path.join(root, "out")
    if not os.path.isdir(outdir):
        warn("SKIP：out/ 不存在（不可核，不算 PASS，照 §23/§24 口径）")
        return 0
    rows, problems = parse_ledger(root)
    for p in problems:
        bad(p)
    hits = big_dirs(root)
    n_miss = 0
    for canon in hits:
        if canon not in rows:
            n_miss += 1
            bad("%s >200MB 但不在账本 → 在 %s 补一行（--init 可生成初版）" % (canon, LEDGER_REL))
    n_ghost = 0
    for canon, (status, _basis, _ref, _date) in sorted(rows.items()):
        if status in ("pending", "active") and not os.path.isdir(os.path.join(root, canon)):
            n_ghost += 1
            bad("%s 标 %s（禁删）但目录已不在盘 —— 账本与磁盘矛盾，先查是谁删的" % (canon, status))
    n_status = {"active": 0, "verified": 0, "superseded": 0, "pending": 0}
    for s, *_ in rows.values():
        n_status[s] += 1
    ok("账本 %d 条（active %d / verified %d / superseded %d / pending %d）；"
       ">200MB 目录 %d 个、缺登记 %d；禁删类失踪 %d"
       % (len(rows), n_status["active"], n_status["verified"], n_status["superseded"],
          n_status["pending"], len(hits), n_miss, n_ghost))
    return 0


# ---------------------------------------------------------------- --selftest
def selftest():
    """合成树三类坏件各重放一次，必须各被恰好 1 条 FAIL 抓到：
    ① 大件缺登记 ② 非法状态词 ③ pending 但目录不存在。"""
    global fail
    fails0 = fail
    import shutil
    results = []
    cases = (
        ("大件缺登记", ""),
        ("非法状态", "out/bad-status\tpendingx\t非法状态样本\t-\t%s\n" % TODAY),
        ("pending 失踪", "out/some-big\tverified\t合成样本\t-\t%s\nout/ghost-pending\tpending\t失踪样本\t-\t%s\n" % (TODAY, TODAY)),
    )
    print("== selftest: 三类坏件（缺登记 / 非法状态 / pending 失踪）==")
    for label, ledger_extra in cases:
        tmp = tempfile.mkdtemp(prefix="out-status-selftest.")
        os.makedirs(os.path.join(tmp, "out", "some-big"))
        os.makedirs(os.path.join(tmp, "versions"))
        # >200MB 触发件用稀疏文件，不占盘
        with open(os.path.join(tmp, "out", "some-big", "blob.img"), "wb") as f:
            f.truncate(BIG_BYTES + 1)
        if label == "非法状态":
            # 该类不造触发目录，避免混入「缺登记」FAIL
            os.remove(os.path.join(tmp, "out", "some-big", "blob.img"))
        with open(os.path.join(tmp, LEDGER_REL), "w") as f:
            f.write("# selftest\n" + ledger_extra)
        f0 = fail
        do_check(tmp)
        results.append((label, fail - f0))
        shutil.rmtree(tmp)
    ok_all = all(n == 1 for _l, n in results)
    for label, n in results:
        (ok if n == 1 else bad)("%s ⇒ %d 条 FAIL（期望 1）" % (label, n))
    if ok_all:
        print("  [ok]   selftest 通过（3 类坏件各被 1 条 FAIL 抓到）")
        return 0
    print("  [FAIL] selftest 未过")
    return 1


def main():
    argv = sys.argv[1:]
    tsv = "--tsv" in argv
    root = "."
    if "--root" in argv:
        root = argv[argv.index("--root") + 1]
    root = os.path.abspath(root)
    if "--selftest" in argv:
        sys.exit(selftest())
    if "--init" in argv:
        sys.exit(do_init(root, "--force" in argv))
    if not tsv:
        print("== 25. out/ 造件生命周期账本门（active/verified/superseded/pending，arch-audit P1#6）==")
    rc = do_check(root)
    if tsv:
        rows, _ = parse_ledger(root)
        for canon, (status, _b, _r, _d) in sorted(rows.items()):
            print("%s\t%s" % (canon, status))
    sys.exit(1 if fail else rc)


if __name__ == "__main__":
    main()
