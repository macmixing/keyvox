#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT_DIR="$REPO_ROOT/Resources/Pronunciation"
LOCK_FILE="$OUT_DIR/sources.lock.json"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

CMUDICT_COMMIT="74790861f652b15e4ac49015a90074ad62a27690"
SCOWL_COMMIT="9829d649f007932ce672a1e8e13678a48be20d55"
CMUDICT_URL="https://raw.githubusercontent.com/cmusphinx/cmudict/$CMUDICT_COMMIT/cmudict.dict"
SCOWL_ARCHIVE_URL="https://codeload.github.com/en-wl/wordlist/tar.gz/$SCOWL_COMMIT"

LEXICON_TARGET_ROWS=240000
LEXICON_MIN_ROWS=235000
LEXICON_MAX_ROWS=450000
COMMON_MIN_ROWS=10000
COMMON_MAX_ROWS=15000

SCOWL_SIZE="${SCOWL_SIZE:-95}"
SCOWL_SPELLINGS="${SCOWL_SPELLINGS:-A}"
SCOWL_VARIANT_LEVEL="${SCOWL_VARIANT_LEVEL:-2}"
QUALITY_HIT_RATE_MIN=90

ensure_allowed_url() {
  local url="$1"
  case "$url" in
    https://raw.githubusercontent.com/cmusphinx/cmudict/*) ;;
    https://codeload.github.com/en-wl/wordlist/tar.gz/*) ;;
    *)
      echo "Disallowed source URL: $url" >&2
      exit 1
      ;;
  esac
}

compute_sha() {
  local file="$1"
  shasum -a 256 "$file" | awk '{print $1}'
}

mkdir -p "$OUT_DIR"

echo "Fetching pinned sources..."
ensure_allowed_url "$CMUDICT_URL"
ensure_allowed_url "$SCOWL_ARCHIVE_URL"
curl -fsSL "$CMUDICT_URL" -o "$TMP_DIR/cmudict.dict"
curl -fsSL "$SCOWL_ARCHIVE_URL" -o "$TMP_DIR/scowl.tar.gz"

CMUDICT_SOURCE_SHA="$(compute_sha "$TMP_DIR/cmudict.dict")"
SCOWL_SOURCE_SHA="$(compute_sha "$TMP_DIR/scowl.tar.gz")"

echo "Extracting CMUdict base pronunciations..."
awk '
  BEGIN { OFS="\t" }
  /^;;;|^#/ { next }
  {
    raw=$1
    gsub(/\([0-9]+\)$/, "", raw)
    word=tolower(raw)
    if (word ~ /[^a-z]/) next

    sig=""
    for (i=2; i<=NF; i++) {
      p=$i
      gsub(/[0-9]/, "", p)
      if (sig == "") sig=p
      else sig=sig"-"p
    }

    if (sig != "" && !seen[word]++) {
      print word, sig
    }
  }
' "$TMP_DIR/cmudict.dict" > "$TMP_DIR/cmudict-lexicon.tsv"

echo "Preparing SCOWL word list..."
tar -xzf "$TMP_DIR/scowl.tar.gz" -C "$TMP_DIR"
SCOWL_DIR="$(find "$TMP_DIR" -maxdepth 1 -type d -name 'wordlist-*' | head -n 1)"
if [[ -z "$SCOWL_DIR" ]]; then
  echo "Unable to locate extracted SCOWL directory." >&2
  exit 1
fi

(
  cd "$SCOWL_DIR"
  make >/dev/null
  ./scowl --db scowl.db word-list "$SCOWL_SIZE" "$SCOWL_SPELLINGS" "$SCOWL_VARIANT_LEVEL" --deaccent \
    > "$TMP_DIR/scowl-words.raw.txt"
)

awk '
  {
    w=tolower($0)
    gsub(/[^a-z]/, "", w)
    if (w == "") next
    if (length(w) < 2 || length(w) > 24) next
    if (!seen[w]++) print w
  }
' "$TMP_DIR/scowl-words.raw.txt" > "$TMP_DIR/scowl-words.txt"

echo "Training/applying G2P for OOV words..."
if ! command -v phonetisaurus-train >/dev/null 2>&1 && \
   ! command -v phonetisaurus-apply >/dev/null 2>&1 && \
   ! command -v phonetisaurus >/dev/null 2>&1; then
  QUALITY_HIT_RATE_MIN=80
  echo "Phonetisaurus unavailable: using fallback G2P and relaxed hit-rate gate (${QUALITY_HIT_RATE_MIN}%)."
fi

"$SCRIPT_DIR/train_g2p.sh" \
  --cmudict "$TMP_DIR/cmudict.dict" \
  --word-list "$TMP_DIR/scowl-words.txt" \
  --output "$TMP_DIR/oov-lexicon.tsv"

