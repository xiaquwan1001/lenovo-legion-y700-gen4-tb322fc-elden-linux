#!/usr/bin/env python3
"""reports-orphan-check.py — `reports/*.md` 是否被「角度层」指针引用（可复跑判据 + 反作弊 + 自测）。

立此脚本的原因（2026-11-26，TASKS/NEXT.md §4.0a T10 / `reports/arch-audit-20261127.md` A16）：
A16 判「468 篇报告无角度 README 指针」，但那个数字**没有落成脚本**，所以每次都得手数、且手数
口径不同（实测 A16 的 225/32.5% 与 468/59 在下面三种语料刻度上都复现不出来）。本脚本把口径固定死。

## 口径（三个刻度，一次全出，避免「换个语料数字就变」）
- `readme`：只算 7 个角度 `README.md`（`DEVICE/ TASKS/ RESOURCES/ RUNBOOK-BRINGUP/ PITFALLS/
  SESSIONS/ HISTORY/`）—— A16「仅角度 README 引用」那一档；
- `top`：上一档 + 角度文件夹**顶层**所有 `*.md`（`TASKS/G1.md`、`TASKS/NEXT.md`、`TASKS/GAPS.md`、
  `TASKS/dim/*.md` … 它们是章节正文，属于角度层策展面）；
- `all`（默认 / `--check` 的判据）：上一档 + 各角度 `sessions/**`（含 T12 归档的 `*.md.gz`）。

**`reports/README.md` 永不计入语料**：它是 `scripts/reports-index.py` 机器生成的全量目录，
收录每一篇（含孤儿），把它算成指针等于自证清白 —— 这正是 `scripts/doctor/s07-08-docs.py` §8f
判别力≈0 的原因（它的语料是「全仓 md/sh/py/tsv 含 reports/ 自身」）。

## 反作弊（否则「一行塞几十个文件名」就能刷绿）
一条**合规指针行**必须同时满足：
1. 行内出现的 `reports/*.md` **不同文件名 ≤ 4 个**（实测真实 README 的上限就是 4：PITFALLS 去重
   审计那行；把清单当指针用会撞这条）；
2. 去掉所有 `*.md` 路径 token 与 `§N` 后，剩下的**非空白字符 ≥ 8**（= 同一行要有一句用途说明；
   纯 `- `reports/x.md`` 这种「裸列表」剩 0–2 字，判不合格）；
3. 该行不是「标题行/围栏行」（`#` 开头、` ``` ` 开头的不算指针）。

`--selftest` 把这 3 条 + 语料排除规则逐条造正/负样本断言（假孤儿必须被判红）。

## 用法
```
scripts/reports-orphan-check.py                 # 三刻度数字 + 孤儿清单（默认 all 刻度的清单）
scripts/reports-orphan-check.py --scale readme   # 只看 README 刻度
scripts/reports-orphan-check.py --list-all       # 打印 all 刻度孤儿（默认就是）
scripts/reports-orphan-check.py --json           # 机读
scripts/reports-orphan-check.py --check          # 门：all 刻度有孤儿 ⇒ rc=1；全部有指针 ⇒ rc=0
scripts/reports-orphan-check.py --check --audit-ledger reports/orphan-triage-20261127.tsv
                                                 # 顺带核台账：pointer 行是否真在 README 里、
                                                 # archived 头部是否真有 `archived=<存在目标>`
scripts/reports-orphan-check.py --selftest       # 反作弊阴性对照（零写盘，只读 + 临时目录）
```
"""
import argparse
import gzip
import os
import re
import sys
import tempfile

ANGLES = ['DEVICE', 'TASKS', 'RESOURCES', 'RUNBOOK-BRINGUP', 'PITFALLS', 'SESSIONS', 'HISTORY']
SCALES = ('readme', 'top', 'all')
MAX_NAMES_PER_LINE = 4     # 实测真实 README 单行最多 4 个报告名（PITFALLS 去重审计那行）
PROSE_MIN = 8              # 去掉路径后至少还剩这么多个非空白字符

RE_MDTOK = re.compile(r'\S*\.md\b')
RE_SECNO = re.compile(r'§\s*\d+(?:\.\d+)*')
# 只留「人写的字」：去掉 markdown 装饰与标点，剩的字符数才代表一句说明
RE_DECOR = re.compile(r'[`*_>|#\-–—~=+•·:：()\[\]{}<>,，.。、;；!！?？/\\\'"]+')


