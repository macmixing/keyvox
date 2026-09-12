// SPDX-License-Identifier: MIT
#include "WhisperQnnEncoder.h"
#include <android/log.h>
#include <exception>
#include <chrono>

namespace {
bool encode(void *instance, const float *mel, size_t melElements, uint16_t *key, uint16_t *value,
    size_t cacheElements, kv_whisper_encoder_abort abort, void *abortData) {
    try {
        const auto start = std::chrono::steady_clock::now();
        const bool completed = static_cast<WhisperQnnEncoder *>(instance)->encode(mel, melElements, key, value,
            cacheElements, abort, abortData);
        __android_log_print(ANDROID_LOG_INFO, "KeyVoxQnn", "KeyVox QNN encode completed=%d elapsed_ms=%.3f\n", completed,
            std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - start).count());
        return completed;
    } catch (const std::exception &error) {
        __android_log_print(ANDROID_LOG_INFO, "KeyVoxQnn", "KeyVox QNN encoder unavailable: %s\n", error.what());
    } catch (...) {
        __android_log_print(ANDROID_LOG_INFO, "KeyVoxQnn", "KeyVox QNN encoder failed\n");
    }
    return false;
}
void destroy(void *instance) { delete static_cast<WhisperQnnEncoder *>(instance); }
}

extern "C" __attribute__((visibility("default"))) bool keyvox_whisper_encoder_create_v1(
    const char *model, const char *runtime, const kv_whisper_encoder_dimensions *dimensions,
    kv_whisper_encoder_instance *output) {
    if (!output) return false;
    *output = {};
    if (!dimensions) return false;
    try {
        auto instance = std::make_unique<WhisperQnnEncoder>(model, runtime, *dimensions);
        *output = {instance.release(), encode, destroy};
        return true;
    } catch (const std::exception &error) {
        __android_log_print(ANDROID_LOG_INFO, "KeyVoxQnn", "KeyVox QNN initialization unavailable: %s\n", error.what());
    } catch (...) {
        __android_log_print(ANDROID_LOG_INFO, "KeyVoxQnn", "KeyVox QNN initialization failed\n");
    }
    return false;
}
