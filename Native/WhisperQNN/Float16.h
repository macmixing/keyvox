// SPDX-License-Identifier: MIT
#pragma once
#include <cstdint>
#include <cstring>

inline uint16_t float16Bits(float value) {
    const _Float16 half = value;
    uint16_t bits;
    std::memcpy(&bits, &half, sizeof(bits));
    return bits;
}
inline float float16Value(const void *bytes) {
    _Float16 half;
    std::memcpy(&half, bytes, sizeof(half));
    return half;
}
