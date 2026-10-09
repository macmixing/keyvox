#!/usr/bin/env bash
# Rebuilds every file the predictive keyboard bundles from these tools, from the sources in
# <data-dir>: the context model, the sentence openers, and the words spelled with capitals.
# The builders share the source readers and the normalizing code, so a change made for one can
# change another's output; run this after changing any tool here, never a single builder alone.
#
# With --check, the package is left alone: each rebuilt file is compared with the bundled one,
# and the script fails if any differ. Without it, files that differ replace the bundled ones.
# Set PYTHON to the interpreter with requirements.txt installed (default: python3).
set -euo pipefail

usage() {
  echo "usage: $0 <data-dir> [--check]" >&2
  exit 1
}

[[ $# -eq 1 || $# -eq 2 ]] || usage
DATA_DIR="$(cd "$1" && pwd)"
CHECK=0
if [[ $# -eq 2 ]]; then
  [[ "$2" == "--check" ]] || usage
  CHECK=1
fi
PYTHON="${PYTHON:-python3}"
TOOLS_DIR="$(cd "$(dirname "$0")" && pwd)"
BUNDLED_DIR="$TOOLS_DIR/../../Packages/KeyVoxPredictiveKeyboard/Sources/KeyVoxPredictiveKeyboard/PredictiveData"
BUILT_DIR="$DATA_DIR/bundled"
SCRATCH_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$SCRATCH_DIR"
}
trap cleanup EXIT

mkdir -p "$BUILT_DIR"
cd "$TOOLS_DIR"

"$PYTHON" download_sources.py "$DATA_DIR"
"$PYTHON" extract_sentences.py "$DATA_DIR"

# Context model.
"$PYTHON" count_ngrams.py "$DATA_DIR"
"$PYTHON" write_context_model.py "$DATA_DIR" "$BUILT_DIR/context_artifact_800k.bin"

# Sentence openers.
xcrun swiftc -O tag_word_kinds.swift -o "$SCRATCH_DIR/tag_word_kinds"
"$SCRATCH_DIR/tag_word_kinds" "$DATA_DIR/word_kinds.tsv" "$DATA_DIR/sentences/tatoeba.txt" "$DATA_DIR/sentences/oasst2.txt"
"$PYTHON" count_sentence_openers.py "$DATA_DIR"
"$PYTHON" write_sentence_openers.py "$DATA_DIR" \
  --weight youtube-commons=0 --weight oasst2=0.3 --weight tatoeba=10 \
  --output "$BUILT_DIR/sentence_openers.txt"

# Words spelled with capitals.
./scowl_words.sh 60 "$SCRATCH_DIR/scowl-60.txt"
./scowl_words.sh 50 "$SCRATCH_DIR/scowl-50.txt"
"$PYTHON" write_capitalized_spellings.py "$DATA_DIR" "$SCRATCH_DIR/scowl-60.txt" "$SCRATCH_DIR/scowl-50.txt" \
  "$BUILT_DIR/capitalized_spellings.txt"

differ=0
for file in context_artifact_800k.bin sentence_openers.txt capitalized_spellings.txt; do
  if cmp -s "$BUILT_DIR/$file" "$BUNDLED_DIR/$file"; then
    echo "$file: same as the bundled file"
    continue
  fi
  differ=1
  if [[ $CHECK -eq 1 ]]; then
    echo "$file: differs from the bundled file"
  else
    cp "$BUILT_DIR/$file" "$BUNDLED_DIR/$file"
    echo "$file: replaced the bundled file"
  fi
done
if [[ $CHECK -eq 1 && $differ -eq 1 ]]; then
  exit 1
fi
