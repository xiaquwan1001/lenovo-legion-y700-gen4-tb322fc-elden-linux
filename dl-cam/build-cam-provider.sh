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

# ELDEN 2026-10-19: ABI 对齐 Android 平台 libc++（容器 /system/lib64/libc++.so）。
#   ABI 必须是 v1 + __1（平台 libc++ 只有 v1 的 __grow_by/__init* 符号；std::string
#   实测 24 字节，与平台头 dl-cam/libcxx/src 一致，不需要 ALTERNATE_STRING_LAYOUT）。
#   容器 libhidlbase 的 getRawServiceInternal 收到我们传的 std::string 会按 32 字节读，
#   于是 hidl_string(cstr) 读出垃圾指针 => hidl_string::~hidl_string free() abort
#   （"Pointer tag for 0x.. was truncated"）。
#   _LIBCPP_ABI_NAMESPACE=__1 => 与平台符号命名一致（否则 __ndk1）。
CFLAGS="--target=aarch64-linux-android$API -std=gnu++17 -O2 -fPIC -fno-exceptions -fno-rtti -Wno-deprecated-declarations -DANDROID -D_LIBCPP_ABI_VERSION=1 -D_LIBCPP_ABI_NAMESPACE=__1"
# PLATFORMLIBCXX=1：用 AOSP 平台 libc++ 头（dl-cam/libcxx/src + 手写 __config_site）替代 NDK 头。
# 动机见 2026-10-18：NDK 头编译的最小 HIDL 客户端在容器里 free() 时 abort（"Pointer tag ... truncated"）。
if [ "${PLATFORMLIBCXX:-0}" = 1 ]; then
  CFLAGS="$CFLAGS -nostdinc++ -isystem $HERE/libcxx/src"
fi

# static helper (android.hardware.camera.common@1.0-helper)
HELPER_SRCS="$IFACE/camera/common/1.0/default/CameraMetadata.cpp \
 $IFACE/camera/common/1.0/default/CameraModule.cpp \
 $IFACE/camera/common/1.0/default/CameraParameters.cpp \
 $IFACE/camera/common/1.0/default/Exif.cpp \
 $IFACE/camera/common/1.0/default/HandleImporter.cpp \
 $IFACE/camera/common/1.0/default/VendorTagDescriptor.cpp"

# shared lib link helper: $1 out.so, rest objs / extra libs after --
SELFIFACE=${SELFIFACE:-0}   # 1 = use our own hidl-gen -Lc++-sources (Bn/Bp) instead of donor iface libs

# [self-iface] compile hidl-gen generated sources (Bn/Bp + types) once
IFACE_OBJS=""
if [ "$SELFIFACE" = 1 ]; then
  echo "[0/7] generated interface sources (Bn/Bp) from gen-src/"
  i=0
  for src in $(find "$HERE/gen-src" -name '*.cpp' | sort); do
    rel=${src#$HERE/gen-src/}
    o=$OUT/obj/iface-$(echo "$rel" | tr '/' '_' | sed 's/\.cpp$/.o/')
    if [ ! -f "$o" ] || [ "$src" -nt "$o" ]; then
      # 某些 gen-src 文件在 clang-14 -O2 下会命中编译器内部崩溃（栈溢出/ICE），
      # 这两处不是性能关键路径，用 -O1 规避（结果等价，只是编译慢一点）。
      $CXX $CFLAGS $INC -I"$HERE/gen-src" -include "$HERE/iface-compat.h" -O1 -c "$src" -o "$o" \
        || { echo "  FAILED $rel"; exit 1; }
      i=$((i+1))
    fi
    IFACE_OBJS="$IFACE_OBJS $o"
  done
  echo "  compiled $i, total $(echo $IFACE_OBJS | wc -w) objects"
  # hide donor iface libs: our generated Bn/Bp replace them
  IFACE_FILTER='s/-l:android\.hardware\.camera\.(provider|device|common)@[0-9.]*\.so//g'
else
  IFACE_FILTER='s/x^//'
fi

link_so() {
  so=$1; shift
  objs=""
  for f in "$@"; do objs="$objs $f"; done
  libs=$(libs_for "$(basename "$so")")
  [ "$SELFIFACE" = 1 ] && libs=$(echo "$libs" | sed -E "$IFACE_FILTER")
  $CXX --target=aarch64-linux-android$API -shared -o "$so" $objs $IFACE_OBJS \
    -Wl,-soname,$(basename "$so") -Wl,--no-undefined -Wl,--exclude-libs,ALL -Wl,--allow-multiple-definition \
    -Wl,--version-script="$HERE/elden-cam-exports.map" -Wl,-rpath-link,"$SYS" \
    -L"$SYS" -L"$OUT" $libs
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
DIRECT=${DIRECT:-0}
if [ "$DIRECT" = 1 ]; then
  $CXX $CFLAGS $INC $INC_EXTRA -c $HERE/external-service-direct.cpp -o $OUT/obj/external-service-direct.o
  SVC_MAIN=$OUT/obj/external-service-direct.o
else
  $CXX $CFLAGS $INC -c $IFACE/camera/provider/2.4/default/external-service.cpp -o $OUT/obj/external-service.o
  SVC_MAIN=$OUT/obj/external-service.o
fi
SVC_IFACE_LIBS="-l:android.hardware.camera.common@1.0.so -l:android.hardware.camera.device@1.0.so \
  -l:android.hardware.camera.device@3.2.so -l:android.hardware.camera.device@3.3.so \
  -l:android.hardware.camera.device@3.4.so -l:android.hardware.camera.device@3.5.so \
  -l:android.hardware.camera.provider@2.4.so"
[ "$SELFIFACE" = 1 ] && SVC_IFACE_LIBS=""
$CXX --target=aarch64-linux-android$API -pie -o $OUT/android.hardware.camera.provider@2.4-external-service \
  $SVC_MAIN $IFACE_OBJS \
  -Wl,--exclude-libs,ALL -Wl,--allow-multiple-definition \
  -Wl,--version-script="$HERE/elden-cam-exports.map" -Wl,-rpath-link,"$SYS" -L"$SYS" -L"$OUT" \
  -l:android.hardware.camera.provider@2.4-external.so \
  -l:android.hardware.camera.provider@2.5-external.so \
  -l:libhidlbase.so -l:libutils.so -l:liblog.so -l:libcutils.so -l:libbinder.so \
  -l:libcamera_metadata.so -l:libtinyxml2.so $SVC_IFACE_LIBS

if [ "${SMOKE:-0}" = 1 ]; then
  echo "[smoke] hidl-smoke (defaultServiceManager path only)"
  $CXX $CFLAGS $INC -I"$HERE/gen-src" -include "$HERE/iface-compat.h" -c $HERE/hidl-smoke.cpp -o $OUT/obj/hidl-smoke.o
  $CXX --target=aarch64-linux-android$API -pie -o $OUT/hidl-smoke $OUT/obj/hidl-smoke.o $IFACE_OBJS \
    -Wl,--allow-multiple-definition -Wl,-rpath-link,"$SYS" -L"$SYS" \
    -l:libhidlbase.so -l:libutils.so -l:liblog.so -l:libcutils.so -l:libbinder.so -l:libc++.so
  ls -l $OUT/hidl-smoke
fi

echo
ls -l $OUT/*.so $OUT/android.hardware.camera.provider@2.4-external-service 2>/dev/null || true
