# Engineering Notes

This document contains implementation and maintainer-focused details that are intentionally kept out of the top-level README.

**Last Updated: 2026-03-19**

## Design Philosophy

KeyVox follows a strict engineering contract:

- No silent data loss.
- No hidden telemetry.
- No background collection of user speech.
- No surprise behavior.

User data is treated as sacred.  
If the clipboard is modified, it must be restored.  
If behavior changes based on a setting, it must be explicit and predictable.  
If something could fail, it must fail safely.

KeyVox is designed to be local-first, transparent, and deterministic.  
Convenience must never come at the cost of trust.

## Architecture Overview

KeyVox is organized by responsibility:

- `App/`: App lifecycle plus persisted app-owned state and registries (`KeyVoxApp`, `AppSettingsStore`, `AppServiceRegistry`, `WeeklyWordStatsStore`).
- `App/iCloud/`: Dedicated iCloud KVS sync helpers and payloads. `KeyVoxiCloudSyncCoordinator` remains focused on dictionary/settings sync, while `WeeklyWordStatsCloudSync` owns weekly usage convergence separately.
- `Core/Transcription/`: Runtime state machine and macOS host-side orchestration (`TranscriptionManager`), with the reusable transcribe -> post-process -> paste boundary extracted into `Packages/KeyVoxCore/Sources/KeyVoxCore/Transcription/` (`DictationPipeline`, `TranscriptionPostProcessor`, `DictationPromptEchoGuard`). The macOS host also persists the most recent successful transcription for Home-tab display after relaunch.
- `Core/Audio/`: Recording, stream processing, silence classification, and threshold policy.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/` and `Packages/KeyVoxCore/Sources/KeyVoxCore/Lists/`: Deterministic dictionary correction and list parsing/rendering, with matcher evaluation strategies organized under `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/Evaluation/` (`Helpers/`, `SplitJoin/`, and strategy files).
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Normalization/`: Ordered pure normalization stages used by post-processing: early literal cleanup, pre-list normalization, late cleanup, and final finishers. The individual passes remain small and composable, while the documented contract stays centered on stable ordering boundaries rather than every micro-pass. Shared normalization utilities (for example URL/domain/email-safe capitalization guards) also live here.
- `Core/Services/`: Paste/injection and update/checking services, while Whisper inference now lives under `Packages/KeyVoxCore/Sources/KeyVoxCore/Services/Whisper/`.
- `Core/Overlay/`: Floating overlay lifecycle, persistence, motion, and generic audio-indicator timing/state driving.
- `Views/`: Onboarding/settings/warnings and presentation-only UI composition, including the proprietary logo system renderer.
- `Tools/`: Maintainer scripts for pronunciation resources, diagnostics, update feed helpers, and quality gates.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Resources/Pronunciation/common-words-v1.txt`: Curated safety/policy list for common-word replacement guards; maintained with pronunciation resources as tuning data.

### macOS Theme Ownership

- `Views/Components/MacAppTheme.swift` is the shared macOS theme surface for reusable app-window styling tokens.
- `MacAppTheme.screenBackground` is the source of truth for the standard macOS app window background (`#1A1740` equivalent).
- Reusable settings/onboarding/update/modal styling should prefer `MacAppTheme` tokens instead of reintroducing local hard-coded indigo/background stacks.
- `Views/StatusMenuView.swift` and `Views/Warnings/*` intentionally keep separate styling and should not be folded into `MacAppTheme` unless product direction changes.

File-level ownership and locations are intentionally maintained in one place: [`CODEMAP.md`](CODEMAP.md).

## Platform Compatibility

- Supported macOS range: macOS 15 and newer.

For the full file-level map, see [`CODEMAP.md`](CODEMAP.md).

## Inference Model

- KeyVox uses Whisper's multilingual base model (`ggml-base`) for on-device transcription.

## Post-Processing Order

