#!/usr/bin/env bash
# Builds every file of a typing language's predictive data from the sources in <data-dir> into
# <output-dir>: the context model, the sentence openers, the words spelled with capitals, the words
# that follow an unknown word or a common word, and the grammar words, with the vocabulary the
# lists were built from. <language> names a build in languages.py (en, de, de-bundestag, es, fr).
# The builders share the source readers and the normalizing code, so a change made for one can
# change another's output; rebuild every language after changing any tool here.
# Set PYTHON to the interpreter with requirements.txt installed (default: python3).
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 <language> <data-dir> <output-dir>" >&2
  exit 1
fi
LANGUAGE="$1"
DATA_DIR="$(cd "$2" && pwd)"
mkdir -p "$3"
OUTPUT_DIR="$(cd "$3" && pwd)"
PYTHON="${PYTHON:-python3}"
TOOLS_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$TOOLS_DIR"
IDENTIFIER="$("$PYTHON" languages.py "$LANGUAGE")"

"$PYTHON" download_sources.py --language "$LANGUAGE" "$DATA_DIR"
"$PYTHON" extract_sentences.py --language "$LANGUAGE" "$DATA_DIR"

# Context model.
"$PYTHON" count_ngrams.py "$DATA_DIR"
"$PYTHON" write_context_model.py "$DATA_DIR" "$OUTPUT_DIR/context_model.bin"

# Sentence openers.
"$PYTHON" write_word_kinds.py --language "$LANGUAGE" "$DATA_DIR"
"$PYTHON" count_sentence_openers.py --language "$LANGUAGE" "$DATA_DIR"
"$PYTHON" write_sentence_openers.py --language "$LANGUAGE" "$DATA_DIR" --output "$OUTPUT_DIR/sentence_openers.txt"

# The vocabulary, and the words spelled with capitals.
"$PYTHON" write_vocabulary.py --language "$LANGUAGE" "$DATA_DIR" "$OUTPUT_DIR/vocabulary.txt" "$OUTPUT_DIR/common_vocabulary.txt"
"$PYTHON" write_capitalized_spellings.py --language "$LANGUAGE" "$DATA_DIR" \
  "$OUTPUT_DIR/vocabulary.txt" "$OUTPUT_DIR/common_vocabulary.txt" "$OUTPUT_DIR/capitalized_spellings_$IDENTIFIER.txt"

# Words that follow an unknown word, and a common word.
"$PYTHON" write_unknown_word_followers.py "$DATA_DIR" "$OUTPUT_DIR/vocabulary.txt" "$OUTPUT_DIR/unknown_word_followers.txt"
"$PYTHON" write_word_followers.py "$DATA_DIR" "$OUTPUT_DIR/vocabulary.txt" "$OUTPUT_DIR/word_followers.txt"

# Grammar words.
"$PYTHON" write_grammar_words.py "$DATA_DIR" "$OUTPUT_DIR/grammar_words.txt"
