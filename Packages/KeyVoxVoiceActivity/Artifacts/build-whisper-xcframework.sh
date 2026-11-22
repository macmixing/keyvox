#!/bin/bash
#
# Builds the vendored whisper.xcframework from the pinned whisper.cpp release source with its
# Metal kernels compiled ahead of time into default.metallib, instead of embedded as source that
# every process compiles on its first load.
#
# Usage: build-whisper-xcframework.sh <work-directory>
# The finished framework replaces Artifacts/whisper.xcframework next to this script.

set -euo pipefail

WHISPER_TAG=b5130
WHISPER_COMMIT=927cfce34f31707e17f2bff35c349632fb9e2c3a

IOS_MIN_OS_VERSION=16.4
MACOS_MIN_OS_VERSION=13.3

script_dir="$(cd "$(dirname "$0")" && pwd)"
work_dir="${1:?usage: $0 <work-directory>}"
source_dir="${work_dir}/whisper.cpp"

rm -rf "${source_dir}"
git clone --quiet --depth 1 --branch "${WHISPER_TAG}" https://github.com/ggml-org/whisper.cpp.git "${source_dir}"
if [[ "$(git -C "${source_dir}" rev-parse HEAD)" != "${WHISPER_COMMIT}" ]]; then
    echo "error: ${WHISPER_TAG} no longer points at ${WHISPER_COMMIT}" >&2
    exit 1
fi
cd "${source_dir}"

XCODE_VERSION=$(xcodebuild -version 2>/dev/null | head -n1 | awk '{ print $2 }')
MAJOR_VERSION=$(echo "${XCODE_VERSION}" | cut -d. -f1)
MINOR_VERSION=$(echo "${XCODE_VERSION}" | cut -d. -f2)
BUILD_STATIC_XCFRAMEWORK=OFF

