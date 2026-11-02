#!/bin/sh
# 每周邮箱整理（2026-11-02 用户批准）：只删「非我方线程 + 非直接发我 + 早于 7 天」的列表流水。
# 备份策略：备份目录不存在或超过 30 天 ⇒ 先全量 mbox 备份（~/Mail/ustc-backup-<date>/，仓库外）。
# 放到 ~/.config/systemd/user/elden-mailbox-cleanup.{service,timer}；日志 logs/mailbox-weekly-*.log。
set -eu
ROOT=${ELDEN_ROOT:-/home/xuqianhui/y700-elden}
PY=${PYTHON:-python3}
cd "$ROOT"
LOG="logs/mailbox-weekly-$(date +%Y%m%d).log"
mkdir -p logs "$HOME/Mail"

LATEST=$(ls -d "$HOME"/Mail/ustc-backup-* 2>/dev/null | sort | tail -1 || true)
need_backup=1
if [ -n "$LATEST" ]; then
  if [ -n "$(find "$LATEST" -maxdepth 0 -mtime -30 2>/dev/null)" ]; then
    need_backup=0
  fi
fi

{
  echo "== $(date -Is) weekly mailbox cleanup =="
  if [ "$need_backup" = 1 ]; then
    echo "backup: none fresh (latest=${LATEST:-none}) -> full mbox backup"
    "$PY" scripts/mailbox-cleanup-20261102.py --backup
  else
    echo "backup: fresh enough -> $LATEST"
  fi
  "$PY" scripts/mailbox-cleanup-20261102.py --delete --aggressive --recent-days 7
  echo "== done $(date -Is) =="
} >>"$LOG" 2>&1
tail -n 20 "$LOG"
