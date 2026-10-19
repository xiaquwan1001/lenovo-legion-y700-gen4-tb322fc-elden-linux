#!/usr/bin/env python3
# gen-sessions.py -- 从 git show <REV>:RESOURCES.md 的 §4 会话索引机械生成 SESSIONS/ 角度文件夹。
#
#   SESSIONS/README.md          头部说明 + §1 统计(逐字) + §2 内核版本时间线(逐字) + §3 全量索引表(逐字) + §4/§5 说明
#   SESSIONS/sessions/*.md      每个会话一个文件 (171)，文件名 = 日期 + 名称(slug)，同日重名加 -2 / -<短id>
#
#   用法: scripts/gen-sessions.py          生成
#         scripts/gen-sessions.py --check  校验：文件数 == 快照表行数；§1/§2/§3 逐字节等于源块
import subprocess, re, os, glob, collections, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REV  = 'd8ae437'
SRCNAME = 'RESOURCES.md'
OUT  = os.path.join(ROOT, 'SESSIONS')
SDIR = os.path.join(OUT, 'sessions')

src = subprocess.run(['git', 'show', f'{REV}:{SRCNAME}'], capture_output=True, text=True, cwd=ROOT)
assert src.returncode == 0, src.stderr
L = src.stdout.split('\n')

def find(pred, start=0):
    for i in range(start, len(L)):
        if pred(L[i]):
            return i
    raise SystemExit(f'not found: {pred}')

i4  = find(lambda l: l.startswith('## 4.'))
i1s = find(lambda l: l.startswith('### 1.'), i4)
i2s = find(lambda l: l.startswith('### 2.'), i4)
i3s = find(lambda l: l.startswith('### 3.'), i4)
i4s = find(lambda l: l.startswith('### 4.'), i4)
tbl_hdr = find(lambda l: l.startswith('| 日期 |'), i2s)
row_ln = [i for i in range(tbl_hdr + 2, i3s) if re.match(r'^\| \d{4}-\d{2}-\d{2} \|', L[i])]
tbl_end = row_ln[-1]
assert len(row_ln) == 171, f'expected 171 rows, got {len(row_ln)}'

# ---- 逐字块：§1 统计 / §3 时间线 / §2 索引表（仅去掉尾部分隔线，正文逐字节一致）----
def verbatim(start, end):
    return '\n'.join(L[start:end]).rstrip('\n').rstrip('-').rstrip()

BLK_STAT  = verbatim(i1s, i2s)
BLK_TIME  = verbatim(i3s, i4s)
BLK_TABLE = '\n'.join(L[tbl_hdr:tbl_end + 1])

rows = []
for i in row_ln:
    p = [x.strip() for x in L[i].strip().strip('|').split('|')]
    assert len(p) == 9, (i + 1, len(p))
    rows.append(dict(date=p[0], id=p[1].strip('`'), name=p[2], topic=p[3], hw=p[4],
                     state=p[5], concl=p[6], kv=p[7], risk=p[8], line=L[i]))

# ---- 会话 id -> 磁盘 jsonl ----
pat = {}
for d in (os.path.join(ROOT, '.pi/sessions'),
          os.path.join(ROOT, '.pi/sessions/--home-xuqianhui1001-y700-elden--')):
    for f in glob.glob(os.path.join(d, '*.jsonl')):
        m = re.search(r'_([0-9a-f]{8})-', os.path.basename(f))
        if m:
            pat.setdefault(m.group(1), []).append(os.path.relpath(f, ROOT))
for k in pat:
    pat[k].sort()
missing = sorted({r['id'] for r in rows} - set(pat))
assert not missing, f'ids not found on disk: {missing}'

# ---- 每日提交数 / HISTORY 日文件 ----
commits = collections.Counter(
    subprocess.run(['git', 'log', '--format=%ad', '--date=short'], capture_output=True,
                   text=True, cwd=ROOT).stdout.split())
days_exist = {os.path.splitext(os.path.basename(p))[0]
              for p in glob.glob(os.path.join(ROOT, 'HISTORY/days/*.md'))}

# ---- 文件名 ----
def slug(name):
    s = re.sub(r'[\uff08(][^\uff09)]*[\uff09)]', '', name)
    s = s.replace(':', ' ').replace('\uff1a', ' ')
    s = re.sub(r'[\u3000\s]+', '-', s.strip()).strip('-')
    s = re.sub(r'[^0-9a-zA-Z@._+\-\u4e00-\u9fff]+', '-', s.lower())
    return re.sub(r'-{2,}', '-', s).strip('-') or 'session'