def eprint(*a):
    print(*a, file=sys.stderr)


def read_text(path):
    """读文本；`.md.gz`（T12 归档会话）透明解压。失败返回 ''。"""
    try:
        if path.endswith('.gz'):
            with gzip.open(path, 'rt', encoding='utf-8', errors='replace') as fh:
                return fh.read()
        with open(path, encoding='utf-8', errors='replace') as fh:
            return fh.read()
    except (OSError, EOFError):
        return ''


def corpus_files(root, scale):
    """角度层语料文件清单。`reports/` 下一个文件都不进（防自证）。"""
    out = []
    for ang in ANGLES:
        d = os.path.join(root, ang)
        readme = os.path.join(d, 'README.md')
        if os.path.isfile(readme):
            out.append(readme)
        if not os.path.isdir(d):
            continue
        if scale in ('top', 'all'):
            for name in sorted(os.listdir(d)):
                p = os.path.join(d, name)
                if os.path.isfile(p) and name.endswith('.md'):
                    out.append(p)
        if scale == 'all':
            sdir = os.path.join(d, 'sessions')
            for dp, _dns, fns in os.walk(sdir):
                for fn in sorted(fns):
                    if fn.endswith('.md') or fn.endswith('.md.gz'):
                        out.append(os.path.join(dp, fn))
    return out


def report_files(root):
    rp = os.path.join(root, 'reports')
    if not os.path.isdir(rp):
        return []
    return sorted(f for f in os.listdir(rp)
                  if f.endswith('.md') and f != 'README.md' and os.path.isfile(os.path.join(rp, f)))


def line_has_pointer(line, name):
    """单行是否构成 `name` 的**合规**指针。返回 (ok, 原因)。"""
    if name not in line:
        return False, 'no-name'
    stripped = line.lstrip()
    if stripped.startswith('#') or stripped.startswith('```'):
        return False, 'heading-or-fence'
    n_names = len(set(RE_MDTOK.findall(line)))
    if n_names > MAX_NAMES_PER_LINE:
        return False, 'too-many-names(%d>%d)' % (n_names, MAX_NAMES_PER_LINE)
    residue = RE_MDTOK.sub(' ', line)
    residue = RE_SECNO.sub(' ', residue)
    residue = RE_DECOR.sub(' ', residue)
    n_prose = len(''.join(residue.split()))
    if n_prose < PROSE_MIN:
        return False, 'no-purpose-sentence(%d<%d)' % (n_prose, PROSE_MIN)
    return True, 'ok'


def scan(root, scale, names=None):
    """→ {report_name: [(file, lineno, line)]}（只含合规指针行）。"""
    names = list(names if names is not None else report_files(root))
    want = set(names)
    hits = {n: [] for n in names}
    for path in corpus_files(root, scale):
        txt = read_text(path)
        if not txt:
            continue
        rel = os.path.relpath(path, root)
        for i, line in enumerate(txt.split('\n'), 1):
            present = [n for n in want if n in line]
            if not present:
                continue
            for n in present:
                ok, _why = line_has_pointer(line, n)
                if ok:
                    hits[n].append((rel, i, line.strip()[:160]))
    return hits


def ledger_rows(path):
    """读台账 `file<TAB>action<TAB>target_or_reason<TAB>evidence`；坏行忽略并回报。"""
    rows, bad = [], []
    if not path or not os.path.isfile(path):
        return rows, bad
    for i, line in enumerate(open(path, encoding='utf-8', errors='replace'), 1):
        if not line.strip() or line.lstrip().startswith('#'):
            continue
        parts = line.rstrip('\n').split('\t')
        if len(parts) < 4:
            bad.append((i, line.rstrip()[:80]))
            continue
        rows.append({'file': parts[0].strip(), 'action': parts[1].strip(),
                     'target': parts[2].strip(), 'evidence': parts[3].strip(), 'line': i})
    return rows, bad


