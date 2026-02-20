# Engineering Notes

This document contains implementation and maintainer-focused details that are intentionally kept out of the top-level README.

**Last Updated: 2026-02-20**

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

- `App/KeyVoxApp.swift`: App entry point, menu bar scene, and window lifecycle.
- `App/AppSettingsStore.swift`: Central persisted settings owner (`triggerBinding`, `autoParagraphsEnabled`, sound, onboarding, update prompts, weekly words).
- `Core/Transcription/TranscriptionManager.swift`: Recording/transcription state orchestration plus internal `DictationPipeline` boundary used by smoke/integration tests.
- `Core/Transcription/DictationPipeline.swift`: Injectable transcribe -> post-process -> paste boundary used by runtime wiring and smoke tests.
- `Core/Transcription/DictationPromptEchoGuard.swift`: Short-utterance prompt-hint guard to reduce dictionary-prompt echo artifacts.
- `Core/Audio/AudioRecorder.swift`: Recorder state holder and public start/stop flow.
- `Core/Audio/AudioRecorder+Session.swift`: Capture session/device lifecycle.
- `Core/Audio/AudioRecorder+Streaming.swift`: Sample conversion/downsampling and live signal state.
- `Core/Audio/AudioRecorder+PostProcessing.swift`: Stop-time gap removal/normalization/classification.
- `Core/Audio/AudioRecorder+Thresholds.swift`: Input-volume-based threshold calibration.
- `Core/Audio/AudioCaptureClassification.swift`: Capture confidence/silence classification.
- `Core/Audio/AudioSilencePolicy.swift`: Shared silence-gate policy rules/constants.
- `Core/Audio/AudioSignalMetrics.swift`: Pure RMS/peak/window-ratio metrics.
- `Core/KeyboardMonitor.swift`: Global/local modifier, escape, and caps-lock monitoring.
- `Core/AudioDeviceManager.swift`: Microphone discovery/selection and active device resolution.
- `Core/ModelDownloader/ModelDownloader.swift`: Download orchestration for Whisper model artifacts.
- `Core/ModelDownloader/ModelDownloader+DownloadLifecycle.swift`: URLSession progress/completion/error handling and download state transitions.
- `Core/ModelDownloader/ModelDownloader+Validation.swift`: Artifact validation and readiness checks.
- `Core/Overlay/OverlayManager.swift`: Overlay lifecycle orchestration and visibility state.
- `Core/Overlay/OverlayMotionController.swift`: Fling/reset motion sequencing.
- `Core/Overlay/OverlayScreenPersistence.swift`: Per-display origin persistence and clamping.
- `Core/Overlay/OverlayPanel.swift`: Drag sampling, double-click reset, release velocity capture.
- `Core/Overlay/OverlayFlingPhysics.swift`: Pure fling impact/reflection/duration calculations.
- `Core/Services/WhisperService.swift`: Local model loading and transcription.
- `Core/Services/WhisperAudioParagraphChunker.swift`: Deterministic silence-window chunking for paragraph-aware transcription.
- `Core/Transcription/TranscriptionPostProcessor.swift`: Post-transcription pipeline orchestration.
- `Core/Normalization/TimeExpressionNormalizer.swift`: Extracted time-shape/meridiem normalization helper used by post-processing.
- `Core/Normalization/LaughterNormalizer.swift`: Dedicated laughter normalization helper kept separate from time normalization.
- `Core/Normalization/CharacterSpamNormalizer.swift`: Collapses model character-spam runs (same non-whitespace character repeated 16+ times) to a single character.
- `Core/Normalization/WhitespaceNormalizer.swift`: Render-mode-aware whitespace normalization (`.multiline` paragraph preservation vs `.singleLineInline` flattening).
- `Core/Normalization/SentenceCapitalizationNormalizer.swift`: Text-start/sentence-boundary/line-break capitalization with email/domain guards.
- `Core/Normalization/ColonNormalizer.swift`: Converts spoken/delimiter colon forms into deterministic `:` punctuation with homophone and punctuation guards.
- `Core/Normalization/TerminalPunctuationNormalizer.swift`: Terminal punctuation completion for sentence-like outputs ending in formatted times.
- `Core/Normalization/AllCapsOverrideNormalizer.swift`: Final post-processing override that forces uppercase output when Caps Lock mode is enabled.
- `Core/AI/Dictionary/*`: Dictionary storage and matcher internals.
- `Core/Normalization/EmailAddressNormalizer.swift`: Shared non-dictionary email literal cleanup utility.
- `Core/Normalization/WebsiteNormalizer.swift`: Shared website/domain helper for compact-domain detection, leading-domain normalization, and standalone website checks reused across list and email flows.
- `Core/AI/Dictionary/Email/DictionaryEmailEntry.swift`: Canonical dictionary email representation and sanitization.
- `Core/AI/Dictionary/Email/DictionaryMatcher+EmailDomainResolution.swift`: Domain candidate extraction and fuzzy-domain ranking/disambiguation helpers.
- `Core/AI/Dictionary/Email/DictionaryMatcher+EmailNormalization.swift`: Spoken/literal/compact email candidate normalization using dictionary-backed resolution.
- `Core/AI/Dictionary/Email/DictionaryMatcher+EmailParsing.swift`: Local/domain normalization and attached-marker parsing helpers reused by email normalization/resolution.
- `Core/AI/Dictionary/Email/DictionaryMatcher+EmailResolution.swift`: Spoken/literal/standalone dictionary email resolution with deterministic ambiguity guards.
- `Core/Lists/*`: Deterministic list detection/rendering (detector + parser/run-selection/trailing-split helpers and renderer).
- `Core/Services/Paste/PasteService.swift`: AX insertion, menu fallback, clipboard restore orchestration.
- `Core/Services/Paste/PasteMenuFallbackExecutor.swift`: Menu fallback orchestration and verification coordination.
- `Core/Services/Paste/PasteMenuFallbackCoordinator.swift`: Menu fallback decision flow, warmup suppression bookkeeping, fallback transport normalization, and runtime-PID live AX verification binding.
- `Core/Services/Paste/PasteMenuScanner.swift`: Menu-bar traversal and Paste/Undo menu item discovery helpers.
- `Core/Services/Paste/PasteAXLiveSession.swift`: Live AX observer session for value-change verification.
- `Core/Services/Paste/PasteFailureRecoveryCoordinator.swift`: Paste failure-recovery lifecycle.
- `Core/Services/AppUpdateService.swift`: GitHub Releases polling and update prompt logic.
- `Core/Services/UpdateFeedConfig.swift`: Tracked update feed config + local override resolution.
- `Core/Services/AppUpdateLogic.swift`: Pure update parsing/version/host validation helpers.
- `Views/OnboardingView.swift`: Onboarding UI flow orchestration across setup steps.
- `Views/OnboardingMicrophoneStepController.swift`: Onboarding Step 1 microphone authorization/gating state and actions.
- `Views/Components/OnboardingMicrophonePickerView.swift`: Onboarding microphone selection modal UI (presentation-only).
- `Views/Settings/SettingsView+Dictionary.swift`: Dictionary tab composition and support-note footer.
- `Views/Settings/SettingsView+DictionarySection.swift`: Dictionary entry management list, sorting controls, and add/edit/delete actions.
- `Views/Settings/SettingsView+ModelSection.swift`: Reusable model install/remove controls now embedded in More tab.
- `Views/Warnings/WarningManager.swift`: Warning overlay lifecycle with hover-aware auto-dismiss and animated dismiss transitions.

