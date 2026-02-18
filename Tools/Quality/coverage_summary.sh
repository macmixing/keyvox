#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <xcresult-path>"
  exit 2
fi

RESULT_BUNDLE="$1"
if [[ ! -d "$RESULT_BUNDLE" ]]; then
  echo "error: xcresult path not found: $RESULT_BUNDLE"
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CORE_PREFIX="${REPO_ROOT}/Core/"

REPORT_FILE="$(mktemp)"
trap 'rm -f "$REPORT_FILE"' EXIT

xcrun xccov view --report "$RESULT_BUNDLE" > "$REPORT_FILE"

overall_line="$(grep -E '^KeyVox\.app[[:space:]]+[0-9]+\.[0-9]+% \([0-9]+/[0-9]+\)' "$REPORT_FILE" | head -n 1 || true)"
if [[ -z "$overall_line" ]]; then
  overall_display="unknown"
else
  overall_display="$(echo "$overall_line" | sed -E 's/.*([0-9]+\.[0-9]+% \([0-9]+\/[0-9]+\)).*/\1/')"
fi

core_stats="$(
  awk -v core_prefix="$CORE_PREFIX" '
    $1 ~ "^" core_prefix {
      counts = $3
      gsub(/[()]/, "", counts)
      split(counts, a, "/")
      covered += a[1]
      executable += a[2]
    }
    END {
      if (executable > 0) {
        printf "%.2f %d %d\n", (covered / executable) * 100, covered, executable
      } else {
        printf "0.00 0 0\n"
      }
    }
  ' "$REPORT_FILE"
)"

core_pct="$(echo "$core_stats" | awk '{print $1}')"
core_cov="$(echo "$core_stats" | awk '{print $2}')"
core_exec="$(echo "$core_stats" | awk '{print $3}')"

echo "## Coverage Summary"
echo
echo "- Overall (\`KeyVox.app\`): **${overall_display}**"
echo "- Core (\`/Core/*\` aggregate): **${core_pct}% (${core_cov}/${core_exec})**"
echo
echo "### Lowest-Coverage Core Files (>= 40 executable lines)"
echo
echo "| Coverage | Lines | File |"
echo "|---:|---:|---|"
awk -v core_prefix="$CORE_PREFIX" '
  $1 ~ "^" core_prefix {
    file = $1
    cov = $2
    counts = $3
    gsub(/%/, "", cov)
    gsub(/[()]/, "", counts)
    split(counts, a, "/")
    covered = a[1] + 0
    executable = a[2] + 0
    if (executable >= 40) {
      printf "%08.2f\t%s\t%d\t%d\n", cov + 0, file, covered, executable
    }
  }
' "$REPORT_FILE" \
  | sort -n \
  | head -n 10 \
  | awk -F'\t' '
      {
        cov = $1 + 0
        file = $2
        covered = $3
        executable = $4
        printf "| %.2f%% | %d/%d | `%s` |\n", cov, covered, executable, file
      }
    '
