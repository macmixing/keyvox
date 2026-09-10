#pragma once
#include <stdbool.h>
#include <stdint.h>
void keyvox_engine_event(const char *json);
void keyvox_engine_configure(const char *resources, const char *models, const char *dictionary, const char *runtime, const char *soc, const char *app_version);
void keyvox_engine_transcribe(const char *path, int64_t request);
void keyvox_engine_cancel(void);
void keyvox_engine_download(void);
void keyvox_promotions_configure(const char *app_version, bool uses_bundled_manifest, const char *preview_campaign_id);
void keyvox_promotions_refresh(void);
uint8_t *keyvox_engine_compose(const uint8_t *transcript, int32_t transcript_length,
    const uint8_t *preceding, int32_t preceding_length, bool preceding_truncated,
    const uint8_t *following, int32_t following_length, bool following_truncated,
    int32_t *output_length);
void keyvox_engine_free_bytes(uint8_t *bytes);
int keyvox_extract_model_member(const char *archive, const char *member, const char *destination, int64_t size);
