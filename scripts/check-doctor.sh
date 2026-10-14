#!/usr/bin/env bash
# elden 项目医生 — 机器账自检（只读，不改任何文件）
#
# 用法:  scripts/check-doctor.sh     退出码: 0 = 全绿；1 = 有 FAIL
#
# 文档 v2 起不再做文档计数 / 死链 / 口径字样检查：记录的区分度靠写入时的
# 文件夹(角度) + 文件名(日期+主题) + pi 会话 id 保证（见 INDEX.md §2 / .pi/AGENT-OPS.md §4）。
# 只保留机器可核对的账：
#   4. 已退场入口不得复辟
#   5. vk 版本账（registry / manifest / 镜像内 UTS 一致）
#   5d. 内核身份表新鲜度 + 命名/溯源规则门
#   5e. manifest 完整性（config_sha256）
#   6. 静态卫生（设备锁单一真源 / bashism / 死脚本）
set -uo pipefail

cd "$(dirname "$0")/.."
ROOT=$PWD

fail=0
warn=0
ok()   { printf '  [ok]   %s\n' "$1"; }
bad()  { printf '  [FAIL] %s\n' "$1"; fail=$((fail+1)); }
warnf(){ printf '  [warn] %s\n' "$1"; warn=$((warn+1)); }

echo "== elden check-doctor — $ROOT =="

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

echo
echo "== 汇总: FAIL=$fail  WARN=$warn =="
[ $fail -eq 0 ] && exit 0 || exit 1
