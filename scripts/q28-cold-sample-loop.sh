#!/bin/bash
# q28-cold-sample-loop.sh — 连续取 N 个**真冷起**样本：每发都等用户在物理 POR 后把设备停在 fastboot，
# 然后 fastboot boot + 三态判读（复用 q28-cold-run.sh，含 65s 存活门与 trial record）。
#
# usage: scripts/q28-cold-sample-loop.sh <boot.img> <tag> [samples] [wait_sec]
# 纪律：真冷起 = 物理断电（PITFALLS #163/#166）；暖复位样本无效；每发一条 record。
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT"
IMG=${1:?usage: q28-cold-sample-loop.sh <boot.img> <tag> [samples] [wait_sec]}
TAG=${2:-$(basename "$IMG" .img)}
N=${3:-4}
WAIT=${4:-900}
SUM=logs/q28-cold-loop-"$TAG"-$(date +%Y%m%d-%H%M%S).tsv
printf 'sample\tverdict\tout\n' > "$SUM"
echo "[loop] IMG=$IMG TAG=$TAG samples=$N wait=${WAIT}s summary=$SUM"

for i in $(seq 1 "$N"); do
	echo "[loop] === sample $i/$N : 等待 fastboot（物理 POR 后 Vol- + 电源；最多 ${WAIT}s）==="
	ok=0
	for t in $(seq 1 $((WAIT / 5))); do
		if timeout 15 fastboot devices 2>/dev/null | grep -q .; then ok=1; break; fi
		sleep 5
	done
	if [ "$ok" != 1 ]; then echo "[loop] sample $i: ${WAIT}s 内未进 fastboot，停止"; break; fi
	echo "[loop] sample $i: fastboot 就绪 -> boot"
	L=logs/q28-cold-loop-"$TAG"-s"$i"-$(date +%Y%m%d-%H%M%S).log
	bash scripts/q28-cold-run.sh "$IMG" "$TAG-s$i" > "$L" 2>&1
	V=$(sed -n 's/^VERDICT=//p' "$L" | tail -1); V=${V:-UNKNOWN}
	OD=$(sed -n 's/^\[cold\] logs -> //p' "$L" | tail -1)
	echo "[loop] sample $i VERDICT=$V log=$L out=$OD"
	printf '%s\t%s\t%s\n' "$i" "$V" "$OD" >> "$SUM"
	if [ "$V" = NOROUTE ]; then echo "[loop] NOROUTE（150s 无 SSH）——停止，需人工介入"; break; fi
done
echo "[loop] done"
cat "$SUM"
