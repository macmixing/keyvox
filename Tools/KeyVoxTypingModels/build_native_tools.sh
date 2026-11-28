#!/usr/bin/env bash
# Compiles the LatinIME dictionary writer and the suggestion reader into <output-dir>, against
# the LatinIME sources bundled in Packages/KeyVoxPredictiveKeyboard, so the dictionary is
# written and read by the same native code the keyboard runs.
#
# The suggestion reader orders candidates of equal score with std::sort, which leaves the order
# of ties to the C++ standard library, and the rankers learn from that order. Only the toolchains
# below have been checked to reproduce the bundled files, so any other one is refused.
set -euo pipefail

VERIFIED_COMPILERS=(
  "Apple clang version 21.0.0 (clang-2100.3.34.1)"
  "Apple clang version 21.0.0 (clang-2100.3.33.1)"
  "Apple clang version 21.0.0 (clang-2100.4.1.1)"
)
EXPECTED_LIBCXX_VERSION="220106"

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <output-dir>" >&2
  exit 1
fi
OUTPUT_DIR="$1"
TOOLS_DIR="$(cd "$(dirname "$0")" && pwd)"
NATIVE_DIR="$TOOLS_DIR/../../Packages/KeyVoxPredictiveKeyboard/Sources/KeyVoxPredictiveNative"

COMPILER="$(xcrun clang++ --version | head -1)"
LIBCXX_VERSION="$(echo '#include <version>' | xcrun clang++ -std=c++17 -dM -E -x c++ - \
  | awk '$2 == "_LIBCPP_VERSION" { print $3 }')"
VERIFIED=0
for verified in "${VERIFIED_COMPILERS[@]}"; do
  [[ "$COMPILER" == "$verified" ]] && VERIFIED=1
done
if [[ $VERIFIED -eq 0 || "$LIBCXX_VERSION" != "$EXPECTED_LIBCXX_VERSION" ]]; then
  echo "This toolchain is \"$COMPILER\" with libc++ ${LIBCXX_VERSION:-missing}." >&2
  echo "The bundled rankers were trained on candidates ordered by \"${VERIFIED_COMPILERS[0]}\"" >&2
  echo "with libc++ $EXPECTED_LIBCXX_VERSION, and the files are checked to rebuild the same with:" >&2
  printf '  "%s"\n' "${VERIFIED_COMPILERS[@]:1}" >&2
  echo "Another toolchain may order equal-score candidates differently and train different" >&2
  echo "rankers. Build on one of those." >&2
  exit 1
fi
mkdir -p "$OUTPUT_DIR"

LATINIME_SOURCES=()
while IFS= read -r source; do
  LATINIME_SOURCES+=("$source")
done < <(find "$NATIVE_DIR/latinime" -name '*.cpp' | sort)

for tool in write_latinime_dictionary latinime_suggestions; do
  xcrun clang++ -std=c++17 -O2 -w \
    -I "$NATIVE_DIR/latinime" -I "$NATIVE_DIR" \
    "$TOOLS_DIR/$tool.cpp" "${LATINIME_SOURCES[@]}" \
    -o "$OUTPUT_DIR/$tool"
  echo "built $OUTPUT_DIR/$tool"
done