# The framework layout and library combining steps come from the release script unchanged.
# Each function runs up to the next top-level block, since its heredocs hold column-zero braces.
eval "$(sed -n '/^setup_framework_structure() {/,/^# Create dynamic libraries from static libraries/{/^# Create dynamic/!p;}' build-xcframework.sh)"
eval "$(sed -n '/^combine_static_libraries() {/,/^echo "Building for iOS simulator/{/^echo "Building/!p;}' build-xcframework.sh)"

COMMON_C_FLAGS="-Wno-macro-redefined -Wno-shorten-64-to-32 -Wno-unused-command-line-argument -g"
COMMON_CXX_FLAGS="${COMMON_C_FLAGS}"

# Matches the release script's options except GGML_METAL_EMBED_LIBRARY.
COMMON_CMAKE_ARGS=(
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED=NO
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY=""
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO
    -DCMAKE_XCODE_ATTRIBUTE_DEBUG_INFORMATION_FORMAT="dwarf-with-dsym"
    -DCMAKE_XCODE_ATTRIBUTE_GCC_GENERATE_DEBUGGING_SYMBOLS=YES
    -DCMAKE_XCODE_ATTRIBUTE_COPY_PHASE_STRIP=NO
    -DCMAKE_XCODE_ATTRIBUTE_STRIP_INSTALLED_PRODUCT=NO
    -DCMAKE_XCODE_ATTRIBUTE_DEVELOPMENT_TEAM=ggml
    -DBUILD_SHARED_LIBS=OFF
    -DWHISPER_BUILD_EXAMPLES=OFF
    -DWHISPER_BUILD_TESTS=OFF
    -DWHISPER_BUILD_SERVER=OFF
    -DGGML_METAL_EMBED_LIBRARY=OFF
    -DGGML_BLAS_DEFAULT=ON
    -DGGML_METAL=ON
    -DGGML_METAL_USE_BF16=ON
    -DGGML_NATIVE=OFF
    -DGGML_OPENMP=OFF
    -DWHISPER_COREML=ON
    -DWHISPER_COREML_ALLOW_FALLBACK=ON
    -DCMAKE_C_FLAGS="${COMMON_C_FLAGS}"
    -DCMAKE_CXX_FLAGS="${COMMON_CXX_FLAGS}"
)

cmake -B build-ios-sim -G Xcode \
    "${COMMON_CMAKE_ARGS[@]}" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=${IOS_MIN_OS_VERSION} \
    -DIOS=ON \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT=iphonesimulator \
    -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
    -DCMAKE_XCODE_ATTRIBUTE_SUPPORTED_PLATFORMS=iphonesimulator \
    -DGGML_METAL_TARGET_OS=ios \
    -S .
cmake --build build-ios-sim --config Release -- -quiet

cmake -B build-ios-device -G Xcode \
    "${COMMON_CMAKE_ARGS[@]}" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=${IOS_MIN_OS_VERSION} \
    -DCMAKE_OSX_SYSROOT=iphoneos \
    -DCMAKE_OSX_ARCHITECTURES="arm64" \
    -DCMAKE_XCODE_ATTRIBUTE_SUPPORTED_PLATFORMS=iphoneos \
    -DGGML_METAL_TARGET_OS=ios \
    -S .
cmake --build build-ios-device --config Release -- -quiet

# ggml adds no Metal deployment target for "macos", and its macOS version flag conflicts with the
# tensor library's target flag, so the Metal target is named "macosx".
cmake -B build-macos -G Xcode \
    "${COMMON_CMAKE_ARGS[@]}" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=${MACOS_MIN_OS_VERSION} \
    -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
    -DGGML_METAL_TARGET_OS=macosx \
    -S .
cmake --build build-macos --config Release -- -quiet

setup_framework_structure "build-ios-sim" ${IOS_MIN_OS_VERSION} "ios"
setup_framework_structure "build-ios-device" ${IOS_MIN_OS_VERSION} "ios"
setup_framework_structure "build-macos" ${MACOS_MIN_OS_VERSION} "macos"

combine_static_libraries "build-ios-sim" "Release-iphonesimulator" "ios" "true"
combine_static_libraries "build-ios-device" "Release-iphoneos" "ios" "false"
combine_static_libraries "build-macos" "Release" "macos" "false"

# ggml looks for default.metallib, and ggml-tensor.metallib where the GPU supports the tensor
# API, in the bundle that holds its own code: the framework's resources.
copy_metal_libraries() {
    local build_dir="$1"
    local resources_dir="$2"
    local metallib
    for metallib in default.metallib ggml-tensor.metallib; do
        local built
        built="$(find "${build_dir}/bin" -name "${metallib}" -type f | head -n1)"
        if [[ -z "${built}" ]]; then
            echo "error: ${build_dir} produced no ${metallib}" >&2
            exit 1
        fi
        cp "${built}" "${resources_dir}/${metallib}"
    done
}
copy_metal_libraries "build-ios-sim" "build-ios-sim/framework/whisper.framework"
copy_metal_libraries "build-ios-device" "build-ios-device/framework/whisper.framework"
copy_metal_libraries "build-macos" "build-macos/framework/whisper.framework/Versions/A/Resources"

rm -rf "${work_dir}/whisper.xcframework"
xcodebuild -create-xcframework \
    -framework "$(pwd)/build-ios-sim/framework/whisper.framework" \
    -debug-symbols "$(pwd)/build-ios-sim/dSYMs/whisper.dSYM" \
    -framework "$(pwd)/build-ios-device/framework/whisper.framework" \
    -debug-symbols "$(pwd)/build-ios-device/dSYMs/whisper.dSYM" \
    -framework "$(pwd)/build-macos/framework/whisper.framework" \
    -debug-symbols "$(pwd)/build-macos/dSYMs/whisper.dSYM" \
    -output "${work_dir}/whisper.xcframework"

rm -rf "${script_dir}/whisper.xcframework"
ditto "${work_dir}/whisper.xcframework" "${script_dir}/whisper.xcframework"
