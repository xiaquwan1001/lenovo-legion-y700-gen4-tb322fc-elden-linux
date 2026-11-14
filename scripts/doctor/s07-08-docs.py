#!/usr/bin/env python3
"""s07-08-docs.py — check-doctor §7/§8 入口文档与索引对账（纯文本判据）。

来源：这两节的逻辑原先内联在 check-doctor.sh 里（约 230 行 heredoc），是「改一条判据就要
动 649 行单体脚本」的典型。2026-11-05 脚本审计把它抽成独立可跑的子门：
  scripts/doctor/s07-08-docs.py            # 人读（同 doctor 输出格式）
  scripts/doctor/s07-08-docs.py --tsv      # `TAG<TAB>值`（机器消费）
  scripts/doctor/s07-08-docs.py --root DIR # 指定仓库根
判据本体**一行未改**（只把 `emit` 从「打印 TAG」改成「收集后按 §7/§8 分组打印」），
这样这次重构的验收判据就是「输出行集合与旧版逐行相同」。
"""
import sys as _sys

_args = _sys.argv[1:]
if '--tsv' in _args:
    _TSV = True
else:
    _TSV = False
_root_from_argv = None
if '--root' in _args:
    _root_from_argv = _args[_args.index('--root') + 1]

import glob, os, re, sys
root = _root_from_argv or (_sys.argv[1] if len(_sys.argv) > 1 and not _sys.argv[1].startswith('--') else '.')

# ---- 7. 入口文档：围栏闭合 + 截断哨兵 + 机器指针泄漏 ----
# 受管入口文件（人类/agent 的第一落点）；改动此清单需同步 INDEX.md §2。
ENTRY = ['INDEX.md', 'AGENTS.md', 'README.md', 'PROGRESS.md',
         '.pi/AGENT-OPS.md', '.pi/README.md', '.pi/ORCHESTRATION.md',
         'TASKS/README.md', 'PITFALLS/README.md', 'DEVICE/README.md',
         'RESOURCES/README.md', 'RUNBOOK-BRINGUP/README.md',
         'SESSIONS/README.md', 'HISTORY/README.md']
fence, leak, tail = [], [], []
for rel in ENTRY:
    p = os.path.join(root, rel)
    if not os.path.isfile(p):
        continue
    try:
        raw = open(p, 'rb').read()
        txt = raw.decode('utf-8', 'replace')
    except OSError:
        continue
    n = sum(1 for ln in txt.split('\n') if ln.startswith('```'))
    if n % 2:
        fence.append('%s(%d)' % (rel, n))
    if 'Exact evidence:' in txt or 'pi-fold-evidence' in txt:
        leak.append(rel)
    if raw and not raw.endswith(b'\n'):
        tail.append(rel)
    # 截断哨兵：正文以孤立的未完成标记结尾（本案形态 = 行尾 `# 【`）
    if re.search(r'# 【\s*$', txt.rstrip('\n'), flags=re.M):
        fence.append('%s(截断:#【)' % rel)

# ---- 8. 索引 <-> 磁盘对账 ----
# 口径依据 INDEX.md §2 / .pi/AGENT-OPS.md §4（文档 v2）：
#   「记录时的区分度靠 文件夹(角度) + 文件名(日期+主题) + pi 会话 id；不手抄索引表」
# ⇒ **README 逐文件登记 sessions/ 不是 v2 的硬要求**，故不能一刀切当 FAIL。
#   本节只做两件有明确判据的事：
#     ① 编号撞车 = 硬错（FAIL）：顺序编号角度里同名编号 ⇒ 引用歧义（2026-10-15 实测两个 33-）。
#        PITFALLS 条目号 `NNN. ` 全局唯一，同属硬错。
#     ② 索引覆盖 = 仅对「声明逐文件登记」的角度核（opt-in），且只 WARN：
#        PITFALLS（README 有 §索引表，实测 36/36）、SESSIONS（171/171）已事实上全登记；
#        TASKS 等未声明，不计（避免把合规写法判成缺陷）。
orphan, dupnum = [], []
ANGLES = ['PITFALLS', 'TASKS', 'DEVICE', 'RESOURCES', 'RUNBOOK-BRINGUP',
          'SESSIONS', 'HISTORY']
