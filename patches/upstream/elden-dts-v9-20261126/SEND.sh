#!/bin/bash
# SEND.sh —— elden 板 DTS v9 投递脚本（**默认只做本地检查**；真发需显式 --send）
#
# v9 只改文字（cover + 2/2 changelog），补丁内容与 v8 逐字节相同 ⇒ 本脚本的核心断言就是
# 「diff 段没变」+「cover 真的把 'waiting on bindings' 写在显眼处」+「2/2 changelog 也写了」。
#
# 用法：
#   bash SEND.sh              # 本地检查（件数/代次/diff 对照/必须段落/行宽/非 ASCII）
#   bash SEND.sh --dry-run    # 追加 `git send-email --dry-run`（需要 smtp 凭据可用）
#   bash SEND.sh --send       # 真发（必须先过本地检查；按 TASKS §7 逐系列放行后才用）
set -uo pipefail
cd "$(dirname "$0")" || exit 1
MODE=local
case "${1:-}" in
	--dry-run) MODE=dryrun ;;
	--send)    MODE=send ;;
	"")        ;;
	*) echo "用法: bash SEND.sh [--dry-run|--send]"; exit 2 ;;
esac

# 收件人 = v8 那次 get_maintainer.pl --no-rolestats 的现查结果（沿用，未重查）
TO="andersson@kernel.org,konradybcio@kernel.org"
CC="abelvesa@kernel.org,mitltlatltl@gmail.com,robh@kernel.org,krzk+dt@kernel.org,conor+dt@kernel.org,devicetree@vger.kernel.org,linux-arm-msm@vger.kernel.org,linux-kernel@vger.kernel.org"

mapfile -t PATCHES < <(ls -1 v9-000*.patch | sort)

echo "== 1) 件数 / 代次"
[ "${#PATCHES[@]}" -eq 3 ] || { echo "❌ 期望 3 封（cover + 2），实际 ${#PATCHES[@]}"; exit 1; }
for p in "${PATCHES[@]}"; do
	subj=$(sed -n 's/^Subject: //p' "$p" | head -1)
	echo "  $p  →  $subj"
	case "$subj" in
	"[PATCH v9 "*) ;;
	*) echo "❌ 版本号不是 v9：$p"; exit 1 ;;
	esac
done

echo "== 2) 与 v8 的 diff 段逐字节相同（v9 只许改文字）"
V8=../elden-dts-v8-20261125
for n in 1 2; do
	v8=$(ls "$V8"/v8-000$n-*.patch); v9=$(ls v9-000$n-*.patch)
	awk '/^diff --git/{f=1} f' "$v8" > /tmp/v9-cmp8-$n.diff
	awk '/^diff --git/{f=1} f' "$v9" > /tmp/v9-cmp9-$n.diff
	if cmp -s /tmp/v9-cmp8-$n.diff /tmp/v9-cmp9-$n.diff; then
		echo "  $n/2 diff 段 cmp 相同（$(sha256sum /tmp/v9-cmp9-$n.diff | cut -c1-16)…）"
	else
		echo "❌ $n/2 的 diff 段与 v8 不同；本代只许改文字，停了别发"; exit 1
	fi
done

echo "== 3) cover 必含「显式等 binding」段（Krzysztof 2026-11-25 12:03:08Z 要求）"
COVER=v9-0000-cover-letter.patch
for pat in "Waiting on bindings" "waits on willsemi,wl2868c" \
           "Documentation/devicetree/bindings/regulator/willsemi,wl2868c.yaml" \
           "84e67d2ee13f" "Merge order" "Cost of taking 2/2 early"; do
	grep -qF "$pat" "$COVER" || { echo "❌ cover 缺「$pat」"; exit 1; }
done
echo "  cover 六段断言全中 ✅"
# 依赖必须出现在 cover 前 30 行（= "instead of wall of text" 的可机械判据）
awk 'NR<=30 && /Waiting on bindings/{found=1} END{exit found?0:1}' "$COVER" \
	|| { echo "❌ 'Waiting on bindings' 不在 cover 前 30 行"; exit 1; }
echo "  位置：第 $(grep -n 'Waiting on bindings' "$COVER" | cut -d: -f1) 行（前 30 行内）✅"

echo "== 4) 2/2 changelog 也写了同一件事"
P2=$(ls v9-0002-*.patch)
sed -n '/^Changes in v9:/,/^Changes in v8:/p' "$P2" | grep -qF "willsemi,wl2868c" \
	|| { echo "❌ 2/2 的 'Changes in v9' 未提 wl2868c"; exit 1; }
echo "  2/2 'Changes in v9' 含依赖声明 ✅"

echo "== 5) 线程形状（v8/v16 口径 = 新线程）"
if grep -qE '^(In-Reply-To|References):' "$COVER"; then
	echo "  ⚠ cover 带 In-Reply-To/References（项目口径是新线程；确认是有意为之再发）"
else
	echo "  新线程（cover 无 In-Reply-To/References）✅"
fi

echo "== 6) 行宽 / 非 ASCII"
for p in "${PATCHES[@]}"; do
	awk 'length > 998 {print FILENAME": 行过宽"; bad=1} END{exit bad?1:0}' "$p" || exit 1
	LC_ALL=C grep -nP '[^\x00-\x7F]' "$p" && { echo "❌ $p 含非 ASCII"; exit 1; }
done
echo "  全部 ≤998 且纯 ASCII ✅"

[ "$MODE" = local ] && { echo "== 本地检查结束（未发、未连 SMTP）。下一步：--dry-run 或 --send"; exit 0; }

COMMON=(git send-email --confirm=never --no-annotate --no-chain-reply-to --thread
	--to="$TO" --cc="$CC" --suppress-cc=all --no-signed-off-cc
	--transfer-encoding=8bit)
mkdir -p logs
if [ "$MODE" = dryrun ]; then
	DRY=logs/dry-run-$(date +%Y%m%d-%H%M%S).txt
	timeout -k 10 300 "${COMMON[@]}" --dry-run "${PATCHES[@]}" > "$DRY" 2>&1
	rc=$?
	grep -E '^(To|Cc|Subject|Message-ID|Result):' "$DRY" | sed 's/^/  /' | head -30
	echo "  send-email dry-run rc=$rc（日志 $DRY）"
	exit "$rc"
fi

echo "== 7) 真发"
SENT=logs/sent-$(date +%Y%m%d-%H%M%S).txt
timeout -k 10 600 "${COMMON[@]}" "${PATCHES[@]}" > "$SENT" 2>&1
rc=$?
grep -E '^(Result|Message-ID):' "$SENT" | sed 's/^/  /'
echo "  send-email rc=$rc（日志 $SENT）"
[ "$rc" = 0 ] || exit "$rc"
sha256sum "${PATCHES[@]}" > "$SENT.sha256"
echo "→ 发完：① 记 SENT.md（MID + Result + lore 命中）② 更新 TASKS §7 / reports/upstream-status-*"
