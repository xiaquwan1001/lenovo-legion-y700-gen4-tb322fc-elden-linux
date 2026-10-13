/*
 * Copyright (C) 2026 The elden project (TB322FC/SM8750 mainline)
 * SPDX-License-Identifier: Apache-2.0
 */
#define LOG_TAG "vibrator.elden"

#include "Vibrator.h"

#include <android-base/logging.h>
#include <fcntl.h>
#include <unistd.h>

#include <cerrno>
#include <cmath>
#include <cstring>

namespace aidl::android::hardware::vibrator {

using ndk::ScopedAStatus;

namespace {

constexpr const char* kBridgeDir = "/sys/class/leds/vibrator";
constexpr int kDefaultDurationMs = 20;

ScopedAStatus unsupported() {
    return ScopedAStatus::fromExceptionCode(EX_UNSUPPORTED_OPERATION);
}

/* Predefined-effect map.  Durations are chosen for a LRA-style motor; the
 * framework only calls perform() for effects we list in getSupportedEffects(). */
bool effectDuration(Effect effect, int* durationMs) {
    switch (effect) {
        case Effect::CLICK:
            *durationMs = 10;
            return true;
        case Effect::DOUBLE_CLICK:
            *durationMs = 22;
            return true;
        case Effect::TICK:
            *durationMs = 5;
            return true;
        case Effect::THUD:
            *durationMs = 25;
            return true;
        case Effect::POP:
            *durationMs = 12;
            return true;
        case Effect::HEAVY_CLICK:
            *durationMs = 16;
            return true;
        default:
            return false;
    }
}

float strengthScale(EffectStrength strength) {
    switch (strength) {
        case EffectStrength::LIGHT:
            return 0.4f;
        case EffectStrength::MEDIUM:
            return 0.7f;
        case EffectStrength::STRONG:
        default:
            return 1.0f;
    }
}

}  // namespace

HapticBridge& HapticBridge::instance() {
    static HapticBridge bridge;
    return bridge;
}

void HapticBridge::writeFile(const char* name, const std::string& value) {
    const std::string path = std::string(kBridgeDir) + "/" + name;
    const std::string payload = value + "\n";
    int fd = open(path.c_str(), O_WRONLY | O_CLOEXEC);
    if (fd < 0) {
        LOG(ERROR) << "vibrator bridge: open " << path << " failed: " << std::strerror(errno);
        return;
    }
    ssize_t n = write(fd, payload.data(), payload.size());
    if (n != static_cast<ssize_t>(payload.size())) {
        LOG(ERROR) << "vibrator bridge: write " << path << " failed: " << std::strerror(errno);
    }
    close(fd);
}

void HapticBridge::setAmplitude255(int v) {
    if (v < 0) v = 0;
    if (v > 255) v = 255;
    bool live;
    {
        std::lock_guard<std::mutex> lock(mMutex);
        mAmplitude255 = v;
        live = mOn;
    }
    /* The framework's SetAmplitudeVibratorStep starts the vibration first and
     * only then pushes the amplitude, so an amplitude change must reach the
     * bridge *while* the motor runs (elden-hapticd re-uploads the FF effect). */
    if (live) {
        writeFile("amplitude", std::to_string(v));
        LOG(INFO) << "vibrator amplitude -> " << v;
    }
}

int HapticBridge::amplitude255() const {
    std::lock_guard<std::mutex> lock(mMutex);
    return mAmplitude255;
}

void HapticBridge::start(int durationMs, int ampOverride) {
    int amp;
    {
        std::lock_guard<std::mutex> lock(mMutex);
        amp = ampOverride >= 0 ? ampOverride : mAmplitude255;
        mQueuedMs = -1;
        mQueuedAmp = -1;
        mOn = true;
    }
    if (durationMs <= 0) durationMs = kDefaultDurationMs;
    /* order matters: elden-hapticd samples activate last, so everything it
     * needs (duration, amplitude) is already written when it sees activate=1. */
    writeFile("state", "1");
    writeFile("duration", std::to_string(durationMs));
    writeFile("amplitude", std::to_string(amp));
    writeFile("activate", "1");
    LOG(VERBOSE) << "vibrator on " << durationMs << "ms amp=" << amp;
}

void HapticBridge::stop() {
    {
        std::lock_guard<std::mutex> lock(mMutex);
        mOn = false;
    }
    writeFile("activate", "0");
    writeFile("state", "0");
    LOG(INFO) << "vibrator off";
}

void HapticBridge::prepare() {
    std::lock_guard<std::mutex> lock(mMutex);
    mPrepared = true;
    mQueuedMs = -1;
}

bool HapticBridge::isPrepared() const {
    std::lock_guard<std::mutex> lock(mMutex);
    return mPrepared;
}

void HapticBridge::queue(int durationMs, int ampOverride) {
    std::lock_guard<std::mutex> lock(mMutex);
    mQueuedMs = durationMs > 0 ? durationMs : kDefaultDurationMs;
    mQueuedAmp = ampOverride;
}

bool HapticBridge::trigger() {
    int queued, queuedAmp;
    {
        std::lock_guard<std::mutex> lock(mMutex);
        queued = mQueuedMs;
        queuedAmp = mQueuedAmp;
        mPrepared = false;
        mQueuedMs = -1;
        mQueuedAmp = -1;
    }
    if (queued > 0) {
        start(queued, queuedAmp);
        return true;
    }
    return false;
}

void HapticBridge::cancelPrepared() {
    std::lock_guard<std::mutex> lock(mMutex);
    mPrepared = false;
    mQueuedMs = -1;
    mQueuedAmp = -1;
}

/* ---- IVibrator ------------------------------------------------------- */

ScopedAStatus Vibrator::getCapabilities(int32_t* _aidl_return) {
    /* We intentionally do not advertise callback capabilities: the motor is
     * stopped by elden-hapticd (or by the framework's own off()), so no
     * HAL-side completion notification is needed. */
    *_aidl_return = IVibrator::CAP_AMPLITUDE_CONTROL;
    return ScopedAStatus::ok();
}

ScopedAStatus Vibrator::off() {
    HapticBridge::instance().stop();
    return ScopedAStatus::ok();
}

ScopedAStatus Vibrator::on(int32_t timeoutMs,
                           const std::shared_ptr<IVibratorCallback>& /*callback*/) {
    auto& bridge = HapticBridge::instance();
    if (bridge.isPrepared()) {
        bridge.queue(timeoutMs);
        return ScopedAStatus::ok();
    }
    bridge.start(timeoutMs);
    return ScopedAStatus::ok();
}

ScopedAStatus Vibrator::perform(Effect effect, EffectStrength strength,
                               const std::shared_ptr<IVibratorCallback>& /*callback*/,
                               int32_t* _aidl_return) {
    int durationMs = 0;
    if (!effectDuration(effect, &durationMs)) {
        return unsupported();
    }
    auto& bridge = HapticBridge::instance();
    /* scale the configured amplitude by the requested strength (no state change) */
    const int scaled =
            static_cast<int>(std::lround(bridge.amplitude255() * strengthScale(strength)));
    if (bridge.isPrepared()) {
        bridge.queue(durationMs, scaled);
    } else {
        bridge.start(durationMs, scaled);
    }
    *_aidl_return = durationMs;
    return ScopedAStatus::ok();
}

ScopedAStatus Vibrator::getSupportedEffects(std::vector<Effect>* _aidl_return) {
    *_aidl_return = {Effect::CLICK, Effect::DOUBLE_CLICK, Effect::TICK,
                     Effect::THUD,  Effect::POP,          Effect::HEAVY_CLICK};
    return ScopedAStatus::ok();
}

ScopedAStatus Vibrator::setAmplitude(float amplitude) {
    int amp = static_cast<int>(std::lround(amplitude * 255.0f));
    HapticBridge::instance().setAmplitude255(amp);
    return ScopedAStatus::ok();
}

ScopedAStatus Vibrator::setExternalControl(bool /*enabled*/) {
    return unsupported();
}

ScopedAStatus Vibrator::getCompositionDelayMax(int32_t* _aidl_return) {
    *_aidl_return = 0;
    return unsupported();
}

ScopedAStatus Vibrator::getCompositionSizeMax(int32_t* _aidl_return) {
    *_aidl_return = 0;
    return unsupported();
}

ScopedAStatus Vibrator::getSupportedPrimitives(std::vector<CompositePrimitive>* _aidl_return) {
    _aidl_return->clear();
    return unsupported();
}

ScopedAStatus Vibrator::getPrimitiveDuration(CompositePrimitive /*primitive*/,
                                             int32_t* _aidl_return) {
    *_aidl_return = 0;
    return unsupported();
}

ScopedAStatus Vibrator::compose(const std::vector<CompositeEffect>& /*composite*/,
                                const std::shared_ptr<IVibratorCallback>& /*callback*/) {
    return unsupported();
}

ScopedAStatus Vibrator::getSupportedAlwaysOnEffects(std::vector<Effect>* _aidl_return) {
    _aidl_return->clear();
    return unsupported();
}

ScopedAStatus Vibrator::alwaysOnEnable(int32_t /*id*/, Effect /*effect*/,
                                       EffectStrength /*strength*/) {
    return unsupported();
}

ScopedAStatus Vibrator::alwaysOnDisable(int32_t /*id*/) {
    return unsupported();
}

ScopedAStatus Vibrator::getResonantFrequency(float* _aidl_return) {
    *_aidl_return = NAN;
    return unsupported();
}

ScopedAStatus Vibrator::getQFactor(float* _aidl_return) {
    *_aidl_return = NAN;
    return unsupported();
}

ScopedAStatus Vibrator::getFrequencyResolution(float* _aidl_return) {
    *_aidl_return = NAN;
    return unsupported();
}

ScopedAStatus Vibrator::getFrequencyMinimum(float* _aidl_return) {
    *_aidl_return = NAN;
    return unsupported();
}

ScopedAStatus Vibrator::getBandwidthAmplitudeMap(std::vector<float>* _aidl_return) {
    _aidl_return->clear();
    return unsupported();
}

ScopedAStatus Vibrator::getPwlePrimitiveDurationMax(int32_t* _aidl_return) {
    *_aidl_return = 0;
    return unsupported();
}

ScopedAStatus Vibrator::getPwleCompositionSizeMax(int32_t* _aidl_return) {
    *_aidl_return = 0;
    return unsupported();
}

ScopedAStatus Vibrator::getSupportedBraking(std::vector<Braking>* _aidl_return) {
    _aidl_return->clear();
    return unsupported();
}

ScopedAStatus Vibrator::composePwle(const std::vector<PrimitivePwle>& /*composite*/,
                                    const std::shared_ptr<IVibratorCallback>& /*callback*/) {
    return unsupported();
}

}  // namespace aidl::android::hardware::vibrator
