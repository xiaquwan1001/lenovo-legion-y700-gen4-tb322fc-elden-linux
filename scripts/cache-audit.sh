#!/bin/bash
# cache-audit.sh — 缓存/工作区台账核对（versions/cache-ledger.tsv ↔ 磁盘 ↔ 软链指向）
#
# 立此脚本的原因（2026-11-26 项目整理）：仓库 123 G 里约 44 G 是可再生/可共享缓存，已搬到
# `~/elden-cache/`，仓库只留软链。没有核对门时会出现两种静默漂移：
#   ① 台账说「物理在 ~/elden-cache/…」而软链指到别处（或变成断链）⇒ 下个会话按台账找东西找不到；
#   ② 台账登记了某条目而磁盘已不存在（或反之，新缓存没登记）⇒ 又回到「不知道能不能删」。
#
# 判据（--check，任一 FAIL 即 rc=1）：
#   * 每个 `path` 在仓库里存在（`-e`，含软链）；
#   * physical 以 `~/` 开头时，软链必须解析到该路径（`readlink -f` 比对）；
#   * physical = `仓库内` 的条目必须**不是**软链；
#   * 台账里出现、但仓库顶层没有的 path ⇒ FAIL；仓库顶层的 `cache` zone 条目未登记 ⇒ FAIL。
#
# 用法：
#   scripts/cache-audit.sh --check     # 门（doctor 外的独立脚本；rc=1 表示漂移）
#   scripts/cache-audit.sh --sizes     # 现查各条目体积（du，慢；不参与门）
#   scripts/cache-audit.sh --list      # 人读表
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
TSV=versions/cache-ledger.tsv
LAYOUT=versions/layout.tsv
MODE=${1:---check}

[ -f "$TSV" ] || { echo "FAIL: $TSV 缺失"; exit 1; }

rows() { awk -F'\t' '!/^#/ && NF>=7 && $1!="path"' "$TSV"; }

case "$MODE" in
--list)
	printf '%-20s %-34s %-12s %-6s %s\n' PATH PHYSICAL CLASS SIZE REGEN
	rows | while IFS=$'\t' read -r p ph cl sz rg sh nt; do
		printf '%-20s %-34s %-12s %-6s %s\n' "$p" "$ph" "$cl" "$sz" "$(printf '%s' "$rg" | cut -c1-60)"
	done
	exit 0 ;;
--sizes)
	rows | while IFS=$'\t' read -r p ph cl sz rg sh nt; do
		[ -e "$p" ] && printf '%-20s %-6s %s\n' "$p" "$sz" "$(du -sh "$p" 2>/dev/null | cut -f1)"
	done
	exit 0 ;;
--check) ;;
*) echo "用法: $0 [--check|--sizes|--list]"; exit 2 ;;
esac

fail=0
checked=0
while IFS=$'\t' read -r p ph cl sz rg sh nt; do
	checked=$((checked + 1))
	pc=${p%/}          # 去掉尾斜杠：`[ -L "build/" ]` 恒假（bash 会跟随后再看），软链判定必须用裸名
	if [ ! -e "$pc" ]; then
		echo "FAIL: 台账登记但磁盘不存在：$p"; fail=1; continue
	fi
	case "$ph" in
	'~/elden-cache/'*)
		want="$HOME/${ph#\~/}"; want=${want%/}
		got=$(readlink -f "$pc" 2>/dev/null)
		if [ "$got" != "$want" ]; then
			echo "FAIL: $p 软链指向 $( [ -L "$pc" ] && readlink "$pc" || echo "（不是软链）" ) ≠ 台账 $want"
			fail=1
		fi ;;
	仓库内|*)
		[ -L "$pc" ] && { echo "FAIL: $p 台账说在仓库内，实际是软链 → $(readlink "$pc")"; fail=1; } ;;
	esac
done < <(rows)

# 反向：layout.tsv 里 zone=cache 的条目必须都在本台账
while IFS= read -r q; do
	[ -z "$q" ] && continue
	awk -F'\t' -v q="$q" '$1==q{found=1} END{exit !found}' "$TSV" ||
		{ echo "FAIL: layout.tsv zone=cache 的 $q 未登记进 cache-ledger.tsv"; fail=1; }
done < <(awk -F'\t' '!/^#/ && $1=="cache"{print $2}' "$LAYOUT")

if [ $fail -eq 0 ]; then
	echo "PASS: 缓存台账一致（$checked 条已核对；cache zone = $(awk -F'\t' '$1=="cache"' "$LAYOUT" | wc -l) 项）"
fi
exit $fail
