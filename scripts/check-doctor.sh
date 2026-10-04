#!/usr/bin/env bash
# elden 项目医生 — 结构 / 一致性自检（只读，不改任何文件）
#
# 用法:  scripts/check-doctor.sh
# 退出码: 0 = 全绿；1 = 有 FAIL
#
# 检查项:
#   1. 计数            .pi/sessions 实有 vs RESOURCES §4 会话索引收录数 vs 根目录文档数
#   2. 死链            活跃文档里引用的本地 .md 是否存在（archive/skills 为历史，不查）
#   3. 过期字样        已删除/合并的旧文件与旧计数是否又被引用
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
rootmd=$(ls *.md 2>/dev/null | wc -l | tr -d ' ')
topics=$(ls archive/topics/*.md 2>/dev/null | wc -l | tr -d ' ')
# RESOURCES §4 会话索引行：形如 | 2026-.. | `01a0xxxx` | ...
indexed=$(grep -cE '^\| 20[0-9]{2}-[0-9]{2}-[0-9]{2} \| `[0-9a-f]{8}`' RESOURCES.md 2>/dev/null || echo 0)
echo "  会话 jsonl=$sessions  RESOURCES§4 收录=$indexed  专题=$topics  根目录 md=$rootmd"

if [ "$rootmd" -eq 7 ]; then ok "根目录 7 份 md（6 维护文档 + AGENTS.md）"; else warnf "根目录 md=$rootmd（预期 7）"; fi
if [ "$sessions" -eq "$indexed" ]; then ok "会话目录与 RESOURCES §4 收录一致（$sessions）"; else warnf "会话目录 $sessions ≠ 索引 $indexed → 补 RESOURCES §4"; fi

# ---------------------------------------------------------------- 2. 死链
echo
echo "== 2. 死链检查（活跃文档）=="
python3 - "$ROOT" <<'PY'
import re, os, sys
root = sys.argv[1]
active = ["INDEX.md","AGENTS.md","DEVICE.md","TASKS.md","RESOURCES.md","PITFALLS.md",
          "RUNBOOK-BRINGUP.md",".pi/README.md"]
allmd = set()
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if d not in
                   ('.git','geekidos-linux','Y700-elden-linux','stock-src','qdl',
                    'env-pass','out','backup','logs')]
    allmd |= {fn for fn in filenames if fn.endswith('.md')}
topdirs = set(os.listdir(root))
tok = re.compile(r'[A-Za-z0-9_./+\-\u4e00-\u9fa5]+\.md')
missing = []
for f in active:
    p = os.path.join(root, f)
    if not os.path.exists(p):
        missing.append((f, "(文件本身缺失)")); continue
    text = open(p, encoding='utf-8', errors='replace').read()
    for m in set(tok.findall(text)):
        if '*' in m or '{' in m or m.startswith('http'): continue
        m = m.lstrip('./')
        if any(os.path.exists(c) for c in
               (os.path.join(root, m), os.path.join(root, os.path.dirname(f), m))):
            continue
        if '/' not in m: continue
        if os.path.basename(m) in allmd: continue
        if m.split('/')[0] not in topdirs: continue
        missing.append((f, m))
if missing:
    print("  [FAIL] 死链 %d 处:" % len(missing))
    for f, m in sorted(missing):
        print("         %s -> %s" % (f, m))
    sys.exit(1)
print("  [ok]   活跃文档无死链（%d 份）" % len(active))
PY
[ $? -ne 0 ] && fail=$((fail+1))

# ---------------------------------------------------------------- 3. 过期字样
echo
echo "== 3. 过期字样扫描 =="
stale=0
# 注：PITFALLS.md 的 §15 故意登记旧文件名，故排除在本扫描外
for pat in 'LESSONS\.md' 'GAPS\.md' 'ANDROID-COMPAT\.md' 'FILES\.md' 'SESSION-INDEX\.md' \
           'sessions-catalog' 'db/elden' 'db/build' 'db/README' '六视角文档集之一'; do
  hit=$(grep -rlE "$pat" INDEX.md AGENTS.md DEVICE.md TASKS.md RESOURCES.md RUNBOOK-BRINGUP.md 2>/dev/null || true)
  if [ -n "$hit" ]; then
    bad "仍引用已删除/合并的 \`$pat\`: $(echo $hit | tr '\n' ' ')"
    stale=$((stale+1))
  fi
done
[ "$stale" -eq 0 ] && ok "无过期文件引用"

# ---------------------------------------------------------------- 3.5 进度百分比口径（INDEX 快照 vs TASKS §0 权威）
echo
echo "== 3.5 进度百分比口径 =="
python3 - <<'PY'
import re, sys
T=open('TASKS.md').read(); I=open('INDEX.md').read()
def first(pat, s, grp=1):
    m=re.search(pat, s)
    return int(m.group(grp)) if m else None
t1=first(r'\|\s*\*\*G1\*\*[^\n]*?(\d+)%', T)
t2=first(r'\|\s*\*\*G2\*\*[^\n]*?(\d+)%', T)
i1=first(r'G1\s*[≈~]?\s*(\d+)%', I)
i2=first(r'G2\s*[≈~]?\s*(\d+)%', I)
bad=0
for name,tv,iv in (("G1",t1,i1),("G2",t2,i2)):
    if tv is None or iv is None:
        print("  [warn] %s 百分比无法解析（TASKS=%s INDEX=%s）" % (name,tv,iv)); bad=-1
    elif tv!=iv:
        print("  [warn] %s 口径漂移：TASKS §0=%s%%（权威） vs INDEX §3 快照=%s%% → 刷 INDEX" % (name,tv,iv)); bad=1
if bad==0: print("  [ok]   G1/G2 百分比 INDEX ≡ TASKS")
sys.exit(1 if bad else 0)
PY
case $?
  in 0) ;; *) warn=$((warn+1)) ;;
esac

# ---------------------------------------------------------------- 4. 已退场入口不得复辟
echo
echo "== 4. 已退场入口（2026-10-04 清理，见 archive/2026-10-04-retired-entrypoints/）=="
for p in .pi/pi-messenger.json .pi/messenger \
         scripts/swarm.sh scripts/swarm-monitor.sh scripts/y700-swarm-reset.sh \
         scripts/y700-harness-restart.sh scripts/start-y700-harness.sh scripts/apply-swarm-patch.sh \
         patches/pi-messenger-swarm-detach-spawn.patch patches/pi-messenger-swarm-spawn.js.patched; do
  if [ -e "$p" ]; then bad "已退场资产又出现在活跃树: $p"; else ok "无 $p"; fi
done
for f in flashing eacndev lob-remake; do
  [ -e "$HOME/.local/bin/$f" ] && warnf "机器层快捷入口复辟: ~/.local/bin/$f（现役 = cd ~/y700-elden && pi）" || ok "无 ~/.local/bin/$f"
done

echo
echo "== 汇总: FAIL=$fail  WARN=$warn =="
[ $fail -eq 0 ] && exit 0 || exit 1
