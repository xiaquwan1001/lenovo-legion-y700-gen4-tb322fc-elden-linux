#!/bin/bash
# check-sessions.sh -- 独立校验 SESSIONS/（不依赖 gen-sessions.py 的实现细节）
#   ① ls SESSIONS/sessions/*.md | wc -l == 源表行数(171)
#   ② README 内 §1 统计 / §2 时间线 / §3 索引表 与 git show d8ae437:RESOURCES.md §4.1/§4.3/§4.2 diff 一致
#   ③ 随机抽 5 个 sessions 档案，与源表对应行逐字段比对
#
# 用法: scripts/check-sessions.sh [N]   # N = 抽检文件数（默认 5）
set -uo pipefail
cd "$(dirname "$0")/.."
REV=${REV:-d8ae437}
N=${1:-5}
OK=0; FAIL=0
chk(){ if [ "$2" = "$3" ]; then echo "  OK   $1: $2"; OK=$((OK+1)); else echo "  FAIL $1: got=$2 want=$3"; FAIL=$((FAIL+1)); fi; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
git show "$REV:RESOURCES.md" > "$TMP/src.md"

# 用 python 做「块提取」（避免 awk 正则转义坑）：只按行号切片，零改写
python3 - "$TMP" <<'PY'
import sys, re
T = sys.argv[1]
L = open(T + '/src.md', encoding='utf-8').read().split('\n')
def find(p, s=0):
    for i in range(s, len(L)):
        if p(L[i]): return i
    raise SystemExit('not found')
i4 = find(lambda l: l.startswith('## 4.'))
i1 = find(lambda l: l.startswith('### 1.'), i4)
i2 = find(lambda l: l.startswith('### 2.'), i4)
i3 = find(lambda l: l.startswith('### 3.'), i4)
i4b = find(lambda l: l.startswith('### 4.'), i4)
def verb(a, b):
    s = '\n'.join(L[a:b])
    out = []
    for ln in s.split('\n'):
        if ln.strip() == '---': break
        out.append(ln)
    while out and out[-1].strip() == '': out.pop()
    return '\n'.join(out) + '\n'
open(T + '/s1.src', 'w', encoding='utf-8').write(verb(i1, i2))
open(T + '/s3.src', 'w', encoding='utf-8').write(verb(i3, i4b))
# README 侧：取 README 内的同名块（标题行为 '## k. ...'）
R = open('SESSIONS/README.md', encoding='utf-8').read().split('\n')
def rblock(anchor, start_head):
    i = next(k for k, l in enumerate(R) if l.startswith(anchor))
    j = next(k for k in range(i + 1, len(R)) if R[k].strip() == '---')
    out = R[i + 1:j]
    while out and out[0].strip() == '': out.pop(0)
    while out and out[-1].strip() == '': out.pop()
    return '\n'.join(out) + '\n'
open(T + '/s1.out', 'w', encoding='utf-8').write(rblock('## 1. 统计', None))
open(T + '/s3.out', 'w', encoding='utf-8').write(rblock('## 2. 内核版本时间线', None))
# §3 索引表：源行 vs README 行（把 ID 链接还原为 `id`）
src_rows = [l for l in L if re.match(r'^\| \d{4}-\d{2}-\d{2} \|', l)]
ri = next(k for k, l in enumerate(R) if l.startswith('## 3. 全量索引'))
rj = next(k for k in range(ri + 1, len(R)) if R[k].strip() == '---')
out_rows = []
for l in R[ri + 1:rj]:
    if not re.match(r'^\| \d{4}-\d{2}-\d{2} \|', l): continue
    m = re.search(r'\| \[`([0-9a-f]{8})`\]\(sessions/[^)]+\) \|', l)
    out_rows.append(l[:m.start()] + '| `%s` |' % m.group(1) + l[m.end():])
open(T + '/tbl.src', 'w', encoding='utf-8').write('\n'.join(src_rows) + '\n')
open(T + '/tbl.out', 'w', encoding='utf-8').write('\n'.join(out_rows) + '\n')
open(T + '/nrows', 'w').write(str(len(src_rows)))
PY
nr=$(cat "$TMP/nrows")

echo "[1] 文件数"
nf=$(ls SESSIONS/sessions/*.md | wc -l)
chk "ls SESSIONS/sessions/*.md | wc -l" "$nf" "$nr"

echo "[2] README 正文逐字节一致（diff）"
chk "§1 统计 vs 源 §4.1" "$(diff -q "$TMP/s1.src" "$TMP/s1.out" >/dev/null && echo same || echo diff)" "same"
chk "§2 内核时间线 vs 源 §4.3" "$(diff -q "$TMP/s3.src" "$TMP/s3.out" >/dev/null && echo same || echo diff)" "same"
chk "§3 全量索引 vs 源 §4.2" "$(diff -q "$TMP/tbl.src" "$TMP/tbl.out" >/dev/null && echo same || echo diff)" "same"

echo "[3] 随机抽 $N 个档案文件逐字段比对"
while read -r f; do
  fn=$(basename "$f")
  row=$(grep -F -- "(sessions/$fn)" SESSIONS/README.md | head -1)
  if [ -z "$row" ]; then echo "  FAIL $fn: README 索引无对应行"; FAIL=$((FAIL+1)); continue; fi
  sid=$(printf '%s' "$row" | sed -n 's/^| [0-9-]* | \[`\([0-9a-f]\{8\}\)`\](sessions\/[^)]*).*/\1/p')
  # 从源表中取同一会话行，做「逐字段」比对（源行只把 ID 列换成链接）
  srow=$(grep -F -- "| \`$sid\` |" "$TMP/tbl.src" | head -1)
  [ -n "$srow" ] || { echo "  FAIL $fn: 源表无 id=$sid"; FAIL=$((FAIL+1)); continue; }
  orow=$(printf '%s' "$row" | sed "s/| \[\`$sid\`\](sessions\/[^)]*) |/| \`$sid\` |/")
  bad=0; why=""
  [ "$orow" = "$srow" ] || { bad=1; why="索引行与源表逐字节不等"; }
  grep -qF -- "| **pi 会话 id** | \`$sid\` |" "$f" || { bad=1; why="$why id"; }
  grep -qF -- ".pi/sessions/*$sid*.jsonl" "$f" || { bad=1; why="$why disk-pattern"; }
  date=$(printf '%s' "$srow" | cut -d'|' -f2 | xargs)
  name=$(printf '%s' "$srow" | cut -d'|' -f4 | xargs)
  concl=$(printf '%s' "$srow" | cut -d'|' -f8 | xargs)
  risk=$(printf '%s' "$srow" | cut -d'|' -f10 | xargs)
  grep -qF -- "| 日期 | $date |" "$f" || { bad=1; why="$why date"; }
  grep -qF -- "| 名称（建议） | $name |" "$f" || { bad=1; why="$why name"; }
  grep -qF -- "$concl" "$f" || { bad=1; why="$why concl"; }
  [ "$risk" = "-" ] || grep -qF -- "$risk" "$f" || { bad=1; why="$why risk"; }
  grep -qF -- "../../HISTORY/days/$date.md" "$f" || { bad=1; why="$why commit-link"; }
  if [ $bad -eq 0 ]; then echo "  OK   $fn  (id=$sid date=$date)"; OK=$((OK+1))
  else echo "  FAIL $fn  (id=$sid): $why"; FAIL=$((FAIL+1)); fi
done < <(ls SESSIONS/sessions/*.md | shuf -n "$N" --random-source=<(yes))

echo "----------------------------------------"
echo "checks OK=$OK FAIL=$FAIL"
[ "$FAIL" -eq 0 ] && { echo "== ALL PASS"; exit 0; } || { echo "== FAIL"; exit 1; }
