#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <coverage-json-path>"
  exit 2
fi

COVERAGE_JSON="$1"
if [[ ! -f "$COVERAGE_JSON" ]]; then
  echo "error: coverage json not found: $COVERAGE_JSON"
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SOURCE_PREFIX="${REPO_ROOT}/Packages/KeyVoxCore/Sources/KeyVoxCore/"

python3 - "$COVERAGE_JSON" "$SOURCE_PREFIX" <<'PY'
import json
import sys

coverage_json = sys.argv[1]
source_prefix = sys.argv[2]

with open(coverage_json, "r", encoding="utf-8") as handle:
    report = json.load(handle)

files = []
for datum in report.get("data", []):
    files.extend(datum.get("files", []))

matched = []
covered_total = 0
executable_total = 0

for entry in files:
    filename = entry.get("filename", "")
    if not filename.startswith(source_prefix) or not filename.endswith(".swift"):
        continue

    lines = ((entry.get("summary") or {}).get("lines") or {})
    covered = int(lines.get("covered", 0))
    executable = int(lines.get("count", 0))
    percent = float(lines.get("percent", 0.0))

    matched.append((percent, filename, covered, executable))
    covered_total += covered
    executable_total += executable

overall = 0.0 if executable_total == 0 else (covered_total / executable_total) * 100.0

print("## Coverage Summary")
print()
print(f"- KeyVoxCore package: **{overall:.2f}% ({covered_total}/{executable_total})**")
print()
print("### Lowest-Coverage KeyVoxCore Files (>= 40 executable lines)")
print()
print("| Coverage | Lines | File |")
print("|---:|---:|---|")

rows = [row for row in matched if row[3] >= 40]
for percent, filename, covered, executable in sorted(rows, key=lambda row: row[0])[:10]:
    print(f"| {percent:.2f}% | {covered}/{executable} | `{filename}` |")
PY
