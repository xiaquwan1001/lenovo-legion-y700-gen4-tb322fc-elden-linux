#!/bin/bash
# waydroid-camera-bake.sh — bake the self-built 64-bit external camera provider into
# Waydroid's vendor.img (TASKS C5 step ②).
#
# What goes in (all under /vendor):
#   bin/hw/android.hardware.camera.provider@2.4-external-service   (our 64-bit build)
#   lib64/hw/android.hardware.camera.provider@2.{4,5}-external.so    (our build)
#   lib64/hw/camera.device@3.{4,5,6}-external-impl.so                (our build)
#   lib64/camera.device@3.{2,3}-impl.so                              (64-bit donor, A13)
#   etc/init/android.hardware.camera.provider@2.4-external-service.rc
#   etc/permissions/android.hardware.camera.external.xml
#   etc/vintf/manifest.xml   → camera.provider 2.7(external) 改成 2.4+2.5(external)
#
# The image is 100% full upstream (PITFALLS #244) ⇒ grow it to 128 MiB first.
#
# usage: scripts/waydroid-camera-bake.sh [--build] [--no-push]
set -eu
cd "$(dirname "$0")/.."
W=dl-cam
TAB=${TAB:-root@192.168.7.1}
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 $TAB"
SCP="scp -q -o BatchMode=yes -o StrictHostKeyChecking=no"
PUSH=1
for a in "$@"; do case "$a" in --no-push) PUSH=0;; esac; done

SRC=$W/vendor-orig.img
OUT=$W/vendor-cam.img
NEW=$W/vendor-cam.img.new

[ -f "$SRC" ] || { echo "missing $SRC (scp from device first)"; exit 1; }

echo "[1/6] stage original vendor tree (the image has only 496 inodes — 14 free ⇒ rebuild)"
STAGE=$W/stage
rm -rf "$STAGE"; mkdir -p "$STAGE"
debugfs -R "rdump / $STAGE" "$SRC" >/dev/null 2>&1 || true
rm -rf "$STAGE/lost+found"
echo "  staged $(find "$STAGE" -type f | wc -l) files"

echo "[3/6] vintf manifest patch"
python3 - "$W/camx/vendor-manifest.xml" "$W/vendor-manifest-cam.xml" <<'PY'
import sys
src, dst = sys.argv[1], sys.argv[2]
s = open(src).read()
old = """    <hal format="hidl">
        <name>android.hardware.camera.provider</name>
        <transport>hwbinder</transport>
        <version>2.7</version>
        <interface>
            <name>ICameraProvider</name>
            <instance>external/0</instance>
        </interface>
        <fqname>@2.7::ICameraProvider/external/0</fqname>
    </hal>"""
new = """    <hal format="hidl">
        <name>android.hardware.camera.provider</name>
        <transport>hwbinder</transport>
        <version>2.4</version>
        <interface>
            <name>ICameraProvider</name>
            <instance>external/0</instance>
        </interface>
        <fqname>@2.4::ICameraProvider/external/0</fqname>
    </hal>"""
assert old in s, "2.7 camera.provider block not found"
open(dst, "w").write(s.replace(old, new))
print("  manifest: 2.7 external -> 2.5 + 2.4 external")
PY

