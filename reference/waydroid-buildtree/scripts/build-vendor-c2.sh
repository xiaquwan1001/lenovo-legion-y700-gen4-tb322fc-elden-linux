#!/bin/bash
# Build the Waydroid vendor image with the container-audio fixes:
#   - C2 (c2.android.*) codec XMLs instead of OMX.google.*
#   - drop the media.omx HAL declaration (no OMX service in the image)
# Usage: bash build-vendor-c2.sh [jobs]
cd /mnt/Samsung/waydroid-build || exit 1
source build/envsetup.sh
lunch lineage_waydroid_arm64_only-userdebug
# Waydroid project patches (wayland fractional-scale protocol, vold fuse, sepolicy...)
type apply-waydroid-patches >/dev/null 2>&1 && apply-waydroid-patches || echo "apply-waydroid-patches: non-fatal"
m vendorimage -j"${1:-16}"
rc=$?
echo "BUILD_DONE rc=$rc"
exit $rc
