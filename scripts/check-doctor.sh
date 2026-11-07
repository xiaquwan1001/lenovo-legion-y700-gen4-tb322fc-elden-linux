#!/usr/bin/env bash
# elden 项目医生 — 机器账自检（只读，不改任何文件）
#
# 用法:  scripts/check-doctor.sh                 退出码: 0 = 全绿；1 = 有 FAIL
#        scripts/check-doctor.sh --staged-fast  入库前档（pre-commit 用）：只跑纯文本/廉价段
#        scripts/check-doctor.sh --only 6       只跑某一节（调试判据时用，见 --list）
#        scripts/check-doctor.sh --list         列出全部子门（含所属档位）
#        scripts/check-doctor.sh --json         机器可读汇总（fail/warn/sections）
#
# ★ 2026-11-05 重构（脚本审计轮）：649 行单体 → **调度器 + 独立子门**。
#   动机与验收数据见 reports/script-audit-20261105.md 与 accept/RESULTS.md：
#     · 旧版全量 12.5 s，其中 90% 在四个**互不依赖**的段（§5 vk 镜像解压 3.3 s、§6 静态扫描
#       3.75 s、§12 olddefconfig 3.2 s、§5f pahole 1.05 s），却全部串行 `$(...)` 执行；
#     · 旧版 --staged-fast 自称「纯文本 ~0.2 s」，实测 3.79 s —— §12 在 fast 档那个 `fi`
#       之后，等于每次 commit 都白跑两遍 make olddefconfig。
#   现在：子门并发跑（scripts/doctor/NN-*.sh|py），fast 档剔除 §12，三处重活各加缓存。
#   判定契约没变：判据只看子门输出的 `  [ok]/[FAIL]/[warn]` 行，退出码不参与。
#
# 子门（scripts/doctor/，每个都能单独手跑，输出与 doctor 内一致）：
#   04-retired.sh    已退场入口不得复辟                            [全量]
#   05-vk.sh         vk 版本账(§5) + 内核身份表(§5d)               [全量] 一次扫描出两节
#   05e-manifest.sh  manifest 完整性（config_sha256）               [全量]
#   05f-abi.sh       ABI 敏感项一致性（.config ↔ 模块树）           [全量]
#   06-hygiene.sh    静态卫生（设备锁单一真源 / bashism / 死脚本）  [全量]
#   s07-08-docs.py   入口文档完整性(§7) + 索引↔磁盘对账(§8)         [全量+fast]
#   09-sessions.sh   SESSIONS/ 快照一致性                           [全量+fast]
#   10-history.sh    HISTORY 对账                                   [全量+fast]
#   11-hooks.sh      提交钩子生效性                                 [全量+fast]
#   12-modular.sh    驱动模块化门禁                                 [全量]  ← fast 档不跑
#   13-assets.sh     文档引用的资产路径存在性                       [全量+fast]
#   14-layout.sh     顶层布局注册表                                 [全量+fast]
#   s16-tasks-counts.py TASKS §0 手写数字 ↔ 计数脚本对账            [全量+fast]
#
# 验收用环境变量（正常使用无需设置）：
#   ELF_ROOT=<dir>        被检查的树（默认 = 本脚本上一级）—— A/B 时指向主仓
#   ELF_HELPERS=<dir>     助手脚本目录（默认 = 本脚本所在目录）
#   ELF_VK_IDENTITY / ELF_MODULAR_CFG / ELF_STATIC_SCAN
#                         分别覆盖三个被重写过的助手（A/B 时指向暂存副本）
#   ELF_SEC_TIMEOUT=<s>   单个子门超时（默认 600）
set -uo pipefail

SELFDIR=$(cd "$(dirname "$0")" && pwd)
ROOT="${ELF_ROOT:-$(cd "$SELFDIR/.." && pwd)}"
HELPERS="${ELF_HELPERS:-$SELFDIR}"
SEC_TIMEOUT="${ELF_SEC_TIMEOUT:-600}"
export ROOT HELPERS

