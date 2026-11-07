#!/usr/bin/env python3
"""s16-tasks-counts.py — check-doctor §16：TASKS §0 手写数字 ↔ 计数脚本自动比对。

来源：PITFALLS #548（2026-11-07 实际事故）。TASKS/README.md §0 手写「G1 34/36 / G2 8/12」，
而 scripts/check-progress-counts.sh 从 §1/§2 的行内标记现算真值；两者只靠人工比对。本轮
§1 某状态格写了个 ✅，脚本立刻算成 35/36，§0 还是 34/36 —— check-doctor 全绿、无人发现。
本门把这条漂移机械化。交付报告（判据/正则/实测/负向验证）：reports/counts-gate-20261107.md。
**真值 = check-progress-counts.sh --tsv 的输出**（EMOJI 优先级口径
是既有契约，本门只消费、不改口径）；**被查对象 = TASKS §0 的两处手写数字**（两向都查）：
  ① 完成度列：G1/G2 表格行末格的 `N/M`；
  ② §0 上方 `> 现状：…G1 34/36…G2 8/12…` 行的数字。

用法（与 s07-08-docs.py 同约定）：
  scripts/doctor/s16-tasks-counts.py             # 人读（同 doctor 输出格式）
  scripts/doctor/s16-tasks-counts.py --tsv       # `TAG<TAB>值`（机器消费）
  scripts/doctor/s16-tasks-counts.py --root DIR  # 指定仓库根
  scripts/doctor/s16-tasks-counts.py --tasks-file F
                                                 # §0 手写值改从 F 抓（负向验证用：
                                                 # 复制 TASKS/README.md 到 /tmp 改数字，
                                                 # 真值仍来自 root 内脚本 → 必 FAIL）
设计原则「宁可吵不要静默通过」：任一处手写数字**抓不到**（格式变了）即 FAIL，绝不跳过。
"""
import sys as _sys

_args = _sys.argv[1:]
_TSV = '--tsv' in _args
_root_from_argv = None
_tasks_file = None
if '--tasks-file' in _args:
    _tasks_file = _args[_args.index('--tasks-file') + 1]
if 'ELF_TASKS_FILE' in __import__('os').environ and not _tasks_file:
    _tasks_file = __import__('os').environ['ELF_TASKS_FILE']
if '--root' in _args:
    _root_from_argv = _args[_args.index('--root') + 1]

import os, re, subprocess, sys
root = _root_from_argv or (_sys.argv[1] if len(_sys.argv) > 1 and not _sys.argv[1].startswith('--') else '.')

ERR, MIS = [], []          # ERR = 数字不一致 / 脚本调用失败；MIS = 手写值抓不到（格式变了）
G1M, G2M = [], []

# ---- 真值：跑既有计数脚本（只消费输出，不改其口径）----
try:
    cp = subprocess.run(['bash', os.path.join(root, 'scripts/check-progress-counts.sh'), '--tsv'],
                        capture_output=True, text=True, timeout=30)
    if cp.returncode != 0:
        ERR.append('check-progress-counts.sh --tsv 退出码 %d（先跑 bash scripts/check-progress-counts.sh 看）'
                   % cp.returncode)
    truth = {}
    for ln in cp.stdout.split('\n'):
        if '\t' in ln:
            k, v = ln.split('\t', 1)
            truth[k] = v
except (OSError, subprocess.TimeoutExpired) as e:
    ERR.append('无法执行 check-progress-counts.sh：%s' % e)
    truth = {}

# ---- 被查对象：TASKS §0 手写数字 ----
tasks_path = _tasks_file or os.path.join(root, 'TASKS/README.md')
try:
    txt = open(tasks_path, encoding='utf-8', errors='replace').read()
except OSError as e:
    ERR.append('读不到 %s：%s' % (tasks_path, e))
    txt = ''