1. `Packages/KeyVoxCore/Sources/KeyVoxCore/Services/Whisper/WhisperAudioParagraphChunker.swift` computes conservative chunk boundaries from silence windows.
2. `Packages/KeyVoxCore/Sources/KeyVoxCore/Services/Whisper/WhisperService.swift` transcribes each chunk and stitches chunk text with `\n\n` when `autoParagraphsEnabled` is on (space-separated when off).
3. Early literal cleanup runs first: `EmailAddressNormalizer` repairs email literal casing/punctuation boundaries before downstream matching, then dictionary correction applies custom-word adherence via `DictionaryMatcher`, including dictionary-backed spoken/literal email recovery.
4. Pre-list normalization prepares deterministic structure: lightweight idiom normalization (`hole in one` -> `hole-in-one`), `ColonNormalizer`, and `MathExpressionNormalizer` run before list parsing so structural markers stabilize early.
5. List formatting applies numeric list rendering when confidence gates pass.
6. Late cleanup normalizes residual model output after list rendering: `LaughterNormalizer`, `CharacterSpamNormalizer`, `TimeExpressionNormalizer`, final email boundary repair, `WebsiteNormalizer`, and `ThousandsGroupingNormalizer`.
7. Final finishers apply render-mode whitespace cleanup, capitalization guards (including URL/domain/email and technical-token safety checks), terminal-time punctuation completion, and the optional `AllCapsOverrideNormalizer`.
8. Final text is inserted via the paste service, where macOS applies final insertion-time heuristics such as dictionary-aware leading-cap normalization and smart spacing based on the focused target context.

## Update Feed and Release Checks

`Core/Services/AppUpdateService.swift` is the update source-of-truth.

- Reads latest release metadata from GitHub Releases.
- Normalizes release tags such as `v1.2.3` to `1.2.3`.
- Uses a summarized release-notes preview (summary section when present, else truncated body text).
- Parses release metadata into an installable zip path vs manual-only fallback.
- Enforces host allowlist checks before opening release links or downloading install assets.
- Treats manual checks differently from automatic prompts: status-menu checks reopen the prompt flow even if the user previously pressed `Later` in the same session.

## In-Place Updater

KeyVox now supports an in-place GitHub Releases updater on macOS.

- Automatic checks still surface a lightweight update prompt first.
- Installable releases require both a `KeyVox-<version>.zip` asset and `keyvox-update-manifest.json`.
- The prompt CTA opens a dedicated updater window instead of sending users to the browser.
- The updater downloads the zip, verifies SHA-256, extracts the staged app, validates bundle identity, and verifies Apple trust before launch handoff.
- Final app replacement is performed by `Resources/updater.sh` after the main app exits.
- The updater only performs in-place installation from `/Applications`; if needed, KeyVox first copies itself into `/Applications`, relaunches, and resumes the updater flow automatically.
- On the first successful launch after update, KeyVox can present a dedicated post-update notice window.

### Updater Runtime Split

The updater is intentionally separated by concern:

- `Core/Services/AppUpdateService.swift`
  release discovery, session snooze behavior, and prompt construction
- `Core/Services/AppUpdateLogic.swift`
  pure release parsing, version comparison, and host allowlist helpers
- `Core/Services/AppUpdate/`
  install pipeline pieces (`AppReleaseInfo`, manifest loading, download transport, checksum verification, extraction, bundle verification, install launch, cleanup, launch notice handling)
- `Views/UpdatePromptOverlay.swift`
  lightweight update-available prompt window
- `Views/Updates/`
  dedicated updater window and post-update notice UI
- `App/WindowManager+Updates.swift`
  updater/post-update window lifecycle, centering, and floating-window presentation

### Release Packaging Contract

The updater expects a release zip and manifest that match the shipped app metadata.

- Zip asset name:
  `KeyVox-<version>.zip`
- Manifest asset name:
  `keyvox-update-manifest.json`
- Manifest fields:
  `version`, `assetName`, `sha256`, `byteSize`, `bundleIdentifier`, `minimumSupportedMacOS`
- Packaging helper:
  `build/build_release.sh`

`build/build_release.sh` assumes maintainers already exported a signed/notarized `.app` from Xcode. The script verifies the exported app, creates the release zip, and writes the updater manifest into `build/Release/`.