def audit_ledger(root, rows):
    """台账是否与磁盘对得上（防「列个清单就宣称处置完」）。"""
    problems, ok = [], 0
    for r in rows:
        f = r['file']
        p = os.path.join(root, f)
        if not os.path.isfile(p):
            problems.append('L%d %s: 文件不存在' % (r['line'], f))
            continue
        if r['action'] == 'pointer':
            # pointer 必须真在该角度 README（或角度顶层 md）里，且是合规行
            name = os.path.basename(f)
            hit = []
            for ang in ANGLES:
                for cand in [os.path.join(ang, 'README.md')] + [
                        os.path.join(ang, n) for n in sorted(os.listdir(os.path.join(root, ang)))
                        if n.endswith('.md')] if os.path.isdir(os.path.join(root, ang)) else []:
                    cp = os.path.join(root, cand)
                    if not os.path.isfile(cp):
                        continue
                    for ln in read_text(cp).split('\n'):
                        if name in ln and line_has_pointer(ln, name)[0]:
                            hit.append(os.path.relpath(cp, root))
            if not hit:
                problems.append('L%d %s: 声称 pointer 但角度层找不到合规指针行' % (r['line'], f))
            else:
                ok += 1
        elif r['action'] == 'archived':
            head = read_text(p).split('\n')[:6]
            m = None
            for ln in head:
                m = re.search(r'archived=(\S+)', ln)
                if m:
                    break
            if not m:
                problems.append('L%d %s: 声称 archived 但头部无 archived=' % (r['line'], f))
            elif not os.path.exists(os.path.join(root, m.group(1))):
                problems.append('L%d %s: archived 指向不存在的 %s' % (r['line'], f, m.group(1)))
            else:
                ok += 1
        else:
            problems.append('L%d %s: 未知 action %r' % (r['line'], f, r['action']))
    return ok, problems


# ---------------------------------------------------------------- selftest
_SELF_CASES = [
    # (说明, 语料文件相对路径, 语料内容, 报告名, 期望是否既有指针, 期望原因前缀)
    ('合规指针行（结论 + 破折号 + 路径）', 'DEVICE/README.md',
     '# 设备\n\n- **UEFI 两种形态都通，根因是 dtbo_a** —— `reports/zz-a.md`\n', 'zz-a.md', True, 'ok'),
    ('裸列表（只有路径）必须判红', 'DEVICE/README.md',
     '# 设备\n\n- `reports/zz-b.md`\n', 'zz-b.md', False, 'no-purpose'),
    ('一行塞 10 个文件名（灌水）必须判红', 'PITFALLS/README.md',
     '# 踩坑\n\n| 一批 | ' + ' '.join('`reports/zz-c%d.md`' % i for i in range(10)) + ' |\n',
     'zz-c0.md', False, 'too-many-names'),
    ('说明只有 2 个字（`见 …`）必须判红', 'TASKS/README.md',
     '# 任务\n\n见 `reports/zz-d.md`\n', 'zz-d.md', False, 'no-purpose'),
    ('只在标题行出现不算指针', 'RESOURCES/README.md',
     '# 资源\n\n## `reports/zz-e.md` 的复现\n', 'zz-e.md', False, 'heading-or-fence'),
    ('表格行里带用途说明算指针', 'TASKS/GAPS.md',
     '# 缺漏\n\n| Q24 | 已关闭 | 根因见 `reports/zz-f.md` §3 |\n', 'zz-f.md', True, 'ok'),
    ('一条说明 + 两个路径仍算指针（≤4）', 'DEVICE/README.md',
     '# 设备\n\n- **去重审计：13 组重复已收敛为指针** —— `reports/zz-g.md` + `reports/zz-h.md`\n',
     'zz-g.md', True, 'ok'),
]


def _mk_tree(base, cases, extra=None):
    """按用例建临时仓库树；extra = [(relpath, content)] 额外落盘（如 reports/README.md）。"""
    os.makedirs(os.path.join(base, 'reports'), exist_ok=True)
    for _d, rel, content, name, _want, _why in cases:
        os.makedirs(os.path.join(base, os.path.dirname(rel)), exist_ok=True)
        with open(os.path.join(base, rel), 'w', encoding='utf-8') as fh:
            fh.write(content)
        pb = os.path.join(base, 'reports', name)
        if not os.path.exists(pb):
            with open(pb, 'w', encoding='utf-8') as fh:
                fh.write('# %s 假报告\n' % name)
    for rel, content in (extra or []):
        p = os.path.join(base, rel)
        os.makedirs(os.path.dirname(p) or base, exist_ok=True)
        with open(p, 'w', encoding='utf-8') as fh:
            fh.write(content)


