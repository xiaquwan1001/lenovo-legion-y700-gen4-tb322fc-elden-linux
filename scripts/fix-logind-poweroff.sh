#!/bin/sh
# fix-logind-poweroff.sh — make logind's Power Off / Restart helpers actually
# reach the kernel reboot(2) syscall on the TB322FC mainline rootfs.
#
# WHY (root cause, 2026-10-03):
#   elogind executes the compile-time helpers /sbin/{poweroff,reboot,halt}
#   (meson `poweroff-path`, absolute path — PATH is irrelevant).
#   Alpine ships those as busybox applet symlinks.  Busybox *without -f* does
#   NOT call reboot(2); it delegates to a sysvinit/busybox-init daemon by
#   signalling PID 1 (poweroff->SIGUSR2, reboot->SIGTERM, halt->SIGUSR1) and
#   exits 0.  On this device PID 1 is /init, a plain `sh` script that does not
#   implement that protocol, so the signal is ignored and the machine never
#   powers off.  elogind then logs "Operation 'poweroff' finished." and — for
#   non-sleep actions it never resets its internal action_job/delayed_action —
#   permanently wedges: every later PowerOff/PrepareForSleep returns
#   "org.freedesktop.login1.OperationInProgress".
#
# FIX: replace the three applet symlinks with tiny wrappers that pass -f, so
#   busybox calls reboot(LINUX_REBOOT_CMD_*) directly (verified via strace
#   fault injection: reboot(...POWER_OFF/RESTART/HALT)).
#
# Idempotent; called from start-desktop.sh before elogind is started.  A
# freshly rebuilt rootfs needs this again (persistent root is /dev/sda17).
set -e

[ "$(id -u)" = 0 ] || { echo "fix-logind-poweroff: must be root" >&2; exit 1; }

for a in poweroff reboot halt; do
	f="/sbin/$a"
	# Already our wrapper?  leave it.
	if [ -f "$f" ] && head -1 "$f" 2>/dev/null | grep -q busybox; then
		continue
	fi
	# Preserve the original (busybox applet symlink) once.
	if [ -L "$f" ] && [ ! -e "$f.orig" ]; then
		ln -s "$(readlink "$f")" "$f.orig"
	fi
	# NB: writing through the symlink would truncate /bin/busybox itself
	# ("Text file busy"); remove the link first.
	rm -f "$f"
	printf '#!/bin/sh\nexec /bin/busybox %s -f "$@"\n' "$a" > "$f"
	chmod 755 "$f"
done
