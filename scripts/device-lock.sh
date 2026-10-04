#!/bin/bash
# device-lock.sh — serialize exclusive access to the tablet across concurrent agents.
#
# The device is a single serial resource: two agents running mod-loop / kexec /
# fastboot at once produce garbage (interleaved rmmod, half-copied modules,
# two kernels loading).  Everything that touches the device must hold this lock.
#
# usage:
#   scripts/device-lock.sh <command...>          # run under the lock
#   scripts/device-lock.sh -w 900 <command...>   # wait up to 900s
#   scripts/device-lock.sh --status              # who holds it / is it free
#
# Env: TAB (default root@192.168.7.1), LOCK_WAIT (default 300s).
#
# To hold the lock for a whole agent turn, prefix the command:
#   scripts/device-lock.sh bash -c 'modprobe x; dmesg > /tmp/e'
# Scripts mod-loop.sh / kexec-boot.sh / to-fastboot.sh already self-lock, so
# they compose safely without an outer wrapper.
set -euo pipefail
TAB=${TAB:-root@192.168.7.1}
LOCK=${DEVICE_LOCK:-/tmp/elden-device-$(echo "$TAB" | tr -c 'A-Za-z0-9' '_').lock}
WAIT=${LOCK_WAIT:-300}

case "${1:-}" in
	--status)
		if flock -n "$LOCK" true 2>/dev/null; then echo "free ($LOCK)"; else
			echo "BUSY ($LOCK)"; [ -f "$LOCK" ] && cat "$LOCK" 2>/dev/null || true
		fi
		exit 0 ;;
	-w) WAIT=$2; shift 2 ;;
	-h|--help) sed -n '2,20p' "$0"; exit 0 ;;
	"") echo "usage: device-lock.sh [-w sec] <command...>" >&2; exit 2 ;;
esac

# Advertise the holder for --status (best effort, informational).
printf 'holder pid=%s cmd=%s\n' "$$" "$*" > "$LOCK" 2>/dev/null || true

exec 9>>"$LOCK"
if ! flock -w "$WAIT" 9; then
	echo "[lock] device busy >${WAIT}s ($LOCK) — another agent holds it" >&2
	exit 1
fi
echo "[lock] acquired ($LOCK)"
export DEVICE_LOCK_HELD=1
"$@"
