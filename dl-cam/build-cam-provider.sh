#!/bin/bash
# Build the AOSP *external* camera provider (HIDL 2.4/2.5) for **arm64** Android 13,
# i.e. the 64-bit variant upstream never builds (`compile_multilib: "32"`).
#
# Outputs into out-cam/:
#   android.hardware.camera.provider@2.4-external-service   (binary)
#   android.hardware.camera.provider@2.4-external.so
#   android.hardware.camera.provider@2.5-external.so
#   camera.device@3.4-external-impl.so
#   camera.device@3.5-external-impl.so
#   camera.device@3.6-external-impl.so
set -eu
cd "$(dirname "$0")"
HERE=$PWD
NDK=${NDK:-$HERE/ndk/android-ndk-r25c}
CXX=$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android33-clang++
API=33
OUT=${OUT:-$HERE/out-cam}
SYS=$HERE/sysroot/lib
IFACE=$HERE/hw-interfaces
AOSP=$HERE/aosp
mkdir -p "$OUT/obj"

INC_EXTRA="-I$IFACE/camera/device/3.4/default -I$IFACE/camera/device/3.5/default -I$IFACE/camera/device/3.6/default -I$IFACE/camera/device/3.4/default/include/ext_device_v3_4_impl -I$IFACE/camera/device/3.5/default/include/ext_device_v3_5_impl -I$IFACE/camera/device/3.6/default/include/ext_device_v3_6_impl"
INC="-I$HERE/gen
 -I$HERE/gen-aidl
 -I$IFACE/camera/provider/2.4/default
 -I$IFACE/camera/common/1.0/default/include
 -I$AOSP/frameworks-native/libs/utils/include
 -I$AOSP/frameworks-native/libs/nativebase/include
 -I$AOSP/libfmq/include
 -I$AOSP/libfmq/base
 -I$AOSP/frameworks-native/libs/sync/include
 -I$AOSP/frameworks-native/libs/binder/include
 -I$AOSP/libhwbinder/include
 -I$AOSP/frameworks-native/libs/ui/include
 -I$AOSP/frameworks-native/libs/gralloc/types/include
 -I$AOSP/system-core/libcutils/include
 -I$AOSP/system-core/libsync/include
 -I$AOSP/system-core/libutils/include
 -I$AOSP/system-core/libsystem/include
 -I$AOSP/system-logging/liblog/include
 -I$AOSP/system-media/camera/include
 -I$AOSP/system-media/private/camera/include
 -I$AOSP/system-libbase/include
 -I$AOSP/hardware-libhardware/include
 -I$HERE/libhidl/base/include
 -I$HERE/libhidl/transport/include
 -I$AOSP/tinyxml2
 -I$AOSP/libjpeg
 -I$AOSP/libyuv/files/include
 -I$AOSP/libyuv/include
 -I$AOSP/libexif
 -I$HERE/libhidl/base/include
 -I$HERE/libhidl/transport/include
 -I$AOSP/tinyxml2
 -I$AOSP/libjpeg
 -I$AOSP/libyuv/files/include
 -I$AOSP/libyuv/include
 -I$AOSP/libexif/libexif"

CFLAGS="--target=aarch64-linux-android$API -std=gnu++17 -O2 -fPIC -fno-exceptions -fno-rtti -Wno-deprecated-declarations -DANDROID -D_LIBCPP_ABI_NAMESPACE=__1"

# static helper (android.hardware.camera.common@1.0-helper)
HELPER_SRCS="$IFACE/camera/common/1.0/default/CameraMetadata.cpp \
 $IFACE/camera/common/1.0/default/CameraModule.cpp \
 $IFACE/camera/common/1.0/default/CameraParameters.cpp \
 $IFACE/camera/common/1.0/default/Exif.cpp \
 $IFACE/camera/common/1.0/default/HandleImporter.cpp \
 $IFACE/camera/common/1.0/default/VendorTagDescriptor.cpp"

