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
#   5. vk 版本账        registry 单调唯一 / registry 号必有 manifest / 树自称 ≡ 镜像内内核
#                        （已审在案的历史项见 versions/vk-ledger-known-issues.tsv，降为 WARN）
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
import re, os, sys, glob
root = sys.argv[1]
active = ["INDEX.md","AGENTS.md","DEVICE.md","TASKS.md","RESOURCES.md","PITFALLS.md",
          "RUNBOOK-BRINGUP.md",".pi/README.md",".pi/AGENT-OPS.md",".pi/CONCURRENCY.md"]
active += sorted(glob.glob(os.path.join(root, '.pi/missions/*.md')))
active += sorted(glob.glob(os.path.join(root, '.pi/agents/*.md')))
active += sorted(glob.glob(os.path.join(root, '.pi/skills/*/SKILL.md')))
allmd = set()
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if d not in
                   ('.git','geekidos-linux','Y700-elden-linux','stock-src','qdl',
                    'env-pass','out','backup','logs')]
    allmd |= {fn for fn in filenames if fn.endswith('.md')}
topdirs = set(os.listdir(root))
tok = re.compile(r'[A-Za-z0-9_./+\-\u4e00-\u9fa5]+\.md(?![A-Za-z0-9_])')
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
               (os.path.join(root, m), os.path.normpath(os.path.join(root, os.path.dirname(f), m)))):
            continue
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
print("  [ok]   活跃文档无死链（%d 份：6 维护 + .pi README/AGENT-OPS/CONCURRENCY/missions/agents/SKILL）" % len(active))
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

# 术语一致性：领域层只有 4 份（DEVICE/TASKS/RESOURCES/RUNBOOK）+ 经验层 1 份（PITFALLS）
term=$(grep -rln "领域层 *[5五] *份" INDEX.md AGENTS.md TASKS.md DEVICE.md RESOURCES.md RUNBOOK-BRINGUP.md PITFALLS.md .pi/AGENT-OPS.md .pi/CONCURRENCY.md 2>/dev/null || true)
if [ -n "$term" ]; then bad "术语漂移「领域层 5 份」（应为领域层 4 + 经验层 1）: $(echo $term | tr '\n' ' ')"; else ok "术语「领域层 4 份 + 经验层 1 份」一致"; fi

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

