#pragma once
#include <stdint.h>
void keyvox_engine_event(const char *json);
void keyvox_engine_configure(const char *resources, const char *models, const char *dictionary, const char *runtime, const char *soc);
void keyvox_engine_transcribe(const char *path, int64_t request);
void keyvox_engine_cancel(void);
void keyvox_engine_download(void);
int keyvox_extract_model_member(const char *archive, const char *member, const char *destination, int64_t size);