for r in rows:
    r['base'] = slug(r['name'])

groups = collections.defaultdict(list)
for r in rows:
    groups[(r['date'], r['base'])].append(r)

used = set()
for r in rows:
    g = groups[(r['date'], r['base'])]
    if len(g) == 1:
        fn = f"{r['date']}-{r['base']}.md"
    elif len(g) == 2:
        fn = f"{r['date']}-{r['base']}-{g.index(r) + 1}.md"
    else:
        fn = f"{r['date']}-{r['base']}-{g.index(r) + 1}-{r['id']}.md"
    assert fn not in used, fn
    used.add(fn)
    r['file'] = fn

# ---- 写 sessions/*.md ----
os.makedirs(SDIR, exist_ok=True)
for f in glob.glob(os.path.join(SDIR, '*.md')):
    os.remove(f)

SESSION_TMPL = """# {date} · {name}

> 会话档案（快照）。**会话身份与检索 = pi 原生 `.pi/sessions/*.jsonl`**（`scripts/sess.sh` / `/resume`）；
> 本文件是 2026-10-14 从 `RESOURCES.md` §4 会话索引快照机械登记的**静态档案**，不含会话全文。
> 索引总表 / 统计 / 内核版本时间线见 [`../README.md`](../README.md)。

## 身份

| 字段 | 值 |
|---|---|
| **pi 会话 id** | `{sid}` |
| 磁盘匹配模式 | `.pi/sessions/*{sid}*.jsonl` |
| 日期 | {date} |
| 名称（建议） | {name} |
| 主题 | `{topic}` |
| 实机 | {hw} |
| 状态 | {state} |
| kv（提及） | {kv} |

### 磁盘上的会话文件（{nfile}）

{disk}

## 结论（原文）

{concl}

## 风险 / 未收口

{risk}

## 相关提交

- 当日提交史：[`../../HISTORY/days/{date}.md`](../../HISTORY/days/{date}.md)（{daynote}）

---

> 生成：`scripts/gen-sessions.py`（机械生成，勿手改）。源：`git show {rev}:{src}` §4 会话索引。
"""

for r in rows:
    d = r['date']
    daynote = (f"当日提交 **{commits.get(d, 0)}** 条" if d in days_exist
               else f"⚠️ 当日无 HISTORY 日文件（当日提交 **{commits.get(d, 0)}** 条）")
    disks = pat[r['id']]
    body = SESSION_TMPL.format(
        date=d, name=r['name'], sid=r['id'], topic=r['topic'], hw=r['hw'], state=r['state'],
        kv=r['kv'] if r['kv'] not in ('', '-') else '—',
        risk=r['risk'] if r['risk'] not in ('', '-') else '—',
        nfile=len(disks), disk='\n'.join(f'  - `{p}`' for p in disks),
        concl=r['concl'], daynote=daynote, rev=REV, src=SRCNAME)
    with open(os.path.join(SDIR, r['file']), 'w', encoding='utf-8') as fh:
        fh.write(body)

# ---- §3 索引表：逐字搬入源行，仅把 ID 列换成指向 sessions/ 档案的链接 ----
# 逐字节保留源行（含单元格内空白），仅替换第 2 个单元格（ID -> 指向 sessions/ 的链接）
# 逐字节保留源行（含单元格内空白与正文里的 `|`），仅替换第 2 个单元格（ID -> 指向 sessions/ 的链接）
idx_lines = []
for r in rows:
    # 用已解析单元格定位 ID 段（避免正文里的 `|` 干扰），并逐字节保留其余部分
    i = r['line'].index(r['id'])          # `01a1xxxx` 在行内唯一
    a = r['line'].rindex('|', 0, i)       # ID 单元格左界
    b = r['line'].index('|', i + len(r['id']))   # 右界
    idx_lines.append(r['line'][:a + 1] + f" [`{r['id']}`](sessions/{r['file']}) " + r['line'][b:])
BLK_INDEX = '\n'.join(idx_lines)

