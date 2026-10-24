#!/bin/bash
# q28-coldboot-collect.sh — 等一次**真实 POR 冷起**，起来后立刻跑 q28-clkdiag.sh 并归档。
#
# 用法： scripts/q28-coldboot-collect.sh <round> [等��秒数=600]
# 前提：用户在机旁做物理断电 + 开机（真 POR；暖复位不算，见 PITFALLS #166）。
# 产出： reports/artifacts/q28-clkdiag-r<round>-<bootid8>.txt
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
R=${1:?usage: $0 <round> [timeout_s]}
WAIT=${2:-600}
SER=HA2EXB0E
SSH="ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=4"
PREV=$(cat /tmp/prev_boot_id.txt 2>/dev/null | tr -d '\n')

pick_target() {
	for t in root@192.168.7.1 ; do
		$SSH "$t" true 2>/dev/null && { echo "$t"; return 0; }
	done
	# 回落：gadget 的 IPv6 链路本地（MAC 02:1e:5e:ed:e1:01 ⇒ …:1e:5eff:feed:e101）
	local ifc
	ifc=$(ip -br link 2>/dev/null | awk '/enx/{print $1}' | while read -r i; do
		[ "$(cat /sys/class/net/$i/address 2>/dev/null)" = "02:1e:5e:ed:e1:01" ] && { echo "$i"; break; }
	done)
	[ -n "$ifc" ] && $SSH "root@fe80::1e:5eff:feed:e101%$ifc" true 2>/dev/null && { echo "root@fe80::1e:5eff:feed:e101%$ifc"; return 0; }
	return 1
}

echo "[collect] 等冷起（最多 ${WAIT}s）… 当前已记录的 boot_id=$PREV"
deadline=$(( $(date +%s) + WAIT ))
while [ "$(date +%s)" -lt "$deadline" ]; do
	T=$(pick_target) || { sleep 5; continue; }
	BID=$($SSH "$T" 'cat /proc/sys/kernel/random/boot_id' 2>/dev/null | tr -d '\r')
	[ -n "$BID" ] || { sleep 5; continue; }
	if [ "$BID" != "$PREV" ]; then
		UP=$($SSH "$T" 'cut -d" " -f1 /proc/uptime' 2>/dev/null | tr -d '\r')
		# 等 udev/驱动稳定到 12 s 再取证
		while [ "${UP%.*}" -lt 12 ] 2>/dev/null; do sleep 2; UP=$($SSH "$T" 'cut -d" " -f1 /proc/uptime' 2>/dev/null | tr -d '\r'); done
		OUT="reports/artifacts/q28-clkdiag-r$R-$(printf '%s' "$BID" | cut -c1-8).txt"
		$SSH "$T" 'bash -s' < "$ROOT/scripts/q28-clkdiag.sh" >/dev/null 2>&1
		$SSH "$T" "cat /var/tmp/q28-clkdiag-$(printf '%s' "$BID" | cut -c1-8).txt" > "$ROOT/$OUT" 2>/dev/null
		# Q32 同发取证：把「复位深度 + 固件有没有留活显示」与 Q28 样本绑在一起
		$SSH "$T" 'RESET_DECLARED=por sh -s' < "$ROOT/scripts/q32-boot-evidence.sh" >/dev/null 2>&1
		$SSH "$T" "cat /var/tmp/q32-boot-$(printf '%s' "$BID" | cut -c1-8).txt" \
			> "$ROOT/reports/artifacts/q32-boot-$(printf '%s' "$BID" | cut -c1-8).txt" 2>/dev/null
		printf '%s' "$BID" > /tmp/prev_boot_id.txt
		echo "[collect] 新启动 boot_id=$BID uptime=${UP}s → $OUT"
		grep -E "^(command DMA timeout|peer command DMA timeout|DSI_PLL_lockfail|reset failure|STORM|recovery is not complete) " "$ROOT/$OUT" | sed 's/^/    /'
		sed -n '/ctl-clock-rates/,/^$/p' "$ROOT/$OUT" | sed 's/^/    /'
		exit 0
	fi
	sleep 5
done
echo "[collect] 超时：没检测到新启动（用户没断电，或 USB 没重新枚举）" >&2
exit 1