## Platform Compatibility

- Supported macOS range: Ventura (macOS 13.5) and newer.

For the full file-level map, see [`CODEMAP.md`](CODEMAP.md).

## Inference Model

- KeyVox uses Whisper's multilingual base model (`ggml-base`) for on-device transcription.

## Post-Processing Order

1. `WhisperAudioParagraphChunker` computes conservative chunk boundaries from silence windows.
2. Whisper transcribes each chunk and `WhisperService` stitches chunk text with `\n\n` when `autoParagraphsEnabled` is on (space-separated when off).
3. `EmailAddressNormalizer` runs first (email literal case + punctuation/sentence-boundary cleanup).
4. Dictionary correction applies custom-word adherence, including dictionary-backed spoken/literal email recovery.
5. `ColonNormalizer` converts spoken/delimiter colon phrases into deterministic punctuation before list parsing.
6. List formatting applies numeric list rendering when confidence gates pass.
7. Dedicated laughter normalization (`LaughterNormalizer`) and repeated-character spam cleanup (`CharacterSpamNormalizer`) run, then time normalization (`TimeExpressionNormalizer`) and final email boundary repair.
8. Normalization helpers apply render-mode whitespace, capitalization guards, and terminal-time punctuation completion.
9. `AllCapsOverrideNormalizer` applies a final uppercase override when Caps Lock mode is active.
10. Final text is inserted via the paste service.

## Update Feed and Release Checks

`Core/Services/AppUpdateService.swift` is the update source-of-truth.

