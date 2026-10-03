#!/bin/sh
# glycin-bwrap-shim.sh — let glycin run its image loaders without the bwrap sandbox.
#
# Why: gdk-pixbuf 2.44 loads PNG/SVG through glycin, which runs the loader inside a
# bwrap sandbox. On TB322FC the sandboxed loader exits 1, gdk-pixbuf aborts on the
# gtkiconhelper assertion and the GTK app (phosh) dies. glycin decides the sandbox
# is unavailable when `bwrap` returns SIGSYS or prints one of a few known
# namespace-failure strings on stderr (see glycin/src/sandbox.rs,
# check_bwrap_syscalls_blocked); it then runs the loader directly and prints
# "WARNING: Glycin running without sandbox."
#
# This script installs a tiny shim in front of bwrap so that detection succeeds.
# The real bubblewrap binary (if any) is preserved as bwrap.real. The same logic is
# applied automatically by the initramfs /init (see rootfs/alpine/init) before
# switch_root, so running this by hand is only needed for images without that init.
#
# usage: glycin-bwrap-shim.sh [apply|revert|status]
set -eu

SHIM_MARK="elden-glycin-shim"

write_shim() {
	cat > "$1" <<'EOF'
#!/bin/sh
# elden-glycin-shim: make glycin's bwrap self-test look blocked so glycin runs
# image loaders without sandboxing (fixes the phosh/gdk-pixbuf abort).
echo "bwrap: Creating new namespace failed: Operation not permitted" >&2
exit 1
EOF
	chmod 755 "$1"
}

apply_one() {
	if [ -e "$1" ] && grep -q "$SHIM_MARK" "$1" 2>/dev/null; then
		return 0
	fi
	if [ -e "$1" ] && [ ! -e "$1.real" ]; then
		cp -a "$1" "$1.real"
	fi
	write_shim "$1"
	if [ -e "$1.real" ]; then
		echo "[shim] installed $1 (real bwrap kept as bwrap.real)"
	else
		echo "[shim] installed $1"
	fi
}

revert_one() {
	if [ -e "$1.real" ]; then
		mv -f "$1.real" "$1"
		echo "[shim] restored $1 from bwrap.real"
	elif grep -q "$SHIM_MARK" "$1" 2>/dev/null; then
		rm -f "$1"
		echo "[shim] removed $1 (no bwrap.real to restore)"
	fi
}

cmd=${1:-status}
case "$cmd" in apply|revert|status) ;; *) echo "usage: $0 apply|revert|status" >&2; exit 2 ;; esac

for f in /usr/local/bin/bwrap /usr/bin/bwrap; do
	[ -d "$(dirname "$f")" ] || continue
	case "$cmd" in
		apply)  apply_one "$f" ;;
		revert) revert_one "$f" ;;
		status)
			if [ -e "$f" ] && grep -q "$SHIM_MARK" "$f" 2>/dev/null; then
				echo "$f: SHIM active"
			elif [ -e "$f" ]; then
				echo "$f: real bwrap"
			else
				echo "$f: absent"
			fi
			;;
	esac
done
