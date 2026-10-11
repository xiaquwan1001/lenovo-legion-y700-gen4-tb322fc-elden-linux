#!/bin/sh
# Build the patched phoc + phosh and install them into the running persistent
# root, together with the auto-rotation quick-setting plugin.  Idempotent
# (marker file); safe to re-run.
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
MARKVAL="phoc-0.55.1+phosh-0.55.0+display2"
PLUGIN=auto-rotation-quick-setting
PLUGDIR=/usr/lib/phosh/plugins

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
PLUGIN_SO="$PHOSH_BUILD/plugins/$PLUGIN/libphosh-plugin-$PLUGIN.so"
PLUGIN_DESK="$PHOSH_BUILD/plugins/$PLUGIN/$PLUGIN.plugin"
[ -f "$PLUGIN_SO" ]   || { echo "[userland-display] missing $PLUGIN_SO" >&2; exit 1; }
[ -f "$PLUGIN_DESK" ] || { echo "[userland-display] missing $PLUGIN_DESK" >&2; exit 1; }

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

echo "[userland-display] installing binaries + plugin"
cp "$WORK/phoc-0.55.1/output/src/phoc"   /usr/bin/phoc
cp "$PHOSH_BUILD/src/phosh"              /usr/libexec/phosh
chmod 755 /usr/bin/phoc /usr/libexec/phosh

install -d "$PLUGDIR"
install -m 0644 "$PLUGIN_DESK" "$PLUGDIR/$PLUGIN.plugin"
install -m 0755 "$PLUGIN_SO"   "$PLUGDIR/libphosh-plugin-$PLUGIN.so"

echo "[userland-display] enabling the plugin for the session user"
# Derive the session user from greetd's config, then write the dconf key with a
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
*"$PLUGIN"*) new="$cur" ;;
"@as []"|"[]"|"") new="['$PLUGIN']" ;;
*) new="${cur%]}, '$PLUGIN']" ;;
esac
run_as_user gsettings set $SCHEMA $KEY "\"$new\"" 2>/dev/null \
	|| echo "[userland-display] WARN: could not enable plugin; add it in the quick-settings editor"

if [ "$START" = 1 ]; then rc-service greetd start; fi

mkdir -p "$(dirname "$MARK")"
echo "$MARKVAL" > "$MARK"
echo "[userland-display] done ($MARKVAL).  rollback:"
echo "  cp $WORK/backup/phoc.0.55.1.orig  /usr/bin/phoc"
echo "  cp $WORK/backup/phosh.0.55.0.orig /usr/libexec/phosh"
echo "  rm $PLUGDIR/libphosh-plugin-$PLUGIN.so $PLUGDIR/$PLUGIN.plugin"
