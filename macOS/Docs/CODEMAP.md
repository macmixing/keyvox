# KeyVox Code Map
**Last Updated: 2026-03-12**

## Project Overview

KeyVox is a macOS menu bar dictation app that records speech while a trigger key is held, transcribes locally with Whisper, and inserts text into the focused app. The default trigger is **Right Option (⌥)**.

## Architecture

- **App**: app entry point, window lifecycle, shared settings/defaults ownership
- **Core**: state machine, audio pipeline, keyboard monitoring, overlay orchestration, model management, paste/update host integration
- **Packages/KeyVoxCore**: shared dictation engine (transcription pipeline, dictionary matching, normalization, lists, shared audio helpers, packaged resources)
- **Core/Services**: reusable host integration services (paste/injection, update checking)
- **Views**: SwiftUI UI layer (menu, onboarding, settings, overlays, warnings, branded visuals)
- **Resources**: assets, entitlements, bundled fonts/icons, pronunciation resources
- **Tools**: maintainer-only scripts (resource generation, dev helpers)
- **KeyVoxTests**: app unit tests for deterministic/runtime-safe logic
- **Packages**: local Swift packages for the shared engine and the `whisper.cpp` wrapper

## Contributor Notes

- Behavior and motion constants are kept file-local near their owning runtime logic to reduce maintenance confusion.
- Proprietary visual tuning remains in the excluded branded file `Views/Components/LogoBarView.swift`.
- Shared macOS app-window theme tokens now live in `Views/Components/MacAppTheme.swift`; use that file for reusable settings/onboarding/update/modal colors instead of repeating local window background stacks.
- `Views/StatusMenuView.swift` and `Views/Warnings/*` intentionally keep separate styling ownership and are not part of `MacAppTheme`.
- No shared constants module is required unless a value is truly reused across multiple domains.
- Unit tests intentionally focus on deterministic/runtime-safe behavior; hardware/global-input/UI-rendering remain integration scope.
- `CODEMAP.md` is the source of truth for high-level file ownership and where major systems live; `ENGINEERING.md` owns behavior contracts, pipeline order, and maintainer policy.

## Directory Index

This is a curated map of the repo layout (intentionally not an exhaustive inventory).

```text
KeyVox/
├── App/
│   ├── KeyVoxApp.swift
│   ├── WindowManager+Updates.swift
│   ├── AppSettingsStore.swift
│   ├── AppServiceRegistry.swift
│   ├── LoginItemController.swift
│   ├── WeeklyWordStatsStore.swift
│   └── UserDefaultsKeys.swift
├── Core/
│   ├── KeyboardMonitor.swift
│   ├── Audio/
│   │   └── AudioRecorder.swift
│   ├── Transcription/
│   │   └── TranscriptionManager.swift
│   ├── Services/
│   │   ├── Paste/
│   │   │   └── PasteService.swift
│   │   ├── AppUpdateService.swift
│   │   └── AppUpdate/
│   ├── Overlay/
│   │   ├── OverlayManager.swift
│   │   └── AudioIndicatorDriver.swift
├── Views/
│   ├── Components/
│   │   ├── LogoBarView.swift
│   │   └── MacAppTheme.swift
│   ├── StatusMenuView.swift
│   ├── OnboardingView.swift
│   ├── RecordingOverlay.swift
│   ├── UpdatePromptOverlay.swift
│   ├── Updates/
│   ├── Settings/
│   └── Warnings/
├── Resources/
├── Packages/
│   ├── KeyVoxCore/
│   │   └── Sources/KeyVoxCore/
│   │       ├── Transcription/
│   │       ├── Services/Whisper/
│   │       ├── Language/
│   │       ├── Lists/
│   │       ├── Normalization/
│   │       ├── Audio/
│   │       └── Resources/Pronunciation/
│   └── KeyVoxWhisper/
├── Tools/
├── KeyVoxTests/
└── Docs/
    ├── CODEMAP.md
    └── ENGINEERING.md
```


## Core Runtime Flow

