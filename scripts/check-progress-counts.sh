#!/usr/bin/env bash
# check-progress-counts.sh — 从 TASKS/README.md §1/§2 的行内状态标记现算完成度
#
# 背景：TASKS §0 的 33/35、8/12 原先靠人手在注里推导（2026-11-02 那次复算写了 3.5 KB 推导过程），
# 数字一改就漂。本脚本把同一套口径机器化：**§1/§2 的行内标记 = 真值**，§0 只贴数字与公式。
#
# 口径（2026-11-02 定，INDEX/§0 同源）：
#   ✅ 完成 / 🟢 已结项（已规避·已出分·已随根因结项）/ 🎯 治本完成  ⇒ 计入「完成」
#   🟡 部分·进行中 / 🆕 取证已做未收口 / ⬜ 未开始                ⇒ 计入「未完成」
#   ❌ 取消 / ⛔ 搁置 ⇒ **不进分母**
#   合并行（如 `| ✅ G1-12…21 |`，状态写在第 1 列）按区间展开计 ID 数。
#
# 用法：scripts/check-progress-counts.sh            # 人类可读
#       scripts/check-progress-counts.sh --tsv      # 机器可读（键<TAB>值）
#       scripts/check-progress-counts.sh --selftest  # 断言当前口径 33/35、8/12（漂了就 rc=1）
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
MODE=${1:-}
exec python3 - "$ROOT" "$MODE" <<'PY'
import re, sys
root, mode = sys.argv[1], (sys.argv[2] if len(sys.argv) > 2 else '')
lines = open(root + '/TASKS/README.md', encoding='utf-8').read().split('\n')

def section(start, end):
    s = next(i for i, l in enumerate(lines) if l.startswith(start))
    e = next(i for i, l in enumerate(lines) if l.startswith(end) and i > s)
    return lines[s:e]

EMOJI = ['✅', '🟢', '🎯', '🟡', '🆕', '⬜', '❌', '⛔']
COMPLETE = {'✅', '🟢', '🎯'}
OUT = {'❌', '⛔'}

def scan(sec, pat):
    """返回 {状态: ID 数}，忽略没有状态标记的行。"""
    tally, rows = {}, 0
    for ln in sec:
        if not re.match(pat, ln):
            continue
        cells = [c.strip() for c in ln.strip().strip('|').split('|')]
        first = cells[0]
        # 合并行：ID 区间写在第 1 列（G1-12…21），状态也在第 1 列
        m = re.search(r'([A-Z]+\d)-(\d+)\s*…\s*(\d+)', first)
        weight = int(m.group(3)) - int(m.group(2)) + 1 if m else 1
        st = next((e for e in EMOJI if e in (cells[2] if len(cells) > 2 else '')), None) \
             or next((e for e in EMOJI if e in first), None)
        if not st:
            continue
        rows += 1
        tally[st] = tally.get(st, 0) + weight
    return tally, rows

def ratio(tally, rows, label):
    total = sum(tally.values())
    out = sum(v for k, v in tally.items() if k in OUT)
    denom = total - out
    done = sum(v for k, v in tally.items() if k in COMPLETE)
    partial = denom - done
    return dict(label=label, total=total, cancelled=out, in_scope=denom,
                complete=done, partial=partial,
                detail=' '.join('%s%d' % (k, tally[k]) for k in EMOJI if k in tally))

g1 = ratio(*scan(section('## 1. G1', '## 2. G2'), r'^\| ?\*{0,2}(G1-|[✅🟢🎯🟡🆕⬜❌⛔].*G1-)'), 'G1')
g2 = ratio(*scan(section('## 2. G2', '## 3. '), r'^\| ?\*{0,2}C\d'), 'G2')

rows = [g1, g2]
if mode == '--tsv':
    for r in rows:
        for k, v in r.items():
            print('%s_%s\t%s' % (r['label'], k, v))
else:
    for r in rows:
        print('%-3s 完成 %2d / 在范围 %2d（ID 总数 %d，取消 %d；未完成 %d）  [%s]'
              % (r['label'], r['complete'], r['in_scope'], r['total'], r['cancelled'], r['partial'], r['detail']))

if mode == '--selftest':
    exp = (('G1', 33, 35), ('G2', 8, 12))
    bad = 0
    for r, (lb, c, d) in zip(rows, exp):
        if (r['complete'], r['in_scope']) != (c, d):
            print('FAIL: %s 口径 %d/%d ≠ 声明 %d/%d（先改 §0 口径注，别只改脚本）'
                  % (lb, r['complete'], r['in_scope'], c, d), file=sys.stderr)
            bad += 1
    sys.exit(1 if bad else 0)
PY
