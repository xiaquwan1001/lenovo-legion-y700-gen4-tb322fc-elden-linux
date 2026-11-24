#!/bin/bash
# SEND.sh —— 板件 v9 投递脚本（**默认 dry-run**；真发需显式 --yes）
#
# 前置（硬）：dwc3 两连接器 binding **必须先进树**（当前在档 = `../dwc3-v14-20261124/`）。
#   不带 binding 的树上，本系列会被打 5 条 `mux-controls`/`mux-state`/`usb-role-switch` unexpected ⇒ 白投。
#   本脚本会在 dry-run 前打印这条前置提醒，但无法自动判断 binding 是否已进树。
# 通道/收件人口径 = v7（`../board-dts-single-20261113-sent-20261117/SENT.md`，9 收件人，1 封 250，
#   lore 三处命中）。
# 用法：
#   bash SEND.sh          # dry-run
#   bash SEND.sh --yes    # 真发（先跑同一套检查）
set -uo pipefail
cd "$(dirname "$0")" || exit 1
YES=0; [ "${1:-}" = "--yes" ] && YES=1

TO="abelvesa@kernel.org,andersson@kernel.org,konradybcio@kernel.org,robh@kernel.org"
CC="krzk+dt@kernel.org,conor+dt@kernel.org,devicetree@vger.kernel.org,linux-arm-msm@vger.kernel.org,linux-kernel@vger.kernel.org"
mapfile -t PATCHES < <(ls -1 v9-000*.patch | sort)

echo "== 0) 前置提醒（人工确认）"
echo "   ⚠ 本系列依赖 dwc3 两连接器 binding 已进树（它给 port@0 的 endpoint 加 mux-controls/mux-state/"
echo "     usb-role-switch）。没进树就投 = 大概率换来「等 binding」。最近一版 = ../dwc3-v14-20261124/。"

echo "== 1) 件数/编号检查"
[ "${#PATCHES[@]}" -eq 3 ] || { echo "❌ 期望 3 封（cover + 2），实际 ${#PATCHES[@]}"; exit 1; }
for p in "${PATCHES[@]}"; do
	echo "  $p  →  $(sed -n 's/^Subject: //p' "$p" | head -1)"
done

echo "== 2) mailinfo 解析检查"
for p in "${PATCHES[@]}"; do
	timeout 30 git mailinfo /tmp/mi-msg /tmp/mi-patch < "$p" >/dev/null 2>&1 || { echo "❌ mailinfo 失败：$p"; exit 1; }
done
echo "  3/3 OK"

echo "== 3) smtp 配置"
smtp=$(git config --get sendemail.smtpserver || true)
echo "  sendemail.smtpserver=${smtp:-<未设>}"
[ -n "$smtp" ] || { echo "❌ 未配置 sendemail.*；按技能 upstream-mail-ustc 配 smtp.ustc.edu.cn:465"; exit 1; }

CMD=(git send-email --confirm=never --no-annotate --to="$TO" --cc="$CC" "${PATCHES[@]}")
echo "== 4) dry-run"
timeout 300 "${CMD[@]}" --dry-run || { echo "❌ dry-run 失败"; exit 1; }
if [ "$YES" = 0 ]; then
	echo; echo "ℹ dry-run 通过。真发：  bash SEND.sh --yes"
	exit 0
fi

echo "== 5) 真发"
mkdir -p logs
timeout 600 "${CMD[@]}" | tee "logs/sent-$(date +%Y%m%d-%H%M%S).txt"
echo
echo "→ 发完记得：① 写 SENT.md（结果 + MID）② lore 三处复核 ③ 更新 TASKS §7 / M3-DTS 行"
