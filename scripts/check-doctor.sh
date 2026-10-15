#!/usr/bin/env bash
# elden 项目医生 — 机器账自检（只读，不改任何文件）
#
# 用法:  scripts/check-doctor.sh                 退出码: 0 = 全绿；1 = 有 FAIL
#        scripts/check-doctor.sh --staged-fast  只跑 §7/§8/§9（纯文本，~0.2 s）
#                                               —— 供 .githooks/pre-commit 用；
#                                               跳过 §5/§5d 的 vk 镜像解压（那是墙钟大头）
#
# 文档 v2 起不再做文档计数 / 死链 / 口径字样检查：记录的区分度靠写入时的
# 文件夹(角度) + 文件名(日期+主题) + pi 会话 id 保证（见 INDEX.md §2 / .pi/AGENT-OPS.md §4）。
# 只保留机器可核对的账：
#   4. 已退场入口不得复辟
#   5. vk 版本账（registry / manifest / 镜像内 UTS 一致）
#   5d. 内核身份表新鲜度 + 命名/溯源规则门
#   5e. manifest 完整性（config_sha256）
#   6. 静态卫生（设备锁单一真源 / bashism / 死脚本）
#   7. 入口文档完整性（围栏闭合 / 截断哨兵 / 机器指针泄漏）  ← 2026-10-15 L1
#   8. 索引↔磁盘对账（编号撞车=FAIL；索引覆盖仅对声明角度=WARN）  ← 2026-10-15 L1
#   9. SESSIONS/ 快照一致性（委托 scripts/check-sessions.sh）  ← 2026-10-15 L1
set -uo pipefail

FAST=0
for a in "$@"; do
  case "$a" in
    --staged-fast|--fast) FAST=1 ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) echo "check-doctor: 未知参数 $a（支持 --staged-fast）" >&2; exit 2 ;;
  esac
done

cd "$(dirname "$0")/.."
ROOT=$PWD

fail=0
warn=0
ok()   { printf '  [ok]   %s\n' "$1"; }
bad()  { printf '  [FAIL] %s\n' "$1"; fail=$((fail+1)); }
warnf(){ printf '  [warn] %s\n' "$1"; warn=$((warn+1)); }

if [ "$FAST" = 1 ]; then
  echo "== elden check-doctor (--staged-fast: 只跑 §7/§8/§9) — $ROOT =="
else
  echo "== elden check-doctor — $ROOT =="
fi

if [ "$FAST" = 1 ]; then
  # ---- 快速路径：跳过 §4/§5/§5d/§5e/§6（含 vk 镜像解压，墙钟 ~14 s） ----
  # 这些节的内容与「文档/索引改动」无关，pre-commit 无需承担其成本。
  :
else

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
# 单次调用 vk-identity --all：一次全量扫描同时产出 §5 结论、§5d 门禁、§5d 新鲜度。
# 旧版此处内联 python + §5d 再调 --gate/--check，同一批镜像被 gzip 解压三遍（墙钟 ~110s）。
_all=$(python3 scripts/vk-identity.py --all 2>/dev/null)
_ledger_st=(); _ledger_msg=(); _gate_st=(); _gate_msg=(); _cst=""
while read -r _tag _st _msg; do
  case "$_tag" in
    L) _ledger_st+=("$_st"); _ledger_msg+=("$_msg") ;;
    G) _gate_st+=("$_st"); _gate_msg+=("$_msg") ;;
    C) _cst="$_st" ;;
  esac
done <<< "$_all"
if [ ${#_ledger_st[@]} -eq 0 ]; then
  warnf "vk 版本账检查未产出结果（python3 缺失？）"
else
  for _i in "${!_ledger_st[@]}"; do
    case "${_ledger_st[$_i]}" in
      OK)   ok   "${_ledger_msg[$_i]}" ;;
      WARN) warnf "${_ledger_msg[$_i]}" ;;
      FAIL) bad  "${_ledger_msg[$_i]}" ;;
    esac
  done
fi