echo "Merging base + OOV pronunciations..."
cat "$TMP_DIR/cmudict-lexicon.tsv" "$TMP_DIR/oov-lexicon.tsv" \
  | awk -F'\t' '
    BEGIN { OFS="\t" }
    NF < 2 { next }
    {
      word=$1
      sig=$2
      gsub(/[[:space:]]+$/, "", word)
      gsub(/[[:space:]]+$/, "", sig)
      if (word == "" || sig == "") next
      if (!seen[word]++) print word, sig
    }
  ' \
  | LC_ALL=C sort -t$'\t' -k1,1 \
  > "$OUT_DIR/lexicon-v1.tsv"

echo "Building common-word guard list..."
awk '
  {
    w=tolower($0)
    gsub(/[^a-z]/, "", w)
    if (w == "") next
    if (length(w) < 2 || length(w) > 12) next
    if (seen[w]++) next
    if (count >= max_rows) next
    print w
    count++
  }
' max_rows="$COMMON_MAX_ROWS" "$TMP_DIR/scowl-words.txt" \
  > "$OUT_DIR/common-words-v1.txt"

LEXICON_ROWS="$(wc -l < "$OUT_DIR/lexicon-v1.tsv" | tr -d ' ')"
COMMON_ROWS="$(wc -l < "$OUT_DIR/common-words-v1.txt" | tr -d ' ')"

if (( LEXICON_ROWS < LEXICON_MIN_ROWS || LEXICON_ROWS > LEXICON_MAX_ROWS )); then
  echo "lexicon-v1.tsv row count ($LEXICON_ROWS) out of range [$LEXICON_MIN_ROWS, $LEXICON_MAX_ROWS]." >&2
  exit 1
fi

if (( COMMON_ROWS < COMMON_MIN_ROWS || COMMON_ROWS > COMMON_MAX_ROWS )); then
  echo "common-words-v1.txt row count ($COMMON_ROWS) out of range [$COMMON_MIN_ROWS, $COMMON_MAX_ROWS]." >&2
  exit 1
fi

LEXICON_SHA="$(compute_sha "$OUT_DIR/lexicon-v1.tsv")"
COMMON_SHA="$(compute_sha "$OUT_DIR/common-words-v1.txt")"
GENERATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

cat > "$LOCK_FILE" <<EOF
{
  "version": 1,
  "generated_at": "$GENERATED_AT",
  "targets": {
    "lexicon_target_rows": $LEXICON_TARGET_ROWS,
    "lexicon_row_range": [$LEXICON_MIN_ROWS, $LEXICON_MAX_ROWS],
    "common_word_row_range": [$COMMON_MIN_ROWS, $COMMON_MAX_ROWS]
  },
  "sources": [
    {
      "id": "cmudict",
      "url": "$CMUDICT_URL",
      "revision": "$CMUDICT_COMMIT",
      "license": "BSD-2-Clause",
      "sha256": "$CMUDICT_SOURCE_SHA"
    },
    {
      "id": "scowl",
      "url": "$SCOWL_ARCHIVE_URL",
      "revision": "$SCOWL_COMMIT",
      "license": "MIT-like (SCOWL Copyright)",
      "sha256": "$SCOWL_SOURCE_SHA"
    },
    {
      "id": "phonetisaurus",
      "url": "https://github.com/AdolfVonKleist/Phonetisaurus",
      "revision": "build-time-tool",
      "license": "BSD-3-Clause",
      "sha256": "n/a"
    },
    {
      "id": "openfst",
      "url": "https://openfst.org",
      "revision": "build-time-tool",
      "license": "Apache-2.0",
      "sha256": "n/a"
    }
  ],
  "artifacts": [
    {
      "path": "Resources/Pronunciation/lexicon-v1.tsv",
      "rows": $LEXICON_ROWS,
      "sha256": "$LEXICON_SHA"
    },
    {
      "path": "Resources/Pronunciation/common-words-v1.txt",
      "rows": $COMMON_ROWS,
      "sha256": "$COMMON_SHA"
    }
  ]
}
EOF

echo "Running license/source policy checks..."
"$SCRIPT_DIR/verify_licenses.sh"

echo "Running quality gates..."
HIT_RATE_MIN="$QUALITY_HIT_RATE_MIN" \
  "$SCRIPT_DIR/benchmarks/run_quality_gates.sh" --repo-root "$REPO_ROOT"

cat <<MSG
Regenerated pronunciation resources:
- $OUT_DIR/lexicon-v1.tsv
- $OUT_DIR/common-words-v1.txt
- $LOCK_FILE

Targets:
- lexicon-v1.tsv rows: $LEXICON_ROWS (target: $LEXICON_TARGET_ROWS, range: $LEXICON_MIN_ROWS-$LEXICON_MAX_ROWS)
- common-words-v1.txt rows: $COMMON_ROWS (range: $COMMON_MIN_ROWS-$COMMON_MAX_ROWS)
MSG
