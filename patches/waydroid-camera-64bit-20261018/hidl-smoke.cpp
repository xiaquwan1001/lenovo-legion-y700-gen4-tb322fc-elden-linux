// 最小 HIDL 冒烟：只走 defaultServiceManager()/getService 路径（getRawServiceInternal +
// hidl_string/std::string 跨界）。用来判定「崩溃是否与 camera 无关，纯 ABI/头文件问题」。
#include <android/hidl/manager/1.0/IServiceManager.h>
#include <hidl/HidlTransportSupport.h>
#include <log/log.h>
#include <binder/ProcessState.h>

int main() {
    android::ProcessState::initWithDriver("/dev/vndbinder");
    ALOGI("smoke: calling IServiceManager::getService()");
    auto sm = android::hidl::manager::V1_0::IServiceManager::getService();
    ALOGI("smoke: sm=%p", sm.get());
    ALOGI("smoke: OK");
    return sm ? 0 : 2;
}
