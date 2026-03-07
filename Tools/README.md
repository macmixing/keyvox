# Tools

Maintainer and contributor utilities live here. These scripts are optional for app runtime, but useful for debugging, release prep, and quality gates.

## Prerequisites

- macOS with Xcode command line tools (`xcrun`, `swiftc`, `xcodebuild`).
- Accessibility permission for AX inspection scripts (`ExploreAX*.swift`).
- For pronunciation regeneration: `curl`, `make`, and optionally `phonetisaurus` binaries.

## Accessibility Inspection

### `ExploreAX.swift`

Deep inspection for the **current frontmost app** to debug KeyVox paste-target verification behavior.

Examples:

```bash
swift Tools/ExploreAX.swift --prompt
swift Tools/ExploreAX.swift --max-depth 20 --max-nodes 12000 --machine
```

### `ExploreAXApps.swift`

Multi-app AX scanner for a list of running app names.

Examples:

```bash
swift Tools/ExploreAXApps.swift --apps "Xcode,Safari,Slack" --prompt
swift Tools/ExploreAXApps.swift --apps "Claude,Codex,Windsurf,Cursor" --max-depth 24 --max-nodes 100000
```

Notes:

- Matches app `localizedName` (case-insensitive exact name match).
- Does not launch apps; only scans apps that are already running.

### `ObservePasteAXNotifications.swift`

Live AX observer for a running app process. Useful for debugging whether paste flows emit
`AXValueChanged` / selection notifications that menu-fallback verification depends on.

Examples:

```bash
swift Tools/ObservePasteAXNotifications.swift --app "Slack" --trigger cmdv --duration 3
swift Tools/ObservePasteAXNotifications.swift --app "Slack" --trigger menu --duration 3
```

### `ExplorePasteSignal.sh`

Batch probe harness for paste-signal timing. Runs repeated trials, triggers paste, and captures
`ExploreAX` dumps at configurable delays into `/tmp/paste-signal-probe` (or custom `--out-dir`).

Examples:

```bash
Tools/ExplorePasteSignal.sh --app "Slack" --mode cmdv --trials 3
Tools/ExplorePasteSignal.sh --app "Slack" --mode menu --delays "0.05 0.10 0.20 0.40 0.80 1.20"
```

## Pronunciation Pipeline

### `Pronunciation/build_lexicon.sh`

Regenerates pinned pronunciation resources:

- `Packages/KeyVoxCore/Sources/KeyVoxCore/Resources/Pronunciation/lexicon-v1.tsv`
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Resources/Pronunciation/common-words-v1.txt`
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Resources/Pronunciation/sources.lock.json`

Runs source pinning checks and benchmark quality gates as part of the workflow.

### `Pronunciation/train_g2p.sh`

Trains/applies G2P on OOV words from a word list and emits KeyVox signature output.

```bash
Tools/Pronunciation/train_g2p.sh --cmudict /path/to/cmudict.dict --word-list /path/to/words.txt --output /tmp/oov.tsv
```

### `Pronunciation/verify_licenses.sh`

Verifies pronunciation source/license policy against:

- `Packages/KeyVoxCore/Sources/KeyVoxCore/Resources/Pronunciation/sources.lock.json`
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Resources/Pronunciation/LICENSES.md`
- `THIRD_PARTY_NOTICES.md`

### `Pronunciation/benchmarks/run_quality_gates.sh`

Builds benchmark evaluator and enforces pronunciation quality gates (coverage, hit rate, false positives, latency).

```bash
Tools/Pronunciation/benchmarks/run_quality_gates.sh --repo-root "$(pwd)"
```

## Update Feed

### `UpdateFeed/configure_local_feed.sh`

Sets/clears/shows a local update-feed override used by update checks.

Examples:

```bash
Tools/UpdateFeed/configure_local_feed.sh set <owner> <repo>
Tools/UpdateFeed/configure_local_feed.sh show
Tools/UpdateFeed/configure_local_feed.sh clear
```

Override path:

- `~/Library/Application Support/KeyVox/update-feed.override.json`

## Coverage Quality Gate

### `Quality/check_core_coverage.sh`

Checks allowlisted core-file coverage from an `.xcresult` bundle.

```bash
Tools/Quality/check_core_coverage.sh /tmp/keyvox-tests.xcresult
```

Optional threshold override:

```bash
CORE_COVERAGE_THRESHOLD=85 Tools/Quality/check_core_coverage.sh /tmp/keyvox-tests.xcresult
```

### `Quality/coverage_summary.sh`

Builds a markdown coverage summary (overall app + core aggregate + lowest-coverage core files),
useful for CI step summaries.

```bash
Tools/Quality/coverage_summary.sh /tmp/keyvox-tests.xcresult
```
