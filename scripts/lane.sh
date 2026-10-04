#!/bin/bash
# lane.sh — baseline+fork workflow for concurrent agents (see .pi/CONCURRENCY.md).
#
# The single-writer rule on main was the old plan; this implements the user's
# chosen model instead: sub-agents fork a baseline into an isolated worktree,
# advance & COMMIT on their own branch, and the parent merges + resolves
# conflicts. Every lane/branch/version is recorded, so provenance is explicit.
#
# usage:
#   scripts/lane.sh install                 # point this repo at .githooks (once)
#   scripts/lane.sh alloc [lane] [note]     # atomically reserve next vkN (flock)
#   scripts/lane.sh new <lane> <baseline> [--kernel]
#   scripts/lane.sh list
#   scripts/lane.sh done <lane>
#   scripts/lane.sh merge <lane>            # parent-only: merge lane into main
#   scripts/lane.sh remove <lane>
#
# Env: LANES_DIR (default .pi/lanes), WT_ROOT (default sibling of main checkout),
#      KERNEL_REPO (default <main>/geekidos-linux), KERNEL_BASE (default v7.2-elden)
set -euo pipefail

repo_root() { git worktree list --porcelain | sed -n 's/^worktree //p' | head -1; }
ROOT=$(repo_root)
[ -n "$ROOT" ] || { echo "lane.sh: not in a git repo" >&2; exit 1; }
LANES=${LANES_DIR:-$ROOT/.pi/lanes}
WT_ROOT=${WT_ROOT:-$(dirname "$ROOT")}
KERNEL_REPO=${KERNEL_REPO:-$ROOT/geekidos-linux}
KERNEL_BASE=${KERNEL_BASE:-v7.2-elden}
REGISTRY=$ROOT/versions/vk-registry.tsv

die() { echo "lane.sh: $*" >&2; exit 1; }
meta() { echo "$LANES/$1.tsv"; }

cmd_install() {
	mkdir -p "$ROOT/versions" "$LANES"
	[ -f "$REGISTRY" ] || printf '# vk-registry.tsv — global monotonic version ledger (SSOT for vkN)\n# vk\tlane\tdate\tnote\n' > "$REGISTRY"
	# absolute path: relative hooksPath breaks inside linked worktrees (resolves to worktree root)
	git -C "$ROOT" config core.hooksPath "$ROOT/.githooks"
	echo "[lane] main repo core.hooksPath=$ROOT/.githooks"
	if [ -d "$KERNEL_REPO/.git" ]; then
		cp "$ROOT/.githooks/commit-msg" "$KERNEL_REPO/.git/hooks/commit-msg"
		chmod +x "$KERNEL_REPO/.git/hooks/commit-msg"
		echo "[lane] kernel commit-msg hook installed"
	fi
	echo "[lane] registry: $REGISTRY"
}

cmd_alloc() {
	local lane=${1:-adhoc} note=${2:-}
	mkdir -p "$(dirname "$REGISTRY")" "$LANES"
	[ -f "$REGISTRY" ] || printf '# vk-registry.tsv — global monotonic version ledger (SSOT for vkN)\n# vk\tlane\tdate\tnote\n' > "$REGISTRY"
	exec 9>>"$REGISTRY.lock"
	flock 9
	local last
	last=$(awk -F'\t' '/^vk[0-9]+/ {gsub(/^vk/,"",$1); if ($1+0>m) m=$1+0} END{print m+0}' "$REGISTRY")
	local n=$((last+1))
	printf 'vk%s\t%s\t%s\t%s\n' "$n" "$lane" "$(date +%F)" "$note" >> "$REGISTRY"
	echo "vk$n"
}

