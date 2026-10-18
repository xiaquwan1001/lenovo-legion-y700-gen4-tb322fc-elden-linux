// 直接注册 Bn，绕过 legacy 的 passthrough 路径（getRawServiceInternal / dlopen -impl.so）。
// 动机：2026-10-18 实测该路径在 Waydroid 容器里会在 hidl_string 析构处 abort
// （"Pointer tag ... was truncated"），而容器自有 HIDL 服务没有这条路径。
#include <hidl/HidlTransportSupport.h>
#include <log/log.h>

#include "CameraProvider_2_4.h"
#include "ExternalCameraProviderImpl_2_4.h"

using android::hardware::configureRpcThreadpool;
using android::hardware::joinRpcThreadpool;
using android::hardware::camera::provider::V2_4::ICameraProvider;
using android::hardware::camera::provider::V2_4::implementation::CameraProvider;
using android::hardware::camera::provider::V2_4::implementation::ExternalCameraProviderImpl_2_4;

int main() {
    ALOGI("External camera provider (direct Bn registration) is starting.");
    configureRpcThreadpool(1, true);

    android::sp<ICameraProvider> impl = new CameraProvider<ExternalCameraProviderImpl_2_4>();
    // 在纯接口实现上直接注册：libhidlbase 会用 gBnMap 里的构造器包成 Bn
    // （绕开 legacy 的 getRawServiceInternal + dlopen(-impl.so) 路径）
    android::status_t status = impl->registerAsService("external/0");
    LOG_ALWAYS_FATAL_IF(status != android::OK,
                        "Error while registering provider service: %d", status);
    ALOGI("Registration complete for @2.4::ICameraProvider/external/0 (direct).");

    joinRpcThreadpool();
    return 0;
}
