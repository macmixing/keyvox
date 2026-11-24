#!/usr/bin/env bash
# Builds every English typing model the predictive keyboard bundles from the sources in
# <data-dir>, into <data-dir>/built: the LatinIME dictionary (candidate_v3_dict), the
# correction ranker, completion ranker, and action model (.kvtr), and the accent overlay.
# The bundled files in the package are left alone; compare and measure before copying.
# Set PYTHON to the interpreter with requirements.txt installed (default: python3).
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <data-dir>" >&2
  exit 1
fi
mkdir -p "$1"
DATA_DIR="$(cd "$1" && pwd)"
PYTHON="${PYTHON:-python3}"
cd "$(dirname "$0")"

"$PYTHON" download_sources.py "$DATA_DIR"
./build_native_tools.sh "$DATA_DIR/bin"
mkdir -p "$DATA_DIR/work" "$DATA_DIR/built"

# Tatoeba's English sentences as of the pinned export.
"$PYTHON" rewind_tatoeba.py "$DATA_DIR"

# Word lists: the dictionary's words, every spelling's words for accents, and the words
# that are never corrected.
./scowl_word_list.sh "$DATA_DIR" 60 A "$DATA_DIR/work/scowl-60-A.txt"
./scowl_word_list.sh "$DATA_DIR" 60 A,B,Z,C,D "$DATA_DIR/work/scowl-60-ABZCD.txt"
./scowl_word_list.sh "$DATA_DIR" 50 A,B,Z,C,D "$DATA_DIR/work/scowl-50-ABZCD.txt"

# Dictionary.
"$PYTHON" write_dictionary_inputs.py "$DATA_DIR"
rm -rf "$DATA_DIR/built/candidate_v3_dict"
"$DATA_DIR/bin/write_latinime_dictionary" "$DATA_DIR/work/dictionary_unigrams.tsv" \
  "$DATA_DIR/work/dictionary_ngrams.tsv" "$DATA_DIR/built/candidate_v3_dict" 2>/dev/null

# Rankers and the action model.
"$PYTHON" split_ite_events.py "$DATA_DIR"
"$PYTHON" write_feature_context_model.py "$DATA_DIR"
"$PYTHON" cache_correction_candidates.py "$DATA_DIR"
"$PYTHON" cache_completion_candidates.py "$DATA_DIR"
"$PYTHON" train_correction_models.py "$DATA_DIR" >/dev/null
"$PYTHON" train_completion_ranker.py "$DATA_DIR" >/dev/null
"$PYTHON" export_tree_models.py "$DATA_DIR"

# Accent overlay.
"$PYTHON" write_accent_words.py "$DATA_DIR"
"$PYTHON" write_accent_overlay.py "$DATA_DIR"

chmod -R u+rwX,go+rX "$DATA_DIR/built"
echo "built files in $DATA_DIR/built"