echo "[4/6] add files to stage + build 128 MiB image with plenty of inodes"
put() { # hostfile targetpath mode
  t=$1; dst=$2; mode=$3
  mkdir -p "$STAGE/$(dirname "${dst#/}")"
  cp -f "$t" "$STAGE/${dst#/}"
  chmod "$mode" "$STAGE/${dst#/}"
}
put "$W/out-cam/android.hardware.camera.provider@2.4-external-service" /bin/hw/android.hardware.camera.provider@2.4-external-service 755
put "$W/out-cam/android.hardware.camera.provider@2.4-external.so" /lib64/hw/android.hardware.camera.provider@2.4-external.so 644
# passthrough lookup matches "<pkg>@<ver>-impl*.so" only (system/libhidl ServiceManagement.cpp:openLibs)
put "$W/out-cam/android.hardware.camera.provider@2.4-external.so" /lib64/hw/android.hardware.camera.provider@2.4-impl.so 644
put "$W/out-cam/android.hardware.camera.provider@2.5-external.so" /lib64/hw/android.hardware.camera.provider@2.5-external.so 644
put "$W/out-cam/camera.device@3.4-external-impl.so" /lib64/hw/camera.device@3.4-external-impl.so 644
put "$W/out-cam/camera.device@3.5-external-impl.so" /lib64/hw/camera.device@3.5-external-impl.so 644
put "$W/out-cam/camera.device@3.6-external-impl.so" /lib64/hw/camera.device@3.6-external-impl.so 644
put "$W/vdump/lib64/camera.device@3.2-impl.so" /lib64/camera.device@3.2-impl.so 644
put "$W/vdump/lib64/camera.device@3.3-impl.so" /lib64/camera.device@3.3-impl.so 644
put "$W/vdump/lib64/android.hardware.camera.common@1.0.so" /lib64/android.hardware.camera.common@1.0.so 644
put "$W/vdump/lib64/android.hardware.camera.device@1.0.so" /lib64/android.hardware.camera.device@1.0.so 644
put "$W/vdump/lib64/android.hardware.camera.device@3.2.so" /lib64/android.hardware.camera.device@3.2.so 644
put "$W/vdump/lib64/android.hardware.camera.device@3.3.so" /lib64/android.hardware.camera.device@3.3.so 644
put "$W/vdump/lib64/android.hardware.camera.device@3.4.so" /lib64/android.hardware.camera.device@3.4.so 644
put "$W/vdump/lib64/android.hardware.camera.device@3.5.so" /lib64/android.hardware.camera.device@3.5.so 644
put "$W/sysroot/lib/android.hardware.camera.device@3.6.so" /lib64/android.hardware.camera.device@3.6.so 644
put "$W/vdump/lib64/android.hardware.camera.provider@2.4.so" /lib64/android.hardware.camera.provider@2.4.so 644
put "$W/vdump/lib64/android.hardware.camera.provider@2.5.so" /lib64/android.hardware.camera.provider@2.5.so 644
put "$W/vdump/lib64/android.hidl.allocator@1.0.so" /lib64/android.hidl.allocator@1.0.so 644
put "$W/sysroot/lib/android.hidl.memory@1.0.so" /lib64/android.hidl.memory@1.0.so 644
put "$W/sysroot/lib/android.hardware.graphics.common@1.0.so" /lib64/android.hardware.graphics.common@1.0.so 644
put "$W/sysroot/lib/android.hardware.graphics.common@1.1.so" /lib64/android.hardware.graphics.common@1.1.so 644
put "$W/sysroot/lib/android.hardware.graphics.common@1.2.so" /lib64/android.hardware.graphics.common@1.2.so 644
put "$W/sysroot/lib/android.hardware.graphics.mapper@2.0.so" /lib64/android.hardware.graphics.mapper@2.0.so 644
put "$W/sysroot/lib/android.hardware.graphics.mapper@3.0.so" /lib64/android.hardware.graphics.mapper@3.0.so 644
put "$W/sysroot/lib/android.hardware.graphics.mapper@4.0.so" /lib64/android.hardware.graphics.mapper@4.0.so 644
put "$W/hw-interfaces/camera/provider/2.4/default/android.hardware.camera.provider@2.4-external-service.rc" /etc/init/android.hardware.camera.provider@2.4-external-service.rc 644
put "$W/vdump/etc/permissions/android.hardware.camera.external.xml" /etc/permissions/android.hardware.camera.external.xml 644
put "$W/vendor-manifest-cam.xml" /etc/vintf/manifest.xml 644

mke2fs -q -t ext4 -b 4096 -I 256 -N 8192 -L vendor -d "$STAGE" "$NEW" 128M
e2fsck -f -y "$NEW" >/dev/null 2>&1 || true

echo "[5/6] fix ownership (0:2000) + verify"
{
  echo "cd /"
  while IFS= read -r p; do
    echo "sif /$p uid 0"
    echo "sif /$p gid 2000"
  done < <(cd "$STAGE" && find . -mindepth 1 -printf '%P\n')
} > "$W/sif-cmds.txt"
debugfs -w -f "$W/sif-cmds.txt" "$NEW" >/dev/null 2>&1 || true
e2fsck -f -y "$NEW" >/dev/null 2>&1 || true
dumpe2fs -h "$NEW" 2>/dev/null | grep -E "Inode count|Free inodes|Block count" | sed 's/^/  /'
debugfs -R "ls -l /bin/hw" "$NEW" 2>/dev/null | grep -i "camera.provider" | sed 's/^/  /'
debugfs -R "ls -l /lib64/hw" "$NEW" 2>/dev/null | grep -i camera | sed 's/^/  /'
debugfs -R "ls -l /etc/init" "$NEW" 2>/dev/null | grep -i camera | sed 's/^/  /'
mv -f "$NEW" "$OUT"
echo "  $OUT $(stat -c%s "$OUT") bytes"

if [ "$PUSH" = 1 ]; then
  echo "[6/6] push to device (stop container first)"
  timeout 60 $SSH 'waydroid session stop >/dev/null 2>&1; waydroid container stop >/dev/null 2>&1; sleep 3; true' || true
  timeout 60 $SSH 'cp -n /var/lib/waydroid/images/vendor.img /var/lib/waydroid/images/vendor.img.bak-pre-cam-$(date +%Y%m%d-%H%M%S) 2>/dev/null; ls /var/lib/waydroid/images/ | grep vendor' || true
  timeout 300 $SCP "$OUT" "$TAB:/var/lib/waydroid/images/vendor.img"
  timeout 60 $SSH 'ls -l /var/lib/waydroid/images/vendor.img'
fi
