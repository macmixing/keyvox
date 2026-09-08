// SPDX-License-Identifier: MIT
#pragma once
#include "DynamicLibrary.h"
#include <QnnInterface.h>
#include <System/QnnSystemInterface.h>
#include <memory>

class QnnRuntime {
public:
    static std::unique_ptr<QnnRuntime> load(const std::string &directory);
    ~QnnRuntime();
    QNN_INTERFACE_VER_TYPE api{};
    QNN_SYSTEM_INTERFACE_VER_TYPE system{};
    Qnn_BackendHandle_t backend = nullptr;
    Qnn_DeviceHandle_t device = nullptr;
    static void check(Qnn_ErrorHandle_t result, const char *operation);
private:
    QnnRuntime() = default;
    std::unique_ptr<DynamicLibrary> backendLibrary;
    std::unique_ptr<DynamicLibrary> systemLibrary;
};