# ---------------------------------------------------------------- 5. vk 版本账
echo
echo "== 5. vk 版本账（registry / manifest / 镜像内 UTS）=="
# 背景：vk52-slim 曾被静默打进 vk42 内核（manifest kernel_release 与镜像 UTS 自相矛盾），
# 而当时无人校验。这里做三条机读检查；历史留白（vk43/49 等）只 warn 不 FAIL。
# 证据与结论：archive/topics/VK-LEDGER-AUDIT-2026-10-06.md
ledger=$(python3 - <<'PY' 2>/dev/null
import os, re, zlib, glob

OUT = 'out'
reg = os.path.join('versions', 'vk-registry.tsv')
rows = []
if os.path.exists(reg):
    for line in open(reg, errors='replace'):
        m = re.match(r'^vk(\d+)\t(\S*)\t(\S*)\t(.*)$', line.rstrip('\n'))
        if m:
            rows.append(int(m.group(1)))

nums = [r for r in rows]
if not rows:
    print('FAIL\tregistry 无任何 vk 行')
else:
    dup = sorted({n for n in nums if nums.count(n) > 1})
    if dup:
        print('FAIL\tregistry 有重复 vkN: %s' % ','.join('vk%d' % n for n in dup))
    if nums != sorted(nums):
        print('FAIL\tregistry vkN 非单调递增')
    if not dup and nums == sorted(nums):
        print('OK\tregistry vk50-%d 单调、无重复（%d 行）' % (max(nums), len(nums)))
regset = set(nums)

# 已知问题白名单：已审查在案的历史项降 WARN，未登记同类问题仍 FAIL
known = {}
kf = os.path.join('versions', 'vk-ledger-known-issues.tsv')
if os.path.exists(kf):
    for line in open(kf, errors='replace'):
        if line.startswith('#') or '\t' not in line:
            continue
        parts = line.rstrip('\n').split('\t')
        if len(parts) >= 2:
            known[(parts[0], parts[1])] = parts[2] if len(parts) > 2 else ''

def uts_of_image(path):
    """镜像内核 UTS 的 release 串（与 build-manifest.sh 同法：首段 gzip → UTS）。"""
    try:
        d = open(path, 'rb').read()
        i = d.find(b'\x1f\x8b\x08')
        if i < 0:
            return None
        k = zlib.decompress(d[i:], 16 + zlib.MAX_WBITS)
        m = re.search(rb'Linux version (\S+)', k)
        return m.group(1).decode() if m else None
    except Exception:
        return None

imgs = sorted(glob.glob(os.path.join(OUT, 'boot-elden-vk*.img')))
no_manifest, mismatch, orphan_reg, orphan_img, tree_drift, dirty_drift = [], [], [], [], [], []

def gitdesc(s):
    """从 KV 串里取 (git sha, 是否 -dirty)，忽略 LOCALVERSION 前缀：g<sha>[-dirty]。"""
    m = re.search(r'g([0-9a-f]{12,})(-dirty)?', s or '')
    return (m.group(1), bool(m.group(2))) if m else None

for img in imgs:
    base = os.path.basename(img)[len('boot-elden-'):-len('.img')]
    m = re.match(r'^vk(\d+)', base)
    num = int(m.group(1)) if m else None
    mf = img[:-len('.img')] + '.manifest'
    has_mf = os.path.exists(mf)
    if num is not None and num in regset and not has_mf:
        no_manifest.append(base)
    if num is None or num not in regset:
        if not has_mf:
            orphan_img.append(base)
        continue
    if has_mf:
        kv = {}
        for line in open(mf, errors='replace'):
            if '=' in line:
                k, v = line.split('=', 1)
                kv[k] = v.strip()
        mu, kr = kv.get('kernel_uts'), kv.get('kernel_release')
        iu = uts_of_image(img)
        if mu and mu != '(unknown)' and iu:
            mr = mu.replace('Linux version ', '').split(' ')[0]
            if mr != iu:
                mismatch.append('%s: manifest=%s 镜像=%s' % (base, mr, iu))
        # vk52 类事故：打包用的 Image.gz 不是构建时那棵树的内核
        a, b = gitdesc(kr), gitdesc(mu)
        if a and b:
            if a[0] != b[0]:
                tree_drift.append((base, '%s: 树/构建记录=%s 但镜像内=%s' % (base, kr, mu)))
            elif a[1] != b[1]:
                dirty_drift.append((base, '%s: 同 sha 但 dirty 位不同（%s vs 镜像内 %s）' % (base, kr, mu)))

for b in no_manifest:
    if (b, 'no_manifest') in known:
        print('WARN\tregistry 号无 manifest（已知留档：%s）' % known[(b, 'no_manifest')])
    else:
        print('FAIL\tregistry 号无 manifest（不可复现/无指纹）：%s' % b)
for s in mismatch:
    print('FAIL\tmanifest 内核 ≡ 镜像内核 不符 → %s' % s)
for base, detail in tree_drift:
    if (base, 'tree_drift') in known:
        print('WARN\t打包内核非本树内核（已知留档：%s）→ %s' % (known[(base, 'tree_drift')], detail))
    else:
        print('FAIL\t打包内核非本树内核（树自称 ≠ 镜像内）→ %s' % detail)
for base, detail in dirty_drift:
    if (base, 'dirty_drift') in known:
        print('WARN\tdirty 位漂移（已知留档：%s）→ %s' % (known[(base, 'dirty_drift')], detail))
    else:
        print('FAIL\tdirty 位漂移（同 commit，镜像含未提交改动）→ %s' % detail)
if not no_manifest and not mismatch and not tree_drift:
    print('OK\tregistry 号均有 manifest，且树自称 = 镜像内 = manifest')
if orphan_img:
    print('WARN\tregistry 前的历史镜像无 manifest（历史留白，见审计档案）：%s' % ','.join(orphan_img))
PY
)
if [ -z "$ledger" ]; then
  warnf "vk 版本账检查未产出结果（python3 缺失？）"
