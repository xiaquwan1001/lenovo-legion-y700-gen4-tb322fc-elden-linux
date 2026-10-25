#!/bin/sh
# pstore-catch.sh — 把 ramoops 里的「上次死挂」证据固化到盘上
#
# 从 /etc/init.d/pstore-catch 剥离（2026-10-25 固化）。为什么需要：
# ramoops 只活在 RAM 里，暖复位还在、**一断电就没了**。罕见的死挂抓到一次
# 不能因为后来一次插拔/断电而丢掉，所以开机第一件事就把记录拷到 /var/log/pstore。

PSTORE=${PSTORE:-/sys/fs/pstore}
KEEP=${KEEP:-/var/log/pstore}

mkdir -p "$PSTORE" "$KEEP"
if ! mountpoint -q "$PSTORE"; then
	mount -t pstore pstore "$PSTORE" || { echo "pstore mount failed" >&2; exit 1; }
fi
n=0
for f in "$PSTORE"/*; do
	[ -e "$f" ] || continue
	b=$(basename "$f")
	install -m 0644 "$f" "$KEEP/$(date +%Y%m%d-%H%M%S)-$b" && { echo "archived $b"; n=$((n + 1)); }
done
[ "$n" = 0 ] && echo "pstore empty (no previous crash)"
# 只留最近 10 份，别把 /var 撑爆
ls -1t "$KEEP" 2>/dev/null | tail -n +11 | while read -r x; do rm -f "$KEEP/$x"; done
exit 0
