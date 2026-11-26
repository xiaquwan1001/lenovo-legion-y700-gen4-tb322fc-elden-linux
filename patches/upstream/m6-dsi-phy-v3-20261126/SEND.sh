#!/bin/bash
# SEND.sh —— M6 dsi/phy PLL_SYSTEM_MUXES v3 投递脚本（**默认 dry-run**；真发需显式 --yes）
#
# 通道/收件人 = v2 实发版（`../m6-dsi-pll-v2-20261113-sent-20261117/SENT.md`：11 封全 250，
# lore linux-arm-msm + dri-devel 命中）。
# 投递形态 = **新线程**（无 --in-reply-to）：Jianfeng Liu 指出 2026-11-17 v2 那封信
# thread 断裂 / subject 空，故 v3 重建线程并在正文 `Changes since v2` 里自述。
# 投递按 `TASKS/README.md` §7「按系列逐次批准」。
# 用法：
#   bash SEND.sh          # dry-run
#   bash SEND.sh --yes    # 真发（先跑同一套检查）
set -uo pipefail
cd "$(dirname "$0")" || exit 1
YES=0; [ "${1:-}" = "--yes" ] && YES=1

PATCH="0001-drm-msm-dsi-phy-program-PLL_SYSTEM_MUXES-on-the-firs.patch"

TO="dri-devel@lists.freedesktop.org,linux-arm-msm@vger.kernel.org"
CC="freedreno@lists.freedesktop.org,linux-kernel@vger.kernel.org"
CC="$CC,robin.clark@oss.qualcomm.com,lumag@kernel.org,abhinav.kumar@linux.dev"
CC="$CC,jesszhan0024@gmail.com,sean@poorly.run,marijn.suijten@somainline.org"
CC="$CC,liujianfeng1994@gmail.com"

echo "== 1) 件存在 / 版本 / Tested-by 断言"
[ -f "$PATCH" ] || { echo "❌ 缺 $PATCH"; exit 1; }
subj=$(tr -d '\n' < "$PATCH" | sed 's/Subject: //' | grep -m1 -o '\[PATCH v3\] drm/msm/dsi/phy: program PLL_SYSTEM_MUXES on the first PHY enable')
[ -n "$subj" ] || { echo "❌ Subject 非 [PATCH v3]（或被换行破坏）"; exit 1; }
grep -q '^Tested-by: Jianfeng Liu <liujianfeng1994@gmail.com>$' "$PATCH" \
  || { echo "❌ 缺 Tested-by: Jianfeng Liu"; exit 1; }
grep -q '^Signed-off-by: Xu Qianhui <xiaqinghuan@mail.ustc.edu.cn>$' "$PATCH" \
  || { echo "❌ 缺 Signed-off-by"; exit 1; }
grep -q '^Tested-by: Jianfeng Liu <liujianfeng1994@gmail.com>$' "$PATCH" \
  && awk '/^Signed-off-by:/{s=NR} /^Tested-by: Jianfeng/{t=NR} END{exit !(t==s+1)}' "$PATCH" \
  || { echo "❌ Tested-by 未紧跟 Signed-off-by"; exit 1; }
echo "  件 OK：v3 前缀 + Tested-by（紧跟 Signed-off-by）"

echo "== 2) mailinfo 解析检查"
timeout 30 git mailinfo /tmp/mi-msg-m6v3 /tmp/mi-patch-m6v3 < "$PATCH" >/dev/null 2>&1 \
  || { echo "❌ mailinfo 失败"; exit 1; }
grep -q 'Tested-by: Jianfeng Liu' /tmp/mi-msg-m6v3 || { echo "❌ mailinfo 丢了 Tested-by"; exit 1; }
grep -q 'REG_DSI_7nm_PHY_PLL_SYSTEM_MUXES' /tmp/mi-patch-m6v3 || { echo "❌ mailinfo 丢了补丁体"; exit 1; }
echo "  mailinfo OK（commit message 含 Tested-by，补丁体完整）"

echo "== 3) 投递形态断言：新线程（无 In-Reply-To）"
grep -q '^In-Reply-To:' <(git send-email --dry-run --confirm=never --no-annotate \
  --to="$TO" --cc="$CC" "$PATCH" 2>&1) \
  && { echo "❌ 不应有 In-Reply-To（v2 线程已断裂，v3 = 新线程）"; exit 1; } || true
echo "  新线程 OK（无 --in-reply-to）"

echo "== 4) smtp 配置"
smtp=$(git config --get sendemail.smtpserver || true)
echo "  sendemail.smtpserver=${smtp:-<未设>}"
[ -n "$smtp" ] || { echo "❌ 未配置 sendemail.*；按技能 upstream-mail-ustc 配 smtp.ustc.edu.cn:465"; exit 1; }

CMD=(git send-email --confirm=never --no-annotate --suppress-from --to="$TO" --cc="$CC" "$PATCH")
echo "== 5) dry-run"
timeout 300 "${CMD[@]}" --dry-run || { echo "❌ dry-run 失败"; exit 1; }
if [ "$YES" = 0 ]; then
	echo; echo "ℹ dry-run 通过。真发：  bash SEND.sh --yes"
	echo "  ⚠ 真发按 TASKS/UPSTREAM.md §7 现行口径（2026-11-26 用户裁决：备料+门禁全绿即可投，不再逐系列批准）；发完做 lore 复核 + SENT.md + mail-append-sent.py"
	exit 0
fi

echo "== 6) 真发"
mkdir -p logs
timeout 600 "${CMD[@]}" | tee "logs/sent-$(date +%Y%m%d-%H%M%S).txt"
echo
echo "→ 发完：① 写 SENT.md（结果 + MID）② scripts/lore-fetch-raw.py 复核 linux-arm-msm + dri-devel ③ 不改 TASKS（§7 账由主会话记）"
