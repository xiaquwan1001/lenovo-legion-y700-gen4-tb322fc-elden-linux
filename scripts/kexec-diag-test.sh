#!/bin/bash
# kexec-diag-test.sh — 在设备上跑，用 vk65-m{0,1,2,3} 诊断内核定位 kexec 掉电阶段。
#
# 前提：当前运行的就是带 [KD] 诊断 hook 的内核（vk65-mX，cmdline 含 kexec_dbg=N）。
# 本脚本在设备上直接跑（经 adb/本地 shell 启动一次即可；dumper 会 setsid 脱离会话）。
#
# 流程：
#   1) 本地 setsid+nohup 起 kmsg→磁盘 dumper（每行 fsync，SSH 断了也照写）；
#   2) kexec_file_load 装载目标 Image（--load-only，安全）；
#   3) sync 落盘；
#   4) kexec -e 触发跳转；掉电点之前的 [KD] stage 已落盘。
#
# 重启回 boot_b 后读 /root/kmsg-diag.log 的最后一行 [KD] stage= 判读。
set -uo pipefail
LOG=${LOG:-/root/kmsg-diag.log}
IMG=${IMG:-}            # 目标 Image（可选，默认复用已加载的 kexec image）
DTB=${DTB:-}
[ -n "$IMG" ] && LOADARGS="--image $IMG"
[ -n "$DTB" ] && LOADARGS="$LOADARGS --dtb $DTB"

echo "== diag mask from cmdline =="
cat /proc/cmdline | tr ' ' '\n' | grep '^kexec_dbg=' || echo "!! NO kexec_dbg= in cmdline — 这不是诊断内核"
echo "== running kernel =="
uname -a
dmesg | grep '\[KD\] kexec_dbg=' || echo "!! 内核未打印 diag mask（确认是 vk65-mX）"

echo "== 1) start local kmsg dumper (setsid, fsync per line, SSH-independent) =="
# 用 python3 逐行 read(/dev/kmsg)+fsync，脱离控制终端与 SSH 会话。
: > "$LOG"
setsid nohup python3 - "$LOG" >/dev/null 2>&1 <<'PY' &
import os, sys
log = sys.argv[1]
fd = os.open("/dev/kmsg", os.O_RDONLY)
out = os.open(log, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o644)
while True:
    try:
        b = os.read(fd, 4096)
    except OSError:
        break
    if not b:
        break
    os.write(out, b)
    os.fsync(out)
PY
DPID=$!
echo "dumper pid=$DPID log=$LOG"
sleep 0.3

echo "== 2) kexec load (safe, no switch) =="
if [ -n "$IMG" ]; then
	kexec -l "$IMG" $LOADARGS --command-line "$(cat /proc/cmdline)" 2>&1 | sed 's/^/[kexec-l] /'
else
	echo "(无 IMG 传入：假定 kexec image 已加载，检查 kexec_loaded)"
fi
echo "kexec_loaded=$(cat /sys/kernel/kexec_loaded 2>/dev/null)"

echo "== 3) final sync + record pre-jump state =="
sync
echo "PRE-JUMP mask=$(cat /proc/cmdline | tr ' ' '\n' | grep kexec_dbg)" >> "$LOG"
sync

echo "== 4) kexec -e NOW  (掉电即预期；重启回 boot_b 后读 $LOG 最后一行 [KD]) =="
sleep 1
kexec -e 2>&1 | sed 's/^/[kexec-e] /'
