#!/bin/bash
# build-arm64-deb.sh — cross-build patched iio-sensor-proxy 3.9 for Debian trixie arm64
#                      and assemble a dpkg-installable .deb. Host-side only, no root, no chroot.
#
# Usage: bash build-arm64-deb.sh [work-dir]      (default /tmp/iio-patch-20261128)
#   env overrides: SRC_TREE  (pristine 3.9 git checkout, default /tmp/ssc-prep/iio-sensor-proxy)
#                  SYSROOT   (trixie arm64 sysroot, default <repo>/out/sysroot-trixie-arm64)
#                  EXTRA_SYSROOT (trixie arm64 sysroot that carries libssc/polkit, default
#                                 /tmp/ssc-prep/sysroot-work/sysroot)
#                  JOBS      (default 8)
#
# Why the overlay: the in-repo sysroot has no libssc/polkit-gobject-1/udev.pc (trixie ships no
# libssc at all), so a symlink farm of the in-repo sysroot is created in the work dir and the
# three packages are overlaid from EXTRA_SYSROOT (same distro/arch, so ABI is unchanged).
# The link step additionally needs -Wl,--allow-shlib-undefined: libssc.so -> libqmi-glib.so.5 ->
# libmbim-glib.so.4 must resolve on the device at run time, they are not in the sysroot.
#
# Rebuild of the deb is byte-comparable to the one in artifacts/ apart from BuildID/timestamps.
set -euo pipefail

SELF="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$SELF/../.." && pwd)"
WORK="${1:-/tmp/iio-patch-20261128}"
SRC_TREE="${SRC_TREE:-/tmp/ssc-prep/iio-sensor-proxy}"
SYSROOT="${SYSROOT:-$REPO/out/sysroot-trixie-arm64}"
EXTRA_SYSROOT="${EXTRA_SYSROOT:-/tmp/ssc-prep/sysroot-work/sysroot}"
JOBS="${JOBS:-8}"
VERSION="3.9-3elden"
TAG="3.9"

[ -d "$SRC_TREE/.git" ] || { echo "!! no git checkout at $SRC_TREE (clone tag $TAG first)" >&2; exit 1; }
[ -d "$SYSROOT/usr/lib/aarch64-linux-gnu" ] || { echo "!! bad SYSROOT: $SYSROOT" >&2; exit 1; }
[ -d "$EXTRA_SYSROOT/usr/lib/aarch64-linux-gnu" ] || { echo "!! bad EXTRA_SYSROOT: $EXTRA_SYSROOT" >&2; exit 1; }

mkdir -p "$WORK"
cd "$WORK"

echo "=== 1/6 source: $SRC_TREE @ tag $TAG + patches"
rm -rf src srctmp
mkdir srctmp
git -C "$SRC_TREE" archive --format=tar "$TAG" | tar -x -C srctmp
mv srctmp src
[ -f src/meson.build ] || { echo "!! source extraction failed" >&2; exit 1; }
for p in "$SELF"/0001-*.patch "$SELF"/0002-*.patch "$SELF"/0003-*.patch; do
	echo "  apply $(basename "$p")"
	patch -p1 -d src -s <"$p"
done

echo "=== 2/6 merged sysroot (symlink farm of $SYSROOT + overlay from $EXTRA_SYSROOT)"
rm -rf sysroot
mkdir -p sysroot
cp -as "$SYSROOT/." sysroot/
L=sysroot/usr/lib/aarch64-linux-gnu          # inside the merged sysroot
X="$EXTRA_SYSROOT/usr/lib/aarch64-linux-gnu"  # inside the source sysroot
mkdir -p "$L/pkgconfig" sysroot/usr/include/libssc
cp -a "$EXTRA_SYSROOT/usr/include/libssc/." sysroot/usr/include/libssc/
cp -a "$EXTRA_SYSROOT/usr/include/polkit-1" sysroot/usr/include/
cp -a "$X"/libssc.so* "$X"/libpolkit-gobject-1.so* "$X"/libqmi-glib.so.5* \
      "$X"/libprotobuf-c.so.1* "$X"/libqrtr-glib.so.0* "$L/"
for l in libqmi-glib.so.5 libprotobuf-c.so.1 libqrtr-glib.so.0; do ln -sf "$l" "$L/${l%.so*}.so"; done
cp -a "$X/pkgconfig/polkit-gobject-1.pc" "$L/pkgconfig/"
# libssc.pc: drop the Requires on qmi-glib/qrtr/protobuf-c (libssc-internal, not needed to link
# the proxy) and name their -l flags explicitly so the link resolves without --copy-dt-needed.
sed -e 's|^Requires:.*|Requires: glib-2.0, gobject-2.0, gio-2.0|' \
    -e 's|^Libs: -L${libdir} -lssc|Libs: -L${libdir} -lssc -lqmi-glib -lprotobuf-c -lqrtr-glib|' \
    "$X/pkgconfig/libssc.pc" >"$L/pkgconfig/libssc.pc"

