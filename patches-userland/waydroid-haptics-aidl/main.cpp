/*
 * Copyright (C) 2026 The elden project (TB322FC/SM8750 mainline)
 * SPDX-License-Identifier: Apache-2.0
 */
#define LOG_TAG "vibrator.elden"

#include <android-base/logging.h>
#include <android/binder_manager.h>
#include <android/binder_process.h>

#include "Vibrator.h"
#include "VibratorManager.h"

using aidl::android::hardware::vibrator::Vibrator;
using aidl::android::hardware::vibrator::VibratorManager;

int main() {
    ABinderProcess_setThreadPoolMaxThreadCount(4);

    auto vibrator = ndk::SharedRefBase::make<Vibrator>();
    const std::string vibName = std::string() + Vibrator::descriptor + "/default";
    binder_status_t status = AServiceManager_addService(vibrator->asBinder().get(), vibName.c_str());
    if (status != STATUS_OK) {
        LOG(ERROR) << "failed to add " << vibName << ": " << status;
        return EXIT_FAILURE;
    }
    LOG(INFO) << "registered " << vibName;

    auto manager = ndk::SharedRefBase::make<VibratorManager>(vibrator);
    const std::string manName = std::string() + VibratorManager::descriptor + "/default";
    status = AServiceManager_addService(manager->asBinder().get(), manName.c_str());
    if (status != STATUS_OK) {
        LOG(ERROR) << "failed to add " << manName << ": " << status;
        return EXIT_FAILURE;
    }
    LOG(INFO) << "registered " << manName;

    ABinderProcess_joinThreadPool();
    return EXIT_FAILURE;  // not reached
}
