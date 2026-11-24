#!/usr/bin/env bash
# Writes a SCOWL word list to <output>, one word per line: words up to <size>, in the
# comma-separated <spellings> (A American, B British, Z British -ize, C Canadian,
# D Australian), variant level 2, with apostrophes written as the ASCII mark.
# SCOWL is built once at the pinned revision credited in THIRD_PARTY_NOTICES.md and kept in
# <data-dir>/sources/scowl.
set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "usage: $0 <data-dir> <size> <spellings> <output>" >&2
  exit 1
fi
DATA_DIR="$1"
SIZE="$2"
SPELLINGS="$3"
OUTPUT="$4"

SCOWL_COMMIT="1e5b7d3a72f47a71da5d28686c1dd4b397178485"
SCOWL_ARCHIVE_URL="https://codeload.github.com/en-wl/wordlist/tar.gz/$SCOWL_COMMIT"
SCOWL_ARCHIVE_SHA256="aaecc7a54af576057e30b22a19b78bad011f2181f7e368ff3b736fbecbdfd4d0"
SCOWL_ROOT="$DATA_DIR/sources/scowl"
SCOWL_DIR="$SCOWL_ROOT/wordlist-$SCOWL_COMMIT"

if [[ ! -f "$SCOWL_DIR/scowl.db" ]]; then
  mkdir -p "$SCOWL_ROOT"
  curl -fsSL "$SCOWL_ARCHIVE_URL" -o "$SCOWL_ROOT/scowl.tar.gz"
  echo "$SCOWL_ARCHIVE_SHA256  $SCOWL_ROOT/scowl.tar.gz" | shasum -a 256 -c - >/dev/null
  rm -rf "$SCOWL_DIR"
  tar -xzf "$SCOWL_ROOT/scowl.tar.gz" -C "$SCOWL_ROOT"
  rm "$SCOWL_ROOT/scowl.tar.gz"
  make -C "$SCOWL_DIR" >/dev/null
fi

(cd "$SCOWL_DIR" && ./scowl --db scowl.db word-list "$SIZE" "$SPELLINGS" 2 --apostrophe middle 2>/dev/null) > "$OUTPUT"
echo "$OUTPUT: $(wc -l < "$OUTPUT" | tr -d ' ') words"
