#!/bin/bash
# q28-por-rounds.sh — 取 N 发**真实 POR 冷起**的 Q28 同口径样本（每发 = 用户一次断电开机）。
#
# 与 q28-coldboot-collect.sh 的区别：
#   · 连续取 N 轮（默认 2），每轮之间**等用户下一次断电**，不用手工重跑；
#   · 每轮同时落三样东西：clkdiag 全量、devprobe 三态判定、`reports/trials/*.json` 记录；
#   · 判据口径固定在 `reports/q28-dpu-intf-next-20261023.md` §2（4 个数）。
#
# 用法：
#   scripts/q28-por-rounds.sh [N=2] [每轮等机秒数=900] [起始轮号=1]
#
# 前提：
#   · `boot_b` 已是待测内核（当前 vk152）——本脚本**不刷机**，只做断电开机 + 取证；
#   · 用户在场：脚本喊「请断电」之后长按电源键 ~10 s 关机、再短按电源开机；
#   · **暖复位不算**（`reboot2 bootloader` 会粘 Q28 坏态，PITFALLS #166）。
#
# 产出：
#   reports/artifacts/q28-clkdiag-r<N>-<bootid8>.txt
#   reports/trials/<UTC>-q28por-r<N>/（probe.txt / dmesg.txt / env.txt）
#   reports/trials/<UTC>-q28por-r<N>.json（trial 记录，verdict 来自 devprobe）
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
N=${1:-2}
WAIT=${2:-900}
R0=${3:-1}
SSH="ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=4"
IMAGE=${IMAGE:-$ROOT/out/boot-elden-vk152.img}
TDIR="$ROOT/reports/trials"

pick_target() {
	$SSH root@192.168.7.1 true 2>/dev/null && { echo root@192.168.7.1; return 0; }
	local ifc
	ifc=$(ip -br link 2>/dev/null | awk '/enx/{print $1}' | while read -r i; do
		[ "$(cat /sys/class/net/$i/address 2>/dev/null)" = "02:1e:5e:ed:e1:01" ] && { echo "$i"; break; }
	done)
	if [ -n "$ifc" ] && $SSH "root@fe80::1e:5eff:feed:e101%$ifc" true 2>/dev/null; then
		echo "root@fe80::1e:5eff:feed:e101%$ifc"; return 0
	fi
	return 1
}

boot_id() { $SSH "$1" 'cat /proc/sys/kernel/random/boot_id' 2>/dev/null | tr -d '\r'; }
uptime_s() { $SSH "$1" 'cut -d" " -f1 /proc/uptime' 2>/dev/null | tr -d '\r'; }

# ---- 起点：记录当前 boot_id，避免把「已经跑着的这一发」当新样本 ----
T=$(pick_target) || { echo "❌ 设备不可达（先 elden-net.sh 起 SSH 通道）" >&2; exit 1; }
PREV=$(boot_id "$T")
[ -n "$PREV" ] || { echo "❌ 读不到 boot_id" >&2; exit 1; }
echo "[POR] 起点 boot_id=${PREV:0:8}  uptime=$(uptime_s "$T")s  待测镜像=$(basename "$IMAGE")"
echo "[POR] 计划取 $N 发真 POR（轮号 $R0 .. $((R0 + N - 1))）"

