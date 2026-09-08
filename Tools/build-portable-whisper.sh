#!/usr/bin/env bash
set -euo pipefail
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# Build the exact runtime version used by the Apple XCFramework. The install
# prefix is explicit so Android headers/libraries cannot replace host libraries.
if [[ $# -lt 2 || $# -gt 3 ]]; then
    echo "Usage: $0 <android|native> <install-prefix> [cpu|vulkan]" >&2
    exit 2
fi
target=$1
prefix=$2
backend=${3:-cpu}
case "$backend" in
    cpu) ;;
    vulkan) [[ "$target" == android ]] || { echo "Vulkan packaging currently requires the Android NDK" >&2; exit 2; } ;;
    *) echo "Unsupported backend: $backend" >&2; exit 2 ;;
esac
case "$prefix" in
    /*) ;;
    *) echo "install-prefix must be absolute" >&2; exit 2 ;;
esac
case "$target" in
    android) : "${ANDROID_NDK_ROOT:?Set ANDROID_NDK_ROOT to the installed NDK}" ;;
    native) ;;
    *) echo "Unsupported target: $target" >&2; exit 2 ;;
esac

work=$(mktemp -d "${TMPDIR:-/tmp}/keyvox-whisper.XXXXXX")
trap 'rm -rf "$work"' EXIT
curl --fail --location --retry 3 \
    https://codeload.github.com/ggml-org/whisper.cpp/tar.gz/refs/tags/v1.7.6 \
    --output "$work/source.tar.gz"
echo "166140e9a6d8a36f787a2bd77f8f44dd64874f12dd8359ff7c1f4f9acb86202e  $work/source.tar.gz" \
    | shasum -a 256 --check
tar -xzf "$work/source.tar.gz" -C "$work"

options=(
    -DCMAKE_BUILD_TYPE=Release
    "-DCMAKE_INSTALL_PREFIX=$prefix"
    -DCMAKE_INSTALL_LIBDIR=lib
    -DBUILD_SHARED_LIBS=OFF
    -DWHISPER_BUILD_TESTS=OFF
    -DWHISPER_BUILD_EXAMPLES=OFF
    -DWHISPER_BUILD_SERVER=OFF
    -DGGML_NATIVE=OFF
    -DGGML_METAL=OFF
    -DGGML_ACCELERATE=OFF
    -DGGML_OPENMP=OFF
)
if [[ "$target" == android ]]; then
    options+=(
        "-DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake"
        -DANDROID_ABI=arm64-v8a
        -DANDROID_PLATFORM=android-28
        -DANDROID_STL=c++_shared
    )
fi
if [[ "$backend" == vulkan ]]; then
    headers_revision=409c16be502e39fe70dd6fe2d9ad4842ef2c9a53
    curl --fail --location --retry 3 \
        "https://codeload.github.com/KhronosGroup/Vulkan-Headers/tar.gz/$headers_revision" \
        --output "$work/vulkan-headers.tar.gz"
    echo "dc96688e8cf01f2f0a8f31a41fa76a7f8d1e27f022e31bbd3a59ff40a24da9d6  $work/vulkan-headers.tar.gz" \
        | shasum -a 256 --check
    tar -xzf "$work/vulkan-headers.tar.gz" -C "$work"
    headers="$work/Vulkan-Headers-$headers_revision"
    cmp "$headers/LICENSES/Apache-2.0.txt" "$script_dir/Licenses/Vulkan-Headers-Apache-2.0.txt"
    ndk_hosts=("$ANDROID_NDK_ROOT"/toolchains/llvm/prebuilt/*)
    [[ ${#ndk_hosts[@]} -eq 1 ]] || { echo "Expected one NDK host toolchain" >&2; exit 2; }
    ndk_host=${ndk_hosts[0]##*/}
    patch --batch --forward -p1 -d "$work/whisper.cpp-1.7.6" \
        < "$script_dir/Patches/whisper-vulkan-query-reset.patch"
    options+=(
        -DGGML_VULKAN=ON
        "-DVulkan_INCLUDE_DIR=$headers/include"
        "-DVulkan_LIBRARY=${ndk_hosts[0]}/sysroot/usr/lib/aarch64-linux-android/28/libvulkan.so"
        "-DVulkan_GLSLC_EXECUTABLE=$ANDROID_NDK_ROOT/shader-tools/$ndk_host/glslc"
    )
fi
cmake -S "$work/whisper.cpp-1.7.6" -B "$work/build" "${options[@]}"
cmake --build "$work/build" --parallel
cmake --install "$work/build"
install -m 644 "$work/whisper.cpp-1.7.6/LICENSE" "$prefix/WHISPER-LICENSE"
mkdir -p "$prefix/share/licenses/keyvox-speech"
install -m 644 "$script_dir/Licenses/Whisper-CPU-NOTICES.txt" \
    "$prefix/share/licenses/keyvox-speech/Whisper-CPU-NOTICES.txt"
if [[ "$target" == android ]]; then
    install -m 644 "$ANDROID_NDK_ROOT/NOTICE" \
        "$prefix/share/licenses/keyvox-speech/ANDROID-NDK-NOTICE"
    install -m 644 "$ANDROID_NDK_ROOT/NOTICE.toolchain" \
        "$prefix/share/licenses/keyvox-speech/ANDROID-NDK-TOOLCHAIN-NOTICE"
fi
if [[ "$backend" == vulkan ]]; then
    install -m 644 "$script_dir/Licenses/Vulkan-Headers-Apache-2.0.txt" \
        "$prefix/share/licenses/keyvox-speech/Vulkan-Headers-Apache-2.0.txt"
    install -m 644 "$script_dir/Licenses/Vulkan-Headers-NOTICES.txt" \
        "$prefix/share/licenses/keyvox-speech/Vulkan-Headers-NOTICES.txt"
fi
echo "Installed Whisper v1.7.6 $backend runtime (CPU retained) in $prefix"