1. `Core/KeyboardMonitor.swift` publishes trigger/shift/escape/caps-lock state.
2. `Core/Transcription/TranscriptionManager.swift` drives app state: `idle -> recording -> transcribing -> idle`.
3. `Core/Audio/AudioRecorder.swift` captures live audio as mono float frames at 16kHz.
4. `Packages/KeyVoxCore/Sources/KeyVoxCore/Services/Whisper/WhisperAudioParagraphChunker.swift` detects long internal silence and computes conservative chunk boundaries.
5. `Packages/KeyVoxCore/Sources/KeyVoxCore/Services/Whisper/WhisperService.swift` transcribes each chunk through `KeyVoxWhisper` and stitches chunks with paragraph or space separators.
6. `Packages/KeyVoxCore/Sources/KeyVoxCore/Transcription/TranscriptionPostProcessor.swift` orchestrates dictionary correction, list formatting, and specialized normalization helpers under `Packages/KeyVoxCore/Sources/KeyVoxCore/Normalization/`, including four-digit quantity grouping.
7. `Core/Services/Paste/PasteService.swift` normalizes leading capitalization and spacing, then inserts text via Accessibility first and menu-bar Paste fallback second.
8. `Core/Overlay/OverlayManager.swift` owns overlay lifecycle orchestration and delegates motion/persistence helpers.
9. `Core/Overlay/AudioIndicatorDriver.swift` owns generic indicator timing, smoothing, stale-sample handling, and published timeline state.
10. `Views/RecordingOverlay.swift` hosts overlay visibility behavior and feeds generic indicator state into the branded renderer.
11. `Views/Components/LogoBarView.swift` is the single branded Mac logo renderer for both standalone logo presentation and overlay-reactive modes.

## Key Components

### App Layer

- `App/KeyVoxApp.swift`
  - App entry point and menu bar scene.
  - Owns onboarding/settings windows via `WindowManager`.
  - Reopen behavior prefers visible non-settings windows (updater, post-update notice, onboarding) before falling back to Settings.
  - Cancels app termination once to close Settings first when the Settings window is visible.
- `App/WindowManager+Updates.swift`
  - Dedicated updater and post-update notice window lifecycle.
  - Applies updater-specific floating-window centering and stoplight hiding.
  - Keeps update-related window policy out of the primary settings/onboarding window code.
- `App/AppSettingsStore.swift`
  - Centralized persisted user-preference owner (`triggerBinding`, `autoParagraphsEnabled`, sound settings, onboarding, selected microphone, update prompt timestamps).
  - Single in-memory observable source consumed by settings UI and runtime managers.
- `App/AppServiceRegistry.swift`
  - Retains shared runtime services and app-owned sync helpers.
  - Owns the dedicated weekly stats store/sync subsystem separately from the general iCloud settings coordinator.
- `App/WeeklyWordStatsStore.swift`
  - Dedicated local weekly-usage store for combined weekly word count plus hidden per-installation contribution totals.
  - Persists a stable installation identifier, current-week snapshot, and rollover behavior outside `AppSettingsStore`.
- `App/iCloud/WeeklyWordStatsCloudSync.swift`
  - Dedicated iCloud KVS sync helper for weekly word stats only.
  - Merges same-week per-device totals deterministically and keeps `KeyVoxiCloudSyncCoordinator` focused on dictionary/settings sync.
- `App/UserDefaultsKeys.swift`
  - Single source of truth for app preference keys.
- `Views/OnboardingView.swift`
  - Onboarding step orchestration UI.
  - Delegates microphone Step 1 flow logic to `OnboardingMicrophoneStepController`.
  - Uses `LogoBarView(size:)` for the standalone branded logo presentation.
- `Views/OnboardingMicrophoneStepController.swift`
  - Owns onboarding microphone authorization and no-built-in gating behavior.
  - Drives microphone-step completion state and prompt visibility.
- `Views/Components/OnboardingMicrophonePickerView.swift`
  - Presentation-only onboarding modal for required microphone selection confirmation.
  - Uses the shared app action button treatment for the microphone confirmation action.
- `Views/Components/MacAppTheme.swift`
  - Shared macOS app-window theme tokens for settings, onboarding, updater, and related modal surfaces.
  - Owns the standard main-window background color (`#1A1740` equivalent) plus reusable card/icon/sidebar/stroke accents.
  - Explicitly excludes `StatusMenuView` and warning overlays from the shared theme boundary.
- `Views/Components/DictionaryFloatingAddButton.swift`
  - Shared floating circular add action used by the dictionary settings surface.
- `Views/Components/LogoBarView.swift`
  - Single branded Mac logo file.
  - Provides both standalone logo presentation (`LogoBarView(size:)`) and recording-indicator presentation (`LogoBarView(phase:timelineState:ringColor:)`).
  - Contains the proprietary ring/glow/bar/ripple visual language and visual tuning.
- `Views/RecordingOverlay.swift`
  - Thin overlay shell for visibility animation, panel sizing, and ring-color selection.
  - Feeds recorder-derived indicator samples into `AudioIndicatorDriver` and renders `LogoBarView`.

### Core Managers

