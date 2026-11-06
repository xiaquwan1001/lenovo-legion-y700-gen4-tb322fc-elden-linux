#!/bin/bash
# bench.sh — check-doctor 新旧 A/B（2026-11-05 脚本审计的验收装置）
#
# 做什么：
#   在同一棵树（默认 = 主仓 /home/xuqianhui/y700-elden，含 out/ build/ backup/ 这些
#   「重资产」）上各跑 3 次，比较 **墙钟** 与 **判定行集合**：
#     OLD = 基线提交里的 scripts/check-doctor.sh（临时落成 <主仓>/scripts/.ab-old-doctor.sh，
#           跑完即删；点开头 ⇒ 不进 §6 的 scripts/*.sh glob、也不进 git 索引）
#     NEW = 本 lane 的 scripts/check-doctor.sh（子门并发 + 缓存），助手按下表指向暂存副本：
#             ELF_VK_IDENTITY / ELF_MODULAR_CFG / ELF_STATIC_SCAN
#           其余助手（check-sessions/doc-assets/layout/abi）用主仓原版 ⇒ 检查的仍是主仓那棵树。
#   缓存目录放在 /tmp（不写主仓），并且「冷/热」各测一轮。
#
# 判据（任一不满足即退出 1）：
#   1. 判定行逐行相同：`grep -E '^  \[(ok|FAIL|warn)\]'` 的输出 diff 为空；
#   2. 汇总行相同：`FAIL=n WARN=m`；
#   3. 新档明显更快：全量冷 ≤ 旧版 ×0.6，全量热 ≤ 旧版 ×0.4；
#      fast 档 ≤ 旧版 ×1.0 **且** ≤ 1.0 s（fast 档的绝对目标；比值会被「构建树在不在」
#      左右：树在场时旧版 fast 含两遍 olddefconfig ≈3.8 s（比值 ~9×），树被清理后
#      旧版自己也只剩 ~0.6 s ⇒ 用绝对值兜底，避免阈值随环境漂）。
#
# 用法： accept/bench.sh [主仓路径]        # 结果同时写 accept/RESULTS.md
set -uo pipefail

MAIN=${1:-/home/xuqianhui/y700-elden}
REPO=$(cd "$(dirname "$0")/../.." && pwd)   # = 本仓根（脚本位于 scripts/doctor/）
# 基线提交 = 「重构前」的 check-doctor（2026-11-05 脚本审计 merge 之前的 main）。
# 用提交号而不是分支名：合并之后 main 上就是新版，拿 main 当基线会变成「新版 vs 新版」。
BASE=${BASE:-aea0eab}
REPEAT=${REPEAT:-3}
CACHE=/tmp/doctor-ab-cache.$$
TMP=/tmp/doctor-ab.$$
mkdir -p "$CACHE" "$TMP"
# 旧版落成 **符号链接** 而非普通文件：链接名里带 `check-doctor.sh`，于是 §6a 的
# 「设备锁块被复制」自命中排除项（旧版只排除含该字符串的路径）对它同样生效，
# 否则新旧判定行会因为「检查器自己的临时文件」而出现假差异。
OLD="$MAIN/scripts/.ab-check-doctor.sh"
cleanup() { rm -rf "$CACHE" "$TMP"; rm -f "$OLD"; }
trap cleanup EXIT

git -C "$MAIN" show "$BASE:scripts/check-doctor.sh" > "$TMP/old-doctor.sh" || { echo "取不到基线版 check-doctor.sh" >&2; exit 1; }
chmod +x "$TMP/old-doctor.sh"
ln -sfn "$TMP/old-doctor.sh" "$OLD"

run_old() {   # $1=profile
  if [ "${1:-full}" = fast ]; then bash "$OLD" --staged-fast; else bash "$OLD"; fi
}
run_new() {   # $1=profile
  local p=${1:-full}
  ELF_ROOT="$MAIN" \
  ELF_HELPERS="$MAIN/scripts" \
  ELF_VK_IDENTITY="$REPO/scripts/vk-identity.py" \
  ELF_MODULAR_CFG="$REPO/scripts/check-modular-config.sh" \
  ELF_STATIC_SCAN="$REPO/scripts/static-scan.py" \
  VK_ROOT="$MAIN" \
  VK_PAYLOAD_CACHE="$CACHE/vk-payload.json" \
  MOD_CFG_CACHE_DIR="$CACHE/modular-config" \
  local extra=()
  [ "$p" = fast ] && extra=(--staged-fast)
  bash "$REPO/scripts/check-doctor.sh" "${extra[@]}"
}

timeit() {    # $1=outfile $2..=cmd
  local out=$1; shift
  local t0 t1
  t0=$(date +%s.%N)
  "$@" > "$out" 2>&1
  t1=$(date +%s.%N)
  awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.2f", b-a}'
}

# 注意：旧版医生跑在**已经含新文件**的树上，会把本次新增的 scripts/doctor/* 当成「问题」
# （§6a 设备锁块的 grep 会把检查器自身当复制）。这类行不是判据差异，是工具自身的观测噪声，
# 故比对时滤掉「提到 scripts/doctor/ 的行」。
# 过滤两类「工具自身观测噪声」（都不是判据差异）：
#   · 提到 scripts/doctor/ 的行 —— 旧版医生跑在已含新子门的树上，把检查器自身当成了问题；
#   · 「设备锁单一真源」 —— 同上，旧版 §6a 自命中新子门 ⇒ 那一侧少了这条 [ok]。
verdicts() { grep -E '^  \[(ok|FAIL|warn)\]' "$1" | grep -v 'scripts/doctor/' | grep -v '设备锁单一真源' | sed -E 's/[[:space:]]+$//'; }
fails() { grep -E '^  \[FAIL\]' "$1" | grep -v 'scripts/doctor/' || true; }
summary()  { grep -E '^== 汇总:' "$1" | tail -1; }

