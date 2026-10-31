#!/usr/bin/env bash
# check-series-selfcontained.sh — 补丁系列自足性门禁（派工单 M3-v5 2026-10-31）
#
# 用法:
#   scripts/check-series-selfcontained.sh <patch-dir> [<base-ref>] [--repo <kernel-repo>]
#   scripts/check-series-selfcontained.sh --self-test
#
# 作用: 在干净临时 worktree（git worktree add --detach 到 /tmp 唯一目录）里，
#   对 <patch-dir> 内每个 *.patch 按文件名序依次 git apply --check / git am --3way，
#   检查: ① 系列自足性（任一枚 apply/am 失败即 FAIL）② 顺序依赖可整串重放
#   ③ 是否缺 cover letter（缺则 WARN）。输出 PASS/FAIL/WARN + 计数，退出码 0/1。
#   cover letter 判定: 文件名匹配 *0000* 或 *cover*。
#
# <base-ref>: git commit（在 --repo 解析出的仓库内）；缺省 = 该仓库 HEAD。
# --repo: 内核仓库路径；缺省依次尝试 $CSSC_REPO → 当前 git toplevel →
#   ./build/*/ 中包含 <base-ref> 的第一个仓库。
#
# --self-test: 在 /tmp 造临时仓库自检（正例 2 枚 PASS + 负例缺依赖 FAIL），不碰本仓库。
# 约束: 不联网；除 scripts/ 外不写仓库任何路径；收尾 worktree remove --force + prune。

set -u

SELF="$(readlink -f "$0")"
PASS=0; FAIL=0; WARN=0

say() { printf '%s\n' "$*"; }
die() { say "FATAL: $*" >&2; exit 2; }

cleanup_worktree() { # $1=repo $2=wt
	[ -n "${1:-}" ] && [ -n "${2:-}" ] || return 0
	git -C "$1" worktree remove --force "$2" >/dev/null 2>&1
	git -C "$1" worktree prune >/dev/null 2>&1
}

# run_gate <patch-dir> <repo> <base-ref> <label>
run_gate() {
	local dir="$1" repo="$2" base="$3" label="$4"
	local patches=() p rc
	local wt; wt=$(mktemp -d /tmp/cssc-XXXXXX)

	if ! git -C "$repo" rev-parse --verify --quiet "${base}^{commit}" >/dev/null; then
		say "FAIL  $label: base-ref '$base' 不在仓库 $repo"
		FAIL=$((FAIL+1)); rmdir "$wt" 2>/dev/null; return 1
	fi
	if ! git -C "$repo" worktree add --detach "$wt" "$base" >/dev/null 2>&1; then
		say "FAIL  $label: 无法创建临时 worktree $wt"
		FAIL=$((FAIL+1)); return 1
	fi

	# shellcheck disable=SC2044  # 文件名无空格是内核补丁目录约定；有则逐个报错
	for p in $(find "$dir" -maxdepth 1 -name '*.patch' | sort); do
		patches+=("$(readlink -f "$p")")
	done
	if [ "${#patches[@]}" -eq 0 ]; then
		say "FAIL  $label: 目录内没有 *.patch"
		FAIL=$((FAIL+1)); cleanup_worktree "$repo" "$wt"; return 1
	fi

	local series_ok=1 failed=""
	for p in "${patches[@]}"; do
		case "$(basename "$p")" in *0000*|*cover*) continue ;; esac
		local name; name=$(basename "$p")
		if ! git -C "$wt" apply --check "$p" >/dev/null 2>&1; then
			say "  FAIL  $name: git apply --check 失败（对当前序列状态不自足）"
			series_ok=0; failed="$name"; break
		fi
		# 仅 format-patch（首行 `From <sha> Mon Sep 17 …`）才能 git am；裸 diff 只做 apply 校验
		if ! head -1 "$p" | grep -Eq '^From [0-9a-f]{12,} '; then
			git -C "$wt" apply "$p" >/dev/null 2>&1 || { say "  FAIL  $name: git apply 失败"; series_ok=0; failed="$name"; break; }
			say "  WARN  $name: 裸 diff（无 format-patch 头）⇒ 只过 apply，不能 git am / 不能直接投递"
			WARN=$((WARN+1)); PASS=$((PASS+1)); continue
		fi
		if ! git -C "$wt" am --3way --quiet "$p" >/dev/null 2>&1; then
			git -C "$wt" am --abort >/dev/null 2>&1
			say "  FAIL  $name: git am --3way 失败（内容冲突，非格式问题）"
			series_ok=0; failed="$name"; break
		fi
		say "  ok    $name"
		PASS=$((PASS+1))
	done

	local has_cover=0
	for p in "${patches[@]}"; do
		case "$(basename "$p")" in
			*0000*|*cover*) has_cover=1 ;;
		esac
	done
	if [ "$has_cover" -eq 0 ]; then
		say "  WARN  缺 cover letter（*0000*/*cover*）"
		WARN=$((WARN+1))
	fi

	cleanup_worktree "$repo" "$wt"

	if [ "$series_ok" -eq 1 ]; then
		say "PASS  $label: 全部 ${#patches[@]} 个文件按序重放成功于 $base"
		return 0
	fi
	say "FAIL  $label: 序列在 $failed 处中断（对 $base 不自足或缺序列内前置）"
	FAIL=$((FAIL+1))
	return 1
}

