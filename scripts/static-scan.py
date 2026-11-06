#!/usr/bin/env python3
"""static-scan.py — check-doctor §6 的静态卫生扫描（bashism / 死脚本）。

为什么独立成文件（2026-11-05 脚本审计）：
  这段逻辑原先内联在 scripts/check-doctor.sh 里（约 60 行 heredoc），是 doctor 的
  最大耗时项（实测 3.75 s / 全量 12.5 s），原因有两个：
    1) 语料用 os.walk 遍历整棵树，只排除了 15 个目录，**漏掉 build/** —— 实测把
       16738 个文件 / 424 MB（内核构建树的 scripts/kconfig、JSON、md）读进内存，
       而真正需要的是「活跃文档 + 脚本」这些 git 纳管文本。
    2) 死脚本判定写成 O(脚本数 × 语料文件数) 的 Python 内层子串比较
       （185 × 2.2 万次 in 判断，字符量 473 MB），单这一步就 ~5 s。
  语料改为 **git 纳管文本 + 未忽略的未跟踪文本**（`git ls-files` / `-o --exclude-standard`）：
  build/ out/ backup/ linux/ 等全被 .gitignore 排除，语料 473 MB → ~20 MB；
  再把 185 个脚本名合成**一条 alternation 正则**，对每个语料文件只扫一次。

判据与旧版等价（故意不改语义，避免同一轮里混入结论变化）：
  bashism = `#!/bin/sh` 脚本里出现 `[[` / `declare -` / `name=(` 数组赋值
  dead    = 该脚本 basename 没有出现在**任何其它**活跃文本文件里（子串，旧版即如此）
  已知局限（旧版同样存在，记为 WARN 不升级）：历史会话文件提到某脚本名也算「被引用」，
  故这条只能抓「从未被写过一次」的脚本，抓不到「写了但已不用」。

用法：
  scripts/static-scan.py            # 人类可读
  scripts/static-scan.py --tsv      # `TAG<TAB>值` 格式（check-doctor §6 消费）
  scripts/static-scan.py --json     # 机器可读
  scripts/static-scan.py --inventory # 全量可执行入口清单（path/行数/字节/live/hist/verdict）
  scripts/static-scan.py --root DIR # 指定仓库根（默认 = 本文件上级目录）
"""
import json
import os
import re
import subprocess
import sys

TEXT_EXT = ('.md', '.sh', '.py', '.tsv', '.json')

# 本工具自己的输出不得进语料：否则清单表会把每个脚本名都「引用」一次（--inventory 自吞）。
SELF_OUTPUT = ('versions/scripts-inventory.tsv',)
BASHISM_PAT = re.compile(r"\[\[(?!:)|declare -|[A-Za-z_][A-Za-z0-9_]*=\(")


def git(root, *args):
    return subprocess.run(('git', '-C', root) + args, capture_output=True, text=True)


def corpus(root):
    """活跃文本语料：git 纳管 + 未忽略的未跟踪；只留 TEXT_EXT。

    用 git pathspec 直接过滤后缀（`-- '*.md' '*.sh' …`）：git 的 pathspec glob 递归匹配，
    省掉「先列全仓再按后缀筛」的一遍。
    """
    spec = tuple('*%s' % e for e in TEXT_EXT)
    files = []
    for extra in ((), ('-o', '--exclude-standard')):
        r = git(root, 'ls-files', '-z', *extra, '--', *spec)
        if r.returncode != 0:
            continue
        files += [p for p in r.stdout.split('\0') if p.endswith(TEXT_EXT)]
    return sorted(set(files) - set(SELF_OUTPUT))


def bashisms(root, scripts):
    out = []
    for rel in scripts:
        try:
            body = open(os.path.join(root, rel), encoding='utf-8', errors='replace').read()
        except OSError:
            continue
        if body.startswith('#!/bin/sh') and BASHISM_PAT.search(body):
            out.append(os.path.basename(rel))
    return out


def _found_pairs_grep(root, names, corpus_files):
    """{(命中串): {命中文件名}}；grep -F（Aho-Corasick）扫一遍语料。

    为什么不用 Python 正则：等价的一条 alternation 正则扫 20 MB 实测 ~0.97 s（全语料
    没有早退机会，因为绝大多数脚本名都能被引用到）。grep -F 同一工作在 0.06 s 完成。
    """
    import tempfile
    with tempfile.NamedTemporaryFile('w', suffix='.pats', delete=False) as fh:
        fh.write('\n'.join(names) + '\n')
        pats = fh.name
    try:
        chunks = [corpus_files[i:i + 500] for i in range(0, len(corpus_files), 500)]
        pairs = {}
        for ch in chunks:
            r = subprocess.run(('grep', '-F', '-H', '-o', '-f', pats, '--') + tuple(ch),
                               cwd=root, capture_output=True, text=True, errors='replace')
            if r.returncode not in (0, 1):
                return None
            for line in r.stdout.splitlines():
                path, _, name = line.rpartition(':')
                if name:
                    pairs.setdefault(name, set()).add(path)
        return pairs
    finally:
        try:
            os.unlink(pats)
        except OSError:
            pass


