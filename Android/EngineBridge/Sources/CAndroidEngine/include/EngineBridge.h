#pragma once
#include <stdint.h>
void keyvox_engine_event(const char *json);
void keyvox_engine_configure(const char *resources, const char *models, const char *dictionary);
void keyvox_engine_transcribe(const char *path, int64_t request);
void keyvox_engine_cancel(void);
void keyvox_engine_download(void);
