#include "encoder.h"
#if !defined(__APPLE__)
// Older/native CPU builds remain usable when the optional extension is absent.
extern bool keyvox_whisper_load_encoder(void *, const char *, const char *, const char *)
    __attribute__((weak));
#endif

bool kv_whisper_configure_encoder(void *context, const char *plugin_path,
                                 const char *model_path, const char *runtime_directory) {
#if !defined(__APPLE__)
    if (keyvox_whisper_load_encoder)
        return keyvox_whisper_load_encoder(context, plugin_path, model_path, runtime_directory);
#endif
    return false;
}
