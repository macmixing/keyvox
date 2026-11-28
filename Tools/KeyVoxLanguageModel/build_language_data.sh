#!/usr/bin/env bash
# Builds every file of a typing language's predictive data from the sources in <data-dir> into
# <output-dir>: the context model, the sentence openers, the words spelled with capitals, the words
# that follow an unknown word or a common word, and the grammar words, with the vocabulary the
# lists were built from, and, given the language's dictionary words and probabilities (a word, a
# tab, and a probability a line; Tools/KeyVoxTypingModels writes English's as
# work/dictionary_unigrams.tsv), the swipe vocabulary of the words that dictionary lacks, with
# the words of the language's swipe dataset, leaving out the words of [left-out-words], a pattern a
# line (Tools/KeyVoxTypingModels writes English's as work/offensive_words.txt).
# <language> names a build in languages.py (en, de, de-bundestag, es, fr).
# The builders share the source readers and the normalizing code, so a change made for one can
# change another's output; rebuild every language after changing any tool here.
# Set PYTHON to the interpreter with requirements.txt installed (default: python3).
set -euo pipefail

if [[ $# -lt 3 || $# -gt 5 ]]; then
  echo "usage: $0 <language> <data-dir> <output-dir> [dictionary-words [left-out-words]]" >&2
  exit 1
fi
LANGUAGE="$1"
DATA_DIR="$(cd "$2" && pwd)"
mkdir -p "$3"
OUTPUT_DIR="$(cd "$3" && pwd)"
DICTIONARY_WORDS=""
[[ $# -ge 4 ]] && DICTIONARY_WORDS="$(cd "$(dirname "$4")" && pwd)/$(basename "$4")"
LEAVE_OUT=()
[[ $# -eq 5 ]] && LEAVE_OUT=(--leave-out "$(cd "$(dirname "$5")" && pwd)/$(basename "$5")")
PYTHON="${PYTHON:-python3}"
TOOLS_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$TOOLS_DIR"
IDENTIFIER="$("$PYTHON" languages.py "$LANGUAGE")"

# Each group of steps reads only the sources, the sentences, or its own files, and writes files
# no other group running beside it reads, so the groups run side by side; the steps that read
# several groups' files run once those groups are done.
context_model() {
  "$PYTHON" count_ngrams.py --language "$LANGUAGE" "$DATA_DIR"
  "$PYTHON" write_context_model.py --language "$LANGUAGE" "$DATA_DIR" "$OUTPUT_DIR/context_model.bin"
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
  "$PYTHON" count_swiped_words.py --language "$LANGUAGE" "$DATA_DIR"
  ./scowl_words.sh 80 "$OUTPUT_DIR/spelling_list.txt" A,B,Z,C,D
}

# Every step runs in the background in a process group of its own (job control, `set -m`), so
# stopping a step stops every program it started. A step that fails signals the build (USR1),
# whose `wait` the signal interrupts at once, and the build stops every step still running. This
# works in the bash 3.2 macOS ships, which has no `wait -n`.
set -m
# The process groups of the steps not yet waited for.
STEP_GROUPS=""
forget_step() {
  local group kept=""
  for group in $STEP_GROUPS; do
    [[ "$group" == "$1" ]] || kept="$kept $group"
  done
  STEP_GROUPS="$kept"
}
# Stops the steps not yet waited for that are still running; a finished step's process group ID
# may already belong to another program.
stop_steps() {
  local group running
  running=" $(jobs -pr | tr '\n' ' ') "
  for group in $STEP_GROUPS; do
    [[ "$running" == *" $group "* ]] && kill -TERM -- "-$group" 2>/dev/null || true
  done
}
step_failed() {
  # Another step failing meanwhile must not end the build with USR1's default action.
  trap '' USR1
  trap - EXIT
  stop_steps
  echo "$0: a step failed; every step still running was stopped" >&2
  exit 1
}
trap step_failed USR1
trap stop_steps EXIT

# Starts a step, a function or a command with its arguments; STEP is its process ID. Errors stop
# the step as `set -e` does, which a step run inside `||` would not.
start() {
  (
    set +e
    (set -e; "$@")
    [[ $? -eq 0 ]] || kill -USR1 $$
  ) &
  STEP=$!
  STEP_GROUPS="$STEP_GROUPS $STEP"
}
# Waits for the steps with these process IDs.
finish() {
  local step
  for step in "$@"; do
    wait "$step"
    forget_step "$step"
  done
}

start "$PYTHON" download_sources.py --language "$LANGUAGE" "$DATA_DIR"
finish "$STEP"

# The vocabulary and the words spelled with capitals, and the swipe vocabulary's counts, read
# only the sources.
start capitalized_spellings; CAPITALIZED=$STEP
SWIPE=""
if [[ -n "$DICTIONARY_WORDS" ]]; then
  start swipe_counts; SWIPE=$STEP
fi

# The context model and the sentence openers read the sentences.
start "$PYTHON" extract_sentences.py --language "$LANGUAGE" "$DATA_DIR"
finish "$STEP"
start context_model; CONTEXT=$STEP
start sentence_openers; OPENERS=$STEP
finish "$CONTEXT" "$OPENERS" "$CAPITALIZED"

# Words that follow an unknown word, and a common word, and the grammar words: the counts, the
# vocabulary, and the word kinds.
start "$PYTHON" write_unknown_word_followers.py "$DATA_DIR" "$OUTPUT_DIR/vocabulary.txt" "$OUTPUT_DIR/unknown_word_followers.txt"
UNKNOWN=$STEP
start "$PYTHON" write_word_followers.py "$DATA_DIR" "$OUTPUT_DIR/vocabulary.txt" "$OUTPUT_DIR/word_followers.txt"
FOLLOWERS=$STEP
start "$PYTHON" write_grammar_words.py "$DATA_DIR" "$OUTPUT_DIR/grammar_words.txt"
finish "$UNKNOWN" "$FOLLOWERS" "$STEP"

# The swipe vocabulary: the words people write that the dictionary lacks.
if [[ -n "$SWIPE" ]]; then
  finish "$SWIPE"
  start "$PYTHON" write_swipe_vocabulary.py --language "$LANGUAGE" "$DATA_DIR" "$DICTIONARY_WORDS" \
    "$OUTPUT_DIR/spelling_list.txt" "$OUTPUT_DIR/swipe_vocabulary.txt" ${LEAVE_OUT[@]+"${LEAVE_OUT[@]}"}
  finish "$STEP"
fi