README = """# SESSIONS — 会话角度（逐会话索引与档案）

> **角度**：本项目（TB322FC / elden）**逐会话的索引与档案**。
> **SSOT 声明**：本目录（`README.md` + `sessions/*.md`）是**会话视角的快照视图**；
> 提交视角（谁在什么时候提交了什么）见 [`../HISTORY/`](../HISTORY/README.md)，两者互补、不互相覆盖。
> 任务状态 / 完成度 / 未解项**不在此维护**，以 `../TASKS/README.md` §0 为准。
> 生成：`scripts/gen-sessions.py`；源快照：`git show {rev}:{src}` §4 会话索引。

---

## 0. 会话身份与检索（**权威不在本目录**）

- **会话身份 + 全文 = pi 原生项目会话**：磁盘 `.pi/sessions/*.jsonl`（项目级 `sessionDir`）。
  检索 = **`scripts/sess.sh`**（hermes 记忆检索）或 pi 会话选择器 **`/resume`**；会话内容**不手抄、不复制进本目录**。
- **§1/§2/§3 是快照**（2026-10-14 从 `RESOURCES.md` §4 会话索引迁出时冻结），此后新增会话不在表内。
- **逐会话档案**：`sessions/YYYY-MM-DD-<名称>.md`（共 {n} 个），与 §3 表**一行一文件**；
  文件名 = 日期 + 「名称（建议）」slug 化；同日重名加 `-2` 或 `-<短id>`。
- **磁盘匹配**：用 `.pi/sessions/*<短id>*.jsonl` 定位；最早 9 条（2026-09-29 → 09-30）因早期目录布局
  存放在 `.pi/sessions/--home-xuqianhui1001-y700-elden--/`（各档案文件内已逐条列出真实路径）。
- **历史子节处置**：源 §4.4「删除候选」（junk 已删/其余待批）与 §4.5「建议重命名」（已执行）**不再保留正文**，
  见本文件 §5。
- **⚠ 快照统计未随 v2 重核（2026-10-14）**：§1「9 条墓碑行」实为 9 条**重复 id 行**（同会话多主题/子代理，非删除/迁移）；
  「reference 34」实测 **35**；§1「主会话 jsonl 162」为快照值，磁盘顶层现 **168** 个 jsonl（快照后新增 6 个）。会话数字以 pi 原生会话（`.pi/sessions/*.jsonl`）为准。
- **缺口**：2026-10-13 的 **Waydroid 马达透传 C10** 无 §3 行/档案（快照冻结后新增），其内容见 `../PITFALLS/README.md` §29/§30；
  已完成子功能合并账见 `COMPLETED-FEATURES.md`。

---

## 1. 统计（逐字搬自源 §4.1，块内标题保持源样）

{stat}

---

## 2. 内核版本时间线与「实机验证边界」（逐字搬自源 §4.3）

{timeline}

---

## 3. 全量索引（按开始时间；逐字搬自源 §4.2）

> 下表**逐字搬自** `git show {rev}:{src}` 的 §4.2，仅把「ID」列改为指向本目录 `sessions/` 档案文件的链接。
> `实机`/`kv` 列口径见源节说明（`kv` ＝摘要中**提及**的内核版本，**非已验证版本**）。

{index}

---

## 4. 逐会话档案（`sessions/`）

`sessions/` 一个文件 = 一个会话（与 §3 表顺序一一对应）：

| 字段 | 说明 |
|---|---|
| pi 会话 id | 短 id；磁盘匹配 `.pi/sessions/*<短id>*.jsonl` |
| 日期 / 名称（建议）/ 主题 / 实机 / 状态 / kv(提及) | 取自 §3 快照表，逐字 |
| 结论（原文） | §3 表「结论」列，逐字 |
| 风险 / 未收口 | §3 表「风险/未收口」列，逐字 |
| 相关提交 | 指向 `../../HISTORY/days/<日期>.md`，并注明当日提交条数 |

**生成与校验（机械，勿手抄）**：

```bash
scripts/gen-sessions.py            # 重新生成 SESSIONS/README.md + sessions/*.md
scripts/gen-sessions.py --check    # ① 文件数 == 快照表行数 ② §1/§2/§3 逐字节等于源块 ③ 字段抽检
```

---

## 5. 已执行完毕的历史子节（源 §4.4 / §4.5，不保留正文）

- **源 §4.4 删除候选**：S1 的 6 条 junk/空会话已于 2026-10-04 删除
  （见 `../archive/topics/清理清单-2026-10-04-精简审计.md`）；其余「已被取代 / junk 冒烟」项仍在 §3 表内
  （`状态` 列 = `superseded` / `junk`），处置仍为**待批**。
- **源 §4.5 建议重命名**：以 `session_info` append 方式执行、**可逆**，**已全部完成**；
  执行结果即 §3 表与 `sessions/` 文件名所用的「名称（建议）」列。
- 需要两节原始全文时查历史版本：`git show {rev}:{src}`。

---

## 6. 已完成子功能合并账

见 [`COMPLETED-FEATURES.md`](COMPLETED-FEATURES.md)：按子系统把「结论 ↔ 会话档案 ↔ 关键提交」并成一张账，
收敛同一完成功能的分散描述并标出缺口（本目录 §3 为 2026-10-14 冻结快照；该账为本轮整理产物，随新完成项增补）。

---

> 会话全文/检索 = pi 原生 `.pi/sessions/*.jsonl`（`scripts/sess.sh` / `/resume`）；本目录只存**快照索引 + 逐会话档案**。
"""


