#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      REPO_ROOT="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

LEXICON_FILE="$REPO_ROOT/Resources/Pronunciation/lexicon-v1.tsv"
COMMON_FILE="$REPO_ROOT/Resources/Pronunciation/common-words-v1.txt"
HIT_RATE_MIN="${HIT_RATE_MIN:-90}"

if [[ ! -f "$LEXICON_FILE" || ! -f "$COMMON_FILE" ]]; then
  echo "Missing pronunciation resources. Run build_lexicon.sh first." >&2
  exit 1
fi

LEXICON_ROWS="$(wc -l < "$LEXICON_FILE" | tr -d ' ')"
COMMON_ROWS="$(wc -l < "$COMMON_FILE" | tr -d ' ')"

if (( LEXICON_ROWS < 240000 || LEXICON_ROWS > 450000 )); then
  echo "lexicon-v1.tsv rows out of range: $LEXICON_ROWS (expected 240000-450000)" >&2
  exit 1
fi

if (( COMMON_ROWS < 10000 || COMMON_ROWS > 15000 )); then
  echo "common-words-v1.txt rows out of range: $COMMON_ROWS (expected 10000-15000)" >&2
  exit 1
fi

TMP_BIN="$(mktemp "$REPO_ROOT/.tmp.pronunciation-bench.XXXXXX")"
trap 'rm -f "$TMP_BIN"' EXIT

xcrun swiftc -O -module-cache-path /tmp/swift-module-cache \
  "$SCRIPT_DIR/evaluate_matcher.swift" \
  "$SCRIPT_DIR/evaluate/EvaluateMatcherCore.swift" \
  "$SCRIPT_DIR/evaluate/EvaluateBenchmarkIO.swift" \
  "$SCRIPT_DIR/evaluate/EvaluateBenchmarkRunner.swift" \
  -o "$TMP_BIN"

METRICS_OUTPUT="$("$TMP_BIN" --repo-root "$REPO_ROOT")"
echo "$METRICS_OUTPUT"

coverage="$(echo "$METRICS_OUTPUT" | awk -F= '/^COVERAGE=/{print $2}')"
hit_rate="$(echo "$METRICS_OUTPUT" | awk -F= '/^HIT_RATE=/{print $2}')"
false_positive_rate="$(echo "$METRICS_OUTPUT" | awk -F= '/^FALSE_POSITIVE_RATE=/{print $2}')"
latency_ms="$(echo "$METRICS_OUTPUT" | awk -F= '/^MEDIAN_LATENCY_MS=/{print $2}')"

if [[ -z "$coverage" || -z "$hit_rate" || -z "$false_positive_rate" || -z "$latency_ms" ]]; then
  echo "Failed to parse quality metrics output." >&2
  exit 1
fi

awk -v value="$coverage" 'BEGIN { if (value + 0 < 95.0) exit 1 }' || {
  echo "Coverage gate failed: $coverage% < 95%" >&2
  exit 1
}

awk -v value="$hit_rate" -v min="$HIT_RATE_MIN" 'BEGIN { if (value + 0 < min + 0) exit 1 }' || {
  echo "Hit-rate gate failed: $hit_rate% < ${HIT_RATE_MIN}%" >&2
  exit 1
}

awk -v value="$false_positive_rate" 'BEGIN { if (value + 0 > 1.0) exit 1 }' || {
  echo "False-positive gate failed: $false_positive_rate% > 1%" >&2
  exit 1
}

awk -v value="$latency_ms" 'BEGIN { if (value + 0 > 10.0) exit 1 }' || {
  echo "Latency gate failed: $latency_ms ms > 10 ms" >&2
  exit 1
}

echo "Quality gates passed."
