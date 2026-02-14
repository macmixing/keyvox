#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  train_g2p.sh --cmudict <path> --word-list <path> --output <path>

Description:
  Trains/uses a Phonetisaurus G2P model from CMUdict and emits OOV pronunciations
  in KeyVox signature format: <word>\t<PHONE-PHONE-...>.
EOF
}

CMUDICT_FILE=""
WORD_LIST_FILE=""
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cmudict)
      CMUDICT_FILE="${2:-}"
      shift 2
      ;;
    --word-list)
      WORD_LIST_FILE="${2:-}"
      shift 2
      ;;
    --output)
      OUTPUT_FILE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$CMUDICT_FILE" || -z "$WORD_LIST_FILE" || -z "$OUTPUT_FILE" ]]; then
  usage
  exit 1
fi

if [[ ! -f "$CMUDICT_FILE" ]]; then
  echo "Missing CMUdict input: $CMUDICT_FILE" >&2
  exit 1
fi

if [[ ! -f "$WORD_LIST_FILE" ]]; then
  echo "Missing word list input: $WORD_LIST_FILE" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

TRAIN_LEXICON="$TMP_DIR/train.lexicon.tsv"
PREDICT_WORDS="$TMP_DIR/predict.words.txt"
KNOWN_WORDS="$TMP_DIR/known.words.txt"
OOV_WORDS="$TMP_DIR/oov.words.txt"
MODEL_PATH="$TMP_DIR/g2p-model.fst"
RAW_PREDICTIONS="$TMP_DIR/raw-predictions.tsv"

awk '
  /^;;;|^#/ { next }
  {
    raw=$1
    gsub(/\([0-9]+\)$/, "", raw)
    word=tolower(raw)
    if (word ~ /[^a-z]/) next

    pron=""
    for (i=2; i<=NF; i++) {
      p=$i
      gsub(/[0-9]/, "", p)
      if (pron == "") pron=p
      else pron=pron" "p
    }

    if (pron != "" && !seen[word]++) {
      print word "\t" pron
    }
  }
' "$CMUDICT_FILE" > "$TRAIN_LEXICON"

cut -f1 "$TRAIN_LEXICON" | LC_ALL=C sort -u > "$KNOWN_WORDS"
awk '
  {
    w=tolower($0)
    gsub(/[^a-z]/, "", w)
    if (w == "") next
    if (!seen[w]++) print w
  }
' "$WORD_LIST_FILE" > "$PREDICT_WORDS"

LC_ALL=C comm -23 "$PREDICT_WORDS" "$KNOWN_WORDS" > "$OOV_WORDS"

if [[ ! -s "$OOV_WORDS" ]]; then
  : > "$OUTPUT_FILE"
  exit 0
fi

if command -v phonetisaurus-train >/dev/null 2>&1 && command -v phonetisaurus-apply >/dev/null 2>&1; then
  phonetisaurus-train --lexicon "$TRAIN_LEXICON" --seq1_max 2 --seq2_max 2 --model "$MODEL_PATH"
  phonetisaurus-apply --model "$MODEL_PATH" --word_list "$OOV_WORDS" > "$RAW_PREDICTIONS"
elif command -v phonetisaurus >/dev/null 2>&1; then
  phonetisaurus train --lexicon "$TRAIN_LEXICON" --seq1_max 2 --seq2_max 2 --model "$MODEL_PATH"
  phonetisaurus predict --model "$MODEL_PATH" --word-list "$OOV_WORDS" > "$RAW_PREDICTIONS"
else
  echo "Phonetisaurus binaries not found. Falling back to deterministic signature encoder." >&2
  awk '
    BEGIN { OFS="\t" }
    function code(ch) {
      if (ch ~ /[aeiouy]/) return "A"
      if (ch ~ /[bp]/) return "B"
      if (ch ~ /[ckqg]/) return "K"
      if (ch ~ /[dt]/) return "T"
      if (ch ~ /[fv]/) return "F"
      if (ch == "j") return "J"
      if (ch == "l") return "L"
      if (ch ~ /[mn]/) return "N"
      if (ch == "r") return "R"
      if (ch ~ /[szx]/) return "S"
      if (ch ~ /[0-9]/) return ch
      return ""
    }
    {
      word=tolower($0)
      gsub(/[^a-z0-9]/, "", word)
      if (word == "" || seen[word]++) next

      sig=""
      last=""
      n=split(word, chars, "")
      for (i=1; i<=n; i++) {
        c=code(chars[i])
        if (c == "") continue
        if (sig == "") {
          sig=c
          last=c
          continue
        }
        if (c == "A" || c == last) continue
        sig=sig c
        last=c
        if (length(sig) >= 8) break
      }

      if (sig == "") sig=word
      print word, sig
    }
  ' "$OOV_WORDS" > "$OUTPUT_FILE"
  exit 0
fi

awk '
  BEGIN { OFS="\t" }
  {
    word=""
    pron=""

    # phonetisaurus-apply tab format: WORD<TAB>PHONES
    if (NF >= 2 && index($0, "\t") > 0) {
      word=tolower($1)
      pron=$2
    } else {
      # common whitespace format: WORD PH1 PH2 ...
      word=tolower($1)
      for (i=2; i<=NF; i++) {
        if (pron == "") pron=$i
        else pron=pron" "$i
      }
    }

    gsub(/[^a-z]/, "", word)
    if (word == "" || pron == "") next

    gsub(/[0-9]/, "", pron)
    gsub(/[[:space:]]+/, "-", pron)
    gsub(/-+/, "-", pron)
    gsub(/^-|-$/, "", pron)
    if (pron == "") next

    if (!seen[word]++) print word, pron
  }
' "$RAW_PREDICTIONS" > "$OUTPUT_FILE"