# shared lib link helper: $1 out.so, rest objs / extra libs after --
link_so() {
  so=$1; shift
  objs=""
  for f in "$@"; do objs="$objs $f"; done
  $CXX --target=aarch64-linux-android$API -shared -o "$so" $objs \
    -Wl,-soname,$(basename "$so") -Wl,--no-undefined -Wl,--exclude-libs,ALL -Wl,--allow-multiple-definition \
    -Wl,-rpath-link,"$SYS" \
    -L"$SYS" -L"$OUT" $(libs_for "$(basename "$so")")
}

libs_for() {
  case "$1" in
    android.hardware.camera.provider@2.5-external.so)
      libs_for android.hardware.camera.provider@2.4-external.so | sed 's/$/ -l:android.hardware.camera.provider@2.4-external.so/'
      ;;
    android.hardware.camera.provider@2.*-external.so)
      echo "-l:libc++.so -l:libhidlbase.so -l:libutils.so -l:libcutils.so -l:liblog.so -l:libhardware.so \
            -l:libcamera_metadata.so -l:libtinyxml2.so -l:libgralloctypes.so -l:libfmq.so \
            -l:libsync.so -l:libyuv.so -l:libjpeg.so -l:libexif.so \
            -l:android.hardware.camera.common@1.0.so -l:android.hardware.camera.device@1.0.so \
            -l:android.hardware.camera.device@3.2.so -l:android.hardware.camera.device@3.3.so \
            -l:android.hardware.camera.device@3.4.so -l:android.hardware.camera.device@3.5.so \
            -l:android.hardware.camera.device@3.6.so -l:android.hardware.camera.provider@2.4.so \
            -l:android.hardware.graphics.mapper@2.0.so -l:android.hardware.graphics.mapper@3.0.so \
            -l:android.hardware.graphics.mapper@4.0.so -l:android.hidl.allocator@1.0.so \
            -l:android.hidl.memory@1.0.so \
            -l:camera.device@3.4-external-impl.so -l:camera.device@3.5-external-impl.so \
            -l:camera.device@3.6-external-impl.so -l:camera.device@3.2-impl.so -l:camera.device@3.3-impl.so"
      ;;
    camera.device@3.5-external-impl.so)
      libs_for camera.device@3.4-external-impl.so | sed 's/$/ -l:camera.device@3.4-external-impl.so/'
      ;;
    camera.device@3.6-external-impl.so)
      libs_for camera.device@3.4-external-impl.so | sed 's/$/ -l:camera.device@3.4-external-impl.so -l:camera.device@3.5-external-impl.so/'
      ;;
    android.hardware.camera.provider@2.4-external.so|\
    android.hardware.camera.provider@2.5-external.so|camera.device@3.*-external-impl.so)
      echo "-l:libc++.so -l:libhidlbase.so -l:libutils.so -l:libcutils.so -l:liblog.so -l:libhardware.so \
            -l:libcamera_metadata.so -l:libgralloctypes.so -l:libfmq.so -l:libsync.so \
            -l:libyuv.so -l:libjpeg.so -l:libexif.so -l:libtinyxml2.so \
            -l:android.hardware.camera.common@1.0.so -l:android.hardware.camera.device@1.0.so \
            -l:android.hardware.camera.device@3.2.so -l:android.hardware.camera.device@3.3.so \
            -l:android.hardware.camera.device@3.4.so -l:android.hardware.camera.device@3.5.so \
            -l:android.hardware.camera.device@3.6.so \
            -l:android.hardware.camera.provider@2.4.so \
            -l:android.hardware.graphics.mapper@2.0.so -l:android.hardware.graphics.mapper@3.0.so \
            -l:android.hardware.graphics.mapper@4.0.so \
            -l:android.hidl.allocator@1.0.so -l:android.hidl.memory@1.0.so \
            -l:camera.device@3.2-impl.so -l:camera.device@3.3-impl.so"
      ;;
  esac
}

echo "[1/7] common helper objects"
for src in $HELPER_SRCS; do
  o=$OUT/obj/helper-$(basename "${src%.cpp}").o
  [ -f "$o" ] && [ "$o" -nt "$src" ] && continue
  echo "  cc $(basename "$src")"
  $CXX $CFLAGS $INC -c "$src" -o "$o"
