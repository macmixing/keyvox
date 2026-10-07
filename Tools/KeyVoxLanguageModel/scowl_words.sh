#!/usr/bin/env bash
# Lists the words of the SCOWL word list the predictive keyboard's dictionary is made from,
# with their capitals, one per line into <output>: up to <size> (the dictionary uses 60),
# American spellings, variant level 2, at the revision credited in THIRD_PARTY_NOTICES.md.
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <size> <output>" >&2
  exit 1
fi
SIZE="$1"
OUTPUT="$2"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

SCOWL_COMMIT="1e5b7d3a72f47a71da5d28686c1dd4b397178485"
SCOWL_ARCHIVE_URL="https://codeload.github.com/en-wl/wordlist/tar.gz/$SCOWL_COMMIT"
SCOWL_ARCHIVE_SHA256="aaecc7a54af576057e30b22a19b78bad011f2181f7e368ff3b736fbecbdfd4d0"

curl -fsSL "$SCOWL_ARCHIVE_URL" -o "$TMP_DIR/scowl.tar.gz"
echo "$SCOWL_ARCHIVE_SHA256  $TMP_DIR/scowl.tar.gz" | shasum -a 256 -c - >/dev/null
tar -xzf "$TMP_DIR/scowl.tar.gz" -C "$TMP_DIR"
(
  cd "$TMP_DIR/wordlist-$SCOWL_COMMIT"
  make >/dev/null 2>&1
  ./scowl --db scowl.db word-list "$SIZE" A 2 2>/dev/null
) > "$OUTPUT"
echo "$OUTPUT: $(wc -l < "$OUTPUT" | tr -d ' ') words"
