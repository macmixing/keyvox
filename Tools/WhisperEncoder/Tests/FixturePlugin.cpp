// SPDX-License-Identifier: MIT
#include "keyvox-whisper-encoder.h"
#include <cstring>
#include <atomic>
#include <thread>

namespace {
std::atomic<int> created{0}, destroyed{0}, executed{0}, active{0};
std::atomic<bool> blocked{false};
struct Instance { bool fail; };
bool encode(void *raw, const float *, size_t, uint16_t *key, uint16_t *value, size_t count,
            kv_whisper_encoder_abort abort, void *data) {
    ++executed;
    ++active;
    while (blocked.load()) std::this_thread::yield();
    --active;
    if (abort && abort(data)) return false;
    if (static_cast<Instance *>(raw)->fail) return false;
    for (size_t i = 0; i < count; ++i) { key[i] = 1; value[i] = 2; }
    return true;
}
void destroy(void *raw) { ++destroyed; delete static_cast<Instance *>(raw); }
}
extern "C" int kv_fixture_created() { return created; }
extern "C" int kv_fixture_destroyed() { return destroyed; }
extern "C" int kv_fixture_executed() { return executed; }
extern "C" int kv_fixture_active() { return active; }
extern "C" void kv_fixture_block(bool value) { blocked = value; }
extern "C" bool keyvox_whisper_encoder_create_v1(const char *model, const char *,
    const kv_whisper_encoder_dimensions *, kv_whisper_encoder_instance *output) {
    *output = {};
    if (std::strcmp(model, "unavailable") == 0) return false;
    ++created;
    *output = {new Instance{std::strcmp(model, "execution-failure") == 0}, encode, destroy};
    return true;
}
