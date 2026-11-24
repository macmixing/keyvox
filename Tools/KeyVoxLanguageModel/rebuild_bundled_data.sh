#!/usr/bin/env bash
# Rebuilds every file the predictive keyboard bundles for English from the sources in <data-dir>,
# with build_language_data.sh: the context model, the sentence openers, the words spelled with
# capitals, the words that follow an unknown word or a common word, and the grammar words.
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
TOOLS_DIR="$(cd "$(dirname "$0")" && pwd)"
BUNDLED_DIR="$TOOLS_DIR/../../Packages/KeyVoxPredictiveKeyboard/Sources/KeyVoxPredictiveKeyboard/PredictiveData/en"
LINGUISTICS_DIR="$TOOLS_DIR/../../Packages/KeyVoxLinguistics/Sources/KeyVoxLinguistics/Resources"
BUILT_DIR="$DATA_DIR/bundled"

"$TOOLS_DIR/build_language_data.sh" en "$DATA_DIR" "$BUILT_DIR"

differ=0
for file in context_model.bin sentence_openers.txt capitalized_spellings_en.txt unknown_word_followers.txt \
  word_followers.txt grammar_words.txt; do
  destination="$BUNDLED_DIR"
  [[ "$file" == capitalized_spellings_en.txt ]] && destination="$LINGUISTICS_DIR"
  if cmp -s "$BUILT_DIR/$file" "$destination/$file"; then
    echo "$file: same as the bundled file"
    continue
  fi
  differ=1
  if [[ $CHECK -eq 1 ]]; then
    echo "$file: differs from the bundled file"
  else
    cp "$BUILT_DIR/$file" "$destination/$file"
    echo "$file: replaced the bundled file"
  fi
done
if [[ $CHECK -eq 1 && $differ -eq 1 ]]; then
  exit 1
fi
