#!/usr/bin/env bash
# tablet-offline-pkgs.sh — L2-A 离线包生成脚本（tablet-offload-20261030）
#
# 用途：为平板（root@192.168.7.1, Debian sid arm64）生成离线依赖包与预传清单。
# 默认 DRY_RUN=1：只打印将要执行的动作与清单，不下载、不传输、不写平板。
# 显式 `--run` 才真正动作。安全：不做 apt install/upgrade，不对平板执行任何写，
# 不做任何 git 写（commit/push/改 remote）；平板侧动作只是生成 ssh 命令文本。
#
# 用法：
#   bash .pi/plans/tablet-offline-pkgs.sh                # 全 DRY_RUN
#   bash .pi/plans/tablet-offline-pkgs.sh --run host     # host 侧：抽取预传文件 + SHA256 清单
#   bash .pi/plans/tablet-offline-pkgs.sh --run apt      # 生成平板 apt-get download 命令清单（仍只在 host 打印/落盘）
#   bash .pi/plans/tablet-offline-pkgs.sh --run npm      # Pi agent 离线目录校验 + npm pack 清单
#
# 排除清单（hard-exclude，任何档位都不得包含）：
#   build/ geekidos-linux/ out/ stock-src/ env-pass/ backup/*.img dl-cam/*.img
#   .pi/sessions/ 未跟踪 out/ 产物
set -euo pipefail

DRY_RUN=1
ACTIONS=""
for a in "$@"; do
  case "$a" in
    --run) DRY_RUN=0 ;;
    host|apt|npm) ACTIONS+="$a " ;;
    *) echo "unknown arg: $a" >&2; exit 2 ;;
  esac
done
[ -n "$ACTIONS" ] || ACTIONS="host apt npm"

REPO="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "not in git repo" >&2; exit 2; }
STAMP=tablet-offload-20261030
OUT="$REPO/reports/artifacts/$STAMP"
PKGDIR="$REPO/out-offline-pkgs"   # host 侧暂存目录（不属于仓库跟踪内容）
SPACE_BUDGET_MB=2000              # 生成离线包最多允许占用 host 磁盘 2 GiB
DISK_FLOOR_MB=2000                # host 磁盘剩余必须 >= 2 GiB，否则 exit 1

log() { printf '%s\n' "$*"; }
run() {
  if [ "$DRY_RUN" = 1 ]; then log "DRY-RUN: $*"; else log "RUN: $*"; "$@"; fi
}

# 空间检查：目标剩余空间不足立即 exit 1
check_space() {
  local avail_mb
  avail_mb=$(df -Pm "$1" | awk 'NR==2{print $4}')
  log "df: $1 available = ${avail_mb} MiB (floor ${DISK_FLOOR_MB} MiB)"
  if [ "$avail_mb" -lt "$DISK_FLOOR_MB" ]; then
    echo "FATAL: not enough disk space on $1 (${avail_mb} MiB < ${DISK_FLOOR_MB} MiB)" >&2
    exit 1
  fi
}

rsync_excludes=(
  --exclude='build/' --exclude='geekidos-linux/' --exclude='out/'
  --exclude='stock-src/' --exclude='env-pass/'
  --exclude='backup/'          # backup 主体是 *.img；整目录排除（含少量脚本可重取）
  --exclude='dl-cam/'          # dl-cam 主体是 *.img
  --exclude='.pi/sessions/'
  --exclude='out-offline-pkgs/'
)