declare -A T
echo "== A/B 目标树: $MAIN（基线 $BASE）=="
for i in $(seq 1 "$REPEAT"); do
  T[old_full_$i]=$(timeit "$TMP/old-full-$i.txt" run_old full)
  echo "  old  full  #$i ${T[old_full_$i]} s"
done
# 冷缓存：先把缓存清空跑一次（该次即冷），再连跑取热值
rm -rf "$CACHE"; mkdir -p "$CACHE"
T[new_cold]=$(timeit "$TMP/new-cold.txt" run_new full)
echo "  new  full  cold ${T[new_cold]} s"
for i in $(seq 1 "$REPEAT"); do
  T[new_full_$i]=$(timeit "$TMP/new-full-$i.txt" run_new full)
  echo "  new  full  warm #$i ${T[new_full_$i]} s"
done
T[old_fast]=$(timeit "$TMP/old-fast.txt" run_old fast)
echo "  old  fast       ${T[old_fast]} s"
T[new_fast]=$(timeit "$TMP/new-fast.txt" run_new fast)
echo "  new  fast       ${T[new_fast]} s"

med() { local arr=("$@"); printf '%s\n' "${arr[@]}" | sort -n | awk '{a[NR]=$1} END{print a[int((NR+1)/2)]}'; }
old_med=$(med "${T[old_full_1]}" "${T[old_full_2]}" "${T[old_full_3]}")
new_med=$(med "${T[new_full_1]}" "${T[new_full_2]}" "${T[new_full_3]}")

echo
echo "== 判定行比对（旧 full 最后一次 vs 新 full 最后一次）=="
verdicts "$TMP/old-full-$REPEAT.txt" > "$TMP/v_old.txt"
verdicts "$TMP/new-full-$REPEAT.txt" > "$TMP/v_new.txt"
if diff -u "$TMP/v_old.txt" "$TMP/v_new.txt" > "$TMP/v.diff"; then
  echo "  判定行逐行相同（$(wc -l < "$TMP/v_old.txt") 行）"
  same=1
else
  echo "  ✗ 判定行有差异："; sed -n '1,40p' "$TMP/v.diff"; same=0
fi
echo "  old $（$(summary "$TMP/old-full-$REPEAT.txt")） / new $（$(summary "$TMP/new-full-$REPEAT.txt")）"
s_old=$(summary "$TMP/old-full-$REPEAT.txt"); s_new=$(summary "$TMP/new-full-$REPEAT.txt")

ok=1
awk -v o="$old_med" -v n="$new_med" 'BEGIN{exit !(n <= o*0.6)}' || { echo "  ✗ 全量冷/热中位数未达 0.6×"; ok=0; }
awk -v o="$old_med" -v n="${T[new_full_1]}" 'BEGIN{exit !(n <= o*0.4)}' || { echo "  ✗ 全量热未达 0.4×"; ok=0; }
awk -v o="${T[old_fast]}" -v n="${T[new_fast]}" 'BEGIN{exit !(n <= o && n <= 1.0)}' || { echo "  ✗ fast 档未达「≤ 旧版 且 ≤ 1.0 s」"; ok=0; }
fails "$TMP/old-full-$REPEAT.txt" > "$TMP/f_old.txt"
fails "$TMP/new-full-$REPEAT.txt" > "$TMP/f_new.txt"
if diff -q "$TMP/f_old.txt" "$TMP/f_new.txt" >/dev/null; then
  echo "  FAIL 行集合相同（$(wc -l < "$TMP/f_old.txt") 条）"
else
  echo "  ✗ FAIL 行集合不同："; diff "$TMP/f_old.txt" "$TMP/f_new.txt"; ok=0
fi
[ "$same" = 1 ] || ok=0

{
  echo "# check-doctor 新旧 A/B（$(date +%F' '%T)）"
  echo
  echo "- 目标树：\`$MAIN\`　基线：\`$BASE\`　每组重复 $REPEAT 次（取中位数）"
  echo
  echo '| 档 | 旧版 | 新版（冷） | 新版（热） | 加速（冷/热） |'
  echo '|---|---|---|---|---|'
  awk -v a="${T[old_fast]}" -v b="${T[new_fast]}" 'BEGIN{printf "| --staged-fast | %s s | — | %s s | %.1f× |\n", a, b, a/b}'
  awk -v a="$old_med" -v b="${T[new_cold]}" -v c="$new_med" 'BEGIN{printf "| 全量 | %s s | %s s | %s s | %.1f× / %.1f× |\n", a, b, c, a/b, a/c}'
  echo
  echo "判定行：$(wc -l < "$TMP/v_old.txt") 行，新旧逐行相同 = $([ "$same" = 1 ] && echo 是 || echo 否)；"
  echo "汇总：旧 \`$s_old\` / 新 \`$s_new\`。"
  echo
  echo '> 冷 = 清空 \`.cache\` 后首次（vk 载荷解压 + modular config 结论重算）；热 = 稳态（收尾轮/反复跑的实际体验）。'
}

echo
echo "== 结果：全量 旧 ${old_med}s → 新 冷 ${T[new_cold]}s / 热 ${new_med}s；fast 旧 ${T[old_fast]}s → 新 ${T[new_fast]}s"
[ "$ok" = 1 ] && { echo "ACCEPT: PASS"; exit 0; } || { echo "ACCEPT: FAIL"; exit 1; }
