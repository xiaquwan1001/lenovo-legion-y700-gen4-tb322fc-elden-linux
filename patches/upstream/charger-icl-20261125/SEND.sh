#!/bin/bash
# SEND.sh —— charger-icl-20261125 投递脚本（**默认 dry-run**；真发需显式 --yes）
#
# 为什么有它：投递按 `TASKS/README.md` §7「按系列逐次批准」，放行那一刻不该再手拼收件人/参数。
#   通道 = USTC smtp（技能 `upstream-mail-ustc`）；同一套命令形态已在 dwc3 系列验过
#   （见 `../dwc3-v12-20261123/SENT.md`）。
# 投前必读：`GATES.md` §4（P0 四步）未做完就真发 = 会带着 `[PATCH v2]`、拼写 warning 与
#   缺失的 AI 披露段出门。
# 用法：
#   bash SEND.sh            # dry-run：件数/编号检查 + mailinfo + smtp 配置 + git send-email --dry-run
#   bash SEND.sh --yes      # 真发（先跑同一套 dry-run 检查，通过才发）
set -uo pipefail
cd "$(dirname "$0")" || exit 1
YES=0; [ "${1:-}" = "--yes" ] && YES=1

# 收件人 = `get_maintainer.pl` 本轮现跑结果；Bjorn/Konrad 是否追加为**待裁决**
# （`README.md` §3），拍板后取消下面那行的注释再跑 dry-run。
TO="sre@kernel.org"
CC="linux-pm@vger.kernel.org,linux-arm-msm@vger.kernel.org,linux-kernel@vger.kernel.org"
# CC="$CC,andersson@kernel.org,konradybcio@kernel.org"

if [ -n "${SERIES_EXTRA_CC:-}" ]; then
	CC="$CC,$SERIES_EXTRA_CC"
fi

mapfile -t PATCHES < <(ls -1 0000-*.patch 0001-*.patch 2>/dev/null | sort)

echo "== 1) 件数/编号检查"
[ "${#PATCHES[@]}" -eq 2 ] || { echo "❌ 期望 2 封（cover + 1），实际 ${#PATCHES[@]}"; exit 1; }
for p in "${PATCHES[@]}"; do
	subj=$(sed -n 's/^Subject: //p' "$p" | head -1)
	echo "  $p  →  $subj"
done
# 首投带版本号 = GATES.md §4 第 4 步没做，直接拦。
if sed -n 's/^Subject: //p' 0000-*.patch 0001-*.patch | grep -q '\[PATCH v'; then
	echo "❌ 首投不应带 [PATCH vN]：先做 GATES.md §4（git format-patch 重生成）"
	[ "$YES" = 1 ] && exit 1
fi
# AI 披露段必须在 `---` tearline 之下（项目口径）。
if ! awk 'BEGIN{t=0} /^---$/{t=1;next} t && /AI-assistance disclosure/{found=1} END{exit !found}' 0000-*.patch; then
	echo "❌ cover 的 AI 披露段不在 \`---\` 之下"
	exit 1
fi
echo "  cover 披露段位置 OK"

echo "== 2) mailinfo 解析检查"
for p in "${PATCHES[@]}"; do
	timeout 30 git mailinfo /tmp/mi-msg /tmp/mi-patch < "$p" >/dev/null 2>&1 || { echo "❌ mailinfo 失败：$p"; exit 1; }
done
echo "  2/2 OK"

echo "== 3) smtp 配置"
smtp=$(git config --get sendemail.smtpserver || true)
port=$(git config --get sendemail.smtpserverport || true)
user=$(git config --get sendemail.smtpuser || true)
echo "  sendemail.smtpserver=${smtp:-<未设>}  port=${port:-<未设>}  smtpuser=${user:-<未设>}"
if [ -z "$smtp" ]; then
	echo "❌ 未配置 sendemail.*；按技能 upstream-mail-ustc 配 smtp.ustc.edu.cn:465 后再跑"
	exit 1
fi

CMD=(git send-email --confirm=never --no-annotate --to="$TO" --cc="$CC" "${PATCHES[@]}")
echo "== 4) dry-run（To=$TO / Cc=$CC）"
timeout 300 "${CMD[@]}" --dry-run || { echo "❌ dry-run 失败（看上面的报错，别真发）"; exit 1; }
if [ "$YES" = 0 ]; then
	echo
	echo "ℹ dry-run 通过。真发：  bash SEND.sh --yes"
	echo "  真发后按 MID 复核（patchwork 摄取滞后不算第一判据）："
	echo "    https://lore.kernel.org/linux-pm/<MID>/   https://lore.kernel.org/linux-arm-msm/<MID>/"
	echo "  把结果写进本目录 SENT.md（cover MID + 1 封 Result + lore 命中清单），"
	echo "  并更新 TASKS/README.md §7 的 M12 行与 patches/upstream/README.md §4 索引。"
	exit 0
fi

echo "== 5) 真发"
mkdir -p logs
timeout 600 "${CMD[@]}" | tee "logs/sent-$(date +%Y%m%d-%H%M%S).txt"
echo
echo "→ 发完记得：① 记 SENT.md（MID/Result）② lore 复核 linux-pm + linux-arm-msm ③ 同步 TASKS §7"