- `Core/Transcription/TranscriptionManager.swift`
  - Orchestrates recording, transcription, and paste.
  - Routes transcribe -> post-process -> paste through internal `DictationPipeline` for boundary-testability.
  - Handles hands-free lock mode and escape cancellation.
  - Chooses list render mode (`multiline` vs `singleLineInline`) from focused target context before post-processing.
  - Records spoken-word totals through `WeeklyWordStatsStore` instead of the general app settings store.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Transcription/DictationPipeline.swift`
  - Boundary helper for transcribe -> post-process -> paste orchestration with injected dependencies for smoke/integration tests.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Transcription/DictationPromptEchoGuard.swift`
  - Post-transcription guard that suppresses likely dictionary-prompt echo output by treating repetitive prompt-like text as no-speech.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Transcription/TranscriptionPostProcessor.swift`
  - Post-transcription orchestration (email pre-normalization, dictionary correction, idiom/colon/math/list passes, laughter/spam/time/email/website/four-digit grouping cleanup, then whitespace/capitalization/terminal-punctuation/all-caps finishing).
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Normalization/TimeExpressionNormalizer.swift`
  - Isolated time-shape and meridiem normalization helper used by post-processing.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Normalization/MathExpressionNormalizer.swift`
  - Deterministic math phrase/operator normalization (`plus/minus/times/divided by`, exponents, percent, chained expressions) with protected URL/email/code/time/date/version spans.
  - Strips terminal punctuation only for standalone math utterances while preserving sentence punctuation.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Normalization/LaughterNormalizer.swift`
  - Dedicated laughter normalization pass (`ha ha` -> `haha`) separated from time normalization.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Normalization/CharacterSpamNormalizer.swift`
  - Collapses model character-spam runs (same non-whitespace character repeated 16+ times) to a single character.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Normalization/WhitespaceNormalizer.swift`
  - Render-mode-aware whitespace normalization (`.multiline` paragraph preservation vs `.singleLineInline` flattening).
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Normalization/SentenceCapitalizationNormalizer.swift`
  - Sentence-start/text-start/line-break capitalization with email/domain safety guards.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Normalization/ColonNormalizer.swift`
  - Converts spoken/delimiter forms of `colon` into punctuation (`:`) with lightweight homophone tolerance and punctuation cleanup guards.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Normalization/TerminalPunctuationNormalizer.swift`
  - Appends terminal period for sentence-like outputs ending in formatted times when punctuation is absent.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Normalization/AllCapsOverrideNormalizer.swift`
  - Final independent override that uppercases post-processed output when Caps Lock mode is enabled.
- `Core/KeyboardMonitor.swift`
  - Global/local key monitors with left/right modifier specificity.
  - Default trigger binding is `rightOption`.
  - Publishes live Caps Lock state used to enable forced all-caps output mode.
  - Mirrors persisted trigger binding from `AppSettingsStore`; owns runtime key state only.
- `Core/Overlay/OverlayManager.swift`
  - Floating overlay lifecycle orchestration and visibility.
- `Core/Overlay/AudioIndicatorDriver.swift`
  - Generic audio-indicator driver for overlay/logo timing.
  - Owns smoothing, stale-sample handling, phase progression, and published timeline state.
  - Keeps reusable indicator types neutral (`AudioIndicatorPhase`, `AudioIndicatorSignalState`, `AudioIndicatorSample`, `AudioIndicatorTimelineState`) and non-branded.
- `Core/Overlay/OverlayMotionController.swift`
  - Fling/reset motion sequencing, timers/work items, and programmatic motion guards.
- `Core/Overlay/OverlayScreenPersistence.swift`
  - Per-display persistence using preferred-display key + origins-by-display map plus legacy migration.
- `Core/Overlay/OverlayPanel.swift`
  - NSPanel event capture for drag velocity sampling and double-click reset trigger.
- `Core/Overlay/OverlayFlingPhysics.swift`
  - Pure fling impact/reflection/duration helpers used by motion control.
- `Core/AudioDeviceManager.swift`
  - Microphone discovery and selection policy.
  - Uses `AppSettingsStore.selectedMicrophoneUID` for persisted selection.
- `Core/ModelDownloader/ModelDownloader.swift`
  - Downloads `ggml-base.bin` plus CoreML encoder zip and validates readiness.
- `Core/ModelDownloader/ModelDownloader+DownloadLifecycle.swift`
  - Owns URLSession delegate callbacks, progress state transitions, and failure completion handling.
- `Core/ModelDownloader/ModelDownloader+Validation.swift`
  - Validates downloaded model artifacts and enforces readiness checks before marking model available.
- `Core/Audio/AudioRecorder.swift`
  - Audio-recorder state holder and public orchestration entrypoints (`startRecording`, `stopRecording`).
- `Core/Audio/AudioRecorder+Session.swift`
  - Capture session/device lifecycle setup and teardown.
