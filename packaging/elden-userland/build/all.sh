#!/bin/bash
# all.sh — 逐个跑本目录所有配方（默认 --dry-run，只打印；要真跑加 --apply）
#
# 用法:
#   bash packaging/elden-userland/build/all.sh              # 全部 dry-run，逐一打印命令
#   bash packaging/elden-userland/build/all.sh --apply      # 真跑（含 root 配方时会要求 sudo）
set -uo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
APPLY=0
for a in "$@"; do
	case "$a" in
		--apply) APPLY=1 ;;
		--dry-run) APPLY=0 ;;
		*) printf '未知参数: %s（--apply / --dry-run）\n' "$a" >&2; exit 2 ;;
	esac
done

RECIPES="ffrumble elden-hapticd eldroid-sensord waydroid-sensord waydroid-sensord-udp elden-ime-focusd reboot2"
rc=0
for r in $RECIPES; do
	printf '\n===== %s =====\n' "$r"
	if [ "$APPLY" = 1 ]; then
		bash "$HERE/$r.sh" || { printf '!!! %s 失败\n' "$r"; rc=1; }
	else
		bash "$HERE/$r.sh" --dry-run || { printf '!!! %s 的 dry-run 失败\n' "$r"; rc=1; }
	fi
done
printf '\n==== build/all: rc=%d（mode=%s）====\n' "$rc" "$([ "$APPLY" = 1 ] && echo apply || echo dry-run)"
exit "$rc"