done
HELPER_OBJS=$(for src in $HELPER_SRCS; do echo "$OUT/obj/helper-$(basename "${src%.cpp}").o"; done)

for v in 3.4 3.5 3.6; do
  echo "[4/7] camera.device@$v-external-impl.so"
  d=$IFACE/camera/device/$v/default
  u=${v/./_}
  INC_V="-I$d -I$d/include/ext_device_v${u}_impl -I$d/include/device_v${u}_impl $INC_EXTRA $INC"
  srcs="$d/ExternalCameraDevice.cpp $d/ExternalCameraDeviceSession.cpp"
  [ -f "$d/ExternalCameraUtils.cpp" ] && srcs="$srcs $d/ExternalCameraUtils.cpp"
  [ -f "$d/ExternalCameraOfflineSession.cpp" ] && srcs="$srcs $d/ExternalCameraOfflineSession.cpp"
  objs=""
  for src in $srcs; do
    o=$OUT/obj/$v-$(basename "${src%.cpp}").o
    [ -f "$o" ] && [ "$o" -nt "$src" ] && { objs="$objs $o"; continue; }
    echo "  cc $(basename "$src")"
    $CXX $CFLAGS $INC_V -c "$src" -o "$o"
    objs="$objs $o"
  done
  link_so $OUT/camera.device@$v-external-impl.so $objs $HELPER_OBJS
done

echo "[2/7] provider@2.4-external.so"
$CXX $CFLAGS $INC $INC_EXTRA -c $IFACE/camera/provider/2.4/default/ExternalCameraProviderImpl_2_4.cpp -o $OUT/obj/ExternalCameraProviderImpl_2_4.o
$CXX $CFLAGS $INC $INC_EXTRA -c $HERE/external-fetch-shim.cpp -o $OUT/obj/external-fetch-shim.o
link_so $OUT/android.hardware.camera.provider@2.4-external.so $OUT/obj/ExternalCameraProviderImpl_2_4.o $OUT/obj/external-fetch-shim.o $HELPER_OBJS

echo "[3/7] provider@2.5-external.so"
if [ -f $IFACE/camera/provider/2.5/default/ExternalCameraProviderImpl_2_5.cpp ]; then
  $CXX $CFLAGS $INC $INC_EXTRA -I$IFACE/camera/provider/2.5/default -c \
    $IFACE/camera/provider/2.5/default/ExternalCameraProviderImpl_2_5.cpp -o $OUT/obj/ExternalCameraProviderImpl_2_5.o
  link_so $OUT/android.hardware.camera.provider@2.5-external.so $OUT/obj/ExternalCameraProviderImpl_2_5.o $HELPER_OBJS
fi

echo "[7/7] external-service binary"
$CXX $CFLAGS $INC -c $IFACE/camera/provider/2.4/default/external-service.cpp -o $OUT/obj/external-service.o
$CXX --target=aarch64-linux-android$API -pie -o $OUT/android.hardware.camera.provider@2.4-external-service \
  $OUT/obj/external-service.o \
  -Wl,--exclude-libs,ALL -Wl,-rpath-link,"$SYS" -L"$SYS" -L"$OUT" \
  -l:android.hardware.camera.provider@2.4-external.so \
  -l:android.hardware.camera.provider@2.5-external.so \
  -l:libhidlbase.so -l:libutils.so -l:liblog.so -l:libcutils.so -l:libbinder.so \
  -l:libcamera_metadata.so -l:libtinyxml2.so \
  -l:android.hardware.camera.common@1.0.so -l:android.hardware.camera.device@1.0.so \
  -l:android.hardware.camera.device@3.2.so -l:android.hardware.camera.device@3.3.so \
  -l:android.hardware.camera.device@3.4.so -l:android.hardware.camera.device@3.5.so \
  -l:android.hardware.camera.provider@2.4.so

echo
ls -l $OUT/*.so $OUT/android.hardware.camera.provider@2.4-external-service 2>/dev/null || true
