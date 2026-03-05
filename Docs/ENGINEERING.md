# Engineering Notes

This document contains implementation and maintainer-focused details that are intentionally kept out of the top-level README.

**Last Updated: 2026-03-05**

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

- `App/`: App lifecycle and persisted settings ownership (`KeyVoxApp`, `AppSettingsStore`).
- `Core/Transcription/`: Runtime state machine and the transcribe -> post-process -> paste orchestration boundary (`TranscriptionManager`, `DictationPipeline`, `TranscriptionPostProcessor`).
- `Core/Audio/`: Recording, stream processing, silence classification, and threshold policy.
- `Core/Language/Dictionary/` and `Core/Lists/`: Deterministic dictionary correction and list parsing/rendering, with matcher evaluation strategies organized under `Core/Language/Dictionary/Evaluation/` (`Helpers/`, `SplitJoin/`, and strategy files).
- `Core/Normalization/`: Ordered pure normalization passes used by post-processing (email literal cleanup, colon/math, laughter/spam/time, website/domain casing, whitespace, capitalization, terminal punctuation, all-caps override) plus shared normalization utilities (for example URL/domain/email-safe capitalization guards).
- `Core/Services/`: Whisper inference (organized under `Core/Services/Whisper/`), paste/injection, and update/checking services.
- `Core/Overlay/`: Floating overlay lifecycle, persistence, and motion.
- `Views/`: Onboarding/settings/warnings and presentation-only UI composition.
- `Tools/`: Maintainer scripts for pronunciation resources, diagnostics, update feed helpers, and quality gates.
- `Resources/Pronunciation/common-words-v1.txt`: Curated safety/policy list for common-word replacement guards; maintained with pronunciation resources as tuning data.

File-level ownership and locations are intentionally maintained in one place: [`CODEMAP.md`](CODEMAP.md).

## Platform Compatibility

- Supported macOS range: Ventura (macOS 13.5) and newer.

For the full file-level map, see [`CODEMAP.md`](CODEMAP.md).

## Inference Model

- KeyVox uses Whisper's multilingual base model (`ggml-base`) for on-device transcription.

## Post-Processing Order

1. `Core/Services/Whisper/WhisperAudioParagraphChunker.swift` computes conservative chunk boundaries from silence windows.
2. `Core/Services/Whisper/WhisperService.swift` transcribes each chunk and stitches chunk text with `\n\n` when `autoParagraphsEnabled` is on (space-separated when off).
3. `EmailAddressNormalizer` runs first (email literal case + punctuation/sentence-boundary cleanup).
4. Dictionary correction applies custom-word adherence via `DictionaryMatcher`, including dictionary-backed spoken/literal email recovery.
5. Lightweight idiom normalization runs (`hole in one` -> `hole-in-one`), then `ColonNormalizer` converts spoken/delimiter colon phrases before list parsing.
6. `MathExpressionNormalizer` converts high-confidence spoken math into deterministic symbol form while preserving protected URL/email/code/time/date/version spans.
7. List formatting applies numeric list rendering when confidence gates pass.
8. Dedicated laughter normalization (`LaughterNormalizer`) and repeated-character spam cleanup (`CharacterSpamNormalizer`) run, then time normalization (`TimeExpressionNormalizer`) and final email boundary repair.
9. `WebsiteNormalizer` applies domain casing normalization after email/time cleanup.
10. Normalization helpers apply render-mode whitespace, capitalization guards (including URL/domain/email and technical-token safety checks), and terminal-time punctuation completion.
11. `AllCapsOverrideNormalizer` applies a final uppercase override when Caps Lock mode is active.
12. Final text is inserted via the paste service.

## Update Feed and Release Checks

`Core/Services/AppUpdateService.swift` is the update source-of-truth.

- Reads latest release metadata from GitHub Releases.
- Normalizes release tags such as `v1.2.3` to `1.2.3`.
- Uses a summarized release-notes preview (summary section when present, else truncated body text).
- Prefers first `.dmg` asset URL, then falls back to release page URL.
- Enforces host allowlist checks before opening update links.

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
  `xcodebuild -project KeyVox.xcodeproj -scheme "KeyVox DEBUG" -configuration Debug -destination 'platform=macOS' -enableCodeCoverage YES CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO -resultBundlePath /tmp/keyvox-tests.xcresult test`
- Package tests:
  `swift test --package-path Packages/KeyVoxWhisper`
- Core coverage gate:
  `Tools/Quality/check_core_coverage.sh /tmp/keyvox-tests.xcresult`
- Coverage markdown summary:
  `Tools/Quality/coverage_summary.sh /tmp/keyvox-tests.xcresult`

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

### Integration-Only Exclusions

- Audio capture hardware/runtime integration paths
- Global keyboard hook behavior
- Overlay window rendering/interaction details

These remain integration/manual-test territory by design.

## Pronunciation Pipeline

- Runtime pronunciation resources:
  `Resources/Pronunciation/`
- Lexicon build script:
  `Tools/Pronunciation/build_lexicon.sh`
- Source/checksum lock:
  `Resources/Pronunciation/sources.lock.json`
- Source/license verification:
  `Tools/Pronunciation/verify_licenses.sh`
- Quality gates:
  `Tools/Pronunciation/benchmarks/run_quality_gates.sh`

## Contributor Notes

- Keep behavior/motion constants close to owning logic.
- Keep branded visual tuning inside branded view files.
- Prefer deterministic pure helpers for unit-test coverage.
- Preserve behavior when doing structural refactors unless explicitly changing product behavior.

## Change Tracking

- `ENGINEERING.md` captures stable contracts and system behavior, not per-commit file churn.
- Use Git history (commits/PRs/tags) and release notes for detailed change logs.
- Keep this doc updated only when architecture, invariants, or operational/testing policy changes.
