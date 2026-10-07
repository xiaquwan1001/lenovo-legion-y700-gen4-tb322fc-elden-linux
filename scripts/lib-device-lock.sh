# lib-device-lock.sh — the SINGLE source of the tablet device lock.
#
# Source this and call device_lock_acquire() instead of copy-pasting the flock
# block into every device-touching script (the old pattern; see audit
# .pi/plans/2026-10-07-造轮子审计.md §1.2).
#
# Usage:
#   . "$(dirname "$0")/lib-device-lock.sh"   # from scripts/*.sh
#   . "$(dirname "$0")/scripts/lib-device-lock.sh"   # from root-level scripts
#   device_lock_acquire
#
# Env:
#   TAB / TABLET   ssh target (default root@192.168.7.1); TAB wins
#   DEVICE_LOCK    lock file path (default /tmp/elden-device-<tab>.lock)
#   LOCK_WAIT      seconds to wait for the lock (default 300)
#   DEVICE_LOCK_HELD=1  set by this function; nested callers skip re-locking
#
# The lock is held for the life of the calling shell (fd 9), so every child
# (ssh/fastboot/…) inherits it.
device_lock_acquire() {
	[ "${DEVICE_LOCK_HELD:-0}" = 1 ] && return 0
	_dl_tab=${TAB:-${TABLET:-root@192.168.7.1}}
	_dl_lock=${DEVICE_LOCK:-/tmp/elden-device-$(printf '%s' "$_dl_tab" | tr -c 'A-Za-z0-9' '_').lock}
	exec 9>>"$_dl_lock"
	flock -w "${LOCK_WAIT:-300}" 9 || {
		echo "[lock] device busy — another agent holds it" >&2
		exit 1
	}
	DEVICE_LOCK_HELD=1
	export DEVICE_LOCK_HELD
}
