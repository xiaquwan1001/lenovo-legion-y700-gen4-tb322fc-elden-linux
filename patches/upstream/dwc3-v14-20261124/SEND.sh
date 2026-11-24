#!/bin/bash
# SEND.sh —— dwc3 v14 投递脚本（**默认 dry-run**；真发需显式 --yes）
#
# 为什么有它：投递按 `TASKS/README.md` §7「按系列逐次批准」，放行那一刻不该再手拼命令。
#   通道 = USTC smtp（Message-ID 逐字保真；技能 `upstream-mail-ustc`、PITFALLS §二十七）。
#   v12/v13 的成功命令形态见 `../dwc3-v12-20261123/SENT.md`（新线程、4 封、4×250）。
# 用法：
#   bash SEND.sh          # dry-run：干净性检查 + `git send-email --dry-run`
#   bash SEND.sh --yes    # 真发（先跑同一套 dry-run 检查，通过才发）
set -uo pipefail
cd "$(dirname "$0")" || exit 1
YES=0; [ "${1:-}" = "--yes" ] && YES=1

TO="Thinh.Nguyen@synopsys.com"
CC="robh@kernel.org,krzk+dt@kernel.org,conor+dt@kernel.org,gregkh@linuxfoundation.org,devicetree@vger.kernel.org,linux-arm-msm@vger.kernel.org,linux-kernel@vger.kernel.org"
mapfile -t PATCHES < <(ls -1 v14-000*.patch | sort)

echo "== 1) 件数/编号检查"
[ "${#PATCHES[@]}" -eq 4 ] || { echo "❌ 期望 4 封（cover + 3），实际 ${#PATCHES[@]}"; exit 1; }
for p in "${PATCHES[@]}"; do
	subj=$(sed -n 's/^Subject: //p' "$p" | head -1)
	echo "  $p  →  $subj"
done

echo "== 2) mailinfo 解析检查"
for p in "${PATCHES[@]}"; do
	timeout 30 git mailinfo /tmp/mi-msg /tmp/mi-patch < "$p" >/dev/null 2>&1 || { echo "❌ mailinfo 失败：$p"; exit 1; }
done
echo "  4/4 OK"

echo "== 3) smtp 配置"
smtp=$(git config --get sendemail.smtpserver || true)
user=$(git config --get sendemail.smtpuser || true)
echo "  sendemail.smtpserver=${smtp:-<未设>}  smtpuser=${user:-<未设>}"
if [ -z "$smtp" ]; then
	echo "❌ 未配置 sendemail.*；按技能 upstream-mail-ustc 配 smtp.ustc.edu.cn:465 后再跑"
	exit 1
fi

CMD=(git send-email --confirm=never --no-annotate --to="$TO" --cc="$CC" "${PATCHES[@]}")
echo "== 4) dry-run"
timeout 300 "${CMD[@]}" --dry-run || { echo "❌ dry-run 失败（看上面的报错，别真发）"; exit 1; }
if [ "$YES" = 0 ]; then
	echo
	echo "ℹ dry-run 通过。真发：  bash SEND.sh --yes"
	echo "  真发后按 MID 复核（patchwork 摄取滞后不算第一判据）："
	echo "    https://lore.kernel.org/linux-devicetree/<MID>/   https://lore.kernel.org/linux-usb/<MID>/"
	echo "  把结果追加进本目录 SENT.md（cover MID + 4 封 Result + lore 命中清单）。"
	exit 0
fi

echo "== 5) 真发"
timeout 600 "${CMD[@]}" | tee "logs/sent-$(date +%Y%m%d-%H%M%S).txt"
echo
echo "→ 发完记得：① 记 SENT.md（结果 + MID）② lore 复核三处列表 ③ 更新 TASKS §7 / reports/upstream-*"
