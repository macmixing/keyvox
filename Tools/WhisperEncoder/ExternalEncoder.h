// SPDX-License-Identifier: MIT
#pragma once
#include "keyvox-whisper-encoder.h"
#include <memory>
#include <mutex>

namespace keyvox {
class ExternalEncoder {
public:
    static std::unique_ptr<ExternalEncoder> load(const char *plugin, const char *model,
        const char *runtime, const kv_whisper_encoder_dimensions &dimensions);
    ~ExternalEncoder();
    ExternalEncoder(const ExternalEncoder &) = delete;
    ExternalEncoder &operator=(const ExternalEncoder &) = delete;
    bool encode(const float *mel, size_t melElements, uint16_t *key, uint16_t *value,
        size_t cacheElements, kv_whisper_encoder_abort abort, void *abortData);
private:
    ExternalEncoder() = default;
    void *library = nullptr;
    kv_whisper_encoder_instance implementation{};
    bool available = true;
    std::mutex executionMutex;
};
}
