#!/bin/bash
# check-doc-assets.sh — 文档里用反引号写出的资产路径必须真实存在。
#
# 立此脚本的原因（2026-10-27）：
#   三条 lane（aw86927-series / b5-resoc / devcam-ab）的产物（patches/ reports/ scripts/）
#   提交在各自 worktree 分支上，主仓 main 只写了一句收口总结 ⇒ TASKS/README.md §7 与
#   reports/upstream-status-20261027.md 里引用的一批路径在主仓**不存在**。
#   文档指向不存在的路径时，下一个会话会照着路径找、找不到，然后重做一遍。
#
# 判据：扫指定文档里被反引号包住的 `patches/...` `reports/...` `scripts/...` 等 token，
#       逐个检查存在性；**前缀截断**（如 `patches/0011`、`patches/dt/0002`）按 glob 前缀解析，
#       命中即算存在；带通配/占位符（`*` `{` `<` `…`）的 token 跳过。
# 豁免：scripts/doc-assets-allowlist.txt，每行 `<path><TAB><理由>`。
#
# 用法：
#   scripts/check-doc-assets.sh            # 默认扫描入口文档 + 最新 upstream 状态页
#   scripts/check-doc-assets.sh FILE...    # 只扫给定文件
#   scripts/check-doc-assets.sh --list     # 打印将要扫描的文件
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

ALLOWLIST=scripts/doc-assets-allowlist.txt

default_files() {
	[ -f TASKS/README.md ] && printf '%s\n' TASKS/README.md
	[ -f INDEX.md ] && printf '%s\n' INDEX.md
	[ -f DEVICE/README.md ] && printf '%s\n' DEVICE/README.md
	[ -f PITFALLS/README.md ] && printf '%s\n' PITFALLS/README.md
	# 当前页 = 文件名最大的 upstream-status-YYYYMMDD.md
	ls reports/upstream-status-*.md 2>/dev/null | sort | tail -1
}

if [ "${1:-}" = "--list" ]; then
	default_files | sed 's/^/scan: /'
	exit 0
fi

if [ $# -gt 0 ]; then
	files=("$@")
else
	mapfile -t files < <(default_files)
fi

[ ${#files[@]} -gt 0 ] || { echo "FAIL: 没有可扫描的文档"; exit 1; }

# 提取 token：只认以已知资产根开头的路径
PAT='`((patches|patches-userland|reports|scripts|rootfs|packaging|bootslot-b|DEVICE|TASKS|RESOURCES|PITFALLS|RUNBOOK-BRINGUP|INDEX\.md)[A-Za-z0-9._+%/<>{}…-]*)`'

missing=0
skip=0
checked=0

is_allowed() {
	[ -f "$ALLOWLIST" ] || return 1
	# 只比对第一列（路径），忽略行尾理由
	awk -F'\t' '{print $1}' "$ALLOWLIST" 2>/dev/null | grep -qxF "$1"
}

for f in "${files[@]}"; do
	[ -f "$f" ] || { echo "WARN: 文档不存在，跳过: $f"; continue; }
	# shellcheck disable=SC2013
	while IFS= read -r tok; do
		case "$tok" in
			*'*'*|*'{'*|*'<'*|*'…'*|*'%'*) skip=$((skip + 1)); continue ;;
		esac
		checked=$((checked + 1))
		if [ -e "$tok" ]; then
			continue
		fi
		# 前缀截断（`patches/0011` 指 0011-*.patch）按 glob 解析；目录同样适用
		if compgen -G "${tok}*" >/dev/null 2>&1; then
			continue
		fi
		if is_allowed "$tok"; then
			skip=$((skip + 1))
			continue
		fi
		echo "MISSING $tok   ($f)"
		missing=$((missing + 1))
	done < <(grep -oE "$PAT" "$f" | sed 's/^`//; s/`$//' | sort -u)
done

echo
echo "checked=$checked  missing=$missing  skipped=$skip  files=${#files[@]}"
if [ $missing -gt 0 ]; then
	echo "FAIL: $missing 个被引用的路径在仓库里不存在（合入该 lane 分支，或补 $ALLOWLIST）"
	exit 1
fi
echo "PASS: 文档引用的资产路径全部存在"
