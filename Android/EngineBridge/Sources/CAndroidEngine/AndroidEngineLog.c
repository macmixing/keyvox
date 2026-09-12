#include "EngineBridge.h"
#include <android/log.h>

void keyvox_engine_log_info(const char *message) {
    if (message) __android_log_write(ANDROID_LOG_INFO, "KeyVoxEngine", message);
}