- Reads latest release metadata from GitHub Releases.
- Normalizes release tags such as `v1.2.3` to `1.2.3`.
- Uses release body as update prompt text.
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

## Working Tree Delta From `HEAD`

- Dictionary matcher file split renamed to extension-style files:
  - Removed: `Core/AI/Dictionary/DictionaryMatcherCandidateEvaluator.swift`, `Core/AI/Dictionary/DictionaryMatcherModels.swift`, `Core/AI/Dictionary/DictionaryMatcherOverlapResolver.swift`, `Core/AI/Dictionary/DictionaryMatcherSplitJoinEvaluator.swift`, `Core/AI/Dictionary/DictionaryMatcherTokenizer.swift`
  - Added: `Core/AI/Dictionary/DictionaryMatcher+CandidateEvaluator.swift`, `Core/AI/Dictionary/DictionaryMatcher+Models.swift`, `Core/AI/Dictionary/DictionaryMatcher+OverlapResolver.swift`, `Core/AI/Dictionary/DictionaryMatcher+SplitJoinEvaluator.swift`, `Core/AI/Dictionary/DictionaryMatcher+Tokenizer.swift`
- Dictionary/email normalization boundaries were separated:
  - Removed: `Core/AI/Dictionary/TextNormalization.swift`
  - Added: `Core/AI/Dictionary/DictionaryTextNormalization.swift`, `Core/Normalization/EmailAddressNormalizer.swift`
  - Updated callers: `Core/AI/Dictionary/DictionaryMatcher.swift`, `Core/AI/PronunciationLexicon.swift`, `KeyVoxTests/AI/Dictionary/DictionaryMatcherCoreLogicTests.swift`
- Website/domain helper extraction centralized URL primitives:
  - Added: `Core/Normalization/WebsiteNormalizer.swift`
  - Updated: `Core/AI/Dictionary/Email/DictionaryMatcher+EmailNormalization.swift`, `Core/Lists/ListPatternDetector.swift`, `Core/Lists/ListPatternMarkerParser.swift`
- Dictionary email helper extensions were renamed:
  - Removed: `Core/AI/Dictionary/Email/DictionaryMatcherEmailNormalization.swift`, `Core/AI/Dictionary/Email/DictionaryMatcherEmailResolution.swift`
  - Added: `Core/AI/Dictionary/Email/DictionaryMatcher+EmailNormalization.swift`, `Core/AI/Dictionary/Email/DictionaryMatcher+EmailResolution.swift`
- Dictionary email resolution helpers were split for maintainability:
  - Added: `Core/AI/Dictionary/Email/DictionaryMatcher+EmailDomainResolution.swift`, `Core/AI/Dictionary/Email/DictionaryMatcher+EmailParsing.swift`
  - Updated: `Core/AI/Dictionary/Email/DictionaryMatcher+EmailResolution.swift` to keep only spoken/literal/standalone resolution logic.
- Post-processing moved under `Core/Transcription` and time normalization was extracted:
  - Removed: `Core/TranscriptionPostProcessor.swift`
  - Added: `Core/Transcription/TranscriptionPostProcessor.swift`, `Core/Normalization/TimeExpressionNormalizer.swift`
- Post-processing normalization internals were split into focused helpers:
  - Added: `Core/Normalization/WhitespaceNormalizer.swift`, `Core/Normalization/SentenceCapitalizationNormalizer.swift`, `Core/Normalization/ColonNormalizer.swift`, `Core/Normalization/TerminalPunctuationNormalizer.swift`, `Core/Normalization/LaughterNormalizer.swift`
  - Updated: `Core/Transcription/TranscriptionPostProcessor.swift` to orchestrate helper modules.
- Character spam hardening was added for post-processing noise suppression:
  - Added: `Core/Normalization/CharacterSpamNormalizer.swift`
  - Updated: `Core/Transcription/TranscriptionPostProcessor.swift`, `KeyVoxTests/Core/TranscriptionPostProcessorTests+LanguageHeuristics.swift`
- Caps Lock all-caps override was added as an independent post-processing layer:
  - Added: `Core/Normalization/AllCapsOverrideNormalizer.swift`
  - Updated: `Core/KeyboardMonitor.swift`, `Core/Transcription/DictationPipeline.swift`, `Core/Transcription/TranscriptionManager.swift`, `Core/Transcription/TranscriptionPostProcessor.swift`
- Project wiring:
  - `KeyVox.xcodeproj/project.pbxproj` updated to align source/build references with the renamed and moved files.
