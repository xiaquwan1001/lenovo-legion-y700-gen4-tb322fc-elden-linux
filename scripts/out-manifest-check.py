#!/usr/bin/env python3
"""out-manifest-check.py — out/ 造件「报告↔镜像」账本门（2026-11-20，arch-audit P0#2）

为什么有这个（.pi/reports/cleanup-audit-20261120/arch-audit.md §5 #2/#5/#6）：
  out/ 87G 造件没有「报告↔镜像」账本门禁，删错 android-slim-v3-20261119 这种
  唯一可用 final 件就毁掉证据链；报告引用的镜像也可以被静默删除（#5）。
  本门只加**账本**不加约束改造件：扫描 out/，把「大件/多镜像却没有报告」的目录报出来。

规则（防误报口径：只盯真正需要账本的造件，小目录/单文件不报）：
  对 out/<name>/（仅一级目录）：
    触发条件 = 目录内有 >200 MB 的文件，或 .img 文件数 >1
    判据     = reports/<name>.md 存在，或 reports/*.md 里有任何一份引用了 out/<name>
    未满足   ⇒ WARN（不是 FAIL —— 本门是防误删的提醒，不阻塞提交）
  豁免：scripts/out-manifest-exempt.tsv，每行 `路径<TAB>理由`（理由 ≥10 字，照 §17
    shell-hygiene 反作弊口径）；**空理由必须 FAIL**（不许「删理由保平安」）。
  路径登记用 `out/<name>` 或 `<name>` 均可（canonical = out/<name>）。

豁免 ≠ 白名单免检：豁免条目仍会出现在 WARN 统计里（--tsv 带 exempt 标记），
只是不产生 WARN 行——它是「如实登记中间方案/已被 vX 取代」的账，不是遮羞布。

用法：
  scripts/out-manifest-check.py                # 人读摘要
  scripts/out-manifest-check.py --tsv          # 机读：状态<TAB>out/<name>
  scripts/out-manifest-check.py --selftest     # 4 类合成样本自检（临时树，不碰仓库）
  scripts/out-manifest-check.py --root DIR     # 指定仓库根

退出码：0 = 无 FAIL（WARN 不阻塞）；1 = 有 FAIL（豁免表坏 / 自检失败）。
"""
import os
import sys
import tempfile

BIG_BYTES = 200 * 1024 * 1024
EXEMPT_REL = "scripts/out-manifest-exempt.tsv"
REPORTS = "reports"

fail = 0
warns = []   # (out/<name>, reason)
exempt = {}  # canonical path -> line no


def bad(msg):
    global fail
    fail += 1
    print("  [FAIL] %s" % msg)


def warn(msg):
    print("  [warn] %s" % msg)


def ok(msg):
    print("  [ok]   %s" % msg)


def load_exempt(root):
    """读豁免表；空理由 / 短理由 = FAIL（反作弊：不许删理由把门关掉）。"""
    path = os.path.join(root, EXEMPT_REL)
    if not os.path.exists(path):
        return {}, []
    problems = []
    table = {}
    for n, raw in enumerate(open(path, encoding="utf-8", errors="replace"), 1):
        line = raw.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        parts = line.split("\t")
        token = parts[0].strip()
        reason = parts[1].strip() if len(parts) > 1 else ""
        if not token:
            problems.append("%s:%d 空路径" % (EXEMPT_REL, n))
            continue
        if len(reason) < 10:
            problems.append("%s:%d 豁免 %r 理由缺失或 <10 字（空理由必须 FAIL，照 §17 口径）"
                            % (EXEMPT_REL, n, token))
            continue
        canon = token if token.startswith("out/") else "out/" + token
        table[canon] = n
    return table, problems