### Local Override Workflow

Maintainers can override the update feed locally without changing tracked defaults.

- Override file path:
  `~/Library/Application Support/KeyVox/update-feed.override.json`
- Helper script:
  `Tools/UpdateFeed/configure_local_feed.sh`
- Example template:
  `Tools/UpdateFeed/update-feed.override.example.json`

## Testing and Quality Gates

- App tests:
  `xcodebuild -project macOS/KeyVox.xcodeproj -scheme "KeyVox DEBUG" -configuration Debug -destination 'platform=macOS' -enableCodeCoverage YES CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO -resultBundlePath /tmp/keyvox-tests.xcresult test`
- Package tests:
  `swift test --package-path Packages/KeyVoxCore`
- Core coverage gate:
  `Tools/Quality/check_core_coverage.sh /tmp/keyvox-tests.xcresult`
- Coverage markdown summary:
  `Tools/Quality/coverage_summary.sh /tmp/keyvox-tests.xcresult`
- KeyVoxCore JSON coverage gate:
  `Tools/Quality/check_keyvoxcore_coverage.sh <coverage-json-path>`
- KeyVoxCore JSON coverage summary:
  `Tools/Quality/keyvoxcore_coverage_summary.sh <coverage-json-path>`

## Tooling

- Tooling guide:
  `Tools/README.md`
- Frontmost-app AX diagnostics:
  `Tools/ExploreAX.swift`
- Multi-app AX diagnostics:
  `Tools/ExploreAXApps.swift`
- Paste signal probe harness:
  `Tools/ExplorePasteSignal.sh`
- AX notification observer for paste debugging:
  `Tools/ObservePasteAXNotifications.swift`
- Pronunciation pipeline/regeneration scripts:
  `Tools/Pronunciation/*`
- Update-feed local override helper:
  `Tools/UpdateFeed/configure_local_feed.sh`
- Release zip + manifest packaging helper:
  `build/build_release.sh`

### Integration-Only Exclusions

- Audio capture hardware/runtime integration paths
- Global keyboard hook behavior
- Overlay window rendering/interaction details

These remain integration/manual-test territory by design.

## Pronunciation Pipeline

- Runtime pronunciation resources:
  `Packages/KeyVoxCore/Sources/KeyVoxCore/Resources/Pronunciation/`
- Lexicon build script:
  `Tools/Pronunciation/build_lexicon.sh`
- Source/checksum lock:
  `Packages/KeyVoxCore/Sources/KeyVoxCore/Resources/Pronunciation/sources.lock.json`
- Source/license verification:
  `Tools/Pronunciation/verify_licenses.sh`
- Quality gates:
  `Tools/Pronunciation/benchmarks/run_quality_gates.sh`

## Contributor Notes

- Keep behavior/motion constants close to owning logic.
- Keep branded visual tuning inside branded view files.
- `Views/Components/LogoBarView.swift` is the only branded Mac logo file on this branch.
- `Views/Components/MacAppTheme.swift` is the shared non-branded macOS theme file for app-window surfaces; keep generic window/theme tokens there rather than scattering repeated values across settings/onboarding/update views.
- Do not route `Views/StatusMenuView.swift` or `Views/Warnings/*` through `MacAppTheme` unless the product explicitly wants those surfaces visually unified with the main app windows.
- `Views/RecordingOverlay.swift` is a thin overlay shell. Generic timing/metering state belongs in `Core/Overlay/AudioIndicatorDriver.swift`, not in the branded renderer.
- Generic reusable indicator models (`AudioIndicatorPhase`, `AudioIndicatorSignalState`, `AudioIndicatorSample`, `AudioIndicatorTimelineState`) should stay neutral and non-branded.
- Prefer deterministic pure helpers for unit-test coverage.
- Preserve behavior when doing structural refactors unless explicitly changing product behavior.

## Change Tracking

- `ENGINEERING.md` captures stable contracts and system behavior, not per-commit file churn.
- Use Git history (commits/PRs/tags) and release notes for detailed change logs.
- Keep this doc updated only when architecture, invariants, or operational/testing policy changes.