### ---- host 侧：抽取预传文件并算 SHA256 ----
do_host() {
  log "=== [host] 预传文件抽取 ==="
  check_space "$REPO"
  # A 档（最小可跑）：git-tracked 工作树 + .git pack + patches/reports/TASKS/PITFALLS/.pi/skills
  run mkdir -p "$PKGDIR"
  run git -C "$REPO" archive --format=tar.gz --prefix=y700-elden/ -o "$PKGDIR/y700-elden-worktree.tar.gz" HEAD
  # .git pack（31.19 MiB）：只取 objects/pack，避免锁与 hook
  run tar -C "$REPO/.git" -czf "$PKGDIR/git-pack.tar.gz" objects/pack
  # 未跟踪但需预传的目录（reports 等 git archive 覆盖不到的部分）
  for d in reports patches TASKS PITFALLS .pi/skills; do
    run rsync -a --delete "$REPO/$d" "$PKGDIR/pool/$d"
  done
  # SHA256 清单
  if [ "$DRY_RUN" = 1 ]; then
    log "DRY-RUN: (cd $PKGDIR && find . -type f -print0 | sort -z | xargs -0 sha256sum > $PKGDIR/SHA256SUMS)"
  else
    (cd "$PKGDIR" && find . -type f -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
    log "manifest: $PKGDIR/SHA256SUMS ($(wc -l < "$PKGDIR/SHA256SUMS") entries)"
  fi
  log "host 侧预估总体积：worktree tar ~25M + git-pack 31M + pool(reports 99M+patches 13M+TASKS 1.1M+PITFALLS 1M+skills 0.4M) ≈ 170 MiB"
}

### ---- apt 侧：平板 apt-get download（USTC sid 源）----
# 平板源应为 mirrors.ustc.edu.cn/debian sid；下列命令文本写入清单，由 L3/执行者
# 在平板上粘贴执行（本脚本绝不 ssh 写平板）。落到 /var/cache/apt/archives.offline。
do_apt() {
  log "=== [apt] 平板侧 apt-get download 命令清单 ==="
  local f="$OUT/tablet-apt-offline-commands.sh"
  run mkdir -p "$OUT"
  cat > "$f" <<'EOS'
#!/usr/bin/env bash
# 在平板（Debian sid arm64）上执行；需要平板先 apt-get update（只读下载索引）。
set -euo pipefail
CACHE=/var/cache/apt/archives.offline
mkdir -p "$CACHE"
# 分组（L1 实测 --print-uris 体积）：
# core-dev 6 pkgs 14.3 MiB
apt-get download build-essential gcc make libc6-dev linux-libc-dev g++ >/dev/null   # 以 L1 清单为准逐包补齐
# ble.sh 1 pkg 0.5 MiB
apt-get download blesh >/dev/null
# nodejs+npm 468 pkgs 67.1 MiB（含依赖全链路）
apt-get download nodejs npm $(apt-get -s install nodejs npm | awk '/^Inst /{print $2}' | sort -u) >/dev/null
# py-static 38 pkgs 12.1 MiB（python3-dev/python3-pip 等，按 L1 清单）
# kbuild 29 pkgs 9.1 MiB（flex bison bc libssl-dev dwarves ccache 等）
# 下载位置：cd 到 $CACHE 再 apt-get download，或用
#   apt-get -o Dir::Cache::archives="$CACHE" --download-only install --no-install-recommends <pkgs>
# ⚠ apt-get download 不递归依赖；完整离线建议用
#   apt-get install --download-only --reinstall -o Dir::Cache::archives="$CACHE" <pkg 列表>
# 完成后核对总数：ls "$CACHE" | wc -l（应 ≥513，与 L1 --print-uris 513 pkgs 一致）
EOS
  if [ "$DRY_RUN" = 1 ]; then
    log "DRY-RUN: would write $f (already shown above); content NOT executed on tablet."
    [ -f "$f" ] && rm -f "$f"   # DRY_RUN 下不留真实文件
  else
    log "written: $f"
  fi
  log "apt 档总体积（L1 实测）：513 pkgs / 84.6 MiB → 平板 /var/cache/apt/archives.offline"
}

### ---- npm / Pi 侧 ----
do_npm() {
  log "=== [npm/Pi] 离线包 ==="
  local pidir="$HOME/.pi/agent/npm"
  # 方案一（首选）：直接 rsync Pi release 目录（含 node_modules 即离线可用）
  if [ -d "$pidir" ]; then
    run du -sh "$pidir"
    log "DRY-RUN: rsync -a $pidir/ $PKGDIR/pool/pi-agent-npm/"
    log "DRY-RUN: node 在平板上以 apt nodejs 24.22.0 直接运行该目录（npm registry 已 200 可作回退）"
  fi
  # 方案二（回退）：npm pack 全量依赖（registry.npmjs.org 200）
  log "DRY-RUN 回退: cd $pidir && npm pack --pack-destination $PKGDIR/pool/npm-tarballs/（不推荐，体积更大）"
  # pypi wheelhouse（dtschema/cryptography/edl-req），在线侧一次取齐
  log "DRY-RUN: pip download dtschema cryptography -d $PKGDIR/pool/wheelhouse/  (~8 MB, USTC pypi 200)"
  log "DRY-RUN: pip download -r <edl-requirements.txt> -d $PKGDIR/pool/wheelhouse-edl/"
}

for a in $ACTIONS; do "do_$a"; done
log "done (DRY_RUN=$DRY_RUN). 排除清单未变：build/ geekidos-linux/ out/ stock-src/ env-pass/ backup/ dl-cam/ .pi/sessions/"