def selftest(verbose=True):
    fails = 0

    def chk(cond, label, detail=''):
        nonlocal fails
        if cond:
            if verbose:
                print('  [ok]   %s%s' % (label, ('  — ' + detail) if detail else ''))
        else:
            fails += 1
            print('  [FAIL] %s  %s' % (label, detail))

    # --- ① 逐行合规性（分类器层）
    for label, rel, content, name, want, why in _SELF_CASES:
        with tempfile.TemporaryDirectory() as d:
            _mk_tree(d, [(label, rel, content, name, want, why)])
            hits = scan(d, 'top', [name])
            got = bool(hits[name])
            chk(got == want, '分类器: ' + label,
                '期望 %s 实得 %s（%s）' % (want, got,
                                        hits[name][-1][0] + ':' + str(hits[name][-1][1])
                                        if hits[name] else 'no-hit'))

    # --- ② 真·假孤儿必须被判出（扫全量口径，期望 ORPHAN=1 且 rc 会红）
    with tempfile.TemporaryDirectory() as d:
        _mk_tree(d, [
            ('假孤儿', 'DEVICE/README.md', '# 设备\n', 'zz-lonely.md', False, 'no-name'),
        ] + [('已覆盖件', 'DEVICE/README.md', '', 'zz-covered.md', True, 'ok')])
        with open(os.path.join(d, 'DEVICE', 'README.md'), 'w', encoding='utf-8') as fh:
            fh.write('# 设备\n\n- **已覆盖的那篇：结论一句话** —— `reports/zz-covered.md`\n')
        names = report_files(d)
        hits = scan(d, 'all', names)
        orph = [n for n in names if not hits[n]]
        chk(orph == ['zz-lonely.md'], '端到端: 假孤儿被单独判出（TOTAL=2 REFERENCED=1 ORPHAN=1）',
            'ORPHAN=%r' % orph)
        rc = 1 if orph else 0
        chk(rc == 1, '端到端: 有孤儿时 rc=1', 'rc=%d' % rc)
        # 处置后转绿：给假孤儿补一条合规指针 ⇒ rc 必须变 0
        with open(os.path.join(d, 'DEVICE', 'README.md'), 'a', encoding='utf-8') as fh:
            fh.write('- **补上的结论：这条路径已复核** —— `reports/zz-lonely.md`\n')
        hits = scan(d, 'all', names)
        orph2 = [n for n in names if not hits[n]]
        chk(orph2 == [], '端到端: 补指针后 rc=0（判据可双向翻转）', 'ORPHAN=%r' % orph2)

    # --- ③ 语料排除 `reports/README.md`（否则机器目录＝自证清白）
    with tempfile.TemporaryDirectory() as d:
        _mk_tree(d, [('空角度', 'DEVICE/README.md', '# 设备\n', 'zz-idx.md', False, '')],
                 extra=[('reports/README.md', '# 索引\n\n| `zz-idx.md` | 全量目录自动收录 |\n')])
        hits = scan(d, 'all', ['zz-idx.md'])
        chk(hits['zz-idx.md'] == [], '语料: reports/README.md 里的收录**不算**指针',
            'hits=%r' % hits['zz-idx.md'])

    # --- ④ `.md.gz`（T12 归档会话）必须能被读到
    with tempfile.TemporaryDirectory() as d:
        _mk_tree(d, [('gz会话', 'TASKS/README.md', '# 任务\n', 'zz-gz.md', True, 'ok')])
        os.makedirs(os.path.join(d, 'TASKS', 'sessions'), exist_ok=True)
        with gzip.open(os.path.join(d, 'TASKS', 'sessions', '2026-01-01-x.md.gz'),
                       'wt', encoding='utf-8') as fh:
            fh.write('**结论：gz 会话里的指针也算** —— `reports/zz-gz.md`\n')
        hits = scan(d, 'all', ['zz-gz.md'])
        chk(bool(hits['zz-gz.md']), '语料: *.md.gz 会话里的合规指针算数',
            'hits=%d' % len(hits['zz-gz.md']))
        # 但 readme 刻度不该看见它
        hits_r = scan(d, 'readme', ['zz-gz.md'])
        chk(not hits_r['zz-gz.md'], '刻度: 同一篇在 readme 刻度上仍是孤儿（三刻度互不污染）')

    print('\nSELFTEST: %d 条断言，FAIL=%d' % (
        len(_SELF_CASES) + 6, fails))
    return 0 if fails == 0 else 1


