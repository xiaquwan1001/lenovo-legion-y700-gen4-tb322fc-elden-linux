#!/bin/bash
# check-layout.sh — 顶层布局注册表门（versions/layout.tsv ↔ 磁盘 ↔ INDEX.md）
#
# 立此脚本的原因（2026-11-03 项目整理）：
#   根目录条目会随专题自发增长（213 G 工作区已有 46 项），没有注册表就没有「哪些是工作区、
#   哪些是源码、哪些是不可再生备份、哪些是可再生/可共享缓存」的稳定口径，新会话无法判断能否删除、能否入库。
#   同时防止两类漂移：① 新目录未登记就落盘；② 台账登记了但磁盘已不存在（死路径）。
#
# 判据（任一 FAIL 即退出码 1）：
#   磁盘顶层条目未登记（`.git` 除外） / 登记的条目磁盘不存在 /
#   INDEX.md 未渲染该条目的布局表行（人读面与机读面同源）/ zone 非法 / path 重复 / 列缺失
#
# 用法：scripts/check-layout.sh [--list]
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

TSV=versions/layout.tsv
INDEX=INDEX.md
ZONES="entry doc evidence src work cache ai"

[ -f "$TSV" ] || { echo "FAIL: $TSV 缺失"; exit 1; }
[ -f "$INDEX" ] || { echo "FAIL: $INDEX 缺失"; exit 1; }

if [ "${1:-}" = "--list" ]; then
	awk -F'\t' '!/^#/ && NF>=4 && $1!="zone" {printf "%-9s %-24s %-7s %s\n", $1, $2, $3, $4}' "$TSV"
	exit 0
fi

fail=0
work=$(mktemp) || exit 1
trap 'rm -f "$work"' EXIT

# 1) 台账自检：列完整、zone 合法、path 唯一，并输出去重后的 path 列表
awk -F'\t' -v zones="$ZONES" -v out="$work" '
	/^#/ || NF < 4 { next }
	$1 == "zone"   { next }
	{
		if ($2 == "" || $3 == "" || $4 == "") { printf "FAIL: layout.tsv 列缺失：%s\n", $0; bad = 1; next }
		if (index(" " zones " ", " " $1 " ") == 0) { printf "FAIL: layout.tsv 未知 zone %s（path=%s）\n", $1, $2; bad = 1 }
		if (seen[$2]++) { printf "FAIL: layout.tsv path 重复：%s\n", $2; bad = 1 }
		np = $2; sub(/\/+$/, "", np)
		print np > out
	}
	END { exit bad }
' "$TSV" || fail=1

# 2) 逐条：存在性 + INDEX 渲染
while IFS= read -r p; do
	[ -e "$p" ] || [ -e "$p/" ] || { echo "FAIL: layout.tsv 登记但磁盘不存在：$p"; fail=1; }
	grep -qF "\`$p/\`" "$INDEX" || grep -qF "\`$p\`" "$INDEX" ||
		{ echo "FAIL: INDEX.md 布局表缺少条目：$p"; fail=1; }
done <"$work"

# 3) 反向：磁盘上每个顶层条目必须已登记
while IFS= read -r p; do
	[ "$p" = ".git" ] && continue
	grep -qxF "$p" "$work" || { echo "FAIL: 顶层条目未登记（versions/layout.tsv）：$p"; fail=1; }
done < <(ls -A1)

# 4) vcs 列有机器语义（2026-11-26 架构审计 A2）：`ignore` 是「默认不入库」，
#   不是「一个都不许入库」（README/小文本证据/manifest 有意入库）—— 所以判据取两条硬红线：
#   ① `vcs=ignore` 的条目下不得有 **≥5 MiB** 的 tracked 文件（那是「大件误入库」）；
#   ② 不得有真·器件/内核件后缀（.img/.bin/.mbn/.elf/.ko）被 tracked。
#   此前 vcs 列是纯装饰（唯一校验是 zone/列/重复），台账说 `cache ignore` 的 `dl-cam/`
#   实际有 231 件入库、无人发现。
#   注意：本段必须用进程替換（< <(...)）而不是管道 —— 管道里的 FAIL 只在子 shell 生效，门就哑了。
while IFS= read -r p; do
	[ -n "$p" ] || continue
	[ -e "$p" ] || continue
	big=$(git ls-files -z -- "$p" 2>/dev/null | xargs -0 -r stat -c '%s %n' 2>/dev/null | awk -v L=5242880 '$1 >= L {printf "%s (%s B), ", $2, $1}')
	[ -n "$big" ] && { echo "FAIL: vcs=ignore 的 $p 下有 tracked 大件（≥5 MiB，应改 vcs=track 或加 .gitignore）：${big%, }"; fail=1; }
	bin=$(git ls-files -- "$p" 2>/dev/null | grep -E '\.(img|bin|mbn|elf|ko)$' | tr '\n' ' ')
	[ -n "$bin" ] && { echo "FAIL: vcs=ignore 的 $p 下有器件/内核件被 tracked：$bin"; fail=1; }
done < <(awk -F'\t' '!/^#/ && NF>=4 && $1!="zone" && $3=="ignore" {print $2}' "$TSV")

if [ $fail -eq 0 ]; then
	echo "PASS: 布局注册表一致（entries=$(wc -l <"$work")）"
else
	exit 1
fi
