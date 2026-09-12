// SPDX-License-Identifier: MIT
#ifndef KEYVOX_WHISPER_ENCODER_H
#define KEYVOX_WHISPER_ENCODER_H
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Native Whisper integration boundary. No application/UI or download ownership.
typedef struct {
    uint32_t mel_bands;
    uint32_t audio_frames;
    uint32_t hidden_size;
    uint32_t attention_heads;
    uint32_t decoder_layers;
} kv_whisper_encoder_dimensions;

typedef bool (*kv_whisper_encoder_abort)(void *user_data);

typedef struct {
    void *instance;
    // Input: row-major Float32 mel features, [mel_bands, audio_frames * 2].
    // Outputs: IEEE FP16 cross-attention caches in Whisper's non-flash layout.
    // K: [layer, frame, hidden], scaled by head_size^-1/4.
    // V: [layer, hidden, frame], unscaled. Both contain cache_elements entries.
    // Calls are serialized by the context owner. No pointer may be retained.
    bool (*encode)(void *instance, const float *mel, size_t mel_elements,
                   uint16_t *key, uint16_t *value, size_t cache_elements,
                   kv_whisper_encoder_abort abort, void *abort_data);
    void (*destroy)(void *instance);
} kv_whisper_encoder_instance;

// A plugin exports this symbol. Failed creation must release partial resources
// and leave output zeroed. The caller owns a successful instance until destroy.
typedef bool (*kv_whisper_encoder_create_v1)(
    const char *model_path, const char *runtime_directory,
    const kv_whisper_encoder_dimensions *dimensions,
    kv_whisper_encoder_instance *output);

// Configure once, before inference. False leaves the existing native encoder
// available. An inference-time plugin failure disables it for this context.
bool keyvox_whisper_load_encoder(void *context, const char *plugin_path,
                                const char *model_path, const char *runtime_directory);

#ifdef __cplusplus
}
#endif
#endif
