/*
 * Shim: export HIDL passthrough entry point from the *external* provider plugin.
 *
 * AOSP only defines HIDL_FETCH_ICameraProvider in
 * android.hardware.camera.provider@2.4-impl.so (CameraProvider_2_4.cpp), which
 * pulls in both the legacy and the external provider. We build a 64-bit-only
 * external provider, so we export the same entry point from this library and
 * always instantiate the external implementation.
 */
#include "ExternalCameraProviderImpl_2_4.h"

namespace android {
namespace hardware {
namespace camera {
namespace provider {
namespace V2_4 {
namespace implementation {

extern "C" ICameraProvider* HIDL_FETCH_ICameraProvider(const char* /*name*/) {
    CameraProvider<ExternalCameraProviderImpl_2_4>* provider =
            new CameraProvider<ExternalCameraProviderImpl_2_4>();
    if (provider == nullptr) {
        return nullptr;
    }
    if (provider->isInitFailed()) {
        delete provider;
        return nullptr;
    }
    return provider;
}

}  // namespace implementation
}  // namespace V2_4
}  // namespace provider
}  // namespace camera
}  // namespace hardware
}  // namespace android
