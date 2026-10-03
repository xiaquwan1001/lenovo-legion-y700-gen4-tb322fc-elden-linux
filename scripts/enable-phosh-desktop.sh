#!/bin/sh
# enable-phosh-desktop.sh — make Phosh the on-boot desktop on the TB322FC
# persistent root (/dev/sde79). Idempotent. Run ON THE DEVICE (or over ssh):
#
#   # first copy the mesa-gl package over (one of these):
#   scp pkgs-phosh/mesa-gl-*.apk root@192.168.7.1:/tmp/
#   # then:
#   ssh root@192.168.7.1 'MESA_GL_APK=/tmp/mesa-gl-26.1.6-r0.apk sh /tmp/enable-phosh-desktop.sh'
#
# What it fixes (see HANDOFF §22.7 / §22.8):
#   1. gdk-pixbuf 2.44 loads images via glycin; glycin's bwrap sandbox aborts the
#      loader -> GTK apps (phosh) die. glyphin falls back to NotSandboxed when its
#      bwrap self-test looks blocked, so install the bwrap shim.
#   2. gnome-session's acceleration check needs libGL.so.1; the mesa-gl package was
#      marked installed but its files were missing -> the check aborts and the
#      session never starts the shell. Restore libGL from the apk.
#   3. Phosh's lock screen asks for a PIN by default (sm.puri.phosh.lockscreen
#      require-unlock=true). We have no PAM config on this image, so no PIN can
#      ever succeed -> set require-unlock=false via a schema override.
#   4. gnome-session treats org.gnome.SettingsDaemon.Power as a required component;
#      it fails without UPower/logind -> fail whale. Drop it from RequiredComponents.
#   5. Point the boot desktop at phosh instead of weston.
set -eu

MESA_GL_APK=${MESA_GL_APK:-/tmp/mesa-gl-26.1.6-r0.apk}
SELF_DIR=$(dirname "$0")

echo "== 1. glycin bwrap shim"
if command -v glycin-bwrap-shim.sh >/dev/null 2>&1; then
	glycin-bwrap-shim.sh apply
elif [ -x "$SELF_DIR/glycin-bwrap-shim.sh" ]; then
	"$SELF_DIR/glycin-bwrap-shim.sh" apply
else
	for f in /usr/local/bin/bwrap /usr/bin/bwrap; do
		[ -e "$f" ] && grep -q elden-glycin-shim "$f" 2>/dev/null && continue
		[ -e "$f" ] && [ ! -e "$f.real" ] && cp -a "$f" "$f.real"
		cat > "$f" <<'EOF'
#!/bin/sh
# elden-glycin-shim: make glycin's bwrap self-test look blocked so glycin runs
# image loaders without sandboxing (fixes the phosh/gdk-pixbuf abort).
echo "bwrap: Creating new namespace failed: Operation not permitted" >&2
exit 1
EOF
		chmod 755 "$f"
		echo "   installed shim $f"
	done
fi

echo "== 2. libGL (mesa-gl)"
if [ -e /usr/lib/libGL.so.1 ]; then
	echo "   libGL.so.1 already present"
else
	[ -f "$MESA_GL_APK" ] || { echo "ERROR: $MESA_GL_APK missing (copy pkgs-phosh/mesa-gl-*.apk)" >&2; exit 1; }
	tar -xzf "$MESA_GL_APK" -C /
	echo "   extracted $(basename "$MESA_GL_APK")"
fi

echo "== 3. lockscreen: no PIN by default"
cat > /usr/share/glib-2.0/schemas/99_elden.gschema.override <<'EOF'
[sm.puri.phosh.lockscreen]
require-unlock=false
shuffle-keypad=false
EOF
glib-compile-schemas /usr/share/glib-2.0/schemas/ 2>/dev/null || true

echo "== 4. drop SettingsDaemon.Power from required components"
S=/usr/share/gnome-session/sessions/phosh.session
[ -f "$S" ] || { echo "ERROR: $S not found" >&2; exit 1; }
[ -f "$S.orig" ] || cp -a "$S" "$S.orig"
sed -i 's/org\.gnome\.SettingsDaemon\.Power;//' "$S"

echo "== 5. install boot desktop = phosh"
if [ -f "$SELF_DIR/start-desktop.sh" ]; then
	install -m 755 "$SELF_DIR/start-desktop.sh" /usr/local/sbin/start-desktop.sh
	echo "   installed start-desktop.sh from $SELF_DIR"
elif [ -f /tmp/start-desktop.sh ]; then
	install -m 755 /tmp/start-desktop.sh /usr/local/sbin/start-desktop.sh
	echo "   installed start-desktop.sh from /tmp"
else
	echo "ERROR: start-desktop.sh not found next to this script or /tmp" >&2
	exit 1
fi

echo "== done. Reboot to verify (fastboot boot out/boot-elden-vk11.img)."
