#!/bin/bash
# SEND.sh —— aw86927 v3 投递脚本（**默认 dry-run**；真发需显式 --yes）
#
# 通道/收件人 = v2 实发版（`../haptics-v2-20261117/SENT.md`：7 封全 250，lore linux-input + linux-devicetree 命中）。
# 投递按 `TASKS/README.md` §7「按系列逐次批准」。
# 用法：
#   bash SEND.sh          # dry-run
#   bash SEND.sh --yes    # 真发（先跑同一套检查）
set -uo pipefail
cd "$(dirname "$0")" || exit 1
YES=0; [ "${1:-}" = "--yes" ] && YES=1

TO="dmitry.torokhov@gmail.com"
CC="robh@kernel.org,krzk+dt@kernel.org,conor+dt@kernel.org,devicetree@vger.kernel.org,linux-input@vger.kernel.org,linux-kernel@vger.kernel.org"
mapfile -t PATCHES < <(ls -1 v3-000*.patch | sort)

echo "== 1) 件数/编号检查"
[ "${#PATCHES[@]}" -eq 7 ] || { echo "❌ 期望 7 封（cover + 6），实际 ${#PATCHES[@]}"; exit 1; }
for p in "${PATCHES[@]}"; do echo "  $p  →  $(sed -n 's/^Subject: //p' "$p" | head -1)"; done

echo "== 2) mailinfo 解析检查"
for p in "${PATCHES[@]}"; do
	timeout 30 git mailinfo /tmp/mi-msg /tmp/mi-patch < "$p" >/dev/null 2>&1 || { echo "❌ mailinfo 失败：$p"; exit 1; }
done
echo "  7/7 OK"

echo "== 3) smtp 配置"
smtp=$(git config --get sendemail.smtpserver || true)
echo "  sendemail.smtpserver=${smtp:-<未设>}"
[ -n "$smtp" ] || { echo "❌ 未配置 sendemail.*；按技能 upstream-mail-ustc 配 smtp.ustc.edu.cn:465"; exit 1; }

CMD=(git send-email --confirm=never --no-annotate --to="$TO" --cc="$CC" "${PATCHES[@]}")
echo "== 4) dry-run"
timeout 300 "${CMD[@]}" --dry-run || { echo "❌ dry-run 失败"; exit 1; }
if [ "$YES" = 0 ]; then
	echo; echo "ℹ dry-run 通过。真发：  bash SEND.sh --yes"
	echo "  ⚠ 建议先在 **linux-next 基线** 复跑 G1/G3（v2 的原基线；本地无该树，v3 门是按 7.4-rc3 验的）"
	exit 0
fi

echo "== 5) 真发"
mkdir -p logs
timeout 600 "${CMD[@]}" | tee "logs/sent-$(date +%Y%m%d-%H%M%S).txt"
echo
echo "→ 发完：① 写 SENT.md（结果 + MID）② lore 复核 linux-input + linux-devicetree ③ 更新 TASKS §7 / M4 相关行"