# ---------------------------------------------------------------- 5d. 内核身份表
# §5 只看 boot-elden-vk*.img、且只比 manifest 内部两个同源字段（永远相等），抓不到
# 「同 UTS 串不同二进制」和「vk 号其实装的是别的号的内核」。这里补上。
echo
echo "== 5d. 内核身份表（号 ↔ 内核二进制 ↔ 源提交）=="
if [ ${#_gate_st[@]} -eq 0 ]; then
  warnf "内核身份检查未产出结果（python3 / geekidos-linux 缺失？）"
else
  for _i in "${!_gate_st[@]}"; do
    case "${_gate_st[$_i]}" in
      OK)    ok   "${_gate_msg[$_i]}" ;;
      WARN)  warnf "${_gate_msg[$_i]}" ;;
      FAIL)  bad  "${_gate_msg[$_i]}" ;;
      *)     warnf "身份表检查输出无法解析：${_gate_st[$_i]} ${_gate_msg[$_i]}" ;;
    esac
  done
fi
if [ "$_cst" = "0" ]; then
  ok "versions/vk-kernel-identity.tsv 与当前镜像/registry/内核 ref 一致"
else
  bad "内核身份表已过期 → 跑 scripts/vk-identity.py > versions/vk-kernel-identity.tsv 并重提交"
fi

# ---------------------------------------------------------------- 5e. manifest 完整性
echo
echo "== 5e. manifest 完整性（构建产物身份可对账）=="
# 正常 build-manifest.sh 始终写 config_sha256；缺号 = 手写 manifest 旁路。
# 2026-10-10 #162：vk81/82/83 死内核的 manifest 全缺号 → 事后无从对账。
# 历史事故见 versions/manifest-incomplete-allowlist.txt（白名单降 WARN）。
_wf=versions/manifest-incomplete-allowlist.txt
declare -A _wfallow=()
if [ -f "$_wf" ]; then
  while read -r _name _rest; do
    [ -z "$_name" ] && continue
    case "$_name" in \#*) continue ;; esac
    _wfallow["$_name"]=1
  done < "$_wf"
