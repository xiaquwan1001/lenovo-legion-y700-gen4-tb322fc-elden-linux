#!/usr/bin/env python3
"""30-tasks-routing.py — TASKS 台账「章节路由」门（2026-11-26 拆分后新增）

拆分的由来与验收账 = `.pi/plans/2026-11-26-TASKS拆分.md`（210389 B → 6280 B；6 章 sha256 与源切片逐字相等）。

本门拦两类**静默**故障（都是拆分后才可能出现的）：
  ① 路由指错 —— `TASKS/README.md` 路由表写 `§5 → TASKS/GAPS.md`，而该文件不存在，
     或文件里第一个 `## <N>.` 标题号与该行声明的 §N 不一致（读者按号找不到，脚本不报）；
  ② 悬空引用 —— 活面（入口/纪律/脚本/报告模板）里写了 `TASKS/README.md` + 越界节号，
     而路由表没有该号。
     历史 citations 不改写（口径见 README 路由表），但**引用的号必须仍可解析**。

判据（宁吵不静默）：
  * 路由表必须覆盖 §1–§7 全部 7 个号；每行反引号里的 `TASKS/*.md` 必须真实存在；
  * 每章文件里第一个 `^## <N>.` 标题的数字必须 == 声明号（章节标题逐字保留是计数门的契约）；
  * 活面里每个 `TASKS/README.md §N` 的 N 必须 ∈ 路由表，或 N == 0（§0 在 README 本体）；
  * 路由表抓不到（格式变了）即 FAIL —— 不允许「抓不到就跳过」。

用法（与其它子门同契约：只打印 `  [ok]/[FAIL]/[warn]` 行，退出码不参与判定）：
  scripts/doctor/30-tasks-routing.py              # 人读（= doctor 内输出）
  scripts/doctor/30-tasks-routing.py --root DIR   # 指定仓库根
  scripts/doctor/30-tasks-routing.py --selftest   # 负向控制：坏路由表 / 悬空引用必须变红
"""
import os
import re
import sys
import glob
import tempfile

