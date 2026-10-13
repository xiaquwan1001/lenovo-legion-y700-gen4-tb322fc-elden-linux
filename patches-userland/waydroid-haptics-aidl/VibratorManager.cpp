/*
 * Copyright (C) 2026 The elden project (TB322FC/SM8750 mainline)
 * SPDX-License-Identifier: Apache-2.0
 */
#define LOG_TAG "vibrator.elden"

#include "VibratorManager.h"

#include <android-base/logging.h>

namespace aidl::android::hardware::vibrator {

using ndk::ScopedAStatus;

VibratorManager::VibratorManager(std::shared_ptr<Vibrator> vibrator)
    : mVibrator(std::move(vibrator)) {}

ScopedAStatus VibratorManager::getCapabilities(int32_t* _aidl_return) {
    /* CAP_SYNC only: we can run a "synced" vibration (trivially, one motor). */
    *_aidl_return = CAP_SYNC | CAP_PREPARE_ON | CAP_PREPARE_PERFORM;
    return ScopedAStatus::ok();
}

ScopedAStatus VibratorManager::getVibratorIds(std::vector<int32_t>* _aidl_return) {
    *_aidl_return = {0};
    return ScopedAStatus::ok();
}

ScopedAStatus VibratorManager::getVibrator(int32_t vibratorId,
                                           std::shared_ptr<IVibrator>* _aidl_return) {
    if (vibratorId != 0) {
        return ScopedAStatus::fromExceptionCode(EX_ILLEGAL_ARGUMENT);
    }
    *_aidl_return = mVibrator;
    return ScopedAStatus::ok();
}

ScopedAStatus VibratorManager::prepareSynced(const std::vector<int32_t>& vibratorIds) {
    for (int32_t id : vibratorIds) {
        if (id != 0) return ScopedAStatus::fromExceptionCode(EX_ILLEGAL_ARGUMENT);
    }
    HapticBridge::instance().prepare();
    return ScopedAStatus::ok();
}

ScopedAStatus VibratorManager::triggerSynced(const std::shared_ptr<IVibratorCallback>& /*callback*/) {
    HapticBridge::instance().trigger();
    return ScopedAStatus::ok();
}

ScopedAStatus VibratorManager::cancelSynced() {
    HapticBridge::instance().cancelPrepared();
    HapticBridge::instance().stop();
    return ScopedAStatus::ok();
}

}  // namespace aidl::android::hardware::vibrator
