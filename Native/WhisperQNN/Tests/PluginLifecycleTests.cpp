// SPDX-License-Identifier: MIT
#include "../../../Tools/WhisperEncoder/include/keyvox-whisper-encoder.h"
#include <cassert>
#include <dlfcn.h>
#include <vector>
int main(int argc, char **argv) {
    assert(argc == 4);
    void *library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    assert(library);
    auto create = reinterpret_cast<kv_whisper_encoder_create_v1>(dlsym(library, "keyvox_whisper_encoder_create_v1"));
    assert(create);
    kv_whisper_encoder_dimensions dimensions{80,1500,512,8,6};
    kv_whisper_encoder_instance instance{};
    assert(!create(nullptr, argv[3], &dimensions, &instance));
    assert(!instance.instance);
    assert(!create(argv[2], nullptr, &dimensions, &instance));
    assert(!instance.instance);
    auto wrong = dimensions; wrong.hidden_size /= 2;
    assert(!create(argv[2], argv[3], &wrong, &instance));
    assert(!instance.instance);
    std::vector<float> mel(dimensions.mel_bands * dimensions.audio_frames * 2);
    const size_t count = dimensions.decoder_layers * dimensions.audio_frames * dimensions.hidden_size;
    std::vector<uint16_t> key(count, 7), value(count, 11);
    for (int repeat=0; repeat<3; ++repeat) {
        assert(create(argv[2], argv[3], &dimensions, &instance));
        assert(instance.instance && instance.encode && instance.destroy);
        assert(!instance.encode(instance.instance, mel.data(), mel.size(), key.data(), value.data(), count,
            [](void *) { return true; }, nullptr));
        assert(key.front()==7 && key.back()==7 && value.front()==11 && value.back()==11);
        assert(!instance.encode(instance.instance, mel.data(), mel.size()-1, key.data(), value.data(), count, nullptr, nullptr));
        instance.destroy(instance.instance);
        instance = {};
    }
    dlclose(library);
}
