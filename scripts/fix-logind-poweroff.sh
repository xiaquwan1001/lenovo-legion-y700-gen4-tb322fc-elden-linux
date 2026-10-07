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
# FIX: replace the three applet symlinks with tiny wrappers.  Since
#   2026-10-06 the device can run native OpenRC with busybox init as PID 1
#   (`/etc/elden-init-mode=openrc`), which DOES implement the PID 1 signal
#   protocol -> a clean, non-force shutdown (services stopped, shift to the
#   shutdown runlevel) works.  Keep `-f` only for the legacy /init shell.
#
# Idempotent; called from start-desktop.sh before elogind is started.  A
# freshly rebuilt rootfs needs this again (persistent root is /dev/sda17).
set -e

[ "$(id -u)" = 0 ] || { echo "fix-logind-poweroff: must be root" >&2; exit 1; }

for a in poweroff reboot halt; do
	f="/sbin/$a"
	# Already our wrapper (current version)?  leave it.  The version tag is
	# `USERLAND-` (only present since the 2026-10-06 marker change).
	if [ -f "$f" ] && grep -q 'USERLAND-' "$f" 2>/dev/null; then
		continue
	fi
	# Preserve the original (busybox applet symlink) once.
	if [ -L "$f" ] && [ ! -e "$f.orig" ]; then
		ln -s "$(readlink "$f")" "$f.orig"
	fi
	# NB: writing through the symlink would truncate /bin/busybox itself
	# ("Text file busy"); remove the link first.
	rm -f "$f"
	cat > "$f" <<EOF
#!/bin/sh
# elden-powerwrap: clean shutdown under busybox init, -f under the legacy /init.
# Also records a durable marker: G1-22/Q24 must tell a *userland-initiated*
# shutdown from a hard reset (USB VBUS auto-powers-on, so "it rebooted" proves
# nothing).  Marker present after the event => userland; absent => kernel died.
printf 'USERLAND-%s %s uptime=%s boot_id=%s\n' "$a" "\$(date '+%F %T')" "\$(cut -d. -f1 /proc/uptime)" "\$(cat /proc/sys/kernel/random/boot_id 2>/dev/null)" >>/root/powerlog.txt 2>/dev/null
sync 2>/dev/null
if [ "\$(cat /etc/elden-init-mode 2>/dev/null)" = openrc ]; then
	exec /bin/busybox $a "\$@"
fi
exec /bin/busybox $a -f "\$@"
EOF
	chmod 755 "$f"
done
