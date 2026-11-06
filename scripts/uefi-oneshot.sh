#!/bin/bash
# uefi-oneshot.sh — 真载荷单档一发：换新 UEFI 会话 → 载 preamble → 打一个 stage → 判读
#
# 为什么必须一档一会话：82 MB 真件连打第二发必退化 `diag st=Load Error last=[[K] ldt=Load Error]`
# （LoadImage 在第二次失败，与 PITFALLS #523 的"一会话一发"同族，但阈值更低：真件 1 发/会话）。
#
# 用法： scripts/uefi-oneshot.sh <stage> [preamble]
#        stage 见 out/real-ladder/real-vs<N>.img（None 也行=打真件原样，判 ret-after-lia 等）
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
S=${FASTBOOT:-fastboot}
ABL=${ABL_SERIAL:-HA2EXB0E}
UEFI=${UEFI_SERIAL:-51318dc0}
ST=${1:?usage: $0 <stage> [preamble]}
PRE=${2:-$ROOT/out/r21-sbstop-p20/uefi-preamble20-r1.img}
IMG=$ROOT/out/real-ladder/real-vs$ST.img
[ -f "$IMG" ] || { echo "缺 $IMG" >&2; exit 1; }

wait_serial() { # $1=serial  $2=超时秒
	local i
	for i in $(seq 1 "$2"); do
		sleep 1
		timeout 6 "$S" devices 2>/dev/null | grep -q "$1" && return 0
	done
	return 1
}

# 1) 确保在 ABL
if ! timeout 6 "$S" devices 2>/dev/null | grep -q "$ABL"; then
	if timeout 6 "$S" devices 2>/dev/null | grep -q "$UEFI"; then
		echo ">> UEFI→reboot bootloader" >&2
		timeout 20 "$S" -s "$UEFI" reboot bootloader >/dev/null 2>&1
		wait_serial "$ABL" 30 || {
			echo ">> 落到 Linux？走 ssh" >&2
			for i in $(seq 1 15); do
				timeout 4 ping -c1 -W1 192.168.7.1 >/dev/null 2>&1 && break
				sleep 4
			done
			timeout 25 ssh -o BatchMode=yes -o StrictHostKeyChecking=no \
				root@192.168.7.1 'eldroid-bootctl reboot bootloader' >/dev/null 2>&1
			wait_serial "$ABL" 40
		}
	fi
fi
timeout 6 "$S" devices 2>/dev/null | grep -q "$ABL" || { echo "!! 不在 ABL（需物理断电→开机→bootloader）" >&2; exit 2; }

# 2) 载 UEFI preamble
echo ">> 载 $(basename "$PRE")" >&2
timeout 60 "$S" -s "$ABL" boot "$PRE" 2>&1 | tail -2 >&2
wait_serial "$UEFI" 60 || { echo "!! UEFI fastboot 没起来" >&2; exit 3; }

# 3) 打一发
echo "== stage $ST（$(basename "$IMG")）" >&2
out=$(timeout 45 "$S" -s "$UEFI" boot "$IMG" 2>&1)
echo "$out" | tail -2

# 4) 判读
if echo "$out" | grep -qE "last=\[(vs-$ST|\[K\] stop=$ST)\]"; then
	echo "VERDICT stage=$ST REPLY"
elif timeout 8 "$S" -s "$UEFI" getvar product 2>&1 | grep -q '^product:'; then
	echo "VERDICT stage=$ST ALIVE-NO-REPLY"
else
	echo "VERDICT stage=$ST CRASH（需物理断电）"
fi