ARGS = sys.argv[1:]
SELFTEST = '--selftest' in ARGS
ROOT = ARGS[ARGS.index('--root') + 1] if '--root' in ARGS else (
    os.environ.get('ROOT') or os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..')))

README = 'TASKS/README.md'
REQUIRED = [1, 2, 3, 4, 5, 6, 7]

# 活面 = 人/agent 会照着找东西的地方（历史 sessions 与 archive 不扫：它们是沿革，不改写）
LIVE_FILES = ['INDEX.md', 'README.md', 'AGENTS.md', 'PROGRESS.md',
              '.pi/AGENT-OPS.md', '.pi/ORCHESTRATION.md', '.pi/README.md',
              README, 'PITFALLS/README.md', 'DEVICE/README.md', 'RESOURCES/README.md',
              'RUNBOOK-BRINGUP/README.md']
LIVE_DIRS = [('.pi', ('.md',)), ('scripts', ('.sh', '.py')),
             ('RUNBOOK-BRINGUP', ('.md',)), ('TASKS', ('.md',))]

RE_ROUTE = re.compile(r'^\|\s*([§\d\s·]+)\|\s*`(TASKS/[A-Za-z0-9._-]+\.md)`')
RE_REF = re.compile(r'TASKS/README\.md[`\s]*§\s*(\d+)')
# §4.0 维度短表 → TASKS/dim/D##.md（2026-11-26 第二轮拆分：双向对账防孤儿/悬空）
RE_DIM = re.compile(r'`(TASKS/dim/(D\d+)\.md)`')


def read(path):
    try:
        return open(path, encoding='utf-8', errors='replace').read()
    except OSError:
        return None


def parse_routes(root):
    """README 路由表 → {节号: 文件}；抓不到返回 None（格式变了要吵）。"""
    txt = read(os.path.join(root, README))
    if txt is None:
        return None
    routes, seen_tbl = {}, False
    for ln in txt.split('\n'):
        if not ln.startswith('|'):
            continue
        m = RE_ROUTE.match(ln)
        if not m:
            continue
        seen_tbl = True
        nums = [int(x) for x in re.findall(r'§\s*(\d+)', m.group(1))]
        for n in nums:
            routes[n] = m.group(2)
    return routes if seen_tbl else None


def heading_nos(root, rel):
    """章节文件里出现的所有 `## <N>.` 号（一个文件可承载多个号：§2 · §3 共用 G2.md）。"""
    txt = read(os.path.join(root, rel))
    if txt is None:
        return None
    return [int(m.group(1)) for m in (re.match(r'^##\s+(\d+)\.', ln) for ln in txt.split('\n'))
            if m]


def live_surface(root):
    out = []
    for rel in LIVE_FILES:
        p = os.path.join(root, rel)
        if os.path.isfile(p):
            out.append(p)
    for d, exts in LIVE_DIRS:
        base = os.path.join(root, d)
        for dp, dns, fns in os.walk(base):
            dns[:] = [x for x in dns if x not in {'sessions', 'archive', 'out', 'build',
                                                  'node_modules', '__pycache__'}]
            for fn in fns:
                if fn.endswith(exts) and not fn.startswith('.trash'):
                    out.append(os.path.join(dp, fn))
    return sorted(set(out))


def check(root, verbose=True):
    """返回 (fails, oks)；fails = [(标题, 明细)]。"""
    fails, oks = [], []
    routes = parse_routes(root)
    if routes is None:
        fails.append(('路由表可解析', '%s 里抓不到 `| §N | `TASKS/*.md` |` 形式的章节路由行'
                      '（格式变了；不允许静默跳过）' % README))
        return fails, oks
    oks.append(('路由表可解析', '%d 条章节路由' % len(routes)))

    missing = [n for n in REQUIRED if n not in routes]
    if missing:
        fails.append(('路由表覆盖 §1–§7', '缺号 %s（读者按号找不到）'
                      % ', '.join('§%d' % n for n in missing)))
    else:
        oks.append(('路由表覆盖 §1–§7', '7/7 命中'))

    bad_head, heads = [], {}
    for n in sorted(routes):
        rel = routes[n]
        if rel not in heads:
            heads[rel] = heading_nos(root, rel)
        got = heads[rel]
        if got is None:
            bad_head.append('§%d → `%s`：文件不存在' % (n, rel))
        elif n not in got:
            bad_head.append('§%d → `%s`：文件里没有 `## %d.` 标题（实有 %s）'
                            % (n, rel, n, got or '无'))
    if bad_head:
        fails.append(('章节文件标题号与路由一致', '；'.join(bad_head)))
    else:
        oks.append(('章节文件标题号与路由一致', '%d/%d' % (len(routes), len(routes))))

    dangling, scanned, cited = [], 0, 0
    for p in live_surface(root):
        txt = read(p)
        if txt is None:
            continue
        scanned += 1
        for m in RE_REF.finditer(txt):
            cited += 1
            n = int(m.group(1))
            if n == 0:
                continue
            if n not in routes:
                line_no = txt[:m.start()].count('\n') + 1
                dangling.append('%s:%d `§%d`' % (os.path.relpath(p, root), line_no, n))
    if dangling:
        fails.append(('活面 §N 引用可解析',
                      '%d 处悬空（路由表无该号）：%s' % (len(dangling), '；'.join(dangling[:8]))))
    else:
        oks.append(('活面 §N 引用可解析', '%d 文件 / %d 处引用，全部命中' % (scanned, cited)))

    # ---- 维度文件双向对账（NEXT.md §4.0 短表 ↔ TASKS/dim/*.md ↔ dim/README.md 索引）----
    next_txt = read(os.path.join(root, 'TASKS/NEXT.md'))
    if next_txt is None:
        fails.append(('维度文件可对账', 'TASKS/NEXT.md 不存在（§4 是维度总表入口）'))
        return fails, oks
    cited_dims = set(RE_DIM.findall(next_txt))
    on_disk = sorted(os.path.basename(p2) for p2 in
                     glob.glob(os.path.join(root, 'TASKS/dim/D*.md')))
    ptr_files = {f for f, _ in cited_dims}
    dangling_dim = sorted(ptr_files - set('TASKS/dim/' + x for x in on_disk))
    orphan_dim = sorted(set(on_disk) - {os.path.basename(f) for f in ptr_files})
    idx_txt = read(os.path.join(root, 'TASKS/dim/README.md')) or ''
    idx_dims = {os.path.basename(f) for f in ptr_files if f in idx_txt}
    if dangling_dim or orphan_dim or len(idx_dims) != len(ptr_files):
        fails.append(('维度文件可对账',
                      '悬空指针 %s / 孤儿文件 %s / 索引缺 %d 条'
                      % (dangling_dim or '-', orphan_dim or '-', len(ptr_files) - len(idx_dims))))
    else:
        oks.append(('维度文件可对账', 'NEXT.md 指针 %d = 磁盘 %d = 索引 %d'
                    % (len(ptr_files), len(on_disk), len(idx_dims))))
    return fails, oks


def run(root):
    fails, oks = check(root)
    for title, detail in oks:
        print('  [ok]   %s（%s）' % (title, detail))
    for title, detail in fails:
        print('  [FAIL] %s —— %s' % (title, detail))
    return 1 if fails else 0


def selftest():
    """负向控制：三种坏形态必须变红，好形态必须绿。"""
    good_readme = '\n'.join(
        ['| 原节 | 文件 | 内容 |', '|---|---|---|'] +
        ['| §%d | `TASKS/C%d.md` | x |' % (n, n) for n in REQUIRED]) + '\n'
    cases = []
    for name, mutate, expect_fail in [
        ('正例：路由 7/7 + 引用 §0/§7', lambda d: None, False),
        ('反例 A：路由表漏 §5', lambda d: _write(d, README, good_readme.replace(
            '| §5 | `TASKS/C5.md` | x |\n', '')), True),
        ('反例 B：路由指向不存在的文件', lambda d: _write(d, README, good_readme.replace(
            'TASKS/C6.md', 'TASKS/NOPE.md')), True),
        ('反例 C：活面引用越界节号', lambda d: _write(
            d, 'INDEX.md', '见 `TASKS/README.md` ' + '\u00a79' + '\n'), True),
        ('反例 D：章节文件标题号不对', lambda d: _write(d, 'TASKS/C4.md', '## 9. 错号\n'), True),
        ('反例 E：路由表整块缺失', lambda d: _write(d, README, '# 没有路由表\n'), True),
        ('反例 F：dim 指针悬空（文件不存在）', lambda d: _write(
            d, 'TASKS/NEXT.md', '| **D1** | x | ✅ | `TASKS/dim/D1.md` |\n`TASKS/dim/D9.md`\n'), True),
        ('反例 G：dim 孤儿文件（无指针）', lambda d: _write(d, 'TASKS/dim/D7.md', '## 7\n'), True),
    ]:
        with tempfile.TemporaryDirectory() as d:
            os.makedirs(os.path.join(d, 'TASKS'), exist_ok=True)
            _write(d, README, good_readme)
            _write(d, 'INDEX.md', '见 `TASKS/README.md` §0 / §7\n')
            for n in REQUIRED:
                _write(d, 'TASKS/C%d.md' % n, '## %d. 第 %d 章\n' % (n, n))
            _write(d, 'TASKS/NEXT.md', '| **D1** | x | ✅ | `TASKS/dim/D1.md` |\n')
            _write(d, 'TASKS/dim/D1.md', '## 1\n')
            _write(d, 'TASKS/dim/README.md', '见 `TASKS/dim/D1.md`\n')
            mutate(d)
            fails, _ = check(d)
            got_fail = bool(fails)
            ok_case = got_fail == expect_fail
            cases.append((name, ok_case, fails[0][0] if fails else '-'))
    print('\n== 30. TASKS 章节路由（§N → 章节文件，拆分后防漏号/悬空） ==')
    bad = [c for c in cases if not c[1]]
    if bad:
        print('  [FAIL] 自检未过：%s'
              % '；'.join('%s（期望变红=%s，实得=%s）' % (n, '是' if e else '否', '红' if r else '绿')
                         for n, okk, r in bad))
        return 1
    print('  [ok]   自检 %d/%d 通过（正例绿 + 5 类坏件各自变红）' % (len(cases), len(cases)))
    fails, oks = check(ROOT)
    for title, detail in oks:
        print('  [ok]   %s（%s）' % (title, detail))
    for title, detail in fails:
        print('  [FAIL] %s —— %s' % (title, detail))
    return 1 if fails else 0


def _write(root, rel, txt):
    p = os.path.join(root, rel)
    os.makedirs(os.path.dirname(p) or '.', exist_ok=True)
    with open(p, 'w', encoding='utf-8') as f:
        f.write(txt)


if __name__ == '__main__':
    if SELFTEST:
        sys.exit(selftest())
    print('\n== 30. TASKS 章节路由（§N → 章节文件，拆分后防漏号/悬空） ==')
    sys.exit(run(ROOT))