def dead_scripts(root, scripts, corpus_files):
    names = sorted({os.path.basename(s) for s in scripts}, key=len, reverse=True)
    if not names:
        return []
    # 引用语义 = 旧版逐字：脚本 basename 出现在**别的**活跃文本文件里（子串命中）。
    # 只把自己排除在外（脚本里写自己的名字不算被引用）。
    own = {'scripts/' + n: n for n in names}
    pairs = _found_pairs_grep(root, names, corpus_files)
    if pairs is None:                                # grep 不可用 → 退回纯 Python
        pat = re.compile('|'.join(re.escape(n) for n in names))
        pairs = {}
        for rel in corpus_files:
            try:
                txt = open(os.path.join(root, rel), encoding='utf-8', errors='replace').read()
            except OSError:
                continue
            for n in set(pat.findall(txt)):
                pairs.setdefault(n, set()).add(rel)
    dead = []
    for n in names:
        refs = pairs.get(n, set())
        if not any(rel != own.get(n) for rel in refs):
            dead.append(n)
    return dead


HIST_PAT = re.compile(r'(^|/)(reports|sessions|plans|archive)/|^\.pi/plans/')


def inventory(root, scripts, cfiles):
    """全量可执行入口清单（2026-11-06 整理轮新增）。

    与 dead_scripts() 的区别：不只判「有没有人提过」，而是把引用分成**两类**——
      live = 入口文档（INDEX/TASKS/RESOURCES/…/AGENTS/README）与非历史文档/脚本里的引用；
      hist = 只出现在 reports/ | */sessions/ | .pi/plans/ | archive/ 里的引用。
    “hist>0 且 live=0” 的脚本 = 只能从历史记录里得知的入口：它们未必是死的（例：
    gpt-restore 只写在报告里），但**缺一个受管注册点**，正是历轮整理反复重查的那批。

    输出列：path / ext / lines / bytes / live / hist / verdict
    verdict：live=LIVE / hist=HIST-ONLY / none=UNREFERENCED（由本工具判定；人工裁决记在
    `PITFALLS/sessions/15-过时废弃功能缺陷登记.md` §15.1，本工具不读也不改它）。
    """
    names = sorted({os.path.basename(s) for s in scripts}, key=len, reverse=True)
    pairs = _found_pairs_grep(root, names, cfiles) if names else {}
    rows = []
    for rel in scripts:
        base = os.path.basename(rel)
        refs = {p for p in (pairs or {}).get(base, set()) if p != rel}
        hist = sorted(p for p in refs if HIST_PAT.search(p))
        live = sorted(refs - set(hist))
        verdict = 'LIVE' if live else ('HIST-ONLY' if hist else 'UNREFERENCED')
        try:
            body = open(os.path.join(root, rel), encoding='utf-8', errors='replace').read()
            lines, size = body.count('\n'), len(body.encode())
        except OSError:
            lines = size = 0
        rows.append((rel, os.path.splitext(rel)[1], lines, size, len(live), len(hist), verdict))
    rows.sort(key=lambda r: (r[6] != 'UNREFERENCED', r[6] != 'HIST-ONLY', r[0]))
    return rows


def main(argv):
    root = None
    mode = 'tsv'
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == '--root':
            i += 1
            root = os.path.abspath(argv[i])
        elif a == '--json':
            mode = 'json'
        elif a == '--tsv':
            mode = 'tsv'
        elif a == '--human':
            mode = 'human'
        elif a == '--inventory':
            mode = 'inventory'
        elif a in ('-h', '--help'):
            print(__doc__)
            return 0
        else:
            print('static-scan.py: 未知参数 %s' % a, file=sys.stderr)
            return 2
        i += 1
    if root is None:
        root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if git(root, 'rev-parse', '--show-toplevel').returncode != 0:
        print('static-scan.py: %s 不是 git 仓库' % root, file=sys.stderr)
        return 2

    scripts = [p for p in git(root, 'ls-files', '-z', '--', 'scripts/*.sh').stdout.split('\0')
               if re.match(r'^scripts/[^/]+\.sh$', p)]
    cfiles = corpus(root)
    if mode == 'inventory':
        spec = ('scripts/*.sh', 'scripts/*.py', 'scripts/*/*.sh', 'scripts/*/*.py',
                'initramfs/*.sh', 'rootfs/*.sh', 'rootfs/*.py', 'rootfs/*/*.sh', 'rootfs/*/*.py',
                'tools/*.py', 'tools/*/*.sh', 'tools/*/*.py', 'packaging/*/*/*.sh')
        alls = [p for p in git(root, 'ls-files', '-z', '--', *spec).stdout.split('\0') if p]
        print('path\text\tlines\tbytes\tlive\thist\tverdict')
        for r in inventory(root, alls, cfiles):
            print('\t'.join(str(x) for x in r))
        return 0
    res = {'BASHISM': bashisms(root, scripts),
           'DEAD': dead_scripts(root, scripts, cfiles),
           'scripts': len(scripts), 'corpus': len(cfiles)}

    if mode == 'json':
        print(json.dumps(res, ensure_ascii=False, indent=2))
    elif mode == 'human':
        for tag in ('BASHISM', 'DEAD'):
            print('%-8s %s' % (tag, ', '.join(res[tag]) or '-'))
        print('（脚本 %d 个 / 语料 %d 个文件）' % (res['scripts'], res['corpus']))
    else:
        for tag in ('BASHISM', 'DEAD'):
            print('%s\t%s' % (tag, ','.join(res[tag]) or '-'))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
