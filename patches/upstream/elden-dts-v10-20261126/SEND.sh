#!/bin/bash
# SEND.sh —— elden 板 DTS v10 投递脚本（**默认只做本地检查**；真发需显式 --send）
#
# v10 相对 v9 的唯一实质改动 = 2/2 加四条 vin*-supply（+ 一处注释）。
# 所以本脚本的断言就是：① 件数/代次；② 1/2 与 v9 逐字节相同；③ 2/2 的 diff 段相对 v9
# 只多了那四行；④ cover 保留 Krzysztof 要的 "Waiting on bindings" 且答了 sashiko 三条；
# ⑤ 行宽/纯 ASCII。
#
# 用法：
#   bash SEND.sh              # 本地检查（不连 SMTP）
#   bash SEND.sh --dry-run    # 追加 `git send-email --dry-run`
#   bash SEND.sh --send       # 真发（须先按 TASKS §7 逐系列放行）
set -uo pipefail
cd "$(dirname "$0")" || exit 1
MODE=local
case "${1:-}" in
	--dry-run) MODE=dryrun ;;
	--send)    MODE=send ;;
	"")        ;;
	*) echo "用法: bash SEND.sh [--dry-run|--send]"; exit 2 ;;
esac

# 收件人沿用 v9 那次 get_maintainer.pl --no-rolestats 的结果（未重查）
TO="andersson@kernel.org,konradybcio@kernel.org"
CC="abelvesa@kernel.org,mitltlatltl@gmail.com,robh@kernel.org,krzk+dt@kernel.org,conor+dt@kernel.org,devicetree@vger.kernel.org,linux-arm-msm@vger.kernel.org,linux-kernel@vger.kernel.org"

mapfile -t PATCHES < <(ls -1 v10-000*.patch | sort)

echo "== 1) 件数 / 代次"
[ "${#PATCHES[@]}" -eq 3 ] || { echo "❌ 期望 3 封（cover + 2），实际 ${#PATCHES[@]}"; exit 1; }
for p in "${PATCHES[@]}"; do
	subj=$(sed -n 's/^Subject: //p' "$p" | head -1)
	echo "  $p  →  $subj"
	case "$subj" in
	"[PATCH v10 "*) ;;
	*) echo "❌ 版本号不是 v10：$p"; exit 1 ;;
	esac
done

echo "== 2) 1/2 与 v9 逐字节相同（本代不动 binding）"
V9=../elden-dts-v9-20261126
v9p1=$(ls "$V9"/v9-0001-*.patch); v10p1=$(ls v10-0001-*.patch)
if cmp -s <(sed -n '/^diff --git/,$p' "$v9p1") <(sed -n '/^diff --git/,$p' "$v10p1"); then
	echo "  1/2 diff 段与 v9 相同 ✅"
else
	echo "❌ 1/2 的 diff 段变了（本代只该动 2/2）"; exit 1
fi

echo "== 3) 2/2 相对 v9 只多四条 vin*-supply"
v9p2=$(ls "$V9"/v9-0002-*.patch); v10p2=$(ls v10-0002-*.patch)
diff <(sed -n '/^diff --git/,$p' "$v9p2") <(sed -n '/^diff --git/,$p' "$v10p2") > /tmp/v10-diff-vs-v9.txt
added=$(grep -c '^> +' /tmp/v10-diff-vs-v9.txt)
removed=$(grep -c '^< ' /tmp/v10-diff-vs-v9.txt)
echo "  相对 v9：+$added 行 / -$removed 行（改 hunk 头与行号计入）"
for s in vin12-supply vin34-supply vin5-supply vin7-supply; do
	grep -q "^> +.*$s = <&wl2868c_vsys>;" /tmp/v10-diff-vs-v9.txt \
		|| { echo "❌ 2/2 缺「$s」"; exit 1; }
done
grep -q '^> +.*vin6-supply' /tmp/v10-diff-vs-v9.txt \
	&& { echo "❌ 不该加 vin6-supply（LDO6 本板未引出）"; exit 1; }
echo "  四条 vin*-supply 齐、无 vin6 ✅"

echo "== 4) cover 必含段（Krzysztof 的 'Waiting on bindings' + sashiko 三条逐条）"
COVER=v10-0000-cover-letter.patch
for pat in "Waiting on bindings" "waits on willsemi,wl2868c" \
           "Merge order" "missing willsemi,wl2868c binding schema in target tree" \
           "missing core boot and power nodes" \
           "missing vin*-supply properties on pmic@2f for active LDOs" \
           "Changes since v9" "LLM coding assistant"; do
	grep -qF "$pat" "$COVER" || { echo "❌ cover 缺「$pat」"; exit 1; }
done
awk 'NR<=30 && /Waiting on bindings/{found=1} END{exit found?0:1}' "$COVER" \
	|| { echo "❌ 'Waiting on bindings' 不在 cover 前 30 行"; exit 1; }
echo "  cover 段落齐、依赖仍在第 $(grep -n 'Waiting on bindings' "$COVER" | cut -d: -f1) 行 ✅"

echo "== 5) 2/2 changelog 记了本代改动"
sed -n '/^Changes in v10:/,/^---$/p' "$v10p2" | grep -qF "vin12" \
	|| { echo "❌ 2/2 的 'Changes in v10' 未提新增 supply"; exit 1; }
echo "  2/2 'Changes in v10' 含 vin12 ✅"

echo "== 6) 线程形状（项目口径 = 新线程）"
if grep -qE '^(In-Reply-To|References):' "$COVER"; then
	echo "  ⚠ cover 带 In-Reply-To/References（确认是有意为之再发）"
else
	echo "  新线程（cover 无 In-Reply-To/References）✅"
fi

echo "== 7) 行宽 / 非 ASCII"
for p in "${PATCHES[@]}"; do
	awk 'length > 998 {print FILENAME": 行过宽"; bad=1} END{exit bad?1:0}' "$p" || exit 1
	LC_ALL=C grep -nP '[^\x00-\x7F]' "$p" && { echo "❌ $p 含非 ASCII"; exit 1; }
done
echo "  全部 ≤998 且纯 ASCII ✅"

[ "$MODE" = local ] && { echo "== 本地检查结束（未发、未连 SMTP）"; exit 0; }

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

echo "== 8) 真发"
SENT=logs/sent-$(date +%Y%m%d-%H%M%S).txt
timeout -k 10 600 "${COMMON[@]}" "${PATCHES[@]}" > "$SENT" 2>&1
rc=$?
grep -E '^(Result|Message-ID):' "$SENT" | sed 's/^/  /'
echo "  send-email rc=$rc（日志 $SENT）"
[ "$rc" = 0 ] || exit "$rc"
sha256sum "${PATCHES[@]}" > "$SENT.sha256"
echo "→ 发完：① 记 SENT.md（MID + Result + lore 命中）② 更新 TASKS §7 / reports/upstream-status-*"
