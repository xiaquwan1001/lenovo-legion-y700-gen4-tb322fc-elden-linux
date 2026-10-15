#!/bin/bash
# rambuild.sh — 内存盘构建区（RAM build scratch）辅助（见 .pi/plans/2026-10-15_081500-内存盘构建区规划.md）
#
# 设计：RAM 层（易失）= 内核树工作集；磁盘层（持久）= ccache + git；快照层 = 只存不可再生的
#       （git diff + 未跟踪文件 + .config + HEAD）。产物不进快照。
#
# 用法：
#   scripts/rambuild.sh status
#   scripts/rambuild.sh guard <need-GiB>            # 空间/内存守卫（不足 exit 3）
#   scripts/rambuild.sh ensure                      # 幂等：建目录 + 按清单重建缺失树 + prune 悬空条目
#   scripts/rambuild.sh new <name> <base-ref> [--kernel|--bare]
#   scripts/rambuild.sh mirror <existing-tree> <name>   # 内存盘独立登记 worktree + 逐字节镜像
#   scripts/rambuild.sh list
#   scripts/rambuild.sh snapshot <name>
#   scripts/rambuild.sh evict <name>                # 先 snapshot 再删树（/bin/rm -rf）
#   scripts/rambuild.sh measure <tree> <label> <targets...>
#
# 注意（2026-10-15 实测）：pi.bash 里的 `rm -rf` 会被换成“移入 ~/.pi/trash”，对 tmpfs 报
#   EXDEV 且删不掉 ⇒ 本脚本一律用 /bin/rm -rf。
#
# Env：ROOT RAM_ROOT KREPO JOBS MIN_AVAIL_GIB
set -euo pipefail

