#!/bin/sh
# Build the patched phoc + phosh and install them into the running persistent
# root.  Idempotent (marker file); safe to re-run.
#
# NOTE (2026-10-19): the auto-rotation quick-setting plugin (0003) is RETIRED.
# Phosh's built-in rotation quick setting already toggles orientation-lock, so the
# extra tile was a duplicate.  This script no longer builds or installs it.
#
# Run AS ROOT ON THE DEVICE:
#     sh install-on-device.sh
# Skip (used by restore.sh):  SKIP_USERLAND_DISPLAY=1
#
# Build deps are installed and KEPT (per project decision).  Original binaries
# are backed up under /root/build/backup/.
set -eu

DIR="$(cd "$(dirname "$0")" && pwd)"
WORK="${WORK:-/root/build}"
DEPS="$DIR/build-deps.txt"
MARK=/usr/local/share/elden/userland-display.marker
MARKVAL="phoc-0.55.1+phosh-0.55.0+display3-norot"

if [ "${SKIP_USERLAND_DISPLAY:-0}" = 1 ]; then
	echo "[userland-display] skipped (SKIP_USERLAND_DISPLAY=1)"
	exit 0
fi
if [ -f "$MARK" ] && [ "$(cat "$MARK" 2>/dev/null)" = "$MARKVAL" ]; then
	echo "[userland-display] already installed ($MARKVAL)"
	exit 0
fi

echo "[userland-display] installing build deps (kept)"
apk add --no-interactive $(grep -v '^#' "$DEPS" | tr '\n' ' ')

echo "[userland-display] building (this takes a few minutes)"
WORK="$WORK" sh "$DIR/build-phoc-phosh.sh" "$WORK" "$DIR"

PHOSH_BUILD="$WORK/phosh-0.55.0/output"

echo "[userland-display] backing up originals"
mkdir -p "$WORK/backup"
[ -f "$WORK/backup/phoc.0.55.1.orig" ]  || cp -p /usr/bin/phoc      "$WORK/backup/phoc.0.55.1.orig"
[ -f "$WORK/backup/phosh.0.55.0.orig" ] || cp -p /usr/libexec/phosh "$WORK/backup/phosh.0.55.0.orig"

# phoc holds its binary mapped; stop the session so we can replace it.
START=0
if rc-service greetd status >/dev/null 2>&1; then
	rc-service greetd stop
	sleep 2
	START=1
fi

echo "[userland-display] installing binaries"
cp "$WORK/phoc-0.55.1/output/src/phoc"   /usr/bin/phoc
cp "$PHOSH_BUILD/src/phosh"              /usr/libexec/phosh
chmod 755 /usr/bin/phoc /usr/libexec/phosh

# Remove the retired duplicate auto-rotation plugin if a previous install left it.
rm -f /usr/lib/phosh/plugins/libphosh-plugin-auto-rotation-quick-setting.so \
      /usr/lib/phosh/plugins/auto-rotation-quick-setting.plugin

echo "[userland-display] dropping the retired auto-rotation plugin from quick-settings"
# Derive the session user from greetd's config, then edit the dconf key with a
# private session bus (the real one may not be running yet).
SESS_USER=$(sed -n 's/^[[:space:]]*user[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' \
		/etc/greetd/config.toml 2>/dev/null | head -1)
[ -n "$SESS_USER" ] || SESS_USER=root
SESS_HOME=$(getent passwd "$SESS_USER" | cut -d: -f6)
[ -n "$SESS_HOME" ] || SESS_HOME=/root
SCHEMA=sm.puri.phosh.plugins
KEY=quick-settings

run_as_user() {
	su -s /bin/sh "$SESS_USER" -c "HOME='$SESS_HOME' dbus-run-session -- $*"
}

cur=$(run_as_user gsettings get $SCHEMA $KEY 2>/dev/null || echo "@as []")
case "$cur" in
*auto-rotation-quick-setting*)
	# Drop only our entry; keep whatever else the user had enabled.
	new=$(printf '%s' "$cur" | sed "s/'auto-rotation-quick-setting', \?//; s/, \?'auto-rotation-quick-setting'//")
	new=$(printf '%s' "$new" | sed "s/\[ *\]/@as []/")
	run_as_user gsettings set $SCHEMA $KEY "\"$new\"" 2>/dev/null \
		|| echo "[userland-display] WARN: could not update $SCHEMA $KEY (left as-is)"
	;;
esac

if [ "$START" = 1 ]; then rc-service greetd start; fi

mkdir -p "$(dirname "$MARK")"
echo "$MARKVAL" > "$MARK"
echo "[userland-display] done ($MARKVAL).  rollback:"
echo "  cp $WORK/backup/phoc.0.55.1.orig  /usr/bin/phoc"
echo "  cp $WORK/backup/phosh.0.55.0.orig /usr/libexec/phosh"