# 顺序编号角度：文件名前导 `NN-` 必须唯一。
SEQ_NUM_ANGLES = {'PITFALLS'}
# 声明「README 逐文件登记 sessions/」的角度（opt-in；未列入者不检查覆盖）。
# 2026-11-03 增 RESOURCES：该角度只有几篇会话，逐文件登记成本低、收益高（原先 3 篇孤儿无人引用）。
# TASKS/ 仍 opt-out：188 篇按日期滚动的会话日志，按主题在 §1/§5/§7 引用，逐文件登记会变成维护负担
#   （口径已写进 RESOURCES/README.md §2.9 与本注释，不是遗漏）。
INDEXED_ANGLES = {'PITFALLS', 'SESSIONS', 'RESOURCES'}
for ang in ANGLES:
    sdir = os.path.join(root, ang, 'sessions')
    idx = os.path.join(root, ang, 'README.md')
    if not os.path.isdir(sdir) or not os.path.isfile(idx):
        continue
    itxt = open(idx, encoding='utf-8', errors='replace').read()
    seqdir = ang in SEQ_NUM_ANGLES
    seen = {}
    for f in sorted(glob.glob(os.path.join(sdir, '*.md'))):
        base = os.path.basename(f)
        if base == 'README.md':      # 角度自述文件，不是条目
            continue
        if ang in INDEXED_ANGLES and base not in itxt:
            orphan.append('%s/sessions/%s' % (ang, base))
        if seqdir:
            m = re.match(r'^(\d+)-', base)
            if m:
                seen.setdefault(m.group(1), []).append(base)
    for num, files in sorted(seen.items()):
        if len(files) > 1:
            dupnum.append('%s: %s- (%s)' % (ang, num, ' | '.join(files)))

# 条目号撞车：PITFALLS 正文里 `NNN. **` 形式的编号必须全局唯一
pdefs = {}
for f in glob.glob(os.path.join(root, 'PITFALLS', 'sessions', '*.md')):
    for ln in open(f, encoding='utf-8', errors='replace'):
        m = re.match(r'^(\d{1,3})\. ', ln)
        if m:
            pdefs.setdefault(m.group(1), []).append(os.path.basename(f))
for num, files in sorted(pdefs.items(), key=lambda kv: int(kv[0])):
    if len(files) > 1:
        dupnum.append('PITFALLS: #%s (%s)' % (num, ' | '.join(sorted(set(files)))))

# ---- 8c. 索引行长度门：索引只放「一句话主题」，超长即说明它在替正文做二次编排 ----
# 判据来源（2026-10-19 整理轮）：PITFALLS/README.md 曾有 9 行 ≥500 B、最长 2682 B，
# 单元格是正文的整段搬运 ⇒ 必然与正文漂移（实测已出现一条被正文推翻的旧结论）。
IDXROW = []
for rel, lim in (('PITFALLS/README.md', 800),):
    p = os.path.join(root, rel)
    if not os.path.isfile(p):
        continue
    for i, ln in enumerate(open(p, encoding='utf-8', errors='replace'), 1):
        # 2026-11-12 去重审计 C-1：长度门不再要求行内含 `sessions/`——指向 ../reports/ 的
        # 索引行同样是「结论堆进索引」，必须一并受 800B 门约束。
        if ln.startswith('|') and '](' in ln and len(ln.encode()) > lim:
            IDXROW.append('%s:%d 索引行 %d B > %d' % (rel, i, len(ln.encode()), lim))

