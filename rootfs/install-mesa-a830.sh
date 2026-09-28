#!/bin/bash
# Install the cross-built Mesa 26.1.6 into a target root and point the desktop
# at it.
#
# Only the Mesa payload is kept: the build also stages libarchive/libxml2 and
# the bsdtar/xmllint helpers pulled in as meson subprojects, which would
# shadow the distro copies if they landed in the runtime library path.
set -euo pipefail

STAGE=${STAGE:-/home/xuqianhui1001/y700-elden/out/mesa-build/stage/opt/mesa-a830}
R=${1:-/mnt/rootfs}
PREFIX=$R/opt/mesa-a830
LIB=lib/aarch64-linux-gnu

test -d "$STAGE"

echo "== installing payload"
rm -rf "$PREFIX"
install -d "$PREFIX/$LIB/dri" "$PREFIX/$LIB/gbm" \
	"$PREFIX/share/vulkan/icd.d" "$PREFIX/share/glvnd/egl_vendor.d" \
	"$PREFIX/runtime"

cp -a "$STAGE/$LIB"/libEGL.so* "$STAGE/$LIB"/libGL.so* \
      "$STAGE/$LIB"/libGLESv2.so* "$STAGE/$LIB"/libgbm.so* \
      "$STAGE/$LIB"/libgallium-*.so "$STAGE/$LIB"/libvulkan_freedreno.so \
      "$PREFIX/$LIB/"
cp -a "$STAGE/$LIB/dri/." "$PREFIX/$LIB/dri/"
cp -a "$STAGE/$LIB/gbm/." "$PREFIX/$LIB/gbm/"
cp -a "$STAGE/share/vulkan/icd.d/." "$PREFIX/share/vulkan/icd.d/"
[ -d "$STAGE/share/glvnd/egl_vendor.d" ] && \
	cp -a "$STAGE/share/glvnd/egl_vendor.d/." "$PREFIX/share/glvnd/egl_vendor.d/"

# Mesa is built without an RPATH, so everything the GL/EGL/GBM libraries pull
# in has to be reachable through LD_LIBRARY_PATH - libgallium included.
for so in libEGL.so.1 libGL.so.1 libGLESv2.so.2 libgbm.so.1 libgallium-26.1.6.so; do
	[ -e "$PREFIX/$LIB/$so" ] && ln -sfn "../$LIB/$so" "$PREFIX/runtime/$so"
done

echo "== egl vendor json"
if [ ! -e "$PREFIX/share/glvnd/egl_vendor.d/50_mesa.json" ]; then
	cat > "$PREFIX/share/glvnd/egl_vendor.d/50_mesa.json" <<EOF
{
    "file_format_version" : "1.0.0",
    "ICD" : {
        "library_path" : "/opt/mesa-a830/$LIB/libEGL.so.1"
    }
}
EOF
fi

echo "== session environment"
cat > "$R/etc/environment" <<EOF
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin"
LD_LIBRARY_PATH="/opt/mesa-a830/runtime"
LIBGL_DRIVERS_PATH="/opt/mesa-a830/$LIB/dri"
GBM_BACKENDS_PATH="/opt/mesa-a830/$LIB/gbm"
__EGL_VENDOR_LIBRARY_FILENAMES="/opt/mesa-a830/share/glvnd/egl_vendor.d/50_mesa.json"
VK_DRIVER_FILES="/opt/mesa-a830/share/vulkan/icd.d/freedreno_icd.aarch64.json"
GDK_SCALE=2
QT_SCALE_FACTOR=2
EOF

echo "== gdm drop-in"
install -d -m 755 "$R/etc/systemd/system/gdm.service.d" \
	"$R/etc/systemd/system/gdm3.service.d"
for d in gdm gdm3; do
	cat > "$R/etc/systemd/system/$d.service.d/50-mesa-a830.conf" <<EOF
[Service]
Environment="LD_LIBRARY_PATH=/opt/mesa-a830/runtime"
Environment="LIBGL_DRIVERS_PATH=/opt/mesa-a830/$LIB/dri"
Environment="GBM_BACKENDS_PATH=/opt/mesa-a830/$LIB/gbm"
Environment="__EGL_VENDOR_LIBRARY_FILENAMES=/opt/mesa-a830/share/glvnd/egl_vendor.d/50_mesa.json"
Environment="VK_DRIVER_FILES=/opt/mesa-a830/share/vulkan/icd.d/freedreno_icd.aarch64.json"
UnsetEnvironment=LIBGL_ALWAYS_SOFTWARE
EOF
done

echo "== result"
du -sh "$PREFIX"
ls "$PREFIX/$LIB/" | head
cat "$R/etc/environment"
