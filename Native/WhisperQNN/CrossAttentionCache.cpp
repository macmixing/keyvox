// SPDX-License-Identifier: MIT
#include "CrossAttentionCache.h"
#include "Float16.h"
#include <cmath>

bool convertCrossAttentionCache(const void *key, const void *value,
    size_t heads, size_t channels, size_t frames, uint16_t *outputKey, uint16_t *outputValue) {
    if (!key || !value || !outputKey || !outputValue || !heads || !channels || !frames) return false;
    const auto *keyBytes = static_cast<const uint8_t *>(key);
    const auto *valueBytes = static_cast<const uint8_t *>(value);
    const float scale = std::pow(float(channels), -0.25f);
    for (size_t head = 0; head < heads; ++head) for (size_t channel = 0; channel < channels; ++channel) {
        for (size_t frame = 0; frame < frames; ++frame) {
            const float k = float16Value(keyBytes + ((head * channels + channel) * frames + frame) * 2);
            const auto *v = valueBytes + ((head * frames + frame) * channels + channel) * 2;
            if (!std::isfinite(k) || !std::isfinite(float16Value(v))) return false;
            outputKey[frame * heads * channels + head * channels + channel] = float16Bits(k * scale);
            std::memcpy(outputValue + (head * channels + channel) * frames + frame, v, sizeof(uint16_t));
        }
    }
    return true;
}
