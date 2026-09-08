// SPDX-License-Identifier: MIT
#include "ExternalEncoder.h"
#include <cassert>
#include <dlfcn.h>
#include <atomic>
#include <chrono>
#include <thread>

int main(int argc, char **argv) {
    assert(argc == 2);
    void *library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    assert(library);
    auto created = reinterpret_cast<int (*)()>(dlsym(library, "kv_fixture_created"));
    auto destroyed = reinterpret_cast<int (*)()>(dlsym(library, "kv_fixture_destroyed"));
    auto executed = reinterpret_cast<int (*)()>(dlsym(library, "kv_fixture_executed"));
    auto active = reinterpret_cast<int (*)()>(dlsym(library, "kv_fixture_active"));
    auto block = reinterpret_cast<void (*)(bool)>(dlsym(library, "kv_fixture_block"));
    assert(created && destroyed && executed);
    assert(active && block);
    kv_whisper_encoder_dimensions dimensions{1, 1, 1, 1, 1};
    assert(!keyvox::ExternalEncoder::load("/unavailable", "", "", dimensions));
    assert(!keyvox::ExternalEncoder::load(argv[1], "unavailable", "", dimensions));
    float mel[2]{}; uint16_t key[1]{}, value[1]{};
    {
        auto encoder = keyvox::ExternalEncoder::load(argv[1], "available", "", dimensions);
        assert(encoder && created() == 1);
        bool cancelled = true;
        auto abort = [](void *raw) { return *static_cast<bool *>(raw); };
        assert(!encoder->encode(mel, 2, key, value, 1, abort, &cancelled));
        assert(executed() == 0);
        cancelled = false;
        assert(encoder->encode(mel, 2, key, value, 1, abort, &cancelled));
        assert(key[0] == 1 && value[0] == 2);
    }
    assert(destroyed() == 1);
    {
        auto encoder = keyvox::ExternalEncoder::load(argv[1], "execution-failure", "", dimensions);
        assert(encoder);
        assert(!encoder->encode(mel, 2, key, value, 1, nullptr, nullptr));
        const int failedCalls = executed();
        assert(!encoder->encode(mel, 2, key, value, 1, nullptr, nullptr));
        assert(executed() == failedCalls);
    }
    assert(created() == destroyed());
    {
        auto encoder = keyvox::ExternalEncoder::load(argv[1], "available", "", dimensions);
        assert(encoder);
        block(true);
        auto run = [&] {
            uint16_t localKey{}, localValue{};
            assert(encoder->encode(mel, 2, &localKey, &localValue, 1, nullptr, nullptr));
        };
        std::thread first(run);
        while (!active()) std::this_thread::yield();
        std::atomic<bool> secondStarted{false};
        std::thread second([&] { secondStarted = true; run(); });
        while (!secondStarted.load()) std::this_thread::yield();
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
        const bool serialized = active() == 1;
        block(false);
        first.join(); second.join();
        assert(serialized);
    }
    assert(created() == destroyed());
    dlclose(library);
}
