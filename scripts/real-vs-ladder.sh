#!/bin/bash
# real-vs-ladder.sh — 在**真内核载荷**上跑 VS_STOP 阶梯（p17 件，零写盘）
#
# 为什么要它：2026-11-06 之前所有 sbstop= 阶梯的"载荷"都是 UEFI preamble 模板（ladder 脚本
# 用 $PREAMBLE 造 stage 件），从未在真内核镜像（out/boot-elden-vk172.img, 82 MB）上验证过。
# 现在已知：同一函数 LoadImageAndAuth，模板载荷走通、真载荷崩（0xCFE98C38）⇒ 必须用真载荷重跑。
#
# 判据：宿主收到 `FAILED (remote: 'diag st=Aborted last=[vs-N]')` ⇒ 该点之前不崩；
#       只打印到 `Sending`/`Booting` 且随后 `getvar` 无应答 ⇒ 崩在该点（需物理断电）。
#
# 用法： scripts/real-vs-ladder.sh [stage...]     默认 "16 20 24 26 27 28 34 35 36 37 38"
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
S=${FASTBOOT:-fastboot}
ABL=${ABL_SERIAL:-HA2EXB0E}
UEFI=${UEFI_SERIAL:-51318dc0}
PRE=${PRE:-$ROOT/out/r21-sbstop-p17/uefi-preamble17-r1.img}
STAGES=${*:-"16 20 24 26 27 28 34 35 36 37 38"}
LOG=$ROOT/reports/artifacts/real-vs-ladder-$(date +%Y%m%dT%H%M%S).tsv

mkdir -p "$(dirname "$LOG")"
printf 'stage\tverdict\treply\n' > "$LOG"

need_uefi() {
	timeout 8 "$S" devices 2>/dev/null | grep -q "$UEFI" && return 0
	timeout 8 "$S" devices 2>/dev/null | grep -q "$ABL" || {
		echo "!! ABL($ABL) 不在 fastboot：请先物理断电→开机→进 bootloader" >&2; return 1; }
	echo ">> 载 UEFI preamble（ABL 侧）" >&2
	timeout 60 "$S" -s "$ABL" boot "$PRE" 2>&1 | tail -2 >&2
	for _ in $(seq 1 12); do
		sleep 4
		timeout 8 "$S" devices 2>/dev/null | grep -q "$UEFI" && return 0
	done
	echo "!! UEFI fastboot($UEFI) 没起来" >&2; return 1
}

alive() { timeout 8 "$S" -s "$UEFI" getvar product 2>&1 | grep -q '^product:'; }

for st in $STAGES; do
	need_uefi || exit 1
	img=$ROOT/out/real-ladder/real-vs$st.img
	[ -f "$img" ] || { echo "skip $st（缺 $img）"; continue; }
	echo "== vs$st" >&2
	out=$(timeout 40 "$S" -s "$UEFI" boot "$img" 2>&1)
	if echo "$out" | grep -qE "last=\[(vs-$st|\[K\] stop=$st)\]"; then
		printf '%s\tREPLY\t%s\n' "$st" "$(echo "$out" | grep -o "remote: .*")" | tee -a "$LOG"
	elif alive; then
		printf '%s\tALIVE-NO-REPLY\t%s\n' "$st" "$(echo "$out" | tr '\n' ' ')" | tee -a "$LOG"
	else
		printf '%s\tCRASH\t%s\n' "$st" "$(echo "$out" | tr '\n' ' ')" | tee -a "$LOG"
		echo ">> 崩在 vs$st：请物理断电→开机→进 bootloader，然后重跑本脚本（从下一档开始）" >&2
		exit 2
	fi
done
echo "全部档位完成；账目：$LOG" >&2
