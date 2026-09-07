#!/usr/bin/env bash
set -euo pipefail
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ $# -ne 1 || "$1" != /* ]]; then
    echo "Usage: $0 <absolute-install-prefix>" >&2
    exit 2
fi
: "${ANDROID_NDK_ROOT:?Set ANDROID_NDK_ROOT to the installed NDK}"
prefix=$1
source_revision=e75de9b6b9b688fd293aa22f7e27aa724ea286f8
ggml_revision=e705c5fed490514458bdd2eaddc43bd098fcce9b
work=$(mktemp -d "${TMPDIR:-/tmp}/keyvox-parakeet.XXXXXX")
trap 'rm -rf "$work"' EXIT

# Fetch only the two audited source trees. No optional dependency fetches.
git init -q "$work/source"
git -C "$work/source" fetch --depth 1 https://github.com/mudler/parakeet.cpp.git "$source_revision"
git -C "$work/source" switch --detach FETCH_HEAD
test "$(git -C "$work/source" rev-parse HEAD)" = "$source_revision"
test "$(git -C "$work/source" rev-parse HEAD:third_party/ggml)" = "$ggml_revision"
git init -q "$work/source/third_party/ggml"
git -C "$work/source/third_party/ggml" fetch --depth 1 https://github.com/ggml-org/ggml.git "$ggml_revision"
git -C "$work/source/third_party/ggml" switch --detach FETCH_HEAD
test "$(git -C "$work/source/third_party/ggml" rev-parse HEAD)" = "$ggml_revision"
# Upstream CMake only warns on a failed patch; make that failure fatal here.
bash "$work/source/scripts/apply_ggml_patches.sh"

cmake -S "$work/source" -B "$work/build" \
    "-DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-28 -DANDROID_STL=c++_shared \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    "-DCMAKE_SHARED_LINKER_FLAGS=-Wl,--exclude-libs,ALL -Wl,--version-script=$script_dir/exports.map" \
    -DPARAKEET_SHARED=ON -DPARAKEET_BUILD_CLI=OFF -DPARAKEET_BUILD_SERVER=OFF \
    -DPARAKEET_BUILD_TESTS=OFF -DBUILD_SHARED_LIBS=OFF \
    -DPARAKEET_GGML_CUDA=OFF -DPARAKEET_GGML_METAL=OFF \
    -DPARAKEET_GGML_VULKAN=OFF -DPARAKEET_GGML_HIP=OFF \
    -DGGML_NATIVE=OFF -DGGML_OPENMP=OFF -DGGML_BLAS=OFF -DGGML_ACCELERATE=OFF \
    -DGGML_LLAMAFILE=OFF -DGGML_CPU_HBM=OFF -DGGML_CPU_KLEIDIAI=OFF \
    -DGGML_BACKEND_DL=OFF -DGGML_CCACHE=OFF
cmake --build "$work/build" --parallel "${KEYVOX_BUILD_JOBS:-6}"
python3 "$script_dir/verify-library.py" "$work/build/libparakeet.so" "$ANDROID_NDK_ROOT"

mkdir -p "$prefix/lib" "$prefix/include" "$prefix/share/licenses/keyvox-parakeet"
install -m 755 "$work/build/libparakeet.so" "$prefix/lib/libparakeet.so"
install -m 644 "$work/source/include/parakeet_capi.h" "$prefix/include/parakeet_capi.h"
notices="$prefix/share/licenses/keyvox-parakeet"
install -m 644 "$work/source/LICENSE" "$notices/PARAKEET-LICENSE.txt"
install -m 644 "$work/source/third_party/ggml/LICENSE" "$notices/GGML-LICENSE.txt"
install -m 644 "$script_dir/CPU-NOTICES.txt" "$notices/CPU-NOTICES.txt"
install -m 644 "$script_dir/README.md" "$notices/PROVENANCE.md"
install -m 644 "$ANDROID_NDK_ROOT/NOTICE" "$notices/ANDROID-NDK-NOTICE"
install -m 644 "$ANDROID_NDK_ROOT/NOTICE.toolchain" "$notices/ANDROID-NDK-TOOLCHAIN-NOTICE"
echo "Installed isolated Parakeet CPU runtime in $prefix"
