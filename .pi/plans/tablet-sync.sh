#!/bin/bash
# tablet-sync.sh — 三方（平板/本机/USTC GitLab）同步合流脚本（L2-B, 20261030）
#
# 规则（与 reports/artifacts/tablet-offload-20261030/l2b-sync-nightrun.md §1 一致）：
#   - 唯一远端：ustc-ssh = ssh://git@git.ustc.edu.cn/xqh/y700-elden.git（https 401 / glab token 失效，SSH:22 可用）
#   - 本机先 fetch 再 rebase/merge；冲突不选边，--abort 后报总管
#   - 平板只推 tablet/<task>，禁直推 main，禁 force push（本脚本从不 push，push 需人工）
#   - 平板只做文档/邮件草稿/日志分析，不碰内核与领域层 SSOT
#
# 用法：
#   tablet-sync.sh --preflight          # 只读：工作区干净 + 未推送阈值检查
#   tablet-sync.sh --fetch-tablet       # 只读：rsync 拉 reports/TASKS/sessions/会话增量
#   tablet-sync.sh --add-remote         # 只写 .git/config：添加 ustc-ssh remote（幂等）
#   tablet-sync.sh --merge-tablet <分支>  # 合并单个 tablet/* 分支（--no-ff，冲突即停）
#
# 未推送 141 提交的处置是**待办**（见报告 §1.5），本脚本只计数报警，不执行 push。
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 1
REMOTE="ustc-ssh"
REMOTE_URL="ssh://git@git.ustc.edu.cn/xqh/y700-elden.git"
ART="reports/artifacts/tablet-offload-20261030"
LOG="$ART/$(basename "$0").log"
mkdir -p "$ART"
exec > >(tee -a "$LOG") 2>&1

die() { echo "[FAIL] $*"; exit "${2:-1}"; }
log() { echo "[sync] $*"; }

cmd="${1:-}"

case "$cmd" in
  --add-remote)
    if git remote get-url "$REMOTE" >/dev/null 2>&1; then
      cur=$(git remote get-url "$REMOTE")
      [ "$cur" = "$REMOTE_URL" ] && { log "remote $REMOTE 已存在且一致"; exit 0; }
      die "remote $REMOTE 已存在但 URL 不同: $cur" 4
    fi
    git remote add "$REMOTE" "$REMOTE_URL" || die "remote add 失败" 5
    log "已添加 remote $REMOTE（未 fetch 未 push）"
    ;;
  --preflight)
    # 1) 工作区干净
    if [ -n "$(git status --porcelain)" ]; then
      git status --porcelain | head -20
      die "工作区不干净，先处理未提交改动" 2
    fi
    log "工作区干净 OK"
    # 2) 未推送阈值（对 ustc-ssh/main；远端不存在时仅提示 141 提交事实）
    if git rev-parse --verify "$REMOTE/main" >/dev/null 2>&1; then
      n=$(git rev-list --count "$REMOTE/main..main")
    else
      n=$(git rev-list --count origin/main..main 2>/dev/null || echo "?")
      log "警告：$REMOTE/main 不可用，暂用 origin/main 计数"
    fi
    log "未推送提交数 = $n"
    if [ "$n" != "?" ]; then
      [ "$n" -gt 200 ] && die "未推送 >200，拒绝继续；处置见报告 §1.5" 3
      [ "$n" -gt 50 ] && log "警告：未推送 >50，建议先执行报告 §1.5 待办"
    fi
    log "preflight PASS"
    ;;
  --fetch-tablet)
    # 会话/用户数据 rsync 单向：主机 <- 平板，--checksum，禁 --delete
    HOST="${TABLET_HOST:-root@192.168.7.1}"
    RPATH="${TABLET_RPATH:-/home/xuqianhui1001/y700-elden}"
    log "rsync 会话目录 (tablet -> host)"
    rsync -av --checksum "$HOST:$RPATH/.pi/sessions/tablet/" "$ROOT/.pi/sessions/tablet/" \
      || die "rsync sessions 失败" 6
    log "rsync 平板 reports 增量"
    rsync -av --checksum --ignore-existing "$HOST:$RPATH/reports/artifacts/" "$ROOT/reports/artifacts/tablet-incoming/" \
      || die "rsync reports 失败" 7
    log "rsync 平板 TASKS/sessions 增量"
    rsync -av --checksum --ignore-existing "$HOST:$RPATH/TASKS/sessions/" "$ROOT/TASKS/sessions/" \
      || die "rsync TASKS/sessions 失败" 8
    log "fetch-tablet 完成（合流清单见报告 §2.3）"
    ;;
  --merge-tablet)
    BR="${2:?usage: --merge-tablet tablet/<task>}"
    case "$BR" in tablet/*) ;; *) die "只许合并 tablet/* 分支: $BR" 9 ;; esac
    git merge --no-ff "$BR" || { git merge --abort 2>/dev/null; die "冲突，已 abort，报总管收口" 10; }
    log "已合并 $BR（push 由人工执行）"
    ;;
  *)
    sed -n '2,14p' "$0"
    exit 1
    ;;
esac