# ---------------------------------------------------------------- main
def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--root', default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    ap.add_argument('--scale', choices=SCALES, default='all', help='清单用哪个刻度（默认 all）')
    ap.add_argument('--check', action='store_true', help='门：all 刻度有孤儿 ⇒ rc=1')
    ap.add_argument('--selftest', action='store_true', help='反作弊阴性对照（零写盘）')
    ap.add_argument('--json', action='store_true', help='机读输出')
    ap.add_argument('--list', dest='show_list', action='store_true', default=True)
    ap.add_argument('--no-list', dest='show_list', action='store_false')
    ap.add_argument('--limit', type=int, default=0, help='清单最多打印 N 行（0=全打）')
    ap.add_argument('--audit-ledger', default='', help='顺带核对台账 TSV（pointer/archived 是否落实）')
    args = ap.parse_args(argv)

    if args.selftest:
        print('== reports-orphan-check --selftest（反作弊阴性对照；不写仓库任何文件）==')
        return selftest()

    root = args.root
    names = report_files(root)
    if not names:
        eprint('FATAL: %s 下没有 reports/*.md' % root)
        return 2

    per = {}
    for sc in SCALES:
        hits = scan(root, sc, names)
        orph = [n for n in names if not hits[n]]
        per[sc] = {'total': len(names), 'referenced': len(names) - len(orph), 'orphan': orph,
                   'hits': {n: v for n, v in hits.items() if v}}

    gate = per['all']
    ratio = 100.0 * gate['referenced'] / gate['total']

    if args.json:
        import json
        print(json.dumps({sc: {'total': per[sc]['total'], 'referenced': per[sc]['referenced'],
                               'orphan': per[sc]['orphan']} for sc in SCALES},
                         ensure_ascii=False, indent=1))
    else:
        print('== reports/*.md 角度层指针判据（语料 = 角度 README ± 顶层 md ± sessions/*.md[.gz]；'
              'reports/README.md 不计）==')
        print('   反作弊：一行 ≤%d 个报告名，且去掉路径后须有 ≥%d 字用途说明'
              % (MAX_NAMES_PER_LINE, PROSE_MIN))
        for sc in SCALES:
            p = per[sc]
            print('  [%-6s] TOTAL=%d  REFERENCED=%d  ORPHAN=%d  (有指针 %.1f%%)'
                  % (sc, p['total'], p['referenced'], len(p['orphan']),
                     100.0 * p['referenced'] / p['total']))
        print('  [gate] 判据刻度 = all：有指针 %.1f%% / 孤儿 %d 篇' % (ratio, len(gate['orphan'])))
        p = per[args.scale]
        if args.show_list and p['orphan']:
            shown = p['orphan'] if not args.limit else p['orphan'][:args.limit]
            print('\n-- 孤儿清单（scale=%s，%d 篇%s）--'
                  % (args.scale, len(p['orphan']),
                     '' if len(shown) == len(p['orphan']) else '，只打前 %d' % len(shown)))
            for n in shown:
                print('  ' + n)

    rc = 0
    if args.audit_ledger:
        rows, bad = ledger_rows(args.audit_ledger)
        okn, probs = audit_ledger(root, rows)
        print('\n-- 台账核对 %s：%d 行，落实 %d，问题 %d --'
              % (args.audit_ledger, len(rows), okn, len(probs) + len(bad)))
        for i, ln in bad:
            print('  [bad] 行 %d 列数不足 4：%s' % (i, ln))
        for pr in probs:
            print('  [bad] ' + pr)
        if probs or bad:
            rc = 1
        # 台账已 pointer 但 all 刻度仍孤儿 ⇒ 指针写歪了（提示，不单独判红）
        led = {os.path.basename(r['file']) for r in rows if r['action'] == 'pointer'}
        orphan_set = set(gate['orphan'])
        stale = sorted(led & orphan_set)
        if stale:
            print('  [warn] 台账标了 pointer 但 all 刻度仍未命中：%d 篇（%s%s）'
                  % (len(stale), ', '.join(stale[:5]), ' …' if len(stale) > 5 else ''))

    if args.check:
        if gate['orphan']:
            eprint('\nCHECK FAIL: all 刻度仍有 %d 篇孤儿报告（有指针 %.1f%% < 100%%）'
                   % (len(gate['orphan']), ratio))
            rc = 1
        else:
            print('\nCHECK OK: all 刻度 0 孤儿（%d 篇全部有角度层合规指针）' % gate['total'])
    return rc


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