- `Core/Audio/AudioRecorder+Streaming.swift`
  - Live sample conversion/downsampling, frame buffering, and quiet/dead/active waveform state updates.
- `Core/Audio/AudioRecorder+PostProcessing.swift`
  - Stop-time gap removal, normalization, capture classification, and final output frame selection.
- `Core/Audio/AudioRecorder+Thresholds.swift`
  - Input-volume-based threshold profile calibration and CoreAudio scalar lookup helpers.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Audio/AudioCaptureClassification.swift`
  - Centralized per-capture classification (absolute silence, long true silence, likely-silence rejection).
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Audio/AudioSilencePolicy.swift`
  - Shared thresholds/rules for low-confidence capture rejection and long true-silence detection.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Audio/AudioSignalMetrics.swift`
  - Pure signal metrics (RMS, peak, true-silence window ratio) used by capture classification.

### Service Layer (`Core/Services` + `Packages/KeyVoxCore/Sources/KeyVoxCore/Services`)

- `Core/Services/AppUpdateService.swift`
  - Fetches the latest GitHub release, applies session snooze rules, and builds the initial update prompt.
  - Keeps automatic prompt policy separate from the install pipeline.
- `Core/Services/AppUpdateLogic.swift`
  - Pure update release parsing, host allowlist checks, version normalization/comparison, and asset classification.
- `Core/Services/AppUpdate/AppReleaseInfo.swift`
  - Canonical updater release and manifest metadata models.
- `Core/Services/AppUpdate/AppUpdateCoordinator.swift`
  - UI-facing updater state machine for release refresh, download, verification, install handoff, and post-update notice state.
- `Core/Services/AppUpdate/AppUpdateManifestLoader.swift`
  - Downloads and decodes the manifest asset referenced by the selected release.
- `Core/Services/AppUpdate/AppUpdateDownloadService.swift`
  - URLSession-based zip download orchestration and staged file delivery.
- `Core/Services/AppUpdate/AppUpdateDownloadDelegate.swift`
  - Download delegate bridge for progress callbacks and completion handling.
- `Core/Services/AppUpdate/AppUpdateChecksumVerifier.swift`
  - SHA-256 verification for downloaded updater archives.
- `Core/Services/AppUpdate/AppUpdateArchiveExtractor.swift`
  - Zip extraction into updater-managed staging directories.
- `Core/Services/AppUpdate/AppUpdateBundleVerifier.swift`
  - Bundle structure, bundle identifier/version, codesign, Team ID, and Gatekeeper verification for staged update apps.
- `Core/Services/AppUpdate/AppUpdateInstallLauncher.swift`
  - Launches `Resources/updater.sh`, stages post-update notice state, and terminates the app only after install handoff is confirmed.
- `Core/Services/AppUpdate/AppUpdateApplicationsPrereflight.swift`
  - `/Applications` prerequisite handling, including self-copy-and-relaunch before resuming install.
- `Core/Services/AppUpdate/AppUpdateLaunchNoticeService.swift`
  - Launch-time resolution of the one-time “updated” notice after successful installs.
- `Core/Services/AppUpdate/AppUpdateCleanupService.swift`
  - Startup cleanup for updater staging artifacts and deferred backup removal.
- `Core/Services/AppUpdate/AppUpdatePaths.swift`
  - Centralized release staging, zip, extract, and cleanup path construction.

- `Packages/KeyVoxCore/Sources/KeyVoxCore/Services/Whisper/WhisperAudioParagraphChunker.swift`
  - Splits long captures into paragraph-sized chunks using deterministic RMS silence windows.
  - Uses configurable chunk-size and silence-run guardrails to avoid over-splitting.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Services/Whisper/WhisperService.swift`
  - Loads model from Application Support and runs inference.
  - Uses automatic language detection (`.auto`).
  - Supports optional auto-paragraph stitching via `enableAutoParagraphs`.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Services/Whisper/WhisperService+ModelLifecycle.swift`
  - Isolates model lifecycle helpers (`warmup`, `unloadModel`, model-path resolution).
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Services/Whisper/WhisperService+TranscriptionCore.swift`
  - Owns chunk transcription flow, retry selection, whitespace normalization, and debug segment logging.

### Post-Processing (`Packages/KeyVoxCore/Transcription` + `Packages/KeyVoxCore/Normalization` + `Packages/KeyVoxCore/Language` + `Packages/KeyVoxCore/Lists`)

- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/DictionaryMatcher.swift`
  - Orchestrates dictionary matching flow and delegates tokenizer/candidate/split-join/overlap helpers.
  - Maintains a domain-indexed email dictionary for spoken/literal email recovery.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Normalization/EmailAddressNormalizer.swift`
  - Shared non-dictionary email literal cleanup (casing, punctuation spacing, sentence-boundary repair, ellipsis normalization).
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Normalization/WebsiteNormalizer.swift`
  - Shared website/domain helper for compact-domain detection, leading-domain normalization, and standalone website checks.
  - Used by list marker parsing/detection and dictionary email normalization to keep website rules centralized.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Normalization/MathExpressionNormalizer.swift`
  - Shared deterministic math normalizer pass used by post-processing before list parsing.
  - Converts high-confidence spoken math into symbol form while preserving non-math structures and protected spans.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Normalization/ColonNormalizer.swift`
  - Provides spoken-colon normalization before list detection to stabilize `label colon value` phrasing into deterministic punctuation.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Normalization/CharacterSpamNormalizer.swift`
  - A model-noise guard that trims extreme repeated-character runs before downstream punctuation/capitalization finishing passes.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Normalization/ThousandsGroupingNormalizer.swift`
  - Adds grouping separators to quantity-style four-digit numerals while preserving year-like references and protected date/version/phone shapes.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Normalization/AllCapsOverrideNormalizer.swift`
  - Final-stage output override that forces uppercase while preserving prior list/email/website/time formatting.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/Email/DictionaryEmailEntry.swift`
  - Canonical email entry model and sanitizer for dictionary phrases that are valid email addresses.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/Email/DictionaryMatcher+EmailDomainResolution.swift`
  - Domain candidate extraction and fuzzy-domain disambiguation helpers for dictionary email matching.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/Email/DictionaryMatcher+EmailNormalization.swift`
  - Detects spoken (`name at domain`), compact (`nameatdomain`), and literal email candidates and rewrites them using dictionary-backed resolution.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/Email/DictionaryMatcher+EmailParsing.swift`
  - Shared local/domain normalization and attached-list-marker parsing helpers used by email normalization/resolution.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/Email/DictionaryMatcher+EmailResolution.swift`
  - Resolves spoken/literal/standalone dictionary email candidates and local-part ambiguity via deterministic guards.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/DictionaryMatcher+Tokenizer.swift`
  - Token extraction and range construction helpers used by matcher runtime.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/Evaluation/DictionaryMatcher+StandardEvaluation.swift`
  - Standard 1-4 token candidate scoring with thresholds, ambiguity, common-word, and short-token guards.
  - Applies contextual gating for common-word-like replacements to avoid unsupported prose substitutions.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/Evaluation/DictionaryMatcher+MergedTokenEvaluation.swift`
  - Merged-token recovery path for compact spoken forms that collapse multi-token dictionary entries.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/Evaluation/DictionaryMatcher+ThreeTokenEvaluation.swift`
  - Three-token-specific recovery paths (middle-initial and compressed-tail patterns).
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/Evaluation/Helpers/DictionaryMatcher+EvaluationStylizedHelpers.swift`
  - Provides stylized-token evidence and fallback-phonetic helpers used by standard/split-join evaluators.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/Evaluation/Helpers/DictionaryMatcher+EvaluationSuffixHelpers.swift`
  - Implements possessive/plural form generation and suffix inference helpers used by evaluators.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/Evaluation/Helpers/DictionaryMatcher+EvaluationEvidenceHelpers.swift`
  - Contains split-tail consumption and token-alignment evidence helpers for deterministic scoring boosts.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/Evaluation/SplitJoin/DictionaryMatcher+SplitJoinScoring.swift`
  - Split-token to single-entry scoring and acceptance path with plural/possessive handling.
  - Promotes plural-tail split joins to possessive output when guarded possessive context is present.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/Evaluation/SplitJoin/DictionaryMatcher+SplitJoinForms.swift`
  - Split-join observed-form generation and replacement-suffix normalization helpers.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/Evaluation/SplitJoin/DictionaryMatcher+SplitJoinGuards.swift`
  - Split-join guard heuristics (domain-shape suppression, anchoring checks, possessive-sound inference).
  - Requires noun-following context for possessive split-join inference to limit false positives.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/DictionaryMatcher+OverlapResolver.swift`
  - Deterministic overlap pruning with confidence-first ordering.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/DictionaryTextNormalization.swift`
  - Shared phrase/token normalization used by dictionary matching and pronunciation lexicon loading.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/DictionaryStore.swift`
  - Persistent custom dictionary storage, validation, and backup recovery.
  - Exposes warning-clear helper for settings lifecycle cleanup.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/DictionaryEntry.swift`
  - Canonical dictionary entry model.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/PronunciationLexicon.swift`
  - Loads bundled pronunciation signatures and curated common-word safety list from `Packages/KeyVoxCore/Sources/KeyVoxCore/Resources/Pronunciation/`.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/PhoneticEncoder.swift`
  - Uses lexicon lookups first, then deterministic fallback encoding for unknown words.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/ReplacementScorer.swift`
  - Centralizes score weights, thresholds, ambiguity margin, and similarity math.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Lists/ListFormattingEngine.swift`
  - Applies conservative numeric list formatting only when reliable list patterns are detected.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Lists/ListPatternDetector.swift`
  - Detects monotonic list markers (digits + locale-aware spoken number cues) with false-positive guards.
  - Splits leading/list/trailing segments to preserve non-list prose around list blocks.
  - Delegates leading domain-token lowercasing to `WebsiteNormalizer`.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Lists/ListPatternMarkerParser.swift`
  - Parses spoken/typed marker tokens into canonical marker metadata used by list detection.
  - Handles markers attached to domains, spoken `to` as list marker 2 in email-list shapes, and time-component false-positive suppression.
  - Uses `WebsiteNormalizer` for domain-token heuristics to avoid duplicated website regex logic.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Lists/ListPatternRunSelector.swift`
  - Selects best monotonic list run and enforces confidence guards before formatting.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Lists/ListPatternTrailingSplitter.swift`
  - Splits trailing prose off list items while preserving valid list item content.
  - Uses scored deterministic split candidates with email-boundary-aware preference.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Lists/ListPatternMarker.swift`
  - Shared marker model for parser/detector/run-selection helpers.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Lists/ListRenderer.swift`
  - Renders detected lists as multiline (`1. ...`) or single-line inline (`1. ...; 2. ...`) based on target context.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Lists/ListFormattingTypes.swift`
  - Shared types for list render mode and detected list segments/items.
