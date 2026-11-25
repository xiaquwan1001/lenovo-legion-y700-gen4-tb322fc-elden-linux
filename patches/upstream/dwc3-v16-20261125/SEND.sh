#!/bin/bash
# SEND.sh —— dwc3 v16 投递脚本（**默认 dry-run**；真发必须显式给 --yes）
#
# 为什么有它：投递按 `TASKS/README.md` §7「按系列逐次批准」，放行那一刻不该再手拼命令。
#   通道 = USTC smtp（Message-ID 逐字保真；技能 `upstream-mail-ustc`、PITFALLS §二十七）。
#   v16 相对 v15 只动 1/3（sashiko 2026-11-25 的两条 [Low]）：2/3、3/3 与本目录之外的
#   `../dwc3-v15-20261125/` 逐字节同内容（本脚本第 2 步现场 cmp + patch-id 复核）。
#   `Cc:` 仍含 `linux-usb@vger.kernel.org`（Greg KH 2026-11-24 的要求）。
# 用法：
#   bash SEND.sh          # dry-run：干净性检查 + `git send-email --dry-run`
#   bash SEND.sh --yes    # 真发（先跑同一套 dry-run 检查，通过才发）
#   其它任何参数都不改变行为：默认仍是 dry-run。
set -uo pipefail
cd "$(dirname "$0")" || exit 1
SEND=0
for arg in "$@"; do
	case "$arg" in
	--yes) SEND=1 ;;
	*) echo "❌ 不认识的参数：$arg（本脚本只接受 --yes；不带参数 = dry-run）"; exit 1 ;;
	esac
done

TO="Thinh.Nguyen@synopsys.com"
CC="gregkh@linuxfoundation.org,linux-usb@vger.kernel.org,robh@kernel.org,krzk+dt@kernel.org,conor+dt@kernel.org,devicetree@vger.kernel.org,linux-arm-msm@vger.kernel.org,linux-kernel@vger.kernel.org"
V15_DIR="../dwc3-v15-20261125"
mapfile -t PATCHES < <(ls -1 v16-000*.patch | sort)

echo "== 1) 件数/编号检查"
[ "${#PATCHES[@]}" -eq 4 ] || { echo "❌ 期望 4 封（cover + 3），实际 ${#PATCHES[@]}"; exit 1; }
for p in "${PATCHES[@]}"; do
	subj=$(sed -n 's/^Subject: //p' "$p" | head -1)
	echo "  $p  →  $subj"
	case "$subj" in
	"[PATCH v16 0/3] "*) ;;
	"[PATCH v16 "*) ;;
	*) echo "❌ 版本号不是 v16：$p"; exit 1 ;;
	esac
done

echo "== 2) 2/3、3/3 与 v15 逐字节同内容（diff 段 cmp + patch-id）"
for n in 2 3; do
	v15=$(ls "$V15_DIR"/v15-000$n-*.patch)
	v16=$(ls v16-000$n-*.patch)
	awk '/^diff --git/{f=1} f' "$v15" > /tmp/v16-cmp-v15-$n.diff
	awk '/^diff --git/{f=1} f' "$v16" > /tmp/v16-cmp-v16-$n.diff
	if cmp -s /tmp/v16-cmp-v15-$n.diff /tmp/v16-cmp-v16-$n.diff; then
		echo "  $n/3  diff 段 cmp 相同（$(sha256sum /tmp/v16-cmp-v16-$n.diff | cut -c1-16)…）"
	else
		echo "❌ $n/3 的 diff 段与 v15 不同；v16 只许动 1/3，停了别发"; exit 1
	fi
	id15=$(git patch-id --stable < "$v15" | cut -d' ' -f1)
	id16=$(git patch-id --stable < "$v16" | cut -d' ' -f1)
	[ "$id15" = "$id16" ] || { echo "❌ $n/3 patch-id 不同：v15=$id15 v16=$id16"; exit 1; }
	echo "  $n/3  patch-id = $id16"
done

echo "== 3) cover：新线程（无 In-Reply-To/References）+ 收件人含 linux-usb"
if grep -qE '^(In-Reply-To|References):' v16-0000-cover-letter.patch; then
	echo "❌ cover 带线程头，会挂到旧线程上"; exit 1
fi
echo "  cover 无 In-Reply-To/References ✓"
case "$CC" in
*linux-usb@vger.kernel.org*) echo "  CC 含 linux-usb@vger.kernel.org ✓" ;;
*) echo "❌ CC 缺 linux-usb@vger.kernel.org（Greg 2026-11-24 的要求）"; exit 1 ;;
esac

