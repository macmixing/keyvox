// SPDX-License-Identifier: MIT
#pragma once
#include <cstddef>
#include <cstdint>

// Convert one Qualcomm cross-attention layer into Whisper's non-flash layout.
bool convertCrossAttentionCache(const void *key, const void *value,
    size_t heads, size_t channels, size_t frames, uint16_t *outputKey, uint16_t *outputValue);