echo "=== 3/6 meson setup (cross)"
cat >"$WORK/cross-aarch64-trixie.ini" <<EOF
[binaries]
c = 'aarch64-linux-gnu-gcc'
cpp = 'aarch64-linux-gnu-g++'
ar = 'aarch64-linux-gnu-ar'
strip = 'aarch64-linux-gnu-strip'
objcopy = 'aarch64-linux-gnu-objcopy'
ld = 'aarch64-linux-gnu-ld'
pkgconfig = 'pkg-config'
exe_wrapper = ''

[host_machine]
system = 'linux'
cpu_family = 'aarch64'
cpu = 'aarch64'
endian = 'little'

[properties]
needs_exe_wrapper = true
sys_root = '$WORK/sysroot'
pkg_config_libdir = '$WORK/sysroot/usr/lib/aarch64-linux-gnu/pkgconfig:$WORK/sysroot/usr/share/pkgconfig'
EOF
rm -rf build
timeout -k 10 300 meson setup build src \
	--cross-file cross-aarch64-trixie.ini \
	--prefix=/usr --libdir=lib/aarch64-linux-gnu --buildtype=release \
	-Dssc-support=enabled -Dtests=false -Dgtk-tests=false \
	-Dudevrulesdir=/usr/lib/udev/rules.d -Dsystemdsystemunitdir=/usr/lib/systemd/system \
	-Dc_link_args="-Wl,--allow-shlib-undefined"

echo "=== 4/6 compile (-j$JOBS)"
timeout -k 10 600 meson compile -C build -j "$JOBS"

echo "=== 5/6 stage + assemble $VERSION deb"
rm -rf stage debbuild
timeout -k 10 300 meson install -C build --destdir "$WORK/stage" >/dev/null
D="debbuild/iio-sensor-proxy"
mkdir -p "$D/DEBIAN" "$D/usr/libexec" "$D/usr/share/polkit-1/actions" "$D/usr/share/lintian/overrides"
cp -a stage/usr/libexec/iio-sensor-proxy "$D/usr/libexec/"
mkdir -p "$D/usr/bin" "$D/usr/share/dbus-1/system.d" "$D/usr/lib/udev/rules.d" "$D/usr/lib/systemd/system"
cp -a stage/usr/bin/monitor-sensor "$D/usr/bin/"
cp -a stage/usr/share/dbus-1/system.d/net.hadess.SensorProxy.conf "$D/usr/share/dbus-1/system.d/"
cp -a stage/usr/lib/udev/rules.d/80-iio-sensor-proxy.rules "$D/usr/lib/udev/rules.d/"
cp -a stage/usr/lib/systemd/system/iio-sensor-proxy.service "$D/usr/lib/systemd/system/"
# meson resolves the polkit policydir through the sysroot; keep the packaged path canonical
cp -a "stage$WORK/sysroot/usr/share/polkit-1/actions/net.hadess.SensorProxy.policy" \
      "$D/usr/share/polkit-1/actions/"
printf '%s\n' 'iio-sensor-proxy: binary-without-manpage usr/bin/monitor-sensor' \
	> "$D/usr/share/lintian/overrides/iio-sensor-proxy"
cat >"$D/DEBIAN/control" <<EOF
Package: iio-sensor-proxy
Version: $VERSION
Architecture: arm64
Maintainer: y700-elden local build <nobody@localhost>
Installed-Size: $(du -sk "$D/usr" | cut -f1)
Depends: libc6 (>= 2.38), libglib2.0-0t64 (>= 2.68.0), libgudev-1.0-0 (>= 234), libpolkit-gobject-1-0 (>= 0.99), libssc2 (>= 0.4.2)
Section: utils
Priority: optional
Homepage: https://gitlab.freedesktop.org/hadess/iio-sensor-proxy
Description: IIO sensors to D-Bus proxy (local cross build, elden patches)
 Upstream 3.9 plus three local patches: Claim() deferral until sensor
 discovery finished, rate limiting of LightLevel reports, and median+EMA
 smoothing with a stronger hysteresis on top of it.
 Built for Debian trixie arm64 from tag $TAG.
EOF
cat >"$D/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if command -v udevadm >/dev/null; then udevadm control --reload || true; fi
if command -v systemctl >/dev/null && [ -d /run/systemd/system ]; then systemctl daemon-reload || true; fi
exit 0
EOF
chmod 0755 "$D/DEBIAN/postinst"
mkdir -p artifacts
dpkg-deb --root-owner-group -b "$D" "artifacts/iio-sensor-proxy_${VERSION}_arm64.deb" >/dev/null

echo "=== 6/6 ABI + artifact check"
B="$WORK/build/src/iio-sensor-proxy"
timeout -k 3 20 file "$B"
echo "-- max GLIBC symbol version:"; timeout -k 3 20 aarch64-linux-gnu-objdump -T "$B" \
	| grep -o 'GLIBC_[0-9.]*' | sort -uV | tail -3
echo "-- NEEDED:"; timeout -k 3 20 aarch64-linux-gnu-objdump -p "$B" | grep NEEDED
echo "-- artifact:"; sha256sum "artifacts/iio-sensor-proxy_${VERSION}_arm64.deb"
echo "-- content:"; dpkg-deb -c "artifacts/iio-sensor-proxy_${VERSION}_arm64.deb" | awk '{print $6}'
