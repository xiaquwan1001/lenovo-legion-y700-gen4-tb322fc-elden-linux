// hidl-gen 10.0.0+r36 生成的 Bn/Bp 代码会引用 libhidlbase 导出的
// gServicePrioMap / gServiceSidMap（新版 hidl/Static.h 才声明）。
// 我们 clone 的 system/libhidl 是 tm-release，声明在 transport/InternalStatic.h，
// 而生成代码不 include 它 ⇒ 用 -include 方式补声明（符号由 libhidlbase 导出）。
#pragma once
#include <hidl/HidlTransportSupport.h>
#include <hidl/Static.h>
#include <hidl/ConcurrentMap.h>
namespace android {
namespace hardware {
namespace details {
extern DoNotDestruct<ConcurrentMap<wp<::android::hidl::base::V1_0::IBase>, SchedPrio>>
        gServicePrioMap;
extern DoNotDestruct<ConcurrentMap<wp<::android::hidl::base::V1_0::IBase>, bool>> gServiceSidMap;
}  // namespace details
}  // namespace hardware
}  // namespace android
