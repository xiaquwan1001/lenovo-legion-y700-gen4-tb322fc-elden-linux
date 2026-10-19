#!/bin/bash
# Generate HIDL C++ SOURCES (Bn/Bp/IFoo.cpp) for the camera external provider.
# Same package list as gen-headers.sh, but -L c++-sources into gen-src/.
# Enumerates every .hal in the packages we need (package-level generation misses
# interfaces that merely re-declare an earlier version's interface).
set -u
cd "$(dirname "$0")"
P=/home/xuqianhui/.local/hidlgen
export LD_LIBRARY_PATH=$P/usr/lib/x86_64-linux-gnu/android:$P/usr/lib/x86_64-linux-gnu
HG=$P/usr/bin/hidl-gen
ROOTS=(-r android.hardware:hw-interfaces -r android.hidl:libhidl/transport)

PKG_DIRS="
hw-interfaces/camera/provider/2.4
hw-interfaces/camera/provider/2.5
hw-interfaces/camera/device/1.0
hw-interfaces/camera/device/3.2
hw-interfaces/camera/device/3.3
hw-interfaces/camera/device/3.4
hw-interfaces/camera/device/3.5
hw-interfaces/camera/device/3.6
hw-interfaces/camera/common/1.0
hw-interfaces/camera/metadata/3.2
hw-interfaces/camera/metadata/3.3
hw-interfaces/camera/metadata/3.4
hw-interfaces/camera/metadata/3.5
hw-interfaces/camera/metadata/3.6
hw-interfaces/graphics/common/1.0
hw-interfaces/graphics/common/1.1
hw-interfaces/graphics/common/1.2
hw-interfaces/graphics/mapper/2.0
hw-interfaces/graphics/mapper/3.0
hw-interfaces/graphics/mapper/4.0
# ELDEN 2026-10-19: android.hidl.* 的 Bn/Bp 一律不自己编 —— 平台
# /apex/com.android.vndk.v33/lib64/libhidlbase.so 已提供 BpHwServiceManager 等实现，
# 我们再导出一份同名 WEAK 符号会抢绑定，导致 IInterface::asBinder(nullptr) /
# ConcurrentMap 崩溃。只用平台的。
#libhidl/transport/base/1.0
#libhidl/transport/memory/1.0
#libhidl/transport/allocator/1.0
#libhidl/transport/manager/1.0
#libhidl/transport/manager/1.1
#libhidl/transport/manager/1.2
#libhidl/transport/token/1.0
"

fqnames=""
for d in $PKG_DIRS; do
  [ -d "$d" ] || { echo "[iface] WARN missing $d"; continue; }
  pkg=$(grep -hoP '^package\s+\K[^;]+' "$d"/*.hal 2>/dev/null | head -1)
  [ -z "$pkg" ] && continue
  for hal in "$d"/*.hal; do
    name=$(basename "$hal" .hal)
    case "$name" in
      types) fqnames="$fqnames $pkg";;
      *)     fqnames="$fqnames $pkg::$name";;
    esac
  done
done

for round in $(seq 1 12); do
  err=$($HG -L c++-sources -o gen-src "${ROOTS[@]}" $fqnames 2>&1)
  missing=$(echo "$err" | grep -oP "Unable to (?:automatically )?import '\K[a-zA-Z0-9._,]+@[0-9.]+" | sort -u)
  if [ -z "$missing" ]; then
    echo "[iface] round $round OK, $(find gen-src -name '*.cpp' | wc -l) sources"
    echo "$err" | grep -v '^$' | head -5
    exit 0
  fi
  echo "[iface] round $round adding: $missing"
  fqnames="$fqnames $missing"
done
echo "[iface] FAILED" >&2
exit 1