# ---- 8d. PITFALLS 正文条目编号必须是 `#NNN` 且全局只定义一次 ----
# 旧规则只认行首 `NNN. `，而 45/46/47/49/51 用的是 `## #NNN ...` 形式 ⇒ #293–#353 长期
# 不受任何唯一性保护（实测 #337/#338/#339 一度只存在于 README 索引里，正文一次都没出现）。
pnum = {}
for f in glob.glob(os.path.join(root, 'PITFALLS', 'sessions', '*.md')):
    for ln in open(f, encoding='utf-8', errors='replace'):
        # 「定义」= 标题行里出现的 #NNN（一条目一节的写法多样：`## #323 …`、`## 2. #337 …`、
        # `# 四十七、…（#331–#336）`），或行首 `NNN. **标题**`。
        # 两条去噪规则（2026-10-19 实测，否则全库误报）：
        #   ① 反引号代码段里的 `#NNN` 是**引用**不是定义（`## 289. ★★ \`PITFALLS #212\` 12 发全存活`）；
        #   ② 同一文件内多次出现不算撞车（一节讲一组编号是正常写法），只报**跨文件**重复。
        line = re.sub(r'`[^`]*`', '`X`', ln)
        if re.match(r'^#{1,4}\s', line):
            # 只取标题里的**第一个**编号：`## #324 推翻 #322 的方法论教训` 里 #322 是引用。
            m = re.search(r'#(\d{1,3})\b', line)
            if m:
                pnum.setdefault(m.group(1), set()).add(os.path.basename(f))
        else:
            m = re.match(r'^(\d{1,3})\.\s+\*\*', line)
            if m:
                pnum.setdefault(m.group(1), set()).add(os.path.basename(f))
        # 未受管的标题形式（`## 286. …`、`# 53. …`）：数字前没有 #，历史上让 9 条真条目对
        # 门禁隐形，并造成 #53/#192/#282–#285 六处跨文件撞号无人报（2026-11-12 审计 C-0/C-4）。
        # 只收 ≥10 的号：`## 1. …`–`## 6. …` 是大量旧文件内的**小节序号**（48/50/59/66/70/161/173/180
        # 等都是），不是全局条目号，收进来会制造假撞号（2026-11-12 执行时实测）。
        m2 = re.match(r'^#{1,4}\s+(\d{2,3})\.\s', line)
        if m2:
            pnum.setdefault(m2.group(1), set()).add(os.path.basename(f))
            dupnum.append('PITFALLS 条目 #%s 标题形式未受管（应写 "## #%s …"）: %s'
                          % (m2.group(1), m2.group(1), os.path.relpath(f, root)))
for num, files in sorted(pnum.items(), key=lambda kv: int(kv[0])):
    if len(files) > 1:
        dupnum.append('PITFALLS 正文 #%s 被多处定义 (%s)' % (num, ' | '.join(sorted(set(files)))))

# ---- 8e. PITFALLS 索引里的 #NNN 必须有正文「定义」（悬空=硬错）----
# 8d 只查「跨文件重复」；索引有、正文没有（或正文用 `# 98 ·` 这类文件序号式标题）
# 长期无人发现（2026-10-30 实测 #418/#419/#471）。本门用**宽松定义集**（标题 + 行首 NNN.
# + 正文粗体 `**#NNN**` 也算定义），且**只喂悬空门**、绝不回喂 8d 的 pnum（否则行内引用
# `**#143**` 会被当成定义，制造假的跨文件重复）。
pdef_all = {k: set(v) for k, v in pnum.items()}
for f in glob.glob(os.path.join(root, 'PITFALLS', 'sessions', '*.md')):
    base = os.path.basename(f)
    for ln in open(f, encoding='utf-8', errors='replace'):
        line = re.sub(r'`[^`]*`', '`X`', ln)
        if re.match(r'^#{1,4}\s', line):
            continue  # 标题首编号已在 pnum
        m = re.search(r'\*\*\s*#(\d{1,3})\s*\*\*', line)
        if m:
            pdef_all.setdefault(m.group(1), set()).add(base)
