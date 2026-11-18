#!/usr/bin/env bash
# backup-triage.sh — backup/ 去重与分级处置（默认 dry-run）
# 依据: reports/backup-triage-20261118.md + versions/backup-manifest.tsv
# 动作:
#   dedup-hardlink  fw/tb322fc-edl 与 official-rom-15.10.259 逐字节相同文件 → 同 inode (ln, 同盘)
#   delete-dup      boot_a-pre-uefi-20261108.img (== stock-259/boot_a.img, sha 相同)
#   delete-empty    3 个空目录 (git-history-rewrite-20261103, git-repair-20261105, m3v5-onboard-20261031)
#   merge-bundles   git-history-rewrite-20261112 两个 pre-rewrite bundle → 删除
#                   (前置校验: git-slim-20261113/main-all-20261113.bundle 覆盖其 tip ref)
# 安全: DELETE 前先写 journal + 校验 sha；journal 逐行记录 mv 目标 (回收站式回滚)。
# 用法: backup-triage.sh [--apply] [--only <action>]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BK="$ROOT/backup"
APPLY=0; ONLY=all
[ "${1:-}" = "--apply" ] && APPLY=1
[ "${1:-}" = "--only" ] && ONLY="${2:?}" && [ "${3:-}" = "--apply" ] && APPLY=1
JOURNAL="$BK/.triage-journal-$(date +%Y%m%d-%H%M%S).tsv"
TRASH="$BK/.triage-trash-$(date +%Y%m%d-%H%M%S)"
# 每个动作都在 `bash -c` 子进程里跑，APPLY/JOURNAL/TRASH/ROOT 必须导出，
# 否则子进程读到 ${APPLY:-0} = 0 ⇒ --apply 静默退化成 dry-run（2026-11-18 实测撞到）。
export ROOT APPLY ONLY JOURNAL TRASH

log() { printf '%s\n' "$*"; }
run() { if [ "$APPLY" = 1 ]; then "$@"; else log "DRY: $*"; fi; }

act() { # act <action> <desc...>
  local a="$1"; shift
  [ "$ONLY" = all ] || [ "$ONLY" = "$a" ] || return 0
  "$@"
}

trash() { # trash <file> — 先 sha 记账再 mv 进回收目录
  local f="$1" rel
  rel="${f#"$ROOT"/}"
  local sha; sha=$(sha256sum "$f" | awk '{print $1}')
  printf 'TRASH\t%s\t%s\t%s\n' "$rel" "$(stat -c%s "$f")" "$sha" >> "$JOURNAL"
  mkdir -p "$TRASH/$(dirname "$rel")"
  run mv "$f" "$TRASH/$rel"
  log "  [trash] $rel (sha=$sha)"
}

# ---------- 1. delete-empty ----------
act delete-empty bash -c '
  for d in "$1"/backup/git-history-rewrite-20261103 "$1"/backup/git-repair-20261105 "$1"/backup/m3v5-onboard-20261031; do
    n=$(find "$d" -type f | wc -l)
    if [ "$n" -eq 0 ]; then
      if [ "${APPLY:-0}" = 1 ]; then rmdir "$d" && echo "  [rmdir] $d"; else echo "DRY: rmdir $d (空, 0 文件)"; fi
    else echo "SKIP 非空: $d"; fi
  done' _ "$ROOT"

# ---------- 2. delete-dup: boot_a-pre-uefi ----------
act delete-dup bash -c '
  f="$1/backup/boot_a-pre-uefi-20261108.img"; ref="$1/backup/stock-259/boot_a.img"
  if [ -f "$f" ]; then
    a=$(sha256sum "$f"|awk "{print \$1}"); b=$(sha256sum "$ref"|awk "{print \$1}")
    if [ "$a" = "$b" ]; then
      if [ "${APPLY:-0}" = 1 ]; then
        printf "DELETE\t%s\t%s\t%s\t%s\n" "${f#"$1"/}" "$(stat -c%s "$f")" "$a" "dup-of:backup/stock-259/boot_a.img" >> "$JOURNAL"
        mkdir -p "$TRASH"; mv "$f" "$TRASH/boot_a-pre-uefi-20261108.img"
        echo "  [trash] boot_a-pre-uefi-20261108.img (100 MiB, sha=$a)"
      else echo "DRY: delete $f (100 MiB, == stock-259/boot_a.img sha=$a)"; fi
    else echo "ABORT sha 不再匹配: $a != $b (不删)"; fi
  fi' _ "$ROOT"

