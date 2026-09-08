// SPDX-License-Identifier: MIT
#include "ExternalEncoder.h"
#include <dlfcn.h>

namespace keyvox {
std::unique_ptr<ExternalEncoder> ExternalEncoder::load(const char *plugin, const char *model,
    const char *runtime, const kv_whisper_encoder_dimensions &dimensions) {
    if (!plugin || !model || !runtime) return nullptr;
    auto result = std::unique_ptr<ExternalEncoder>(new ExternalEncoder);
    result->library = dlopen(plugin, RTLD_NOW | RTLD_LOCAL);
    if (!result->library) return nullptr;
    auto create = reinterpret_cast<kv_whisper_encoder_create_v1>(
        dlsym(result->library, "keyvox_whisper_encoder_create_v1"));
    if (!create || !create(model, runtime, &dimensions, &result->implementation)) return nullptr;
    if (!result->implementation.instance || !result->implementation.encode || !result->implementation.destroy)
        return nullptr;
    return result;
}

ExternalEncoder::~ExternalEncoder() {
    if (implementation.instance && implementation.destroy) implementation.destroy(implementation.instance);
    if (library) dlclose(library);
}

bool ExternalEncoder::encode(const float *mel, size_t melElements, uint16_t *key, uint16_t *value,
    size_t cacheElements, kv_whisper_encoder_abort abort, void *abortData) {
    // whisper_full_parallel can share one context across multiple native states.
    std::lock_guard<std::mutex> lock(executionMutex);
    if (!available || (abort && abort(abortData))) return false;
    if (implementation.encode(implementation.instance, mel, melElements, key, value, cacheElements, abort, abortData))
        return true;
    // Cancellation is request-scoped; a runtime failure disables the fast path.
    if (!(abort && abort(abortData))) available = false;
    return false;
}
}
