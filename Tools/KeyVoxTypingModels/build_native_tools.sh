#!/usr/bin/env bash
# Compiles the LatinIME dictionary writer and the suggestion reader into <output-dir>, against
# the LatinIME sources bundled in Packages/KeyVoxPredictiveKeyboard, so the dictionary is
# written and read by the same native code the keyboard runs.
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <output-dir>" >&2
  exit 1
fi
OUTPUT_DIR="$1"
TOOLS_DIR="$(cd "$(dirname "$0")" && pwd)"
NATIVE_DIR="$TOOLS_DIR/../../Packages/KeyVoxPredictiveKeyboard/Sources/KeyVoxPredictiveNative"
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