for k in $(seq 0 $((N - 1))); do
	R=$((R0 + k))
	echo
	echo "=============== Round $R / $((R0 + N - 1)) ==============="
	echo "→ 请现在做【物理断电】：长按电源键 ~10 s 关机，然后短按电源开机（不要用 reboot！）"
	echo "  本脚本会等 ${WAIT}s 内的新启动（boot_id 变化即认定为新样本）…"

	deadline=$(( $(date +%s) + WAIT ))
	BID=""
	while [ "$(date +%s)" -lt "$deadline" ]; do
		TT=$(pick_target) || { sleep 5; continue; }
		b=$(boot_id "$TT")
		[ -n "$b" ] || { sleep 5; continue; }
		[ "$b" = "$PREV" ] && { sleep 5; continue; }
		BID=$b; T=$TT; break
	done
	if [ -z "$BID" ]; then
		echo "❌ Round $R 超时：${WAIT}s 内没检测到新的 boot_id（没断电？还是没起来？）" >&2
		exit 1
	fi
	PREV=$BID
	B8=$(printf '%s' "$BID" | cut -c1-8)
	echo "[POR] 新启动 boot_id=$B8"

	# 等驱动/udev 稳定到 ≥12 s，且给 DPU/DSI 足够时间落定
	up=$(uptime_s "$T")
	while [ "${up%.*}" -lt 12 ] 2>/dev/null; do sleep 2; up=$(uptime_s "$T"); done
	echo "[POR] uptime=${up}s → 取证"

	# ---- 1) clkdiag 全量（只读）----
	OUT_REL="reports/artifacts/q28-clkdiag-r$R-$B8.txt"
	$SSH "$T" 'bash -s' < "$ROOT/scripts/q28-clkdiag.sh" >/dev/null 2>&1
	$SSH "$T" "cat /var/tmp/q28-clkdiag-$B8.txt" > "$ROOT/$OUT_REL" 2>/dev/null
	[ -s "$ROOT/$OUT_REL" ] || echo "  ⚠ clkdiag 产物为空：$OUT_REL" >&2

	# ---- 2) devprobe 三态判定 + dmesg/env ----
	STAMP=$(date -u +%Y%m%dT%H%M%SZ)
	LOGDIR="$TDIR/${STAMP}-q28por-r$R"
	mkdir -p "$LOGDIR"
	$SSH "$T" 'uname -a; cat /proc/uptime; cat /proc/cmdline' > "$LOGDIR/env.txt" 2>&1
	$SSH "$T" 'dmesg' > "$LOGDIR/dmesg.txt" 2>&1
	$SSH "$T" 'sh -s' < "$ROOT/scripts/q28-devprobe.sh" > "$LOGDIR/probe.txt" 2>&1
	VERDICT=$(grep -oE 'VERDICT=[A-Z]+' "$LOGDIR/probe.txt" | head -1 | cut -d= -f2)
	[ -n "$VERDICT" ] || VERDICT=UNKNOWN
	printf 'boot_id=%s\nimage=%s\n' "$BID" "$(basename "$IMAGE")" > "$LOGDIR/README.txt"
	cp -f "$ROOT/$OUT_REL" "$LOGDIR/" 2>/dev/null

	# ---- 3) trial 记录（与其它冷起样本同表，便于事后统计）----
	TAB="$T" bash "$ROOT/scripts/trial.sh" record --label "q28por-r$R" --image "$IMAGE" \
		--reset por --deploy none --probe none --verdict "$VERDICT" --logdir "$LOGDIR" \
		--note "Q28 真 POR 同口径样本（boot_id=$B8，clkdiag=$OUT_REL）" >/dev/null 2>&1 || \
		echo "  ⚠ trial 记录失败（继续）" >&2

	# ---- 4) 打印判据四数（reports/q28-dpu-intf-next-20261023.md §2）----
	echo "[POR] VERDICT=$VERDICT  产物: $OUT_REL"
	grep -E '^(command DMA timeout|peer command DMA timeout|DSI_PLL_lockfail|reset failure|STORM|recovery is not complete|failed to acquire mdss resets)' \
		"$ROOT/$OUT_REL" | sed 's/^/    /'
	echo "    -- pclk/byte parent+rate（判据 1、2）:"
	sed -n '/ctl-clock-rates/,/^$/p' "$ROOT/$OUT_REL" | grep -E 'pclk|byte' | sed 's/^/    /'
	echo "    -- connector:"
	grep -E 'DSI-1/(status|enabled|dpms)|card0-DSI-1' "$ROOT/$OUT_REL" | sed 's/^/    /'
done

echo
echo "[POR] 完成 $N 发。汇总（本轮新增）:"
for k in $(seq 0 $((N - 1))); do
	R=$((R0 + k))
	f=$(ls -t "$ROOT"/reports/artifacts/q28-clkdiag-r$R-*.txt 2>/dev/null | head -1)
	[ -n "$f" ] || continue
	v=$(grep -oE 'VERDICT=[A-Z]+' "$ROOT/reports/trials/"*"q28por-r$R/probe.txt" 2>/dev/null | head -1 | cut -d= -f2)
	printf '  r%s  %-14s %s\n' "$R" "${v:-?}" "$(basename "$f")"
done
