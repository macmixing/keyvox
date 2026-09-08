// SPDX-License-Identifier: MIT
#pragma once
#include "QnnGraph.h"
#include "keyvox-whisper-encoder.h"

class WhisperQnnEncoder {
public:
    WhisperQnnEncoder(const char *model, const char *runtimeDirectory,
                      const kv_whisper_encoder_dimensions &dimensions);
    bool encode(const float *mel, size_t melElements, uint16_t *key, uint16_t *value,
                size_t cacheElements, kv_whisper_encoder_abort abort, void *abortData);
private:
    kv_whisper_encoder_dimensions dimensions;
    std::unique_ptr<QnnRuntime> runtime;
    std::unique_ptr<QnnGraph> graph;
};