cmd_new() {
	local lane=${1:?usage: lane.sh new <lane> <baseline> [--kernel]}
	local base=${2:?usage: lane.sh new <lane> <baseline> [--kernel]}
	local with_kernel=0
	[ "${3:-}" = "--kernel" ] && with_kernel=1
	[ -n "$lane" ] || die "empty lane"
	[ -f "$(meta "$lane")" ] && die "lane '$lane' already exists ($(meta "$lane"))"
	git -C "$ROOT" rev-parse --verify "$base^{commit}" >/dev/null 2>&1 || die "baseline '$base' not found"

	local wt=$WT_ROOT/wt-$lane
	local br=lane/$lane
	git -C "$ROOT" worktree add -b "$br" "$wt" "$base"
	echo "[lane] main worktree  : $wt  ($br @ $base)"

	local kbr="" kwt=""
	if [ "$with_kernel" = 1 ]; then
		[ -d "$KERNEL_REPO/.git" ] || die "kernel repo not found: $KERNEL_REPO"
		git -C "$KERNEL_REPO" rev-parse --verify "$KERNEL_BASE^{commit}" >/dev/null 2>&1 || die "kernel base '$KERNEL_BASE' not found"
		kbr=elden/lane-$lane
		kwt=$WT_ROOT/wt-$lane-kernel
		git -C "$KERNEL_REPO" worktree add -b "$kbr" "$kwt" "$KERNEL_BASE"
		echo "[lane] kernel worktree: $kwt  ($kbr @ $KERNEL_BASE)"
	fi

	mkdir -p "$LANES"
	{
		echo "lane=$lane"
		echo "branch=$br"
		echo "worktree=$wt"
		echo "baseline=$base"
		echo "kernel_branch=$kbr"
		echo "kernel_worktree=$kwt"
		echo "status=open"
		echo "created=$(date +%F)"
	} > "$(meta "$lane")"
	echo "[lane] meta: $(meta "$lane")"
}

cmd_list() {
	[ -d "$LANES" ] || { echo "(no lanes)"; return; }
	for f in "$LANES"/*.tsv; do
		[ -e "$f" ] || continue
		awk -F= '/^(lane|branch|worktree|baseline|kernel_branch|status)=/ {printf "%s=%s ", $1, $2} END{print ""}' "$f"
	done
}

_cmd_field() { sed -n "s/^$2=//p" "$(meta "$1")"; }
_set_status() { sed -i "s/^status=.*/status=$2/" "$(meta "$1")"; }

cmd_done() {
	local lane=${1:?usage: lane.sh done <lane>}
	[ -f "$(meta "$lane")" ] || die "no such lane '$lane'"
	_set_status "$lane" done
	echo "[lane] '$lane' -> done; parent merges with: scripts/lane.sh merge $lane"
}

cmd_merge() {
	local lane=${1:?usage: lane.sh merge <lane>}
	[ -f "$(meta "$lane")" ] || die "no such lane '$lane'"
	local br; br=$(_cmd_field "$lane" branch)
	local cur; cur=$(git -C "$ROOT" symbolic-ref --short HEAD)
	[ "$cur" = "main" ] || die "parent must be on main to merge (currently '$cur')"
	git -C "$ROOT" merge --no-ff -m "merge($lane): $br -> main

Lane: $lane
Agent: parent
Baseline: $(_cmd_field "$lane" baseline)" "$br"
	_set_status "$lane" merged
	local kbr; kbr=$(_cmd_field "$lane" kernel_branch)
	if [ -n "$kbr" ]; then
		echo "[lane] NOTE kernel lane '$kbr' is separate — merge it inside $KERNEL_REPO"
	fi
	echo "[lane] merged. now run: scripts/check-doctor.sh && git tag merge/$lane"
}

cmd_remove() {
	local lane=${1:?usage: lane.sh remove <lane>}
	[ -f "$(meta "$lane")" ] || die "no such lane '$lane'"
	local br wt kbr kwt
	br=$(_cmd_field "$lane" branch); wt=$(_cmd_field "$lane" worktree)
	kbr=$(_cmd_field "$lane" kernel_branch); kwt=$(_cmd_field "$lane" kernel_worktree)
	[ -n "$wt" ] && git -C "$ROOT" worktree remove --force "$wt" 2>/dev/null || true
	git -C "$ROOT" branch -D "$br" 2>/dev/null || true
	if [ -n "$kwt" ]; then
		git -C "$KERNEL_REPO" worktree remove --force "$kwt" 2>/dev/null || true
		git -C "$KERNEL_REPO" branch -D "$kbr" 2>/dev/null || true
	fi
	rm -f "$(meta "$lane")"
	echo "[lane] removed '$lane'"
}

case "${1:-}" in
	install) shift; cmd_install "$@" ;;
	alloc)   shift; cmd_alloc "$@" ;;
	new)     shift; cmd_new "$@" ;;
	list)    shift; cmd_list "$@" ;;
	done)    shift; cmd_done "$@" ;;
	merge)   shift; cmd_merge "$@" ;;
	remove)  shift; cmd_remove "$@" ;;
	-h|--help|"") sed -n '2,25p' "$0" ;;
	*) die "unknown subcommand '$1'" ;;
esac