ROOT=${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
RAM_ROOT=${RAM_ROOT:-/dev/shm/elden}
KREPO=${KREPO:-$ROOT/geekidos-linux}
SNAP_ROOT=${SNAP_ROOT:-$ROOT/.pi/rambuild}
MANIFEST=$SNAP_ROOT/manifest.tsv
RESULTS=${RESULTS:-$ROOT/reports/rambuild-measure.tsv}
LOGDIR=${LOGDIR:-$ROOT/logs}
MIN_AVAIL_GIB=${MIN_AVAIL_GIB:-12}

usage() { sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-1}"; }
die()   { echo "rambuild: $*" >&2; exit 1; }

mem_avail_mb() { awk '/^MemAvailable:/{printf "%d", $2/1024}' /proc/meminfo; }
fs_of()        { findmnt -no FSTYPE -T "$1" 2>/dev/null || stat -f -c %T "$1" 2>/dev/null; }
avail_mb()     { df -BM --output=avail "$1" 2>/dev/null | tail -1 | tr -dc '0-9'; }
shm_used_mb()  { awk '/^Shmem:/{printf "%d", $2/1024}' /proc/meminfo; }
require_table()  { [ -f "$MANIFEST" ] || { mkdir -p "$SNAP_ROOT"; printf '# name\tbase\tpath\tcreated\n' > "$MANIFEST"; }; }
row_of()  { require_table; awk -F'\t' -v n="$1" '$1==n{print; exit}' "$MANIFEST"; }
field()   { row_of "$1" | cut -f"$2"; }

cmd_status() {
  echo "[rambuild] RAM_ROOT=$RAM_ROOT fs=$(fs_of "$RAM_ROOT" 2>/dev/null || echo missing) used=$( [ -d "$RAM_ROOT" ] && avail_mb "$RAM_ROOT" >/dev/null && { df -BM --output=used "$RAM_ROOT"|tail -1|tr -dc '0-9'; } || echo 0)MB avail=$( [ -d "$RAM_ROOT" ] && avail_mb "$RAM_ROOT" || echo 0)MB"
  echo "[rambuild] MemAvailable=$(mem_avail_mb)MB  Shmem=$(shm_used_mb)MB  MIN_AVAIL_GIB=$MIN_AVAIL_GIB"
  echo "[rambuild] 监视器: systemctl --user list-timers | grep tmpfs  /  ~/.local/bin/tmpfs-usage-report.sh"
  require_table
  if [ -s "$MANIFEST" ]; then
    printf '[rambuild] 内存盘上的树:\n'
    while IFS=$'\t' read -r n b p c; do
      case "$n" in \#*|"") continue;; esac
      [ -d "$p" ] && printf '  %-24s %-22s %s (%s MB)\n' "$n" "$b" "$p" "$(du -sm "$p" 2>/dev/null | cut -f1)" \
                   || printf '  %-24s %-22s %s  [缺失→ensure 重建]\n' "$n" "$b" "$p"
    done < "$MANIFEST"
  fi
  echo "[rambuild] 悬空 worktree 条目: $(git -C "$KREPO" worktree list --porcelain | grep -c '^worktree ') 个已登记；prunable: $(git -C "$KREPO" worktree list | grep -c prunable || true)"
}

cmd_guard() { # need-GiB
  local need=${1:?usage: rambuild.sh guard <need-GiB>}
  local avail_mem avail_disk
  avail_mem=$(mem_avail_mb); avail_disk=$(avail_mb "$RAM_ROOT" 2>/dev/null || avail_mb /dev/shm)
  echo "[guard] 需要 ${need}GiB：MemAvailable=$((avail_mem/1024))GiB  RAM盘可用=$((avail_disk/1024))GiB  下限=${MIN_AVAIL_GIB}GiB"
  [ "$((avail_disk/1024))" -ge "$need" ] || { echo "[guard] ✗ RAM 盘空间不足（需 ${need}GiB）→ 先 rambuild.sh evict <name>" >&2; exit 3; }
  [ "$((avail_mem/1024))" -ge "$((need+MIN_AVAIL_GIB))" ] || { echo "[guard] ✗ 内存不足：需 ${need}+${MIN_AVAIL_GIB}GiB 可用，实为 $((avail_mem/1024))GiB" >&2; exit 3; }
  echo "[guard] ✓ 通过"
}

cmd_ensure() {
  mkdir -p "$RAM_ROOT" "$SNAP_ROOT"; chmod 700 "$RAM_ROOT"
  require_table
  git -C "$KREPO" worktree prune
  while IFS=$'\t' read -r n b p c; do
    case "$n" in \#*|"") continue;; esac
    if [ -d "$p" ]; then echo "[ensure] ok      $n"; continue; fi
    echo "[ensure] 重建    $n  ($b → $p)"
    git -C "$KREPO" worktree add --detach "$p" "$b" >/dev/null
    [ -f "$SNAP_ROOT/$n/.config" ] && cp -a "$SNAP_ROOT/$n/.config" "$p/.config"
    [ -f "$SNAP_ROOT/$n/diff.patch" ] && git -C "$p" apply --whitespace=nowarn "$SNAP_ROOT/$n/diff.patch" 2>/dev/null || true
  done < "$MANIFEST"
  echo "[ensure] 完成"
}

cmd_new() { # name base-ref [--kernel|--bare]
  local name=${1:?usage: rambuild.sh new <name> <base-ref>} base=${2:?缺 base-ref}
  cmd_guard 3
  local path=$RAM_ROOT/t-$name
  [ -e "$path" ] && die "已存在：$path（先 evict $name）"
  git -C "$KREPO" worktree add --detach "$path" "$base"
  [ -f "$KREPO/.config" ] && cp -a "$KREPO/.config" "$path/.config" 2>/dev/null || true
  require_table; printf '%s\t%s\t%s\t%s\n' "$name" "$base" "$path" "$(date -F'%F %T')" >> "$MANIFEST" 2>/dev/null || printf '%s\t%s\t%s\t%s\n' "$name" "$base" "$path" "$(date '+%F %T')" >> "$MANIFEST"
  echo "[new] $name → $path（$(fs_of "$path")）"
}

cmd_mirror() { # existing-tree name —— 内存盘建**独立登记**的 worktree，再把内容逐字节镜像过去
  local src=${1:?usage: rambuild.sh mirror <existing-tree> <name>} name=${2:?缺 name}
  [ -d "$src" ] || die "无此树：$src"
  command -v rsync >/dev/null || die "缺 rsync"
  local need=$(( $(du -sm "$src" | cut -f1) / 1024 + 1 ))
  cmd_guard "$need"
  local dst=$RAM_ROOT/t-$name sha
  [ -e "$dst" ] && die "已存在：$dst（先 evict $name）"
  sha=$(git -C "$src" rev-parse HEAD)
  # 先登记独立 worktree —— 不要用 cp -a 复制（会把同一个 .git 指针带过去，两个工作树共用一份元数据）
  git -C "$KREPO" worktree add --detach "$dst" "$sha" >/dev/null
  echo "[mirror] rsync $src/ → $dst/（排除 .git，--delete，约 ${need}GiB）"
  rsync -a --delete --exclude='.git' "$src/" "$dst/"
  require_table; printf '%s\t%s\t%s\t%s\n' "$name" "mirror:$sha" "$dst" "$(date '+%F %T')" >> "$MANIFEST"
  mkdir -p "$SNAP_ROOT/$name"; [ -f "$dst/.config" ] && cp -a "$dst/.config" "$SNAP_ROOT/$name/.config" || true
  echo "[mirror] 完成（$dst，$(fs_of "$dst")，HEAD=$sha）；两側一致性：diff -r --no-dereference --brief"
}

cmd_snapshot() { # name   （也接受 tree 路径）
  local name=${1:?usage: rambuild.sh snapshot <name|tree-path>}
  local path
  if [ -d "$name" ]; then path=$name; name=$(basename "$path"); else path=$(field "$name" 3); fi
  [ -d "$path" ] || die "无此树：$path"
  local d=$SNAP_ROOT/$name; mkdir -p "$d"
  git -C "$path" rev-parse HEAD > "$d/HEAD"
  git -C "$path" rev-parse --abbrev-ref HEAD > "$d/branch" 2>/dev/null || true
  git -C "$path" diff > "$d/diff.patch" 2>/dev/null || true
  git -C "$path" status --porcelain=v1 > "$d/status.txt"
  [ -f "$path/.config" ] && cp -a "$path/.config" "$d/.config"
  # 护栏：已编译的树里「未跟踪文件」= 全部构建产物（可达数 GB）⇒ 打包会把仓库撑爆。
  # 只快照源码层的未跟踪文件；产物可重生，本就不该进快照。
  local nu; nu=$(git -C "$path" ls-files --others --exclude-standard 2>/dev/null | wc -l)
  if [ "$nu" -gt 2000 ]; then
    echo "[snapshot] ⚠️  未跟踪文件 $nu 个（已编译的树）⇒ 跳过 untracked 打包（产物可重生）"
    echo "untracked: skipped ($nu files, artifacts)" > "$d/untracked-skipped.txt"
  else
    git -C "$path" ls-files --others --exclude-standard -z 2>/dev/null \
      | tar --null -T - -czf "$d/untracked.tar.gz" 2>/dev/null || : > "$d/untracked.tar.gz"
  fi
  echo "[snapshot] $name → $d（diff $(wc -l < "$d/diff.patch") 行, untracked $(du -h "$d/untracked.tar.gz" | cut -f1), 未跟踪 $(wc -l < "$d/status.txt") 项）"
}

cmd_evict() { # name
  local name=${1:?usage: rambuild.sh evict <name>}
  local path; path=$(field "$name" 3); [ -n "$path" ] || path=$RAM_ROOT/t-$name
  [ -d "$path" ] || die "无此树：$path"
  if pgrep -af 'make' | grep -q "$path"; then die "该树上有 make 在跑（$path）→ 拒绝删除"; fi
  cmd_snapshot "$name"
  echo "[evict] /bin/rm -rf $path"
  /bin/rm -rf "$path"
  git -C "$KREPO" worktree prune
  require_table; awk -F'\t' -v n="$name" '$1!=n' "$MANIFEST" > "$MANIFEST.tmp" && mv "$MANIFEST.tmp" "$MANIFEST"
  echo "[evict] 完成（快照保留在 $SNAP_ROOT/$name）"
}

cmd_list() { require_table; cat "$MANIFEST"; }

cmd_measure() { # <tree> <label> <make targets...>
  local tree=${1:?usage: rambuild.sh measure <tree> <label> <targets...>} label=${2:?缺 label}; shift 2
  [ -d "$tree" ] || die "无此树：$tree"
  # shellcheck disable=SC1091
  . "$ROOT/scripts/env-build.sh"
  # A/B 可比性：按 commit 固定构建身份（仅本函数内，不改 env-build.sh 默认语义；见规划 §0-8）
  export KBUILD_BUILD_TIMESTAMP="$(git -C "$tree" log -1 --format=%cd --date=format:'%Y-%m-%d %T %Z' 2>/dev/null || date '+%Y-%m-%d %T %Z')"
  local fs; fs=$(fs_of "$tree")
  local log=$LOGDIR/rambuild-$label.log csv=$LOGDIR/rambuild-$label.mem.csv
  : > "$csv"
  ( while :; do printf '%s\t%s\t%s\n' "$(date +%s)" "$(mem_avail_mb)" "$(shm_used_mb)" >> "$csv"; sleep 5; done ) &
  local sampler=$!
  echo "[measure] label=$label tree=$tree fs=$fs targets=$* JOBS=${JOBS:-$(nproc)} KBUILD_BUILD_TIMESTAMP=$KBUILD_BUILD_TIMESTAMP"
  local t0 ts0; ts0=$(date +%s); t0=$SECONDS
  make -C "$tree" -j"${JOBS:-$(nproc)}" LOCALVERSION= "$@" > "$log" 2>&1 && rc=0 || rc=$?
  local wall=$((SECONDS-t0)); kill "$sampler" 2>/dev/null || true; wait "$sampler" 2>/dev/null || true
  local mmin; mmin=$(awk -F'\t' 'NR==1{m=$2} $2<m{m=$2} END{print m}' "$csv")
  local img=$tree/arch/arm64/boot/Image.gz dtb=$tree/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb
  local sha_img=- sha_dtb=- uts_rel=- uts_ver=-
  [ -f "$img" ] && sha_img=$(sha256sum "$img" | cut -c1-16)
  [ -f "$dtb" ] && sha_dtb=$(sha256sum "$dtb" | cut -c1-16)
  uts_rel=$(make -s -C "$tree" ARCH=arm64 kernelrelease 2>/dev/null || true)
  # 注意：set -o pipefail + grep -m1 会让上游 strings 收 SIGPIPE ⇒ 管道状态非 0（曾把 '-'
  # 拼进本字段并撑破 tsv 行）。这里用 || true 忽略管道状态，只取输出。
  uts_ver=$(strings "$tree/vmlinux" 2>/dev/null | grep -m1 -E '^#[0-9]+ SMP' || true)
  [ -f "$RESULTS" ] || { mkdir -p "$(dirname "$RESULTS")"; printf 'label\tdate\ttree\tfs\ttargets\twall_s\tmemavail_min_mb\timg_sha16\tdtb_sha16\tuts_release\tuts_version\trc\n' > "$RESULTS"; }
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$label" "$(date '+%F %T')" "$tree" "$fs" "$*" "$wall" "$mmin" "$sha_img" "$sha_dtb" "$uts_rel" "$uts_ver" "$rc" >> "$RESULTS"
  echo "[measure] rc=$rc wall=${wall}s memavail_min=${mmin}MB img=$sha_img dtb=$sha_dtb"
  echo "[measure] 记录 → $RESULTS ；日志 → $log ；内存曲线 → $csv"
  return "$rc"
}

case "${1:-}" in
  status)   cmd_status ;;
  guard)    shift; cmd_guard "$@" ;;
  ensure)   cmd_ensure ;;
  new)      shift; cmd_new "$@" ;;
  adopt|mirror) shift; cmd_mirror "$@" ;;
  snapshot) shift; cmd_snapshot "$@" ;;
  evict)    shift; cmd_evict "$@" ;;
  list)     cmd_list ;;
  measure)  shift; cmd_measure "$@" ;;
  ''|-h|--help|help) usage 0 ;;
  *) die "未知子命令：$1（-h 看用法）" ;;
esac
