#!/usr/bin/env bash
set -euo pipefail
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# Build the exact runtime version used by the Apple XCFramework. The install
# prefix is explicit so Android headers/libraries cannot replace host libraries.
if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <android|native> <install-prefix>" >&2
    exit 2
fi
target=$1
prefix=$2
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
echo "Installed Whisper v1.7.6 CPU runtime in $prefix"
