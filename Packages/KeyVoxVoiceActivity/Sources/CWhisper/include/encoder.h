#ifndef KEYVOX_ENCODER_SHIM_H
#define KEYVOX_ENCODER_SHIM_H
#include <stdbool.h>
bool kv_whisper_configure_encoder(void *context, const char *plugin_path,
                                 const char *model_path, const char *runtime_directory);
#endif
