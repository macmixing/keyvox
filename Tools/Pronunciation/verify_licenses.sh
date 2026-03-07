#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOCK_FILE="$REPO_ROOT/Packages/KeyVoxCore/Sources/KeyVoxCore/Resources/Pronunciation/sources.lock.json"
ATTRIBUTION_FILE="$REPO_ROOT/Packages/KeyVoxCore/Sources/KeyVoxCore/Resources/Pronunciation/LICENSES.md"
THIRD_PARTY_FILE="$REPO_ROOT/THIRD_PARTY_NOTICES.md"

if [[ ! -f "$LOCK_FILE" ]]; then
  echo "Missing lock file: $LOCK_FILE" >&2
  exit 1
fi

if [[ ! -f "$ATTRIBUTION_FILE" ]]; then
  echo "Missing attribution file: $ATTRIBUTION_FILE" >&2
  exit 1
fi

if [[ ! -f "$THIRD_PARTY_FILE" ]]; then
  echo "Missing third-party notices file: $THIRD_PARTY_FILE" >&2
  exit 1
fi

require_pattern() {
  local pattern="$1"
  local file="$2"
  if ! rg -q "$pattern" "$file"; then
    echo "Policy check failed: expected pattern '$pattern' in $file" >&2
    exit 1
  fi
}

deny_pattern() {
  local pattern="$1"
  local file="$2"
  if rg -q "$pattern" "$file"; then
    echo "Policy check failed: disallowed pattern '$pattern' found in $file" >&2
    exit 1
  fi
}

# Allowed sources must be pinned and present in lock.
require_pattern '"id": "cmudict"' "$LOCK_FILE"
require_pattern '"url": "https://raw.githubusercontent.com/cmusphinx/cmudict/' "$LOCK_FILE"
require_pattern '"license": "BSD-2-Clause"' "$LOCK_FILE"
require_pattern '"id": "scowl"' "$LOCK_FILE"
require_pattern '"url": "https://codeload.github.com/en-wl/wordlist/tar.gz/' "$LOCK_FILE"
require_pattern '"license": "MIT-like \(SCOWL Copyright\)"' "$LOCK_FILE"
require_pattern '"id": "phonetisaurus"' "$LOCK_FILE"
require_pattern '"license": "BSD-3-Clause"' "$LOCK_FILE"
require_pattern '"id": "openfst"' "$LOCK_FILE"
require_pattern '"license": "Apache-2.0"' "$LOCK_FILE"

# Verify attribution doc references all active upstream data/toolchain dependencies.
require_pattern 'CMU Pronouncing Dictionary' "$ATTRIBUTION_FILE"
require_pattern 'SCOWL' "$ATTRIBUTION_FILE"
require_pattern 'Phonetisaurus' "$ATTRIBUTION_FILE"
require_pattern 'OpenFst' "$ATTRIBUTION_FILE"
require_pattern 'IN NO EVENT SHALL CARNEGIE MELLON UNIVERSITY' "$ATTRIBUTION_FILE"
require_pattern 'THE WORD LISTS, SCRIPTS, AND OUTPUT FILES ARE PROVIDED "AS IS"' "$ATTRIBUTION_FILE"

# Verify authoritative root notice index includes app-level shipped runtime obligations.
require_pattern '^# Third-Party Notices' "$THIRD_PARTY_FILE"
require_pattern 'whisper.cpp' "$THIRD_PARTY_FILE"
require_pattern 'OpenAI Whisper' "$THIRD_PARTY_FILE"
require_pattern 'Kanit Font' "$THIRD_PARTY_FILE"
require_pattern 'Full OFL text is bundled in `Resources/OFL.txt`' "$THIRD_PARTY_FILE"

echo "Pronunciation licensing/source policy checks passed."