idxnums = set()
idxrows_reports = set()   # 指向 ../reports/ 的索引行里的 #NNN（正文在专题报告，不在 sessions）
idx_archived = set()      # 行末带 `<!-- … archived=YYYY-MM-DD … -->` 的已归档索引条目（2026-11-14 起）
for ln in open(os.path.join(root, 'PITFALLS', 'README.md'), encoding='utf-8', errors='replace'):
    # 2026-11-12 去重审计 C-2：悬空门不再要求行内含 `sessions/`——指向 ../reports/ 的
    # 索引行里的 #NNN 同样要有正文定义（2026-11-12 基线：36 行指向 reports/）。
    if ln.startswith('|') and '](' in ln:
        # 2026-11-14：`#628–#635` 这类**范围引用**不是一条索引（历史上 #282–#289 让位改号后，
        # #289 被当成一条「正文只在报告」的幽灵条目，WARN 恒挂）。先剔范围再取号。
        _ln = re.sub(r'#\d{1,3}\s*[–—\-]\s*#?\d{1,3}', 'X', ln)
        nums = set(re.findall(r'#(\d{1,3})\b', re.sub(r'`[^`]*`', 'X', _ln)))
        idxnums |= nums
        if '../reports/' in ln:
            idxrows_reports |= nums
        if re.search(r'archived=20\d\d-\d\d-\d\d', ln):
            idx_archived |= nums
# 2026-11-12 执行收尾：正文只在专题报告（reports/*.md）的条目，不算悬空——但必须显式降为 WARN，
# 不能静默放过（那正是本次审计 §C-1 抓的「索引变成正文替代品」）。判据 = 该 #NNN 在任一
# reports/*.md 里以 `#NNN` 形式出现。
def _defined_in_reports(num):
    import glob as _g
    pat = re.compile(r'#%s\b' % re.escape(num))
    for rp in _g.glob(os.path.join(root, 'reports', '*.md')):
        try:
            if pat.search(open(rp, encoding='utf-8', errors='replace').read()):
                return os.path.basename(rp)
        except OSError:
            pass
    return None

DANGLING = []
REPORTS_ONLY = []
ARCHIVED = []
for n in sorted(idxnums, key=int):
    if n in pdef_all:
        continue
    where = _defined_in_reports(n)
    if where and n in idx_archived:
        # 2026-11-14 用户授权归档：条目行带 `archived=YYYY-MM-DD` 的，正文确在专题报告里，
        # 显式登记为**已归档豁免**（C 类存量），单列一行计数，不静默、不混进普通 WARN。
        ARCHIVED.append(n)
        continue
    if where:
        REPORTS_ONLY.append('PITFALLS 索引 #%s 正文在专题报告 %s（无 sessions 条目；补正文或标 RETIRED）' % (n, where))
    else:
        DANGLING.append('PITFALLS 索引 #%s 无正文定义' % n)

_RESULTS = []


def emit(tag, items):
    _RESULTS.append((tag, items))
emit('FENCE', fence)
emit('LEAK', leak)
emit('TAIL', tail)
emit('ORPHAN', orphan)
emit('DUPNUM', dupnum)
emit('DANGLING', DANGLING)
if ARCHIVED:
    emit('ARCHIVED', [' #' + n for n in ARCHIVED])
emit('REPORTS_ONLY', REPORTS_ONLY)

# ---- 8b. 写死在文档里的「N 节 / N 条」计数必须与磁盘实际条数一致 ----
# 依据：2026-10-15 实测 INDEX.md 写「PITFALLS §0 + 33 节索引」，而实际已 36 节——
# 这类手写计数只会在每次新增条目时静默漂移，属可机读的账（readme 的表格行数 = 真值）。
stale = []
# (受管文档, 正则捕获组1=声明的数, 真值来源目录)
COUNT_RULES = [
    ('INDEX.md', r'PITFALLS[^\n]*?(\d+)\s*节', 'PITFALLS'),
]
for rel, pat, ang in COUNT_RULES:
    p = os.path.join(root, rel)
    if not os.path.isfile(p):
        continue
    txt = open(p, encoding='utf-8', errors='replace').read()
    idx = os.path.join(root, ang, 'README.md')
    if not os.path.isfile(idx):
        continue
    # 真值 = 该角度 README 索引表里指向 sessions/ 的行数（与 §8 的正文对账同源）
    # 注：链接是相对的（`sessions/NN-...`），**不带**前导斜杠 —— 用 '/sessions/' 会恒为 0。
    real = sum(1 for ln in open(idx, encoding='utf-8', errors='replace')
               if ln.startswith('|') and 'sessions/' in ln)
    for m in re.finditer(pat, txt):
        if int(m.group(1)) != real:
            stale.append('%s 声明「%s 节」但实际 %d 节' % (rel, m.group(1), real))
