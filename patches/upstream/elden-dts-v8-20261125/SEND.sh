#!/bin/bash
# SEND.sh —— elden 板 DTS v8 投递脚本（**默认 dry-run**；真发需显式 --send）
#
# 投递按 `TASKS/README.md` §7「按系列逐次批准」：放行那一刻不该再手拼命令。
# 通道 = USTC smtp（Message-ID 逐字保真；技能 `upstream-mail-ustc`、PITFALLS §二十七）。
#
# 与 v7 的差别只有 cover + 新增 1/2：
#   · 2/2 的 diff 段与 v7 逐字节相同（本脚本第 2 步现场 cmp）
#   · 1/2 = qcom.yaml 加 `lenovo,elden`（v7 漏的那一行；dtbs_check 缺它直接判根节点不合法）
#   · cover 必含「supersedes Pengyu Luo v2 + 2026-10-25 移交」段（`reports/dup-check-20261125.md` 附节）
#
# 用法：
#   bash SEND.sh                 # dry-run：件数/编号 + 与 v7 同内容 + cover 必含段 + send-email --dry-run
#   bash SEND.sh --send          # 真发（先跑同一套检查，通过才发）
set -uo pipefail
cd "$(dirname "$0")" || exit 1
SEND=0; [ "${1:-}" = "--send" ] && SEND=1

# 收件人 = 2026-11-25 `get_maintainer.pl --no-rolestats` 现查 + Pengyu Luo（关系声明）
TO="andersson@kernel.org,konradybcio@kernel.org"
CC="abelvesa@kernel.org,mitltlatltl@gmail.com,robh@kernel.org,krzk+dt@kernel.org,conor+dt@kernel.org,devicetree@vger.kernel.org,linux-arm-msm@vger.kernel.org,linux-kernel@vger.kernel.org"

mapfile -t PATCHES < <(ls -1 v8-000*.patch | sort)

echo "== 1) 件数/编号"
[ "${#PATCHES[@]}" -eq 3 ] || { echo "❌ 期望 3 封（cover + 2），实际 ${#PATCHES[@]}"; exit 1; }
for p in "${PATCHES[@]}"; do
	subj=$(sed -n 's/^Subject: //p' "$p" | head -1)
	echo "  $p  →  $subj"
	case "$subj" in
	"[PATCH v8 "*) ;;
	*) echo "❌ 版本号不是 v8：$p"; exit 1 ;;
	esac
done

echo "== 2) 2/2 与 v7 的 diff 段逐字节相同"
V7_DIR="../board-dts-single-20261113-sent-20261117"
v7=$(ls "$V7_DIR"/0001-*.patch)
v8=$(ls v8-0002-*.patch)
awk '/^diff --git/{f=1} f' "$v7" > /tmp/v8-cmp-v7.diff
awk '/^diff --git/{f=1} f' "$v8" > /tmp/v8-cmp-v8.diff
if cmp -s /tmp/v8-cmp-v7.diff /tmp/v8-cmp-v8.diff; then
	echo "  2/2 diff 段 cmp 相同（$(sha256sum /tmp/v8-cmp-v8.diff | cut -c1-16)…）"
else
	echo "❌ 2/2 的 diff 段与 v7 不同；本系列只许加 binding 行，停了别发"; exit 1
fi

echo "== 3) cover 必含段（supersedes / 移交 / 依赖 / AI 披露）"
for pat in "supersedes" "Pengyu Luo" "WL2868C" "LLM coding assistant"; do
	grep -qi "$pat" v8-0000-cover-letter.patch || { echo "❌ cover 缺「$pat」段"; exit 1; }
done
grep -qE '^(In-Reply-To|References):' v8-0000-cover-letter.patch \
	&& echo "  ⚠ cover 带 In-Reply-To（v7 无线程，正常应为新线程）" \
	|| echo "  新线程（无 In-Reply-To/References）✅"

echo "== 4) 件内不得有非 ASCII 以外的问题（行宽/尾随空格）"
for p in "${PATCHES[@]}"; do
	awk 'length > 998 {print FILENAME": 行过宽"; bad=1} END{exit bad?1:0}' "$p" || exit 1
done

echo "== 5) git send-email --dry-run"
COMMON=(git send-email --confirm=never --no-annotate --no-chain-reply-to --thread
	--to="$TO" --cc="$CC" --suppress-cc=all --no-signed-off-cc
	--transfer-encoding=8bit)
mkdir -p logs
DRY=logs/dry-run-$(date +%Y%m%d-%H%M%S).txt
timeout 300 "${COMMON[@]}" --dry-run "${PATCHES[@]}" > "$DRY" 2>&1
rc=$?
grep -E '^(To|Cc|Subject|Message-ID|Result):' "$DRY" | sed 's/^/  /' | head -30
echo "  send-email dry-run rc=$rc（日志 $DRY）"
[ "$rc" = 0 ] || { echo "❌ dry-run 失败，停了"; tail -15 "$DRY"; exit 1; }

if [ "$SEND" = 0 ]; then
	echo "== 6) dry-run 结束（未发）。放行后：bash SEND.sh --send"
	exit 0
fi

echo "== 6) 真发"
SENT=logs/sent-$(date +%Y%m%d-%H%M%S).txt
timeout 600 "${COMMON[@]}" "${PATCHES[@]}" > "$SENT" 2>&1
rc=$?
grep -E '^(Result|Message-ID):' "$SENT" | sed 's/^/  /'
echo "  send-email rc=$rc（日志 $SENT）"
[ "$rc" = 0 ] || exit "$rc"
sha256sum "${PATCHES[@]}" > "$SENT.sha256"
echo "→ 发完：① 记 SENT.md（MID + Result + lore 命中）② 更新 TASKS §7 / reports/upstream-status-*"
