// SPDX-License-Identifier: MIT
#include "QnnRuntime.h"
#include <stdexcept>

void QnnRuntime::check(Qnn_ErrorHandle_t result, const char *operation) {
    if (result) throw std::runtime_error(std::string(operation) + ": " + std::to_string(result));
}

std::unique_ptr<QnnRuntime> QnnRuntime::load(const std::string &directory) {
    auto result = std::unique_ptr<QnnRuntime>(new QnnRuntime);
    result->backendLibrary = std::make_unique<DynamicLibrary>(directory + "/libQnnHtp.so");
    result->systemLibrary = std::make_unique<DynamicLibrary>(directory + "/libQnnSystem.so");
    const QnnInterface_t **providers = nullptr;
    uint32_t count = 0;
    auto getProviders = reinterpret_cast<decltype(&QnnInterface_getProviders)>(
        result->backendLibrary->symbol("QnnInterface_getProviders"));
    check(getProviders(&providers, &count), "QNN providers");
    bool compatible = false;
    for (uint32_t i = 0; providers && i < count; ++i) {
        if (!providers[i]) continue;
        const auto &version = providers[i]->apiVersion.coreApiVersion;
        if (version.major == QNN_API_VERSION_MAJOR && version.minor >= QNN_API_VERSION_MINOR) {
            result->api = providers[i]->QNN_INTERFACE_VER_NAME;
            compatible = true; break;
        }
    }
    if (!compatible) throw std::runtime_error("Incompatible QNN backend interface");
    const QnnSystemInterface_t **systemProviders = nullptr;
    auto getSystemProviders = reinterpret_cast<decltype(&QnnSystemInterface_getProviders)>(
        result->systemLibrary->symbol("QnnSystemInterface_getProviders"));
    check(getSystemProviders(&systemProviders, &count), "QNN system providers");
    compatible = false;
    for (uint32_t i = 0; systemProviders && i < count; ++i) {
        if (!systemProviders[i]) continue;
        const auto &version = systemProviders[i]->systemApiVersion;
        if (version.major == QNN_SYSTEM_API_VERSION_MAJOR && version.minor >= QNN_SYSTEM_API_VERSION_MINOR) {
            result->system = systemProviders[i]->QNN_SYSTEM_INTERFACE_VER_NAME;
            compatible = true; break;
        }
    }
    if (!compatible) throw std::runtime_error("Incompatible QNN system interface");
    check(result->api.backendCreate(nullptr, nullptr, &result->backend), "QNN backend creation");
    check(result->api.deviceCreate(nullptr, nullptr, &result->device), "QNN device creation");
    return result;
}

QnnRuntime::~QnnRuntime() {
    if (device) api.deviceFree(device);
    if (backend) api.backendFree(backend);
}
