#!/usr/bin/env bash
# elden 项目医生 — 结构 / 一致性自检（只读，不改任何文件）
#
# 用法:  scripts/check-doctor.sh
# 退出码: 0 = 全绿；1 = 有 FAIL（计数漂移 / 死链 / db 过期 / 口径冲突）
#
# 检查项:
#   1. 计数一致性    .pi/sessions 实有 vs archive/sessions-catalog vs db
#   2. 死链          tracked *.md 里引用的本地 .md 是否存在（排除 skills 与外部路径）
#   3. db 新鲜度     db/elden.db 是否比其文本源旧
#   4. 口径冲突      已知「多处维护」的数字/定义是否又冒出来
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD

fail=0
warn=0
ok()   { printf '  [ok]   %s\n' "$1"; }
bad()  { printf '  [FAIL] %s\n' "$1"; fail=$((fail+1)); }
warnf(){ printf '  [warn] %s\n' "$1"; warn=$((warn+1)); }

echo "== elden check-doctor — $ROOT =="

# ---------------------------------------------------------------- 1. 计数
echo
echo "== 1. 计数一致性 =="
sessions=$(find .pi/sessions -name '*.jsonl' 2>/dev/null | wc -l | tr -d ' ')
catalog=$(cat archive/sessions-catalog-*.jsonl 2>/dev/null | wc -l | tr -d ' ')
topics=$(ls archive/topics/*.md 2>/dev/null | wc -l | tr -d ' ')
rootmd=$(ls *.md 2>/dev/null | wc -l | tr -d ' ')
echo "  实有会话 jsonl=$sessions  catalog=$catalog  专题=$topics  根目录 md=$rootmd"

if [ "$sessions" -gt "$catalog" ]; then
  warnf "会话目录比 catalog 多 $((sessions-catalog)) 个 → SESSION-INDEX/db 未覆盖新会话（收尾时同步）"
else
  ok "会话目录与 catalog 数量一致"
fi
if [ "$catalog" -gt 0 ] && [ -f db/elden.db ]; then
  dbn=$(python3 -c 'import sqlite3;print(sqlite3.connect("db/elden.db").execute("select count(*) from sessions").fetchone()[0])' 2>/dev/null || echo -1)
  if [ "$dbn" = "$catalog" ]; then ok "db sessions=$dbn = catalog"; else warnf "db sessions=$dbn ≠ catalog=$catalog（db 可能过期）"; fi
fi

if grep -rn '45 个历史会话' *.md 2>/dev/null; then
  bad "仍有文档写「45 个历史会话」（实为 $catalog catalog / $sessions 文件）"
else
  ok "无过期「45 个历史会话」字样"
fi

# ---------------------------------------------------------------- 2. 死链
echo
echo "== 2. 死链检查（tracked *.md）=="
python3 - "$ROOT" <<'PY'
import subprocess, re, os, sys
root = sys.argv[1]
out = subprocess.run(["git","-c","core.quotepath=false","ls-files","*.md"],
                     cwd=root, capture_output=True, text=True).stdout
files = [f for f in out.splitlines() if f and not f.startswith(".pi/skills/") and '"' not in f]
allmd = set()
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if d not in
                   ('.git','geekidos-linux','Y700-elden-linux','stock-src','qdl',
                    'env-pass','out','backup','logs','.pi')]
    allmd |= {fn for fn in filenames if fn.endswith('.md')}
topdirs = set(os.listdir(root))
tok = re.compile(r'[A-Za-z0-9_./+\-\u4e00-\u9fa5]+\.md')
missing = []
for f in files:
    text = open(os.path.join(root, f), encoding='utf-8', errors='replace').read()
    for m in set(tok.findall(text)):
        if '*' in m or '{' in m or m.startswith('http'):
            continue
        m = m.lstrip('./')
        if '/' not in m:                     # 裸文件名：叙述文本，放过（根目录若真有则视为引用）
            continue
        if any(os.path.exists(c) for c in
               (os.path.join(root, m), os.path.join(root, os.path.dirname(f), m))):
            continue
        if os.path.basename(m) in allmd:     # 同名文件在别处
            continue
        if m.split('/')[0] not in topdirs:   # 首段非仓库顶层 → 外部/固件路径
            continue
        missing.append((f, m))
if missing:
    print("  [FAIL] 死链 %d 处:" % len(missing))
    for f, m in sorted(missing):
        print("         %s -> %s" % (f, m))
    sys.exit(1)
print("  [ok]   无死链（%d 份 tracked md，已排除 skills 与外部路径）" % len(files))
PY
[ $? -ne 0 ] && fail=$((fail+1))

# ---------------------------------------------------------------- 3. db 新鲜度
echo
echo "== 3. db 新鲜度 =="
if [ ! -f db/elden.db ]; then
  warnf "db/elden.db 不存在（跑 python3 db/build.py --lessons）"
else
  newest_src=$(ls -t PITFALLS.md TASKS.md RESOURCES.md archive/sessions-catalog-*.jsonl 2>/dev/null | head -1)
  if [ -n "$newest_src" ] && [ "$newest_src" -nt db/elden.db ]; then
    warnf "db/elden.db 比 $newest_src 旧 → 重建: python3 db/build.py --lessons"
  else
    ok "db/elden.db 不旧于文本源"
  fi
  if [ -f LESSONS.md ] && [ db/elden.db -nt LESSONS.md ]; then
    warnf "LESSONS.md 比 db 旧 → 重建: python3 db/build.py --lessons"
  fi
fi

# ---------------------------------------------------------------- 4. 口径冲突
echo
echo "== 4. 口径冲突扫描 =="
if grep -ln '六视角文档集之一' *.md 2>/dev/null | grep -v '^AGENTS.md$' >/dev/null 2>&1; then
  warnf "下列文件仍写「六视角文档集之一」（应改为「领域层活文档之一」）:"
  grep -ln '六视角文档集之一' *.md 2>/dev/null | sed 's/^/         /'
else
  ok "各领域文档表头口径统一"
fi
n80=$(grep -rl '80%\|≈80%' *.md 2>/dev/null | wc -l | tr -d ' ')
if [ "$n80" -gt 2 ]; then
  warnf "「G1 ≈80%」出现在 $n80 份文件 → 权威为 TASKS.md §0，其余应改为指针"
else
  ok "完成度数字未散落（$n80 份）"
fi

echo
echo "== 汇总: FAIL=$fail  WARN=$warn =="
[ $fail -eq 0 ] && exit 0 || exit 1
