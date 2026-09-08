// SPDX-License-Identifier: MIT
#include "DynamicLibrary.h"
#include <dlfcn.h>
#include <stdexcept>

DynamicLibrary::DynamicLibrary(const std::string &path) {
    handle = dlopen(path.c_str(), RTLD_NOW | RTLD_LOCAL);
    if (!handle) throw std::runtime_error("Unable to load accelerator library: " + path);
}
DynamicLibrary::~DynamicLibrary() { if (handle) dlclose(handle); }
void *DynamicLibrary::symbol(const char *name) const {
    auto result = dlsym(handle, name);
    if (!result) throw std::runtime_error(std::string("Missing accelerator symbol: ") + name);
    return result;
}