# resolve_repo <base-ref-or-empty>
resolve_repo() {
	local base="$1"
	if [ -n "${CSSC_REPO:-}" ] && [ -d "$CSSC_REPO/.git" ]; then echo "$CSSC_REPO"; return 0; fi
	local top; top=$(git rev-parse --show-toplevel 2>/dev/null) || true
	if [ -n "$top" ] && { [ -z "$base" ] || git -C "$top" rev-parse --verify --quiet "${base}^{commit}" >/dev/null; }; then
		echo "$top"; return 0
	fi
	local d
	for d in build/*/; do
		git -C "$d" rev-parse --git-dir >/dev/null 2>&1 || continue
		[ -z "$base" ] || git -C "$d" rev-parse --verify --quiet "${base}^{commit}" >/dev/null || continue
		echo "${d%/}"; return 0
	done
	return 1
}

self_test() {
	local t; t=$(mktemp -d /tmp/cssc-selftest-XXXXXX)
	local repo="$t/repo" dir="$t/patches"
	local rc=0
	git init -q "$repo"
	git -C "$repo" -c user.email=a@b -c user.name=t commit -q --allow-empty -m base
	mkdir -p "$dir"
	echo one > "$t/f1"
	git -C "$repo" add "$t/f1" 2>/dev/null || cp "$t/f1" "$repo/f1"
	git -C "$repo" add f1
	git -C "$repo" -c user.email=a@b -c user.name=t commit -q -m "add f1"
	echo two >> "$repo/f1"   # 0002 依赖 0001 引入的 f1（改其内容）
	echo two > "$repo/f2"
	git -C "$repo" add f1 f2
	git -C "$repo" -c user.email=a@b -c user.name=t commit -q -m "add f2, extend f1"
	git -C "$repo" format-patch --cover-letter -2 -o "$dir" HEAD >/dev/null
	local base; base=$(git -C "$repo" rev-parse HEAD~2)

	say "== self-test 正例（2 枚完整依赖链）=="
	local out1; out1=$(run_gate "$dir" "$repo" "$base" "selftest-positive")
	say "$out1"
	[[ "$out1" == *"WARN"* ]] && say "self-test 正例不应有 WARN（缺 cover 判定）"
	mkdir -p "$t/neg"; cp "$dir"/0002-* "$t/neg/"
	say "== self-test 负例（删 0001，仅剩依赖它的 0002）=="
	local out2; out2=$(run_gate "$t/neg" "$repo" "$base" "selftest-negative")
	say "$out2"

	# 判定: 正例必须 PASS 且 2 ok；负例必须 FAIL 且停在 0002
	[[ "$out1" == *"PASS  selftest-positive"* ]] || { say "SELF-TEST FAIL: 正例未 PASS"; rc=1; }
	[[ "$out2" == *"FAIL  selftest-negative: 序列在 0002-"* ]] || { say "SELF-TEST FAIL: 负例未 FAIL"; rc=1; }
	rm -rf "$t"
	if [ "$rc" -eq 0 ]; then say "SELF-TEST: PASS"; else say "SELF-TEST: FAIL"; fi
	return $rc
}

main() {
	if [ "${1:-}" = "--self-test" ]; then
		PASS=0; FAIL=0; WARN=0
		self_test
		return $?
	fi
	[ -n "${1:-}" ] || die "用法: $0 <patch-dir> [<base-ref>] [--repo <kernel-repo>] | --self-test"
	local dir="$1" base="" repo=""
	shift
	while [ $# -gt 0 ]; do
		case "$1" in
			--repo) repo="$2"; shift 2 ;;
			*) base="$1"; shift ;;
		esac
	done
	[ -d "$dir" ] || die "补丁目录不存在: $dir"
	[ -n "$repo" ] || repo=$(resolve_repo "$base") || die "解析不到仓库: 传 --repo 或设 CSSC_REPO"
	[ -n "$base" ] || base=$(git -C "$repo" rev-parse HEAD)
	say "== 门禁: $dir  base=$base  repo=$repo =="
	run_gate "$dir" "$repo" "$base" "$(basename "$dir")"
	local gate_rc=$?
	say "== 汇总: PASS=$PASS FAIL=$FAIL WARN=$WARN 退出码=$gate_rc =="
	[ "$FAIL" -eq 0 ]
}

main "$@"