- `Tools/Pronunciation/build_lexicon.sh`
  - Maintainer pipeline for pinned-source regeneration of lexicon/common-word resources.
  - Enforces row targets and writes package-owned outputs under `Packages/KeyVoxCore/Sources/KeyVoxCore/Resources/Pronunciation/`, including `sources.lock.json`.

### Update UI (`Views/UpdatePromptOverlay.swift` + `Views/Updates` + `Views/Components`)

- `Views/Components/AppActionButton.swift`
  - Shared capsule-styled primary/secondary/destructive button used across updater, settings prompt, and onboarding confirmation surfaces.
- `Views/UpdatePromptOverlay.swift`
  - Lightweight update prompt shown before entering the dedicated updater window.
  - Owns prompt-window centering through `UpdatePromptManager`.
- `Views/Updates/UpdateWindowView.swift`
  - Dedicated updater window shell with dynamic height reporting and explicit drag region.
- `Views/Updates/UpdateHeaderCard.swift`
  - Current version / target version / state summary card for the updater window.
- `Views/Updates/UpdateProgressCard.swift`
  - Download/install progress card and byte-count presentation.
- `Views/Updates/UpdateApplicationsRequirementCard.swift`
  - `/Applications` prerequisite card shown before self-move and relaunch.
- `Views/Updates/UpdateFailureCard.swift`
  - Failure presentation card for updater pipeline errors.
- `Views/Updates/PostUpdateNoticeView.swift`
  - Final post-update notice window shown after successful installs.
- `Views/Components/AppUpdateProgressBar.swift`
  - Updater-specific progress bar component used inside updater progress UI.

### Release Tooling (`build/`)

- `build/build_release.sh`
  - Maintainer packaging helper for exported release apps.
  - Verifies a signed/notarized exported `.app`, creates `Release/KeyVox-<version>.zip`, and writes `Release/keyvox-update-manifest.json`.
- `build/build_dmg.sh`
  - Maintainer DMG packaging script for manual-install distribution artifacts.
- `Tools/Pronunciation/train_g2p.sh`
  - Build-time Phonetisaurus/OpenFst G2P generation for OOV pronunciation candidates used when regenerating package-owned pronunciation resources.
- `Tools/Pronunciation/verify_licenses.sh`
  - Enforces allowed-source and attribution policy before distribution.
- `Tools/Pronunciation/benchmarks/run_quality_gates.sh`
  - Enforces coverage/hit-rate/false-positive/latency thresholds using benchmark fixtures.
- `Tools/Pronunciation/benchmarks/evaluate_matcher.swift`
  - Thin benchmark CLI entrypoint (`@main`) that delegates to modular evaluator helpers.
- `Tools/Pronunciation/benchmarks/evaluate/EvaluateMatcherCore.swift`
  - Offline matcher core used by pronunciation benchmark quality evaluation.
