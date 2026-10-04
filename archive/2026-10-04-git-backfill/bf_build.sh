#!/bin/bash
# 从 mtime 清单 + 计划表 构建 pre-vk34 回填历史（纯 plumbing，不动工作树/索引）
# 用法: bf_build.sh <plan.tsv> <branch-ref> <baseline-commit>
# plan.tsv 行: ITER<TAB>epoch<TAB>tag<TAB>subject<TAB>body（body 用字面 \n 表示换行）
# 文件集 = baseline 树（默认 e3ec468）；blob/mode 亦取自 baseline；
# mtime：当前路径存在则 stat；若已被 rename 则 stat 新路径；否则落到桥接提交。
set -euo pipefail
cd ~/y700-elden

PLAN="$1"; REF="$2"; BASE="${3:-e3ec468}"

mapfile -t LINES < "$PLAN"
n=${#LINES[@]}
declare -a BOUND TAG SUBJ BODY HNT
for ((i=0;i<n;i++)); do
  IFS=$'\t' read -r iter ep tag subj body hints <<< "${LINES[$i]}"
  BOUND[$i]="$ep"; TAG[$i]="$tag"; SUBJ[$i]="$subj"; BODY[$i]="$body"; HNT[$i]="${hints:-}"
done
BRIDGE_EP="${BOUND[$((n-1))]}"

# 基线文件集 + blob/mode
declare -A BLOB
while IFS= read -r -d '' entry; do
  path="${entry#*$'\t'}"
  read -r mode _type sha <<< "${entry%%$'\t'*}"
  BLOB["$path"]="$mode $sha"
done < <(git ls-tree -r -z "$BASE")

# rename map BASE->HEAD（仅取 R 行）
declare -A REN
while IFS=$'\t' read -r st old new; do
  [ "${st:0:1}" = "R" ] || continue
  REN["$old"]="$new"
done < <(git diff -M --name-status "$BASE" HEAD)

# 每个基线路径的 mtime
declare -A MT
for path in "${!BLOB[@]}"; do
  if [ -e "$path" ]; then
    MT["$path"]=$(stat -c %Y -- "$path")
  elif [ -n "${REN[$path]:-}" ] && [ -e "${REN[$path]}" ]; then
    MT["$path"]=$(stat -c %Y -- "${REN[$path]}")
  else
    MT["$path"]="$BRIDGE_EP"
  fi
done

# 归属：mtime <= 边界中最早的一个
declare -A ASSIGN
for path in "${!BLOB[@]}"; do
  for ((i=0;i<n;i++)); do
    if [ "${MT[$path]}" -le "${BOUND[$i]}" ]; then ASSIGN["$path"]=$i; break; fi
  done
  # mtime 晚于所有边界（git 纳管前后仍在改）→ 归入最后的桥接提交，
  # 使桥接提交恰好等于基线快照。
  [ -n "${ASSIGN[$path]:-}" ] || ASSIGN["$path"]=$((n-1))
done

# 显式提示覆盖 mtime 归属（补丁/配置按引入它的版本钉住）
for ((i=0;i<n;i++)); do
  for p in ${HNT[$i]}; do
    [ -n "${BLOB[$p]:-}" ] || { echo "HINT not in baseline: $p" >&2; continue; }
    ASSIGN["$p"]=$i
  done
done

# 构建
IDX="$(mktemp /tmp/bf_index.XXXXXX)"; rm -f "$IDX"
export GIT_INDEX_FILE="$IDX"
git read-tree --empty

parent=""; tip=""
for ((i=0;i<n;i++)); do
  for path in "${!ASSIGN[@]}"; do
    [ "${ASSIGN[$path]}" -eq "$i" ] || continue
    read -r mode sha stage <<< "${BLOB[$path]}"
    git update-index --add --cacheinfo "$mode,$sha,$path"
  done
  tree=$(git write-tree)
  msg="${SUBJ[$i]}"
  [ -n "${BODY[$i]}" ] && msg="${SUBJ[$i]}"$'\n\n'"$(printf '%b' "${BODY[$i]}")"
  if [ -n "$parent" ]; then
    commit=$(GIT_AUTHOR_DATE="@${BOUND[$i]} +0800" GIT_COMMITTER_DATE="@${BOUND[$i]} +0800" \
      git commit-tree "$tree" -p "$parent" -m "$msg")
  else
    commit=$(GIT_AUTHOR_DATE="@${BOUND[$i]} +0800" GIT_COMMITTER_DATE="@${BOUND[$i]} +0800" \
      git commit-tree "$tree" -m "$msg")
  fi
  tip="$commit"; parent="$commit"
  if [ -n "${TAG[$i]}" ] && [ "${TAG[$i]}" != "-" ]; then
    GIT_COMMITTER_DATE="@${BOUND[$i]} +0800" git tag -f -a "${TAG[$i]}" -m "${SUBJ[$i]}" "$commit" >/dev/null
  fi
done

git update-ref "refs/heads/$REF" "$tip"
unset GIT_INDEX_FILE
rm -f "$IDX"
echo "REF refs/heads/$REF -> $tip"