# 子门清单：按输出顺序排列（数字 = 与旧版 §N 对齐）。
ALL="04-retired.sh 05-vk.sh 05e-manifest.sh 05f-abi.sh 06-hygiene.sh s07-08-docs.py 09-sessions.sh 10-history.sh 11-hooks.sh 12-modular.sh 13-assets.sh 14-layout.sh s16-tasks-counts.py"
# fast 档 = 旧版 --staged-fast 的语义（§7/§8/§9 + 其后的廉价段）**减去 §12**：
# 文档/索引提交与内核 .config 无关，那 3.2 s 是纯浪费；手改 .config 的拦截交给收尾轮全量 doctor。
# 2026-11-07 加 s16（PITFALLS #548）：TASKS §0 手写数字漂移门，只读两个文件 ~0.04 s，纳入 fast。
FAST="s07-08-docs.py 09-sessions.sh 10-history.sh 11-hooks.sh 13-assets.sh 14-layout.sh s16-tasks-counts.py"

PROFILE=full
ONLY=""
JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --staged-fast|--fast) PROFILE=fast ;;
    --full) PROFILE=full ;;
    --only) ONLY="${2:?--only 需要节号/文件名}"; shift ;;
    --only=*) ONLY="${1#--only=}" ;;
    --json) JSON=1 ;;
    --list)
      for s in $ALL; do
        case " $FAST " in *" $s "*) p="full+fast" ;; *) p="full" ;; esac
        printf '%-18s %s\n' "$s" "$p"
      done
      exit 0 ;;
    -h|--help) sed -n '2,35p' "$0"; exit 0 ;;
    *) echo "check-doctor: 未知参数 $1（支持 --staged-fast / --only N / --list / --json）" >&2; exit 2 ;;
  esac
  shift
done

# --only：接受 `6` / `06` / `06-hygiene.sh` / `s07-08-docs.py` / 唯一子串
if [ -n "$ONLY" ]; then
  SEL=""
  for s in $ALL; do
    case "$s" in
      "$ONLY"|"$ONLY".*|*"$ONLY"*) SEL="$s"; break ;;
    esac
  done
  [ -n "$SEL" ] || { echo "check-doctor: 没有匹配 '$ONLY' 的子门（用 --list）" >&2; exit 2; }
  LIST="$SEL"
elif [ "$PROFILE" = fast ]; then
  LIST="$FAST"
else
  LIST="$ALL"
fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/doctor.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

if [ "$JSON" != 1 ]; then
  if [ "$PROFILE" = fast ] && [ -z "$ONLY" ]; then
    echo "== elden check-doctor (--staged-fast: 纯文本档，跳过 §4/§5/§5d/§5e/§5f/§6/§12) — $ROOT =="
  else
    echo "== elden check-doctor — $ROOT =="
  fi
fi

# ---- 并发调度：子门互不共享状态（§5 只读镜像 / §6+§7/8 只读文本 / §12 只在 mktemp 里跑
#      olddefconfig / §5f 只读 vmlinux），因此可全部同时起。输出各自落盘后按固定顺序拼接，
#      所以并发不会打乱报告顺序，也不会让某一段的输出插进另一段。
pids=""
for s in $LIST; do
  f="$SELFDIR/doctor/$s"
  out="$TMP/$s.out"
  if [ ! -f "$f" ]; then
    printf '\n== %s ==\n  [FAIL] 子门脚本缺失: %s\n' "$s" "$f" > "$out"
    continue
  fi
  ( cd "$ROOT" && timeout "$SEC_TIMEOUT" "$f" ) > "$out" 2>&1 &
  pids="$pids $!:"
done
for p in $pids; do wait "${p%:}"; done

# ---- 按固定顺序输出 + 统计 ----
fail=0
warn=0
for s in $LIST; do
  out="$TMP/$s.out"
  if [ ! -s "$out" ]; then
    printf '\n== %s ==\n  [warn] 子门无输出（超时 %ss 或异常退出？单独跑一次看）\n' "$s" "$SEC_TIMEOUT" > "$out"
  fi
  cat "$out"
  fail=$((fail + $(grep -c '^  \[FAIL\]' "$out")))
  warn=$((warn + $(grep -c '^  \[warn\]' "$out")))
done

if [ "$JSON" = 1 ]; then
  secs=""
  for s in $LIST; do
    secs="$secs${secs:+,}\"$s\""
  done
  printf '{"fail":%d,"warn":%d,"profile":"%s","sections":[%s]}\n' \
    "$fail" "$warn" "$PROFILE" "$secs"
else
  echo
  echo "== 汇总: FAIL=$fail  WARN=$warn =="
fi
[ "$fail" -eq 0 ] && exit 0 || exit 1
