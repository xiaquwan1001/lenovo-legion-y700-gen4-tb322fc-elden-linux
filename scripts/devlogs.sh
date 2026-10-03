#!/usr/bin/env bash
# devlogs.sh — runtime log capture for feature bring-up/verification.
#
# Channels available on this device (2026-10-03):
#   * kernel printk -> ttyGS0 (USB ACM0 on host) + tty0  => host serial capture
#   * ramoops/pstore (reserved 4 MiB, console_size 2 MiB) => survives a hard reset
#   * userspace: /run/{phosh,elogind,seatd,dbus,sshd}.log, /var/log/kmsg-*.log
#
# Usage (run on the host):
#   scripts/devlogs.sh pull [tag]     collect a device snapshot -> logs/devlogs-<tag>-<ts>/
#   scripts/devlogs.sh pstore         show ramoops/pstore records (post-reset crash log)
#   scripts/devlogs.sh tail           live-follow device dmesg
#   scripts/devlogs.sh serial [secs]  capture host serial console (ttyACM0); 0 = until killed
#   scripts/devlogs.sh watch [secs] [interval]  repeatedly `pull` to catch a transient event
#
# Env: TAB=root@192.168.7.1
set -u
cd "$(dirname "$0")/.."
TAB="${TAB:-root@192.168.7.1}"
SSH=(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$TAB")
mkdir -p logs

# One remote invocation that prints an annotated snapshot.  Kept as a single
# SSH call so the whole snapshot is consistent (and to avoid SSH churn).
_remote_snapshot() {
	"${SSH[@]}" 'sh -s' <<'EOS'
echo "### date"; date
echo "### uname"; uname -a
echo "### uptime"; uptime
echo "### boot_id"; cat /proc/sys/kernel/random/boot_id
echo "### cmdline"; cat /proc/cmdline
echo "### power/state"; cat /sys/power/state 2>/dev/null; echo
 echo "### power/mem_sleep"; cat /sys/power/mem_sleep 2>/dev/null; echo
echo "### dmesg"; dmesg
for f in /run/*.log; do [ -f "$f" ] || continue; echo "### $f"; cat "$f"; done
for f in /var/log/kmsg-*.log /var/log/*.log; do [ -f "$f" ] || continue; echo "### $f"; cat "$f"; done
echo "### pstore"; ls -la /sys/fs/pstore 2>/dev/null
for f in /sys/fs/pstore/*; do [ -f "$f" ] || continue; echo "### pstore:$f"; cat "$f"; done
EOS
}

cmd_pull() {
	local tag="${1:-manual}" ts out
	ts="$(date +%Y%m%d-%H%M%S)"
	out="logs/devlogs-${tag}-${ts}"
	mkdir -p "$out"
	echo "[devlogs] -> $out"
	if ! _remote_snapshot >"$out/device-snapshot.txt" 2>"$out/ssh.err"; then
		echo "[devlogs] SSH snapshot failed:"; cat "$out/ssh.err" >&2; return 1
	fi
	# Split out the big ones for convenience.
	awk '/^### dmesg$/{f=1;next} /^### /{f=0} f' "$out/device-snapshot.txt" >"$out/dmesg.txt"
	grep -E '^### (uname|uptime|boot_id|power/state|power/mem_sleep)$' -A1 "$out/device-snapshot.txt" >"$out/summary.txt"
	# Raw phosh/elogind, extracted from the snapshot.
	sed -n '/^### \/run\/phosh\.log$/,/^### \/run\//p' "$out/device-snapshot.txt" | sed '$d' >"$out/phosh.log"
	sed -n '/^### \/run\/elogind\.log$/,/^### \/run\//p' "$out/device-snapshot.txt" | sed '$d' >"$out/elogind.log"
	printf 'boot_id:  '; sed -n '/^### boot_id$/{n;p}' "$out/summary.txt"
	printf 'dmesg:    '; wc -l <"$out/dmesg.txt"; printf 'phosh:    '; wc -l <"$out/phosh.log"
}

cmd_pstore() {
	echo "== /sys/fs/pstore on $TAB =="
	"${SSH[@]}" 'ls -la /sys/fs/pstore; for f in /sys/fs/pstore/*; do [ -f "$f" ] || continue; echo "===== $f"; cat "$f"; done'
}

cmd_tail() {
	exec "${SSH[@]}" 'dmesg -w'
}

cmd_serial() {
	local secs="${1:-0}"
	exec scripts/serial-log.sh "$secs"
}

cmd_watch() {
	local secs="${1:-120}" interval="${2:-10}" end tag
	local b0 b1
	b0="$("${SSH[@]}" cat /proc/sys/kernel/random/boot_id 2>/dev/null)"
	echo "[watch] boot_id=$b0 for ${secs}s, pull every ${interval}s"
	end=$(( $(date +%s) + secs ))
	while [ "$(date +%s)" -lt "$end" ]; do
		cmd_pull "watch" || true
		sleep "$interval"
		b1="$("${SSH[@]}" cat /proc/sys/kernel/random/boot_id 2>/dev/null)"
		[ "$b1" != "$b0" ] && { echo "[watch] RESET detected: $b0 -> $b1"; b0="$b1"; }
	done
}

case "${1:-}" in
	pull)   shift; cmd_pull "${1:-manual}" ;;
	pstore) shift; cmd_pstore ;;
	tail)   shift; cmd_tail ;;
	serial) shift; cmd_serial "${1:-0}" ;;
	watch)  shift; cmd_watch "${1:-120}" "${2:-10}" ;;
	*) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