fi
_miss=(); _waived=0; _hist=0
# 纪律起始日：2026-10-10（#162 事故当天 manifest 完整性纳入流程）。此前的 ad-hoc 构建
# （dp*/vkB*/vkB*/vkX/vkY 等与 vk59-61）一律 grandfather，不再逐个白名单。
_CUTOFF="2026-10-10"
for _m in out/*.manifest; do
  [ -e "$_m" ] || continue
  grep -qE '^config_sha256=[0-9a-f]{64}' "$_m" && continue
  _b=$(basename "$_m")
  if [ -n "${_wfallow[$_b]:-}" ]; then _waived=$((_waived+1)); continue; fi
  _gen=$(grep -m1 '^generated=' "$_m" | cut -d= -f2 | cut -c1-10)
  if [ -n "$_gen" ] && [[ "$_gen" < "$_CUTOFF" ]]; then _hist=$((_hist+1)); continue; fi
  _miss+=("$_b")
done
if [ ${#_miss[@]} -eq 0 ]; then
  ok "所有 ≥$_CUTOFF 的 manifest 含 config_sha256（白名单 $_waived / 历史 grandfather $_hist）"
else
  bad "manifest 缺 config_sha256（应走 scripts/build-manifest.sh，勿手写）: ${_miss[*]}"
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

fi   # ← --staged-fast 快速路径到此结束；以下 §7/§8/§9 两条路径都跑

# ---------------------------------------------------------------- 7/8/9. 入口与索引完整性（L1）
# 立此节的直接原因（2026-10-15 独立审查）：三项硬故障全部落在此前自检的盲区里——
#   a) INDEX.md（自称唯一入口）在未闭合 ``` 围栏内物理截断，且尾部泄漏机器证据指针；
#      自首次提交起即存在，无任何检查发现。
#   b) PITFALLS/sessions 有两个 `33-`，索引只登记其一 ⇒ 另一份成孤儿；且其条目号
#      #171–#178 与 22-构建守卫 已定义的 #171–#178 撞车（全库唯一一组重复号），
#      而 reports/ 全量引用的正是后者 ⇒ 静默的引用歧义。
#   c) scripts/check-sessions.sh 早已存在且可跑，但从未被任何门调用（静默腐烂）。
# 本节的判据全部是「纯文本/行数」级，无镜像解压，墙钟 <1 s。
_media=$(python3 - "$ROOT" <<'PY'
import glob, os, re, sys
root = sys.argv[1]

# ---- 7. 入口文档：围栏闭合 + 截断哨兵 + 机器指针泄漏 ----
# 受管入口文件（人类/agent 的第一落点）；改动此清单需同步 INDEX.md §2。
ENTRY = ['INDEX.md', 'AGENTS.md', 'README.md', 'PROGRESS.md',
         '.pi/AGENT-OPS.md', '.pi/README.md',
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
INDEXED_ANGLES = {'PITFALLS', 'SESSIONS'}
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

def emit(tag, items):
    print('%s\t%s' % (tag, '; '.join(items) if items else '-'))
emit('FENCE', fence)
emit('LEAK', leak)
emit('TAIL', tail)
emit('ORPHAN', orphan)
emit('DUPNUM', dupnum)

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
PY
)
echo
echo "== 7. 入口文档完整性（围栏 / 截断 / 机器指针）=="
while IFS=$'\t' read -r _st _msg; do
  case "$_st" in
    FENCE)  [ "$_msg" = "-" ] && ok "受管入口文档围栏闭合、无截断标记" || bad "围栏未闭合或疑似截断（补齐代码围栏 / 恢复被截正文）: $_msg" ;;
    LEAK)   [ "$_msg" = "-" ] && ok "无机器证据指针泄漏进入口文档" || bad "入口文档混入 pi-fold 证据指针（应只留相对路径引用）: $_msg" ;;
    TAIL)   [ "$_msg" = "-" ] && ok "受管入口文档均以换行结尾" || warnf "文件缺少结尾换行: $_msg" ;;
  esac
done <<< "$_media"

echo
echo "== 8. 索引↔磁盘对账（编号撞车=硬错 / 索引覆盖=仅声明角度）=="
while IFS=$'\t' read -r _st _msg; do
  case "$_st" in
    ORPHAN) [ "$_msg" = "-" ] && ok "已声明登记的角度：sessions/ 正文均被 README 引用" || warnf "索引未登记（仅对声明逐文件登记的角度核；补 README 行或移出该口径）: $_msg" ;;
    DUPNUM) [ "$_msg" = "-" ] && ok "文件名/条目编号无撞车" || bad "编号撞车（引用歧义，必须重编）: $_msg" ;;
    STALECOUNT) [ "$_msg" = "-" ] && ok "文档内手写条目计数与磁盘一致" || bad "文档手写计数已过期（改为不写死数字，或同步修正）: $_msg" ;;
  esac
done <<< "$_media"

# ---------------------------------------------------------------- 9. SESSIONS/ 快照一致性
# check-sessions.sh 自 2026-10-14 落地后长期无人调用（审查发现）。此处委托执行：
# 它校验的是「SESSIONS/ 冻结快照 vs git show d8ae437:RESOURCES.md」，属可机读账，故并入 doctor。
# 抽检数固定 3（doctor 应快；全量抽检可手动跑 bash scripts/check-sessions.sh 20）。
echo
echo "== 9. SESSIONS/ 快照一致性（委托 check-sessions.sh）=="
if [ ! -x scripts/check-sessions.sh ] && [ ! -f scripts/check-sessions.sh ]; then
  warnf "scripts/check-sessions.sh 缺失，跳过"
else
  _cs=$(bash scripts/check-sessions.sh 3 2>&1)
  _csrc=$?
  _csl=$(printf '%s\n' "$_cs" | grep -E '^checks OK=|ALL PASS|FAIL' | tail -2 | tr '\n' ' ')
  if [ $_csrc -eq 0 ]; then
    ok "SESSIONS 快照与源一致（$_csl）"
  else
    bad "SESSIONS 快照与源不一致（$_csl）→ 跑 bash scripts/check-sessions.sh 看细节"
  fi
fi

echo
echo "== 汇总: FAIL=$fail  WARN=$warn =="
[ $fail -eq 0 ] && exit 0 || exit 1