- `Tools/Pronunciation/benchmarks/evaluate/EvaluateBenchmarkIO.swift`
  - Benchmark fixture loading and shared parsing/stat helper functions.
- `Tools/Pronunciation/benchmarks/evaluate/EvaluateBenchmarkRunner.swift`
  - End-to-end metric computation and main execution wrapper.
- `Tools/ExploreAX.swift`
  - Single-app (frontmost) Accessibility tree and candidate diagnostics for paste verification troubleshooting.
- `Tools/ExploreAXApps.swift`
  - Multi-app Accessibility scanner for comparing AX candidate quality across running apps.
- `Tools/ObservePasteAXNotifications.swift`
  - Captures AX notifications for focused targets during paste debugging.
- `Tools/ExplorePasteSignal.sh`
  - Repeatable shell harness for probing paste signal behavior and AX fallback timing.
- `Tools/README.md`
  - Maintainer/contributor guide for all scripts in `Tools/`.
- `Core/Services/Paste/PasteService.swift`
  - Orchestrates paste pipeline (dictionary-aware leading-cap normalization, smart spacing, AX injection, menu fallback, recovery, clipboard restore).
  - Determines preferred list render mode from focused AX role for single-line graceful fallback.
- `Core/Services/Paste/Clipboard/PasteFailureRecoveryCoordinator.swift`
  - Manages active paste-failure recovery session lifecycle, timers, and Command-V detection.
- `Core/Services/Paste/Accessibility/PasteAXInspector.swift`
  - Shared AX inspection helpers used by spacing, injector, and fallback verification.
- `Core/Services/Paste/Accessibility/PasteAccessibilityInjector.swift`
  - Direct AX selected-text insertion path with outcome classification.
- `Core/Services/Paste/MenuFallback/PasteMenuFallbackExecutor.swift`
  - Orchestrates menu fallback execution and verification decisions.
  - Coordinates AX snapshot verification, undo-state fallback checks, and live AX session verification.
- `Core/Services/Paste/MenuFallback/PasteMenuFallbackCoordinator.swift`
  - Coordinates menu-fallback decision flow from `PasteService` and computes fallback result flags.
  - Owns first-success warmup suppression bookkeeping and menu fallback transport normalization.
  - Binds live AX value-change verification to runtime frontmost PID (with captured target fallback).
- `Core/Services/Paste/MenuFallback/PasteMenuScanner.swift`
  - Encapsulates menu traversal/discovery for Paste and Undo menu items.
  - Keeps AX identifier/shortcut/title matching and menu-item attribute readers.
- `Core/Services/Paste/Accessibility/PasteAXLiveSession.swift`
  - Encapsulates AXObserver lifecycle used for live value-change verification during menu fallback.
- `Core/Services/Paste/Clipboard/PasteClipboardSnapshot.swift`
  - Full-fidelity clipboard snapshot capture/restore utilities.
- `Core/Services/Paste/Heuristics/PasteCapitalizationHeuristics.swift`
  - Sentence-boundary-aware leading-cap normalization for finalized transcription right before insertion.
  - Preserves dictionary-backed and structurally intentional casing while removing Whisper-style sentence casing mid-sentence.
- `Core/Services/Paste/Heuristics/PasteDictionaryCasingStore.swift`
  - Reads the persisted macOS dictionary snapshot to preserve exact leading phrase casing during paste-time normalization.
- `Core/Services/Paste/Heuristics/PasteSpacingHeuristics.swift`
  - Smart leading separator logic and cross-dictation spacing heuristics.
- `Core/Services/Paste/Pipeline/PastePolicies.swift`
  - Static policy helpers for list render mode and failure-recovery decisions.
- `Core/Services/Paste/Pipeline/PasteModels.swift`
  - Shared internal model/enums for paste pipeline collaborators.
- `Core/Services/UpdateFeedConfig.swift`
  - Centralized update feed owner/repo defaults.
  - Supports optional local override file at `~/Library/Application Support/KeyVox/update-feed.override.json`.
- `Core/Services/AppUpdateLogic.swift`
  - Pure helpers for release mapping, host allowlist checks, version normalization, and version comparison.
- `Core/Services/AppUpdateService.swift`
  - Fetches latest release metadata from GitHub Releases API.
  - Endpoint is composed from resolved update feed config.
  - Maps `tag_name` to app version comparison and builds a summarized release-notes preview from the release body.
  - Prefers `.dmg` `browser_download_url`, then falls back to release `html_url`.
  - Supports timer-based checks and manual checks.
  - Treats network/decoding failures as no-update for auto checks; manual checks surface an "Updates Temporarily Unavailable" prompt.
  - Triggers `UpdatePromptOverlay` through an injected prompt-presenting seam.