echo "== 4) cover：changelog / AI 披露在 tearline 之下"
tear=$(grep -n '^---$' v16-0000-cover-letter.patch | head -1 | cut -d: -f1)
[ -n "$tear" ] || { echo "❌ cover 没有 --- tearline"; exit 1; }
for pat in '*** AI-assistance disclosure' 'Changes since v15' 'Changes since v14' 'Changes since v13' 'Changes since v11' 'Changes since v10' 'Changes in earlier versions'; do
	line=$(awk -v p="$pat" 'index($0, p) == 1 { print NR; exit }' v16-0000-cover-letter.patch)
	if [ -z "$line" ] || [ "$line" -lt "$tear" ]; then
		echo "❌ 「$pat」不在 tearline 之下（tearline 行 $tear，命中行 ${line:-无}）"; exit 1
	fi
	echo "  「$pat」@ 行 $line > tearline $tear ✓"
done

echo "== 5) 1/3：changelog 在 tearline 之下、commit message 里没有它"
tear1=$(grep -n '^---$' v16-0001-*.patch | head -1 | cut -d: -f1)
c15=$(grep -n '^Changes since v15' v16-0001-*.patch | head -1 | cut -d: -f1)
if [ -z "$c15" ] || [ "$c15" -lt "$tear1" ]; then
	echo "❌ 1/3 的 changelog 不在 tearline 之下（tearline 行 ${tear1}，命中行 ${c15:-无}）"; exit 1
fi
echo "  1/3 的「Changes since v15」@ 行 $c15 > tearline $tear1 ✓"
if sed -n "1,${tear1}p" v16-0001-*.patch | grep -qE '^(Changes since|Changes in|\*\*\* AI-assistance)'; then
	echo "❌ 1/3 的 commit message 区（tearline 之前）里还有 changelog/披露段"; exit 1
fi
echo "  1/3 的 commit message 区干净 ✓"

echo "== 6) mailinfo 解析检查"
for p in "${PATCHES[@]}"; do
	timeout -k 5 30 git mailinfo /tmp/mi-msg /tmp/mi-patch < "$p" >/dev/null 2>&1 || { echo "❌ mailinfo 失败：$p"; exit 1; }
done
echo "  4/4 OK"

echo "== 7) smtp 配置"
smtp=$(git config --get sendemail.smtpserver || true)
user=$(git config --get sendemail.smtpuser || true)
echo "  sendemail.smtpserver=${smtp:-<未设>}  smtpuser=${user:-<未设>}"
if [ -z "$smtp" ]; then
	echo "❌ 未配置 sendemail.*；按技能 upstream-mail-ustc 配 smtp.ustc.edu.cn:465 后再跑"
	exit 1
fi

CMD=(git send-email --confirm=never --no-annotate --to="$TO" --cc="$CC" "${PATCHES[@]}")
echo "== 8) dry-run"
mkdir -p logs
DRY=logs/dry-run-$(date +%Y%m%d-%H%M%S).txt
timeout -k 5 300 "${CMD[@]}" --dry-run > "$DRY" 2>&1 || { echo "❌ dry-run 失败（见 $DRY）"; tail -20 "$DRY"; exit 1; }
grep -E '^(RCPT TO|Subject|Message-ID|Result):' "$DRY" | sed 's/^/  /' | head -60
if ! grep -q 'RCPT TO:<linux-usb@vger.kernel.org>' "$DRY"; then
	echo "❌ dry-run 的收件人里没有 linux-usb@vger.kernel.org（Greg 2026-11-24 的要求）"; exit 1
fi
echo "  linux-usb 在收件人里 ✓（日志 $DRY）"
if [ "$SEND" = 0 ]; then
	echo
	echo "ℹ dry-run 通过。真发：  bash SEND.sh --yes"
	echo "  真发后按 MID 复核（patchwork 摄取滞后不算第一判据）："
	echo "    https://lore.kernel.org/linux-usb/<MID>/   https://lore.kernel.org/linux-devicetree/<MID>/"
	echo "  把结果追加进本目录 SENT.md（cover MID + 4 封 Result + lore 命中清单）。"
	exit 0
fi

echo "== 9) 真发"
timeout -k 5 600 "${CMD[@]}" | tee "logs/sent-$(date +%Y%m%d-%H%M%S).txt"
echo
echo "→ 发完记得：① 记 SENT.md（结果 + MID）② lore 复核 linux-usb 与 linux-devicetree 两处"
echo "  ③ 更新 TASKS §7 / reports/* ④ 回帖只答问题不复述"