lines = txt.split('\n')
# §0 = `## 0. ` 到下一个 `## `
s0 = next((i for i, l in enumerate(lines) if re.match(r'^## 0\.', l)), None)
if s0 is None:
    MIS.append('找不到 §0 标题（`^## 0.`），§0 结构变了？')
    sec0 = []
else:
    end = next((i for i in range(s0 + 1, len(lines)) if re.match(r'^## ', lines[i])), len(lines))
    sec0 = lines[s0:end]

def grab_table(label):
    """完成度列：G1/G2 表格行（首格含 label）里最后一个 `N/M`。"""
    for ln in sec0:
        if not ln.startswith('|'):
            continue
        cells = [c.strip() for c in ln.strip().strip('|').split('|')]
        if cells and label in cells[0]:
            m = re.findall(r'(\d+)\s*/\s*(\d+)', ln)
            if m:
                return tuple(map(int, m[-1]))
            return None
    return None

def grab_quote(label):
    """`> 现状：…**G1 34/36**…**G2 8/12**…` 里的数字。"""
    for ln in sec0:
        if ln.startswith('>') and '现状' in ln:
            m = re.search(label + r'\s*(\d+)\s*/\s*(\d+)', ln)
            return tuple(map(int, m.groups())) if m else None
    return None

hw = {}
for lb in ('G1', 'G2'):
    t = grab_table(lb)
    q = grab_quote(lb)
    if t is None:
        MIS.append('§0 %s 表格「完成度」列抓不到 `N/M`（格式变了，勿静默通过）' % lb)
    if q is None:
        MIS.append('§0 `> 现状：` 行抓不到 `%s N/M`（格式变了，勿静默通过）' % lb)
    hw[lb] = (t, q)

# ---- 比对：手写两处 × 真值 ----
for lb, bad_tag in (('G1', G1M), ('G2', G2M)):
    try:
        tv = (int(truth.get('%s_complete' % lb)), int(truth.get('%s_in_scope' % lb)))
    except (TypeError, ValueError):
        continue  # 脚本失败已在 ERR 报，不重复报
    t, q = hw[lb]
    for src, val in (('§0 完成度列', t), ('§0 现状行', q)):
        if val is None:
            continue  # 抓不到已在 MIS 报
        if val != tv:
            diff = int(val[0]) - int(tv[0])
            bad_tag.append('%s 说 %s %d/%d，脚本算 %s/%s（完成数差 %+d）；先跑 '
                           'bash scripts/check-progress-counts.sh 核对 §1/§2 行内标记'
                           % (src, lb, val[0], val[1], tv[0], tv[1], diff))

_RESULTS = []
def emit(tag, items):
    _RESULTS.append((tag, items))
emit('ERR', ERR)
emit('MIS', MIS)
emit('G1M', G1M)
emit('G2M', G2M)

MSG = {
    'ERR': ('bad', '计数脚本可执行且输出可解析',
            'check-progress-counts.sh 调用/解析失败'),
    'MIS': ('bad', 'TASKS §0 两处手写数字均可抓取（完成度列 + 现状行）',
            '§0 手写数字抓取失败（格式变了；宁可吵不要静默通过）'),
    'G1M': ('bad', '§0 手写 G1 数字与脚本现算一致', '§0 与脚本 G1 计数漂移'),
    'G2M': ('bad', '§0 手写 G2 数字与脚本现算一致', '§0 与脚本 G2 计数漂移'),
}
_res = dict(_RESULTS)
if _TSV:
    for tag, items in _RESULTS:
        print('%s\t%s' % (tag, '; '.join(items) if items else '-'))
else:
    print()
    print('== 16. TASKS §0 手写数字 ↔ 计数脚本对账（漂移门，PITFALLS #548）==')
    for tag in ('ERR', 'MIS', 'G1M', 'G2M'):
        kind, okmsg, badmsg = MSG[tag]
        items = _res.get(tag) or []
        if items:
            print('  [%s] %s: %s' % ('FAIL' if kind == 'bad' else 'warn', badmsg,
                                     '; '.join(items)))
        else:
            print('  [ok]   %s' % okmsg)
