#!/bin/sh
# Build the patched phoc + phosh and install them into the running persistent
# root.  Idempotent (marker file); safe to re-run.
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
MARKVAL="phoc-0.55.1+phosh-0.55.0+display1"

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
WORK="$WORK" PATCHES="$DIR" sh "$DIR/build-phoc-phosh.sh" "$WORK" "$DIR"

echo "[userland-display] installing binaries"
mkdir -p "$WORK/backup"
[ -f "$WORK/backup/phoc.0.55.1.orig" ]  || cp -p /usr/bin/phoc         "$WORK/backup/phoc.0.55.1.orig"
[ -f "$WORK/backup/phosh.0.55.0.orig" ] || cp -p /usr/libexec/phosh    "$WORK/backup/phosh.0.55.0.orig"

# phoc holds its binary mapped; stop the session so we can replace it.
if rc-service greetd status >/dev/null 2>&1; then
	rc-service greetd stop
	sleep 2
	START=1
fi
cp "$WORK/phoc-0.55.1/output/src/phoc"   /usr/bin/phoc
cp "$WORK/phosh-0.55.0/output/src/phosh" /usr/libexec/phosh
chmod 755 /usr/bin/phoc /usr/libexec/phosh
if [ "${START:-0}" = 1 ]; then rc-service greetd start; fi

mkdir -p "$(dirname "$MARK")"
echo "$MARKVAL" > "$MARK"
echo "[userland-display] done ($MARKVAL).  rollback:"
echo "  cp $WORK/backup/phoc.0.55.1.orig  /usr/bin/phoc"
echo "  cp $WORK/backup/phosh.0.55.0.orig /usr/libexec/phosh"
