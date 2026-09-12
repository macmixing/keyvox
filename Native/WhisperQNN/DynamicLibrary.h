// SPDX-License-Identifier: MIT
#pragma once
#include <string>

class DynamicLibrary {
public:
    explicit DynamicLibrary(const std::string &path);
    ~DynamicLibrary();
    DynamicLibrary(const DynamicLibrary &) = delete;
    DynamicLibrary &operator=(const DynamicLibrary &) = delete;
    void *symbol(const char *name) const;
private:
    void *handle = nullptr;
};
