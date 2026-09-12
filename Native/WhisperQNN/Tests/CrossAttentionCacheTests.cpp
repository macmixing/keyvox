// SPDX-License-Identifier: MIT
#include "../CrossAttentionCache.h"
#include "../Float16.h"
#include <cassert>
#include <cmath>
#include <limits>
#include <vector>
int main() {
    constexpr size_t heads = 2, channels = 4, frames = 3;
    constexpr size_t count = heads * channels * frames;
    std::vector<uint16_t> key(count), value(count), outputKey(count), outputValue(count);
    for (size_t i = 0; i < count; ++i) {
        key[i] = float16Bits(float(i) / 8);
        value[i] = float16Bits(-float(i) / 16);
    }
    assert(convertCrossAttentionCache(key.data(), value.data(), heads, channels, frames,
        outputKey.data(), outputValue.data()));
    for (size_t h = 0; h < heads; ++h) for (size_t c = 0; c < channels; ++c)
        for (size_t f = 0; f < frames; ++f) {
            const auto expected = float16Bits(float16Value(&key[(h * channels + c) * frames + f])
                * std::pow(float(channels), -0.25f));
            assert(outputKey[f * heads * channels + h * channels + c] == expected);
            assert(outputValue[(h * channels + c) * frames + f] == value[(h * frames + f) * channels + c]);
        }
    for (float invalid : {std::numeric_limits<float>::infinity(), std::numeric_limits<float>::quiet_NaN()}) {
        key[0] = float16Bits(invalid);
        assert(!convertCrossAttentionCache(key.data(), value.data(), heads, channels, frames,
            outputKey.data(), outputValue.data()));
        key[0] = float16Bits(0);
        value[0] = float16Bits(invalid);
        assert(!convertCrossAttentionCache(key.data(), value.data(), heads, channels, frames,
            outputKey.data(), outputValue.data()));
        value[0] = float16Bits(0);
    }
    assert(!convertCrossAttentionCache(nullptr, value.data(), heads, channels, frames,
        outputKey.data(), outputValue.data()));
    assert(!convertCrossAttentionCache(key.data(), value.data(), heads, 0, frames,
        outputKey.data(), outputValue.data()));
}