# ---------- --check ----------
def _check():
    files = sorted(glob.glob(os.path.join(SDIR, '*.md')))
    ok = True
    print('[1] ls SESSIONS/sessions/*.md | wc -l = %d ; 源表行数 = %d' % (len(files), len(rows)))
    if len(files) != len(rows):
        print('    FAIL: 文件数 != 表行数'); ok = False
    else:
        print('    OK')

    readme = open(os.path.join(OUT, 'README.md'), encoding='utf-8').read()
    def block_of(text, marker, from_pos):
        i = text.index(marker, from_pos)
        j = text.index('\n---\n', i)
        return text[i:j].rstrip('\n')
    b_stat = block_of(readme, '### 1. 统计', readme.index('## 1. 统计'))
    b_time = block_of(readme, '### 3. 内核版本时间线', readme.index('## 2. 内核版本时间线'))
    src_stat = '\n'.join(L[i1s:i2s]).rstrip('\n').rstrip('-').rstrip()
    src_time = '\n'.join(L[i3s:i4s]).rstrip('\n').rstrip('-').rstrip()
    s1 = (b_stat == src_stat); s3 = (b_time == src_time)
    print('[2a] §1 统计 逐字节等于源 §4.1 :', s1)
    print('[2b] §2 时间线 逐字节等于源 §4.3 :', s3)
    ok = ok and s1 and s3

    i = readme.index('## 3. 全量索引'); j = readme.index('\n---\n', i)
    tbl = [l for l in readme[i:j].split('\n') if l.startswith('| 2026')]
    diffs = 0
    for r, l in zip(rows, tbl):
        o = l.replace('| [`%s`](sessions/%s) |' % (r['id'], r['file']), '| `%s` |' % r['id'], 1)
        if o != r['line']:
            diffs += 1
            if diffs <= 3:
                print('    DIFF', r['id']); print('      src:', r['line'][:130]); print('      out:', o[:130])
    s2 = (diffs == 0 and len(tbl) == len(rows))
    print('[2c] §3 索引表行数 = %d (源 %d)' % (len(tbl), len(rows)))
    print('[2d] §3 表逐字节等于源 §4.2 (仅 ID 列链接化) :', s2)
    ok = ok and s2

    bad = []
    for r in rows:
        t = open(os.path.join(SDIR, r['file']), encoding='utf-8').read()
        for label, val in (('日期', r['date']), ('名称（建议）', r['name']), ('主题', '`%s`' % r['topic']),
                           ('实机', r['hw']), ('状态', r['state'])):
            if '| %s | %s |' % (label, val) not in t:
                bad.append((r['file'], label))
        if '## 结论（原文）\n\n%s\n' % r['concl'] not in t:
            bad.append((r['file'], '结论'))
        rk = r['risk'] if r['risk'] not in ('', '-') else '-'
        if ('## 风险 / 未收口\n\n%s\n' % rk) not in t and ('## 风险 / 未收口\n\n—\n' not in t or rk != '-'):
            bad.append((r['file'], '风险'))
        if '.pi/sessions/*%s*.jsonl' % r['id'] not in t:
            bad.append((r['file'], 'id匹配模式'))
        if r['date'] in days_exist and '../../HISTORY/days/%s.md' % r['date'] not in t:
            bad.append((r['file'], '相关提交'))
    print('[3] 全部 %d 个文件逐字段比对 : %s' % (len(rows), 'OK' if not bad else 'FAIL ' + str(bad[:5])))
    ok = ok and not bad
    print('== CHECK', 'PASS' if ok else 'FAIL')
    return 0 if ok else 1

if '--check' in sys.argv:
    sys.exit(_check())

readme = README.format(rev=REV, src=SRCNAME, n=len(rows), stat=BLK_STAT,
                       timeline=BLK_TIME, index=BLK_INDEX)
with open(os.path.join(OUT, 'README.md'), 'w', encoding='utf-8') as fh:
    fh.write(readme)

print(f'sessions/*.md = {len(glob.glob(os.path.join(SDIR, "*.md")))}  (源表行数 {len(rows)})')
print('README.md 已写入')