emit('STALECOUNT', stale)
emit('IDXROW', IDXROW)

# ---- 8e. 表格结构完整性（GFM：遇首个非 `|` 行即终止表格）----
# 立此判据的原因（2026-10-19 实测）：TASKS/README.md 有 4 处把一个表格行写成跨 4–6 个物理行的
# 整段叙事（续行不以 `|` 开头）⇒ 源文件看着能读，渲染出来该行后半截 + 其后**全部数据行**
# 降级为纯文本段落；同时 grep/表格解析工具会读丢内容。这是「人肉可读但机器不可读」的静默故障。
TBL = []
TBL_DOCS = ['TASKS/README.md', 'PITFALLS/README.md', 'DEVICE/README.md',
            'RESOURCES/README.md', 'RUNBOOK-BRINGUP/README.md', 'INDEX.md']
for rel in TBL_DOCS:
    p = os.path.join(root, rel)
    if not os.path.isfile(p):
        continue
    lines = open(p, encoding='utf-8', errors='replace').read().split('\n')
    for i, ln in enumerate(lines):
        if i == 0 or not ln.strip():
            continue
        # 续行 = 上一行是表格行，本行既不是表格行也不是标题/引用/围栏
        if lines[i-1].startswith('|') and not ln.startswith('|') \
           and not ln.lstrip().startswith(('#', '>', '```', '- ')):
            TBL.append('%s:%d 表格行被换行拆开（该行及其后全部数据行会退化成纯文本）' % (rel, i + 1))
emit('TBL', TBL)

# ---- 8f. reports/ 不得有孤儿（AGENT-OPS §3「报告必须被引用」的机器版）----
# 立此判据的原因：2026-10-15 实例——`reports/q24-causal-audit-20261015.md` 既未入 git
# 也无人引用，结论随文件沉底。2026-10-19 复盘又查出 5 篇孤儿报告。
# 判据：报告文件名必须出现在**自身以外**的 md/sh/py/tsv 里（含 glob 写法）。
# 白名单 = reports/ 下的索引类文件（它们引用别人，不需要被别人引用）。
ORPHANR = []
RP = os.path.join(root, 'reports')
if os.path.isdir(RP):
    selfdocs = {'Q24-Q28-INDEX.md', 'q28-INDEX.md', 'q28-DOSSIER.md'}
    corpus = []
    for dp, dns, fns in os.walk(root):
        dns[:] = [d for d in dns if d not in {'.git', 'node_modules', 'out', 'logs', 'backup',
                                              'geekidos-linux', 'Y700-elden-linux', 'stock-src',
                                              'dl-cam', 'env-pass', 'build'}]
        for fn in fns:
            if fn.endswith(('.md', '.sh', '.py', '.tsv')):
                corpus.append(os.path.join(dp, fn))
    texts = {}
    for cf in corpus:
        try:
            texts[cf] = open(cf, encoding='utf-8', errors='replace').read()
        except OSError:
            pass
    for rp in sorted(glob.glob(os.path.join(RP, '*.md'))):
        base = os.path.basename(rp)
        if base in selfdocs:
            continue
        if not any(base in tx for cf, tx in texts.items() if cf != rp):
            ORPHANR.append('reports/' + base)
emit('ORPHANR', ORPHANR)

