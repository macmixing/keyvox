#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <xcresult-path>"
  exit 2
fi

RESULT_BUNDLE="$1"
THRESHOLD="${CORE_COVERAGE_THRESHOLD:-80}"

if [[ ! -d "$RESULT_BUNDLE" ]]; then
  echo "error: xcresult path not found: $RESULT_BUNDLE"
  exit 2
fi

ALLOWLIST=(
  "/Core/Services/AppUpdateLogic.swift"
  "/Core/Services/UpdateFeedConfig.swift"
  "/Core/Services/AppUpdateService.swift"
)

REPORT_FILE="$(mktemp)"
trap 'rm -f "$REPORT_FILE"' EXIT

xcrun xccov view --report "$RESULT_BUNDLE" > "$REPORT_FILE"

total_covered=0
total_executable=0
missing=()

for suffix in "${ALLOWLIST[@]}"; do
  line="$(grep -E "^    .*$suffix[[:space:]]+[0-9]+\.[0-9]+% \([0-9]+/[0-9]+\)" "$REPORT_FILE" | head -n 1 || true)"

  if [[ -z "$line" ]]; then
    missing+=("$suffix")
    continue
  fi

  counts="$(echo "$line" | sed -E 's/.*\(([0-9]+)\/([0-9]+)\).*/\1 \2/')"
  covered="$(echo "$counts" | awk '{print $1}')"
  executable="$(echo "$counts" | awk '{print $2}')"

  total_covered=$((total_covered + covered))
  total_executable=$((total_executable + executable))
done

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "error: coverage report missing allowlisted files:" >&2
  for item in "${missing[@]}"; do
    echo "  - $item" >&2
  done
  exit 1
fi

if [[ $total_executable -le 0 ]]; then
  echo "error: no executable lines found for allowlisted core files" >&2
  exit 1
fi

coverage="$(awk -v c="$total_covered" -v e="$total_executable" 'BEGIN { printf "%.2f", (c / e) * 100 }')"

echo "App-owned core coverage: ${coverage}% (threshold: ${THRESHOLD}%)"

if awk -v cov="$coverage" -v thr="$THRESHOLD" 'BEGIN { exit (cov + 0 < thr + 0 ? 0 : 1) }'; then
  echo "error: app-owned core coverage ${coverage}% is below threshold ${THRESHOLD}%" >&2
  exit 1
fi