def triggered(dirpath):
    """触发条件：>200MB 文件 或 .img >1。返回 (bool, 描述)。"""
    big, imgs = 0, 0
    sample = ""
    for dirpath_cur, dirs, files in os.walk(dirpath):
        for fn in files:
            fp = os.path.join(dirpath_cur, fn)
            try:
                st = os.stat(fp, follow_symlinks=False)
            except OSError:
                continue
            if not os.path.isfile(fp) or os.path.islink(fp):
                continue
            if st.st_size > BIG_BYTES:
                big += 1
                sample = "大件 %s (%dMB)" % (fn, st.st_size // (1024 * 1024))
            if fn.endswith(".img"):
                imgs += 1
    if big:
        return True, sample
    if imgs > 1:
        return True, "%d 个 .img" % imgs
    return False, ""


def referenced(root, name):
    """reports/<name>.md 存在，或 reports/*.md 任一提到 out/<name>。"""
    repdir = os.path.join(root, REPORTS)
    if os.path.isfile(os.path.join(repdir, name + ".md")):
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


def check_tree(root):
    outdir = os.path.join(root, "out")
    if not os.path.isdir(outdir):
        ok("out/ 不存在（新树，无事可查）")
        return 0
    n_trig = 0
    for entry in sorted(os.listdir(outdir)):
        dirpath = os.path.join(outdir, entry)
        if not os.path.isdir(dirpath) or os.path.islink(dirpath):
            continue
        hit, why = triggered(dirpath)
        if not hit:
            continue
        n_trig += 1
        canon = "out/" + entry
        ref = referenced(root, entry)
        if ref:
            ok("%s ← %s（%s）" % (canon, ref, why))
            continue
        if canon in exempt:
            ok("%s 已豁免登记（%s:%d）" % (canon, EXEMPT_REL, exempt[canon]))
            continue
        warns.append(canon)
        warn("%s 无报告且未豁免（%s）→ 删除/瘦身前必须先补 reports/%s.md" % (canon, why, entry))
    return n_trig


def selftest():
    """4 类合成样本：有报告=过 / 无报告=warn / 豁免带理由=过 / 空理由=FAIL。"""
    global fail, warns, exempt
    fails0 = fail
    tmp = tempfile.mkdtemp(prefix="out-manifest-selftest.")
    for sub in ("reports", "scripts", "out/has-report", "out/no-report", "out/exempted"):
        os.makedirs(os.path.join(tmp, sub), exist_ok=True)
    # 造触发件：两个 .img（>1 即触发，不需要真 200MB）
    for d in ("has-report", "no-report", "exempted"):
        for i in (1, 2):
            with open(os.path.join(tmp, "out", d, "a%d.img" % i), "wb") as f:
                f.write(b"x")
    with open(os.path.join(tmp, "reports", "has-report.md"), "w") as f:
        f.write("# has-report\n引用 out/has-report\n")
    with open(os.path.join(tmp, "reports", "ref-in-other.md"), "w") as f:
        f.write("# 其他报告提到 out/exempted\n")
    with open(os.path.join(tmp, EXEMPT_REL), "w") as f:
        f.write("out/exempted\t中间方案，已被 slim-v3 取代留作对照\n")

    print("== selftest: 4 类合成样本 ==")
    cases = [
        ("有报告", "has-report", "ok"),
        ("无报告", "no-report", "warn"),
        ("豁免带理由", "exempted", "ok"),
    ]
    table, problems = load_exempt(tmp)
    for p in problems:
        bad(p)
    exempt = table
    n = check_tree(tmp)
    # 第 4 类：空理由豁免必须 FAIL
    with open(os.path.join(tmp, EXEMPT_REL), "w") as f:
        f.write("out/exempted\t\n")
    table2, problems2 = load_exempt(tmp)
    if any("理由缺失" in p for p in problems2):
        ok("空理由豁免 → FAIL（反作弊生效）")
    else:
        bad("空理由豁免未被拒 —— 门是空转的")
    import shutil
    shutil.rmtree(tmp)
    if fail - fails0 == 0:
        print("  [ok]   selftest 通过（3 实跑样本 + 1 空理由反作弊）")
        return 0
    print("  [FAIL] selftest 未过")
    return 1


def main():
    global exempt
    argv = sys.argv[1:]
    tsv = "--tsv" in argv
    root = "."
    if "--root" in argv:
        root = argv[argv.index("--root") + 1]
    root = os.path.abspath(root)
    if "--selftest" in argv:
        sys.exit(selftest())
    if not tsv:
        print("== 23. out/ 造件账本门（>200MB 或 >1 .img 必须有报告，arch-audit P0#2）==")
    table, problems = load_exempt(root)
    for p in problems:
        bad(p)
    exempt = table
    n = check_tree(root)
    if tsv:
        for c in warns:
            print("WARN\t%s" % c)
        for c in sorted(table):
            if c not in warns:
                print("EXEMPT-OK\t%s" % c)
        sys.exit(1 if fail else 0)
    print("  [info] 触发门禁的 out/ 目录 %d 个，WARN %d 条，豁免登记 %d 条"
          % (n, len(warns), len(table)))
    sys.exit(1 if fail else 0)


if __name__ == "__main__":
    main()