# ---- 输出：§7 一组、§8 一组，逐行 `  [ok]/[FAIL]/[warn] 消息`（与旧版 check-doctor 逐字一致）----
MSG = {
    'FENCE': ('bad', '受管入口文档围栏闭合、无截断标记',
              '围栏未闭合或疑似截断（补齐代码围栏 / 恢复被截正文）'),
    'LEAK': ('bad', '无机器证据指针泄漏进入口文档',
             '入口文档混入 pi-fold 证据指针（应只留相对路径引用）'),
    'TAIL': ('warn', '受管入口文档均以换行结尾', '文件缺少结尾换行'),
    'ORPHAN': ('warn', '已声明登记的角度：sessions/ 正文均被 README 引用',
               '索引未登记（仅对声明逐文件登记的角度核；补 README 行或移出该口径）'),
    'DUPNUM': ('bad', '文件名/条目编号无撞车', '编号撞车（引用歧义，必须重编）'),
    'DANGLING': ('bad', 'PITFALLS 索引 #NNN 均有正文定义',
                 'PITFALLS 索引悬空（正文缺 #NNN 锚点，或正文标题用文件序号式）'),
    # 2026-11-14：`archived=YYYY-MM-DD` 的条目 = 已归档豁免（正文在专题报告，2026-11-14 用户授权）。
    # 只报计数与号段，不再每轮刷 28 条 WARN；新增条目仍必须补正文或先标 archived。
    'ARCHIVED': ('ok', '已归档豁免：无（正文只在专题报告的旧条目都已显式标注 `archived=`）',
                 '已归档豁免（正文在专题报告，行内 `archived=` 已标注）：%s'),
    # 2026-11-12：正文只在 reports/ 专题报告里的条目单列 WARN——不许静默放过（那正是
    # 审计 §C-1 抓的「索引变成正文替代品」），也不升级为 FAIL（事实已在报告里落盘）。
    'REPORTS_ONLY': ('warn', 'PITFALLS 索引条目均有 sessions 正文',
                     '索引条目正文只在专题报告（无 sessions 条目；补正文或标 RETIRED）'),
    'STALECOUNT': ('bad', '文档内手写条目计数与磁盘一致',
                   '文档手写计数已过期（改为不写死数字，或同步修正）'),
    'IDXROW': ('bad', '索引行长度合规（结论只在正文，索引只放一句话主题）',
               '索引行超长（内容应搬进正文，索引留一段主题 + 链接）'),
    'TBL': ('bad', '入口文档表格结构完整（无被换行拆断的表格行）',
            '表格行被换行拆开（合并成一行，叙事搬去 reports/）'),
    'ORPHANR': ('warn', 'reports/ 无孤儿报告（每篇都被至少一处引用）',
                '报告无人引用（结论会随文件沉底，补一处指针到对应 README/TASKS 行）'),
}
GROUPS = [
    ('== 7. 入口文档完整性（围栏 / 截断 / 机器指针）==', ['FENCE', 'LEAK', 'TAIL']),
    ('== 8. 索引↔磁盘对账（编号撞车=硬错 / 索引覆盖=仅声明角度）==',
     ['ORPHAN', 'DUPNUM', 'DANGLING', 'ARCHIVED', 'REPORTS_ONLY', 'STALECOUNT', 'IDXROW', 'TBL', 'ORPHANR']),
]
_res = dict(_RESULTS)
if _TSV:
    for tag, items in _RESULTS:
        print('%s\t%s' % (tag, '; '.join(items) if items else '-'))
else:
    for title, tags in GROUPS:
        print()
        print(title)
        for tag in tags:
            kind, okmsg, badmsg = MSG[tag]
            items = _res.get(tag) or []
            if items:
                if kind == 'ok':
                    # 已归档豁免：是**已声明的状态**，不是待办 ⇒ 用 [ok] 行 + 计数，不刷 warn
                    print('  [ok]   %s' % (badmsg % ' '.join(items)))
                else:
                    print('  [%s] %s: %s' % ('FAIL' if kind == 'bad' else 'warn', badmsg,
                                             '; '.join(items)))
            else:
                print('  [ok]   %s' % okmsg)
