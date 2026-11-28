#!/usr/bin/env bash
# Builds every typing model the predictive keyboard bundles for a typing language from the sources
# in <data-dir>, into <data-dir>/built under the names of the package's typing language folder: the
# LatinIME dictionary (dictionary/), the correction and completion rankers and the autocorrect
# decision model (.kvtr), and the accent overlay.
#
# English (the default) is built from its pinned sources and ITE's typing. Any other language
# (--language) is built from its Tools/KeyVoxLanguageModel build, linked in as
# <data-dir>/sources/language-build, and its rankers learn from simulated typing, with the typo
# simulator's English calibration linked in as <data-dir>/sources/typo-calibration (an English
# data directory's work/simulation after the simulator's steps; see the README). --language-file
# reads the language's language.json from outside the package.
#
# The bundled files in the package are left alone: each built file is compared with the bundled
# one, and with --check the script fails if any differ or the package does not bundle the
# language. Measure before copying.
# Set PYTHON to the interpreter with requirements.txt installed (default: python3).
set -euo pipefail

usage() {
  echo "usage: $0 <data-dir> [--check] [--language <language>] [--language-file <language.json>]" >&2
  exit 1
}

[[ $# -ge 1 ]] || usage
DATA_ARGUMENT="$1"
shift
CHECK=0
LANGUAGE=en
LANGUAGE_FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) CHECK=1; shift ;;
    --language) [[ $# -ge 2 ]] || usage; LANGUAGE="$2"; shift 2 ;;
    --language-file) [[ $# -ge 2 ]] || usage; LANGUAGE_FILE="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"; shift 2 ;;
    *) usage ;;
  esac
done
mkdir -p "$DATA_ARGUMENT"
DATA_DIR="$(cd "$DATA_ARGUMENT" && pwd)"
PYTHON="${PYTHON:-python3}"
cd "$(dirname "$0")"

LANGUAGE_OPTIONS=(--language "$LANGUAGE")
if [[ -n "$LANGUAGE_FILE" ]]; then
  LANGUAGE_OPTIONS+=(--language-file "$LANGUAGE_FILE")
fi
TEXT="$("$PYTHON" typing_languages.py text "${LANGUAGE_OPTIONS[@]}")"

"$PYTHON" download_sources.py "$DATA_DIR" "${LANGUAGE_OPTIONS[@]}"
./build_native_tools.sh "$DATA_DIR/bin"
mkdir -p "$DATA_DIR/work" "$DATA_DIR/built"

if [[ "$TEXT" == english ]]; then
  # Tatoeba's English sentences as of the cutoff, checked against their recorded SHA-256.
  "$PYTHON" rewind_tatoeba.py "$DATA_DIR"

  # Word lists: the dictionary's words, every spelling's words for accents, and the words
  # that are never corrected.
  ./scowl_word_list.sh "$DATA_DIR" 60 A "$DATA_DIR/work/scowl-60-A.txt"
  ./scowl_word_list.sh "$DATA_DIR" 60 A,B,Z,C,D "$DATA_DIR/work/scowl-60-ABZCD.txt"
  ./scowl_word_list.sh "$DATA_DIR" 50 A,B,Z,C,D "$DATA_DIR/work/scowl-50-ABZCD.txt"
fi

# Dictionary, without the words the profanity list's patterns match, with the language's locale.
"$PYTHON" offensive_words.py "$DATA_DIR" "${LANGUAGE_OPTIONS[@]}"
"$PYTHON" write_dictionary_inputs.py "$DATA_DIR" "${LANGUAGE_OPTIONS[@]}"
DICTIONARY_OPTIONS=()
while IFS= read -r option; do
  DICTIONARY_OPTIONS+=("$option")
done < <("$PYTHON" typing_languages.py dictionary-options "${LANGUAGE_OPTIONS[@]}")
rm -rf "$DATA_DIR/built/dictionary" "$DATA_DIR/work/counted_dictionary"
"$DATA_DIR/bin/write_latinime_dictionary" "${DICTIONARY_OPTIONS[@]}" \
  "$DATA_DIR/work/dictionary_kept_unigrams.tsv" "$DATA_DIR/work/dictionary_kept_ngrams.tsv" \
  "$DATA_DIR/built/dictionary" 2>/dev/null
# The dictionary as counted, which the caches ask as the bundled rankers learned from it, and for
# every other language, so the words left out leave its rankers as they would be without them.
"$DATA_DIR/bin/write_latinime_dictionary" "${DICTIONARY_OPTIONS[@]}" \
  "$DATA_DIR/work/dictionary_unigrams.tsv" "$DATA_DIR/work/dictionary_ngrams.tsv" \
  "$DATA_DIR/work/counted_dictionary" 2>/dev/null

if [[ "$TEXT" == english ]]; then
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
else
  # Rankers and the action model, from typing simulated on the language's sentences and letter
  # layout with the English calibration.
  CALIBRATION="$DATA_DIR/sources/typo-calibration"
  for file in ite_typing.json typo_calibration.json; do
    [[ -f "$CALIBRATION/$file" ]] || {
      echo "$CALIBRATION/$file: missing; link an English data directory's work/simulation" \
        "there after the typo simulator's steps (README, \"Training on simulated typing\")" >&2
      exit 1
    }
  done
  "$PYTHON" measure_accent_typing.py "$DATA_DIR" "${LANGUAGE_OPTIONS[@]}"
  "$PYTHON" write_simulated_records.py "$DATA_DIR" --calibration "$CALIBRATION" "${LANGUAGE_OPTIONS[@]}"
  "$PYTHON" write_feature_context_model.py "$DATA_DIR" "${LANGUAGE_OPTIONS[@]}"
  "$PYTHON" cache_correction_candidates.py "$DATA_DIR" "${LANGUAGE_OPTIONS[@]}"
  "$PYTHON" cache_completion_candidates.py "$DATA_DIR" "${LANGUAGE_OPTIONS[@]}"
  "$PYTHON" train_correction_models.py "$DATA_DIR" "${LANGUAGE_OPTIONS[@]}" >/dev/null
  "$PYTHON" train_completion_ranker.py "$DATA_DIR" "${LANGUAGE_OPTIONS[@]}" >/dev/null
fi
"$PYTHON" export_tree_models.py "$DATA_DIR"

# Accent overlay.
"$PYTHON" write_accent_words.py "$DATA_DIR" "${LANGUAGE_OPTIONS[@]}"
"$PYTHON" write_accent_overlay.py "$DATA_DIR"

chmod -R u+rwX,go+rX "$DATA_DIR/built"
echo "built files in $DATA_DIR/built"

if ! "$PYTHON" compare_with_bundled.py "$DATA_DIR" "${LANGUAGE_OPTIONS[@]}" && [[ $CHECK -eq 1 ]]; then
  exit 1
fi
