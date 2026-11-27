#!/bin/bash
# SEND.sh —— coresight MODULE_DEVICE_TABLE v1 投递脚本（**默认 dry-run**；真发必须显式 `--yes`）
#
# 口径：`TASKS/README.md` §7（用户 2026-11-26 全面放行：备料+门禁全绿即可投）。
#   通道 = USTC smtp（`~/.gitconfig` 的 sendemail.*；技能 `upstream-mail-ustc`）。
#   本系列两枚补丁各自 1 行；证据 = 同一台 SM8750 上「模块化前无 alias / 加宏后有 alias 且 udev 自动加载」
#   （reports/upstream-coresight-fixes-20261127.md）。
#
# 用法：
#   bash SEND.sh          # dry-run：干净性检查 + git send-email --dry-run
#   bash SEND.sh --yes    # 真发
set -uo pipefail
cd "$(dirname "$0")" || exit 1
SEND=0
for arg in "$@"; do
	case "$arg" in
	--yes) SEND=1 ;;
	*) echo "❌ 不认识的参数：$arg（只接受 --yes）"; exit 1 ;;
	esac
done

TO="suzuki.poulose@arm.com"
CC="mike.leach@arm.com,james.clark@linaro.org,leo.yan@arm.com,alexander.shishkin@linux.intel.com,coresight@lists.linaro.org,linux-arm-kernel@lists.infradead.org,linux-kernel@vger.kernel.org"
mapfile -t PATCHES < <(ls -1 v1-000*.patch | sort)

echo "== 1) 件数/编号/Subject"
[ "${#PATCHES[@]}" -eq 3 ] || { echo "❌ 期望 3 封（cover + 2），实际 ${#PATCHES[@]}"; exit 1; }
for p in "${PATCHES[@]}"; do
	echo "  $p  →  $(sed -n 's/^Subject: //p' "$p" | head -1)"
done
grep -q 'Subject: \[PATCH 0/2\]' v1-0000-cover-letter.patch || { echo "❌ cover 编号不对"; exit 1; }

echo "== 2) 每封都有 AI 披露 + Signed-off-by"
for p in "${PATCHES[@]}"; do
	grep -q 'AI-assistance disclosure\|LLM coding assistant' "$p" || { echo "❌ $p 缺 AI 披露"; exit 1; }
	grep -q '^Signed-off-by: Qianhui Xu <xiaqinghuan@mail.ustc.edu.cn>' "$p" || { echo "❌ $p 缺 SOB"; exit 1; }
done
echo "  ok"

echo "== 3) checkpatch --strict（用发件树 /tmp/cs-wt；没有就跳过并告警）"
if [ -x /tmp/cs-wt/scripts/checkpatch.pl ]; then
	for p in "${PATCHES[@]:1}"; do
		out=$(perl /tmp/cs-wt/scripts/checkpatch.pl --strict --no-signoff "$p" 2>&1)
		case "$out" in
		*"0 errors, 0 warnings, 0 checks"*) echo "  $(basename "$p") 0E/0W/0C ✓" ;;
		*) echo "❌ checkpatch：$(basename "$p")"; echo "$out" | tail -10; exit 1 ;;
		esac
	done
else
	echo "  ⚠ 无 /tmp/cs-wt/scripts/checkpatch.pl，跳过（门禁记录见 GATES.md）"
fi

echo "== 4) 干跑发送"
CMD=(git send-email --confirm=never --no-annotate --to="$TO" --cc="$CC" "${PATCHES[@]}")
mkdir -p logs
DRY=logs/dry-run-$(date +%Y%m%d-%H%M%S).txt
timeout -k 5 300 "${CMD[@]}" --dry-run > "$DRY" 2>&1 || { echo "❌ dry-run 失败（见 $DRY）"; tail -20 "$DRY"; exit 1; }
grep -E '^(RCPT TO|Subject|Message-ID|Result):' "$DRY" | sed 's/^/  /' | head -40
if [ "$SEND" = 0 ]; then
	echo
	echo "ℹ dry-run 通过。真发： bash SEND.sh --yes"
	exit 0
fi

echo "== 5) 真发"
timeout -k 5 600 "${CMD[@]}" | tee "logs/sent-$(date +%Y%m%d-%H%M%S).txt"
echo "→ 发完：① 记 SENT.md（MID + Result）② lore 复核 coresight/linux-arm-kernel"
echo "  ③ 回填 TASKS/UPSTREAM.md §7 与 reports/upstream-coresight-fixes-20261127.md"