- `Core/Services/UpdatePromptPresenting.swift`
  - Main-actor protocol seam used to test update prompt flow without UI window dependencies.
- `Tools/UpdateFeed/configure_local_feed.sh`
  - Maintainer helper for setting, clearing, and showing the local update feed override file.
- `Tools/UpdateFeed/update-feed.override.example.json`
  - Template for local override JSON shape (the active override lives in Application Support, not in the repo).
- `Tools/Quality/check_core_coverage.sh`
  - Enforces allowlisted core-file coverage threshold from `.xcresult` using `xccov`.
- `Tools/Quality/coverage_summary.sh`
  - Emits markdown coverage summaries for CI job step output.

### UI Layer

- `Views/StatusMenuView.swift`
  - Menu bar UI, status rendering, warning actions.
  - Routes model-missing actions to the More settings tab and triggers model download.
- `Views/OnboardingView.swift`
  - First-run setup for permissions and model download.
  - Accessibility and microphone authorization hooks are delegated to `WindowManager` callbacks.
- `Views/Settings/*`
  - Split settings tabs and reusable settings components.
  - Shared app-window styling is sourced from `Views/Components/MacAppTheme.swift`.
- `Views/Settings/SettingsView+Dictionary.swift`
  - Dictionary tab container and English-only support footer text.
- `Views/Settings/SettingsView+DictionarySection.swift`
  - Dictionary management UI plus A-Z/Recently Added list sort toggle (hidden when no entries exist).
  - Dictionary description includes custom words, email addresses, and short phrases.
  - Primary add action is surfaced as a floating corner button from `Views/Components/DictionaryFloatingAddButton.swift`.
- `Views/Settings/SettingsView+ModelSection.swift`
  - Model install/remove row UI (`ModelSettingsRow`).
- `Views/Settings/SettingsView+More.swift`
  - More tab includes Launch at Login and model installer controls.
- `Views/Warnings/*`
  - Warning UI and panel orchestration for both system warnings and paste-failure recovery.
- `Views/Warnings/WarningManager.swift`
  - Owns warning panel lifecycle and paste-failure recovery panel presentation/update/dismiss.
  - Adds hover-aware auto-dismiss scheduling and animated slide/fade exit transitions.
- `Views/Warnings/PasteFailureRecoveryOverlayView.swift`
  - Paste-failure recovery view with `⌘ Cmd + V` guidance and progress bar.
- `Views/UpdatePromptOverlay.swift`
  - In-app update prompt UI.
  - Shares the standard macOS app-window theme surface through `MacAppTheme`.

## Change Tracking

- `CODEMAP.md` documents the current structure/ownership map only.
- Detailed change history should live in Git commits/PRs and release notes, not as hand-maintained per-file delta blocks.

## Persistence & Defaults

- Centralized persisted preferences owner: `App/AppSettingsStore.swift`
  - trigger binding, auto paragraphs toggle, sound enable/volume, selected microphone UID, onboarding completion, update prompt timestamps
- Shared app-owned runtime registry: `App/AppServiceRegistry.swift`
  - retains the dedicated weekly stats store/sync subsystem separately from the general iCloud settings coordinator
- Preference key catalog: `App/UserDefaultsKeys.swift`
- Paragraph style preference key: `KeyVox.AutoParagraphsEnabled`
- Audio-device initialization marker: `KeyVox.HasInitializedMicrophoneDefault` (owned in `Core/AudioDeviceManager.swift`)
- Weekly word stats owner: `App/WeeklyWordStatsStore.swift`
  - persists a stable installation identifier plus the current-week usage snapshot and local rollover behavior
- Weekly word stats iCloud sync: `App/iCloud/WeeklyWordStatsCloudSync.swift`
  - syncs the weekly stats payload through iCloud KVS and merges same-week per-device totals deterministically
- Weekly word stats local keys:
  - `KeyVox.App.WeeklyWordStatsPayload`
  - `KeyVox.App.WeeklyWordStatsInstallationID`
- Overlay placement:
  - preferred display key: `KeyVox.RecordingOverlayPreferredDisplayKey`
  - origins by display map: `KeyVox.RecordingOverlayOriginsByDisplay`
  - legacy read-only migration key: `KeyVox.RecordingOverlayOrigin`

## System / Build Facts

- Compatibility target: **macOS Ventura (13.5) and newer**
- App type: menu bar app (`MenuBarExtra`)
- Local model artifact name: `ggml-base.bin`
- Local packages:
  - `Packages/KeyVoxCore`: extracted shared engine, packaged resources, and reusable tests
  - `Packages/KeyVoxWhisper`: local `whisper.cpp` wrapper package