else
  while IFS=$'\t' read -r st msg; do
    case "$st" in
      OK)   ok   "$msg" ;;
      WARN) warnf "$msg" ;;
      FAIL) bad  "$msg" ;;
    esac
  done <<< "$ledger"
fi

# ---------------------------------------------------------------- 6. 静态卫生（防造轮回退）
echo
echo "== 6. 静态卫生（重复 / 死代码 / bashism）=="
# 依据：.pi/plans/2026-10-07-造轮子审计.md（P0 防回归门）

# 6a. 设备锁必须单一真源：除 lib-device-lock.sh 外不得内联锁块
lockdup=$(grep -rl 'DEVICE_LOCK_HELD' --include='*.sh' scripts cycle.sh build.sh iterate.sh 2>/dev/null | grep -v 'lib-device-lock.sh' | grep -v 'check-doctor.sh' || true)
if [ -n "$lockdup" ]; then
  bad "设备锁块被复制（应只用 scripts/lib-device-lock.sh）: $(echo $lockdup | tr '\n' ' ')"
else
  ok "设备锁单一真源（lib-device-lock.sh）"
fi

# 6b/6c. bashism 与死脚本（Python，避免 shell 误判）
static=$(python3 - "$ROOT" <<'PY'
import glob, os, re, sys
root = sys.argv[1]
scripts = sorted(glob.glob(os.path.join(root, 'scripts', '*.sh')))
# 引用语料：全仓 md/脚本（排除归档快照与生成物），避免把「仅被文档引用」误判为死代码。
SKIP = {'.git', 'node_modules', 'out', 'logs', 'backup', 'flashing-bundle', 'linux', 'geekidos-linux', 'Y700-elden-linux', 'stock-src', 'qdl', 'env-pass', 'edk2-aarch64-gunyah', 'edk2-gunyah', 'edk2-gunyah-qemu', 'mu_wide_platforms'}
corpus_files = []
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if d not in SKIP]
    for fn in filenames:
        if fn.endswith(('.md', '.sh', '.py', '.tsv', '.json')):
            corpus_files.append(os.path.join(dirpath, fn))
text = {}
for cf in set(corpus_files):
    try:
        text[cf] = open(cf, encoding='utf-8', errors='replace').read()
    except OSError:
        pass
bashism = []
for f in scripts:
    body = open(f, encoding='utf-8', errors='replace').read()
    if body.startswith('#!/bin/sh') and re.search(r"\[\[(?!:)|declare -|[A-Za-z_][A-Za-z0-9_]*=\(", body):
        bashism.append(os.path.basename(f))
dead = [os.path.basename(f) for f in scripts
        if not any(os.path.basename(f) in t for cf, t in text.items() if cf != f)]
print('BASHISM\t' + (','.join(bashism) or '-'))
print('DEAD\t' + (','.join(dead) or '-'))
PY
)
while IFS=$'\t' read -r st msg; do
  case "$st" in
    BASHISM) [ "$msg" = "-" ] && ok "#!/bin/sh 脚本无常见 bashism" || warnf "bashism 风险（改 #!/bin/bash 或改写法）: $msg" ;;
    DEAD)    [ "$msg" = "-" ] && ok "scripts/*.sh 无死脚本" || warnf "疑似死脚本（无任何活跃引用，核实后删/标 legacy）: $msg" ;;
  esac
done <<< "$static"

echo
echo "== 汇总: FAIL=$fail  WARN=$warn =="
[ $fail -eq 0 ] && exit 0 || exit 1
