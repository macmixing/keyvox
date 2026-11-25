#!/usr/bin/env bash
# Builds every file of a typing language's predictive data from the sources in <data-dir> into
# <output-dir>: the context model, the sentence openers, the words spelled with capitals, the words
# that follow an unknown word or a common word, and the grammar words, with the vocabulary the
# lists were built from, and, given the language's dictionary words and probabilities (a word, a
# tab, and a probability a line; Tools/KeyVoxTypingModels writes English's as
# work/dictionary_unigrams.tsv), the swipe vocabulary of the words that dictionary lacks.
# <language> names a build in languages.py (en, de, de-bundestag, es, fr).
# The builders share the source readers and the normalizing code, so a change made for one can
# change another's output; rebuild every language after changing any tool here.
# Set PYTHON to the interpreter with requirements.txt installed (default: python3).
set -euo pipefail

if [[ $# -ne 3 && $# -ne 4 ]]; then
  echo "usage: $0 <language> <data-dir> <output-dir> [dictionary-words]" >&2
  exit 1
fi
LANGUAGE="$1"
DATA_DIR="$(cd "$2" && pwd)"
mkdir -p "$3"
OUTPUT_DIR="$(cd "$3" && pwd)"
DICTIONARY_WORDS=""
[[ $# -eq 4 ]] && DICTIONARY_WORDS="$(cd "$(dirname "$4")" && pwd)/$(basename "$4")"
PYTHON="${PYTHON:-python3}"
TOOLS_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$TOOLS_DIR"
IDENTIFIER="$("$PYTHON" languages.py "$LANGUAGE")"

# Each group of steps reads only the sources, the sentences, or its own files, and writes files
# no other group running beside it reads, so the groups run side by side; the steps that read
# several groups' files run once those groups are done.
context_model() {
  "$PYTHON" count_ngrams.py "$DATA_DIR"
  "$PYTHON" write_context_model.py "$DATA_DIR" "$OUTPUT_DIR/context_model.bin"
}
sentence_openers() {
  "$PYTHON" write_word_kinds.py --language "$LANGUAGE" "$DATA_DIR"
  "$PYTHON" count_sentence_openers.py --language "$LANGUAGE" "$DATA_DIR"
  "$PYTHON" write_sentence_openers.py --language "$LANGUAGE" "$DATA_DIR" --output "$OUTPUT_DIR/sentence_openers.txt"
}
capitalized_spellings() {
  "$PYTHON" write_vocabulary.py --language "$LANGUAGE" "$DATA_DIR" "$OUTPUT_DIR/vocabulary.txt" "$OUTPUT_DIR/common_vocabulary.txt"
  "$PYTHON" write_capitalized_spellings.py --language "$LANGUAGE" "$DATA_DIR" \
    "$OUTPUT_DIR/vocabulary.txt" "$OUTPUT_DIR/common_vocabulary.txt" "$OUTPUT_DIR/capitalized_spellings_$IDENTIFIER.txt"
}
swipe_counts() {
  "$PYTHON" count_swipe_words.py --language "$LANGUAGE" "$DATA_DIR"
  ./scowl_words.sh 80 "$OUTPUT_DIR/spelling_list.txt" A,B,Z,C,D
}
trap 'kill $(jobs -p) 2>/dev/null || true' EXIT

"$PYTHON" download_sources.py --language "$LANGUAGE" "$DATA_DIR"

# The vocabulary and the words spelled with capitals, and the swipe vocabulary's counts, read
# only the sources.
capitalized_spellings & CAPITALIZED=$!
SWIPE=""
if [[ -n "$DICTIONARY_WORDS" ]]; then
  swipe_counts & SWIPE=$!
fi

# The context model and the sentence openers read the sentences.
"$PYTHON" extract_sentences.py --language "$LANGUAGE" "$DATA_DIR"
context_model & CONTEXT=$!
sentence_openers & OPENERS=$!
wait "$CONTEXT"
wait "$OPENERS"
wait "$CAPITALIZED"

# Words that follow an unknown word, and a common word, and the grammar words: the counts, the
# vocabulary, and the word kinds.
"$PYTHON" write_unknown_word_followers.py "$DATA_DIR" "$OUTPUT_DIR/vocabulary.txt" "$OUTPUT_DIR/unknown_word_followers.txt" &
UNKNOWN=$!
"$PYTHON" write_word_followers.py "$DATA_DIR" "$OUTPUT_DIR/vocabulary.txt" "$OUTPUT_DIR/word_followers.txt" &
FOLLOWERS=$!
"$PYTHON" write_grammar_words.py "$DATA_DIR" "$OUTPUT_DIR/grammar_words.txt"
wait "$UNKNOWN"
wait "$FOLLOWERS"

# The swipe vocabulary: the words people write that the dictionary lacks.
if [[ -n "$SWIPE" ]]; then
  wait "$SWIPE"
  "$PYTHON" write_swipe_vocabulary.py --language "$LANGUAGE" "$DATA_DIR" "$DICTIONARY_WORDS" \
    "$OUTPUT_DIR/spelling_list.txt" "$OUTPUT_DIR/swipe_vocabulary.txt"
fi
