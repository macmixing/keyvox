#!/usr/bin/env bash
# Builds every English typing model the predictive keyboard bundles from the sources in
# <data-dir>, into <data-dir>/built under the names of the package's English typing language
# folder: the LatinIME dictionary (dictionary/), the correction and completion rankers and the
# autocorrect decision model (.kvtr), and the accent overlay.
# The bundled files in the package are left alone: each built file is compared with the bundled
# one, and with --check the script fails if any differ. Measure before copying.
# Set PYTHON to the interpreter with requirements.txt installed (default: python3).
set -euo pipefail

usage() {
  echo "usage: $0 <data-dir> [--check]" >&2
  exit 1
}

[[ $# -eq 1 || $# -eq 2 ]] || usage
CHECK=0
if [[ $# -eq 2 ]]; then
  [[ "$2" == "--check" ]] || usage
  CHECK=1
fi
mkdir -p "$1"
DATA_DIR="$(cd "$1" && pwd)"
PYTHON="${PYTHON:-python3}"
cd "$(dirname "$0")"

"$PYTHON" download_sources.py "$DATA_DIR"
./build_native_tools.sh "$DATA_DIR/bin"
mkdir -p "$DATA_DIR/work" "$DATA_DIR/built"

# Tatoeba's English sentences as of the cutoff, checked against their recorded SHA-256.
"$PYTHON" rewind_tatoeba.py "$DATA_DIR"

# Word lists: the dictionary's words, every spelling's words for accents, and the words
# that are never corrected.
./scowl_word_list.sh "$DATA_DIR" 60 A "$DATA_DIR/work/scowl-60-A.txt"
./scowl_word_list.sh "$DATA_DIR" 60 A,B,Z,C,D "$DATA_DIR/work/scowl-60-ABZCD.txt"
./scowl_word_list.sh "$DATA_DIR" 50 A,B,Z,C,D "$DATA_DIR/work/scowl-50-ABZCD.txt"

# Dictionary.
"$PYTHON" write_dictionary_inputs.py "$DATA_DIR"
rm -rf "$DATA_DIR/built/dictionary"
"$DATA_DIR/bin/write_latinime_dictionary" "$DATA_DIR/work/dictionary_unigrams.tsv" \
  "$DATA_DIR/work/dictionary_ngrams.tsv" "$DATA_DIR/built/dictionary" 2>/dev/null

# Rankers and the action model.
"$PYTHON" split_ite_events.py "$DATA_DIR"
"$PYTHON" write_feature_context_model.py "$DATA_DIR"
# The caches ask the queries the bundled rankers learned from, as they asked them, so the
# rankers rebuild byte for byte; without --as-bundled they ask for every record the trainers
# read, for training new rankers.
"$PYTHON" cache_correction_candidates.py "$DATA_DIR" --as-bundled
"$PYTHON" cache_completion_candidates.py "$DATA_DIR" --as-bundled
"$PYTHON" train_correction_models.py "$DATA_DIR" >/dev/null
"$PYTHON" train_completion_ranker.py "$DATA_DIR" >/dev/null
"$PYTHON" export_tree_models.py "$DATA_DIR"

# Accent overlay.
"$PYTHON" write_accent_words.py "$DATA_DIR"
"$PYTHON" write_accent_overlay.py "$DATA_DIR"

chmod -R u+rwX,go+rX "$DATA_DIR/built"
echo "built files in $DATA_DIR/built"

if ! "$PYTHON" compare_with_bundled.py "$DATA_DIR" && [[ $CHECK -eq 1 ]]; then
  exit 1
fi
