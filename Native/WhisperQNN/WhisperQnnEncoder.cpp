// SPDX-License-Identifier: MIT
#include "WhisperQnnEncoder.h"
#include "CrossAttentionCache.h"
#include "Float16.h"
#include <cmath>
#include <limits>
#include <stdexcept>

WhisperQnnEncoder::WhisperQnnEncoder(const char *model, const char *runtimeDirectory,
    const kv_whisper_encoder_dimensions &shape) : dimensions(shape) {
    if (!model || !runtimeDirectory || !shape.mel_bands || !shape.hidden_size || !shape.decoder_layers ||
        !shape.audio_frames || shape.audio_frames > std::numeric_limits<uint32_t>::max() / 2 ||
        !shape.attention_heads || shape.hidden_size % shape.attention_heads)
        throw std::runtime_error("Invalid Whisper encoder dimensions");
    runtime = QnnRuntime::load(runtimeDirectory);
    graph = QnnGraph::load(*runtime, model);
    if (graph->inputCount() != 1 || graph->outputCount() != size_t(shape.decoder_layers) * 2)
        throw std::runtime_error("Encoder model interface mismatch");
    QnnGraph::requireShape(graph->input("input_features"), {1, shape.mel_bands, shape.audio_frames * 2});
    const uint32_t channels = shape.hidden_size / shape.attention_heads;
    for (uint32_t layer = 0; layer < shape.decoder_layers; ++layer) {
        QnnGraph::requireShape(graph->output("k_cache_cross_" + std::to_string(layer)),
            {shape.attention_heads, 1, channels, shape.audio_frames});
        QnnGraph::requireShape(graph->output("v_cache_cross_" + std::to_string(layer)),
            {shape.attention_heads, 1, shape.audio_frames, channels});
    }
}

bool WhisperQnnEncoder::encode(const float *mel, size_t melElements, uint16_t *key, uint16_t *value,
    size_t cacheElements, kv_whisper_encoder_abort abort, void *abortData) {
    auto &input = graph->input("input_features");
    const size_t layerElements = size_t(dimensions.hidden_size) * dimensions.audio_frames;
    if (!mel || !key || !value || melElements != input.clientBuf.dataSize / sizeof(uint16_t) ||
        cacheElements != size_t(dimensions.decoder_layers) * layerElements) return false;
    if (abort && abort(abortData)) return false;
    auto *bytes = static_cast<uint8_t *>(input.clientBuf.data);
    for (size_t i = 0; i < melElements; ++i) {
        const uint16_t half = float16Bits(mel[i]);
        if (!std::isfinite(mel[i]) || !std::isfinite(float16Value(&half))) return false;
        std::memcpy(bytes + i * sizeof(half), &half, sizeof(half));
    }
    if (abort && abort(abortData)) return false;
    graph->execute();
    for (uint32_t layer = 0; layer < dimensions.decoder_layers; ++layer) {
        if (abort && abort(abortData)) return false;
        if (!convertCrossAttentionCache(graph->output("k_cache_cross_" + std::to_string(layer)).clientBuf.data,
            graph->output("v_cache_cross_" + std::to_string(layer)).clientBuf.data,
            dimensions.attention_heads, dimensions.hidden_size / dimensions.attention_heads,
            dimensions.audio_frames, key + layer * layerElements, value + layer * layerElements)) return false;
    }
    return true;
}
