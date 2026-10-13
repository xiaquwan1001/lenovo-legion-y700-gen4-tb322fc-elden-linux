/*
 * Copyright (C) 2026 The elden project (TB322FC/SM8750 mainline)
 * SPDX-License-Identifier: Apache-2.0
 *
 * AIDL vibrator HAL for Waydroid on mainline elden.
 * Replaces the Waydroid HIDL 1.0 HAL (which writes AOSP LED-trigger paths that
 * do not exist on mainline and silently ignores the failures) with an AIDL V2
 * HAL that:
 *   - reports CAP_AMPLITUDE_CONTROL  -> intensity sliders / setAmplitude work
 *   - off() really stops the motor   -> framework cancel() now stops it
 *   - writes the host bridge files consumed by elden-hapticd (see
 *     scripts/elden-hapticd.c), which drives the aw86927 FF_RUMBLE devices.
 */
#pragma once

#include <aidl/android/hardware/vibrator/BnVibrator.h>

#include <mutex>
#include <string>
#include <vector>

namespace aidl::android::hardware::vibrator {

// Writes the bridge ABI consumed by elden-hapticd on the Alpine host:
//   /sys/class/leds/vibrator/{state,duration,amplitude,activate}
// (bind-mounted from the host; see scripts/waydroid-haptics-setup.sh)
class HapticBridge {
  public:
    static HapticBridge& instance();

    void setAmplitude255(int v);
    int amplitude255() const;
    /* ampOverride < 0 -> use the configured amplitude */
    void start(int durationMs, int ampOverride = -1);
    void stop();

    // "synced" (IVibratorManager) support: defer start() until trigger()
    void prepare();
    bool isPrepared() const;
    void queue(int durationMs, int ampOverride = -1);
    bool trigger();  // true if something was actually fired
    void cancelPrepared();

  private:
    HapticBridge() = default;
    static void writeFile(const char* name, const std::string& value);

    mutable std::mutex mMutex;
    int mAmplitude255 = 255;
    bool mOn = false;
    bool mPrepared = false;
    int mQueuedMs = -1;
    int mQueuedAmp = -1;
};

class Vibrator : public BnVibrator {
  public:
    Vibrator() = default;

    ndk::ScopedAStatus getCapabilities(int32_t* _aidl_return) override;
    ndk::ScopedAStatus off() override;
    ndk::ScopedAStatus on(int32_t timeoutMs,
                          const std::shared_ptr<IVibratorCallback>& callback) override;
    ndk::ScopedAStatus perform(Effect effect, EffectStrength strength,
                              const std::shared_ptr<IVibratorCallback>& callback,
                              int32_t* _aidl_return) override;
    ndk::ScopedAStatus getSupportedEffects(std::vector<Effect>* _aidl_return) override;
    ndk::ScopedAStatus setAmplitude(float amplitude) override;
    ndk::ScopedAStatus setExternalControl(bool enabled) override;
    ndk::ScopedAStatus getCompositionDelayMax(int32_t* _aidl_return) override;
    ndk::ScopedAStatus getCompositionSizeMax(int32_t* _aidl_return) override;
    ndk::ScopedAStatus getSupportedPrimitives(std::vector<CompositePrimitive>* _aidl_return) override;
    ndk::ScopedAStatus getPrimitiveDuration(CompositePrimitive primitive,
                                            int32_t* _aidl_return) override;
    ndk::ScopedAStatus compose(const std::vector<CompositeEffect>& composite,
                               const std::shared_ptr<IVibratorCallback>& callback) override;
    ndk::ScopedAStatus getSupportedAlwaysOnEffects(std::vector<Effect>* _aidl_return) override;
    ndk::ScopedAStatus alwaysOnEnable(int32_t id, Effect effect, EffectStrength strength) override;
    ndk::ScopedAStatus alwaysOnDisable(int32_t id) override;
    ndk::ScopedAStatus getResonantFrequency(float* _aidl_return) override;
    ndk::ScopedAStatus getQFactor(float* _aidl_return) override;
    ndk::ScopedAStatus getFrequencyResolution(float* _aidl_return) override;
    ndk::ScopedAStatus getFrequencyMinimum(float* _aidl_return) override;
    ndk::ScopedAStatus getBandwidthAmplitudeMap(std::vector<float>* _aidl_return) override;
    ndk::ScopedAStatus getPwlePrimitiveDurationMax(int32_t* _aidl_return) override;
    ndk::ScopedAStatus getPwleCompositionSizeMax(int32_t* _aidl_return) override;
    ndk::ScopedAStatus getSupportedBraking(std::vector<Braking>* _aidl_return) override;
    ndk::ScopedAStatus composePwle(const std::vector<PrimitivePwle>& composite,
                                   const std::shared_ptr<IVibratorCallback>& callback) override;
};

}  // namespace aidl::android::hardware::vibrator