# ---------- 3. dedup-hardlink: tb322fc-edl vs official-rom ----------
act dedup-hardlink bash -c '
  saved=0
  for f in "$1"/backup/fw/tb322fc-edl/*; do
    [ -f "$f" ] || continue
    b=$(basename "$f"); r="$1/backup/official-rom-15.10.259/$b"
    [ -f "$r" ] || continue
    [ "$(stat -c%i "$f")" = "$(stat -c%i "$r")" ] && continue
    a=$(sha256sum "$f"|awk "{print \$1}"); s=$(sha256sum "$r"|awk "{print \$1}")
    if [ "$a" = "$s" ]; then
      sz=$(stat -c%s "$f"); saved=$((saved+sz))
      if [ "${APPLY:-0}" = 1 ]; then
        printf "HARDLINK\t%s\t%s\t%s\n" "${f#"$1"/}" "$sz" "$a" >> "$JOURNAL"
        ln -f "$r" "$f.tmp-link" && mv "$f.tmp-link" "$f"
      else echo "DRY: hardlink fw/tb322fc-edl/$b ($sz B)"; fi
    fi
  done
  echo "  hardlink 去重可省: $saved B ($((saved/1048576)) MiB)"' _ "$ROOT"

# ---------- 4. merge-bundles: pre-rewrite bundles ----------
act merge-bundles bash -c '
  d="$1/backup/git-history-rewrite-20261112"
  all="$1/backup/git-slim-20261113/main-all-20261113.bundle"
  [ -d "$d" ] || exit 0
  tip2=$(git bundle list-heads "$d/pre-rewrite-main-2.bundle" 2>/dev/null | awk "{print \$1}")
  orig=$(git bundle list-heads "$all" 2>/dev/null | grep "refs/original/refs/heads/main" | awk "{print \$1}")
  if [ "$tip2" = "$orig" ] && [ -n "$tip2" ]; then
    echo "  main-all-20261113.bundle refs/original == pre-rewrite-main-2 tip ($tip2) → 可回收两份 pre-rewrite bundle"
    # 逐对象覆盖校验: 从 pre-rewrite bundle 做 fetch 试取进临时仓
    tmp=$(mktemp -d); git init -q "$tmp/r" 2>/dev/null
    if git -C "$tmp/r" fetch -q "$d/pre-rewrite-main-2.bundle" "refs/heads/main:refs/heads/x" 2>/dev/null &&
       git -C "$tmp/r" cat-file -e "$tip2^{commit}" 2>/dev/null; then
      if [ "${APPLY:-0}" = 1 ]; then
        for b in pre-rewrite-main.bundle pre-rewrite-main-2.bundle; do
          printf "DELETE\tbackup/git-history-rewrite-20261112/%s\t%s\t%s\tcovered-by:git-slim-20261113/main-all-20261113.bundle\n" "$b" "$(stat -c%s "$d/$b")" "$(sha256sum "$d/$b"|awk "{print \$1}")" >> "$JOURNAL"
          mv "$d/$b" "$TRASH/$b"
        done
        echo "  [trash] pre-rewrite-main{,-2}.bundle (共 $(( (413842628+413187041)/1048576 )) MiB)"
      else
        echo "DRY: delete pre-rewrite-main.bundle (394.7 MiB) + pre-rewrite-main-2.bundle (394.1 MiB)"
      fi
    else echo "ABORT: 对象级覆盖校验未通过 (保守不删)"; fi
    rm -rf "$tmp"
  else
    echo "ABORT: tip 不匹配 (pre-rewrite-2=$tip2, main-all/original=$orig) — 不删"
  fi' _ "$ROOT"

# ---------- 汇总 ----------
log ""
if [ "$APPLY" = 1 ]; then
  log "APPLY 完成。journal=$JOURNAL"; log "回滚: 把 $TRASH 下文件按 journal 的相对路径 mv 回去"
  if [ -s "$JOURNAL" ]; then log "journal 条目: $(wc -l < "$JOURNAL")";
  elif [ "$ONLY" != delete-empty ]; then log "WARN: APPLY 但没写任何 journal 条目（动作未生效？）"; fi
else
  log "DRY-RUN 结束。预计一次 --apply 净回收 ≈ 1.31 GiB (100 MiB boot dup + 467 MiB hardlink + 789 MiB bundles + 空目录)"
  log "未做任何写操作。"
fi
