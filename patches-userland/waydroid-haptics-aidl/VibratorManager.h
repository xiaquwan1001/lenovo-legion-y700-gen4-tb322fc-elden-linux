/*
 * Copyright (C) 2026 The elden project (TB322FC/SM8750 mainline)
 * SPDX-License-Identifier: Apache-2.0
 */
#pragma once

#include <aidl/android/hardware/vibrator/BnVibratorManager.h>

#include "Vibrator.h"

namespace aidl::android::hardware::vibrator {

/* Single-motor device: exposes exactly one vibrator (id 0).  "Synced" support
 * is required for `adb shell cmd vibrator_manager synced ...`; the actual
 * vibration is deferred until triggerSynced() so the semantics stay correct. */
class VibratorManager : public BnVibratorManager {
  public:
    explicit VibratorManager(std::shared_ptr<Vibrator> vibrator);

    ndk::ScopedAStatus getCapabilities(int32_t* _aidl_return) override;
    ndk::ScopedAStatus getVibratorIds(std::vector<int32_t>* _aidl_return) override;
    ndk::ScopedAStatus getVibrator(int32_t vibratorId,
                                   std::shared_ptr<IVibrator>* _aidl_return) override;
    ndk::ScopedAStatus prepareSynced(const std::vector<int32_t>& vibratorIds) override;
    ndk::ScopedAStatus triggerSynced(const std::shared_ptr<IVibratorCallback>& callback) override;
    ndk::ScopedAStatus cancelSynced() override;

  private:
    std::shared_ptr<Vibrator> mVibrator;
};

}  // namespace aidl::android::hardware::vibrator
