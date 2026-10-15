#!/bin/bash
# q28-por-queue.sh — 交替采样队列：逐个镜像等用户 POR 进 fastboot，再跑一次冷起样本。
#
# usage: scripts/q28-por-queue.sh <label:img> [<label:img> ...]
#   例:  scripts/q28-por-queue.sh vk124:out/boot-elden-vk124-merged.img vk94:out/boot-elden-vk94.img
# 每轮：阻塞等 fastboot 出现（=用户已物理 POR + Vol-+电源）→ q28-cold-run.sh → 打印下一步提示。
# 停止：Ctrl-C；或 touch /tmp/q28-por-queue.stop
# 纪律：串口 logger 需另行常驻；实验前确认 q28-watchdog off（脚本会尝试在台架上关一次）。
set -uo pipefail
cd /home/xuqianhui1001/y700-elden
STOP=/tmp/q28-por-queue.stop
rm -f "$STOP"
[ $# -ge 1 ] || { echo "usage: $0 <label:img> [...]"; exit 2; }
n=0
for spec in "$@"; do
	n=$((n+1))
	LABEL=${spec%%:*}; IMG=${spec#*:}
	[ -f "$IMG" ] || { echo "[queue] ❌ 缺镜像 $IMG"; exit 2; }
	echo "[queue] ($n/$#) 等待 fastboot（请物理断电 → Vol- + 电源）= $LABEL / $IMG"
	while ! fastboot devices 2>/dev/null | grep -q .; do
		[ -e "$STOP" ] && { echo "[queue] stop marker -> 退出"; exit 0; }
		sleep 3
	done
	echo "[queue] fastboot 就绪 -> 采样 $LABEL"
	bash scripts/q28-cold-run.sh "$IMG" "$LABEL"
	# 台架就绪后立即关看门狗（坏发 75 s 会自动重启，污染样本）
	for i in $(seq 1 15); do
		ssh -o StrictHostKeyChecking=no -o ConnectTimeout=4 -b 0 root@192.168.7.1 \
			'/usr/local/sbin/q28-watchdog.sh off >/dev/null 2>&1; echo ok' 2>/dev/null | grep -q ok && break
		sleep 4
	done
	echo "[queue] ---- $LABEL 完成；下一轮请再次 POR ----"
done
echo "[queue] 队列结束（共 $# 发）"
