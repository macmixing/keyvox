#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <coverage-json-path>"
  exit 2
fi

COVERAGE_JSON="$1"
THRESHOLD="${KEYVOXCORE_COVERAGE_THRESHOLD:-80}"

if [[ ! -f "$COVERAGE_JSON" ]]; then
  echo "error: coverage json not found: $COVERAGE_JSON"
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SOURCE_PREFIX="${REPO_ROOT}/Packages/KeyVoxCore/Sources/KeyVoxCore/"

if ! coverage="$(
python3 - "$COVERAGE_JSON" "$SOURCE_PREFIX" <<'PY'
import json
import sys

coverage_json = sys.argv[1]
source_prefix = sys.argv[2]

with open(coverage_json, "r", encoding="utf-8") as handle:
    report = json.load(handle)

covered_total = 0
executable_total = 0

for datum in report.get("data", []):
    for entry in datum.get("files", []):
        filename = entry.get("filename", "")
        if not filename.startswith(source_prefix) or not filename.endswith(".swift"):
            continue
        lines = ((entry.get("summary") or {}).get("lines") or {})
        covered_total += int(lines.get("covered", 0))
        executable_total += int(lines.get("count", 0))

if executable_total <= 0:
    sys.exit(2)

print(f"{(covered_total / executable_total) * 100.0:.2f} {covered_total} {executable_total}")
PY
)"; then
  echo "error: no executable lines found for KeyVoxCore source files" >&2
  exit 1
fi

coverage_pct="$(echo "$coverage" | awk '{print $1}')"
covered_lines="$(echo "$coverage" | awk '{print $2}')"
executable_lines="$(echo "$coverage" | awk '{print $3}')"

echo "KeyVoxCore coverage: ${coverage_pct}% (${covered_lines}/${executable_lines}) (threshold: ${THRESHOLD}%)"

if awk -v cov="$coverage_pct" -v thr="$THRESHOLD" 'BEGIN { exit (cov + 0 < thr + 0 ? 0 : 1) }'; then
  echo "error: KeyVoxCore coverage ${coverage_pct}% is below threshold ${THRESHOLD}%" >&2
  exit 1
fi
