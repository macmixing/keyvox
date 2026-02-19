# KeyVox Code Map
**Last Updated: 2026-02-19**

## Project Overview

KeyVox is a macOS menu bar dictation app that records speech while a trigger key is held, transcribes locally with Whisper, and inserts text into the focused app. The default trigger is **Right Option (⌥)**.

## Architecture

- **App**: app entry point, window lifecycle, shared settings/defaults ownership
- **Core**: state machine, audio pipeline, keyboard monitoring, overlay orchestration, model management
- **Core/AI**: dictionary storage + post-transcription normalization/matching helpers
- **Core/Lists**: deterministic text formatting (list detection/rendering)
- **Core/Services**: reusable integration services (Whisper, paste/injection, update checking)
- **Views**: SwiftUI UI layer (menu, onboarding, settings, overlays, warnings, branded visuals)
- **Resources**: assets, entitlements, bundled fonts/icons, pronunciation resources
- **Tools**: maintainer-only scripts (resource generation, dev helpers)
- **KeyVoxTests**: app unit tests for deterministic/runtime-safe logic
- **Packages**: local Swift package wrapping `whisper.cpp`

## Contributor Notes

- Behavior and motion constants are kept file-local near their owning runtime logic to reduce maintenance confusion.
- Proprietary visual tuning remains in excluded branded files (`Views/RecordingOverlay.swift`, `Views/Components/KeyVoxLogo.swift`).
- No shared constants module is required unless a value is truly reused across multiple domains.
- Unit tests intentionally focus on deterministic/runtime-safe behavior; hardware/global-input/UI-rendering remain integration scope.

## File Tree

```text
KeyVox/
├── App/
│   ├── AppSettingsStore.swift
│   ├── KeyVoxApp.swift
│   ├── LoginItemController.swift
│   └── UserDefaultsKeys.swift
├── Core/
│   ├── Services/
│   │   ├── AppUpdateLogic.swift
│   │   ├── AppUpdateService.swift
│   │   ├── Paste/
│   │   │   ├── PasteAXInspector.swift
│   │   │   ├── PasteAccessibilityInjector.swift
│   │   │   ├── PasteAXLiveSession.swift
│   │   │   ├── PasteClipboardSnapshot.swift
│   │   │   ├── PasteFailureRecoveryCoordinator.swift
│   │   │   ├── PasteMenuFallbackExecutor.swift
│   │   │   ├── PasteMenuFallbackCoordinator.swift
│   │   │   ├── PasteMenuScanner.swift
│   │   │   ├── PasteModels.swift
│   │   │   ├── PastePolicies.swift
│   │   │   ├── PasteService.swift
│   │   │   └── PasteSpacingHeuristics.swift
│   │   ├── UpdatePromptPresenting.swift
│   │   ├── UpdateFeedConfig.swift
│   │   ├── WhisperAudioParagraphChunker.swift
│   │   └── WhisperService.swift
│   ├── AI/
│   │   ├── Dictionary/
│   │   │   ├── Email/
│   │   │   │   ├── DictionaryEmailEntry.swift
│   │   │   │   ├── DictionaryMatcherEmailNormalization.swift
│   │   │   │   └── DictionaryMatcherEmailResolution.swift
│   │   │   ├── DictionaryEntry.swift
│   │   │   ├── DictionaryMatcher.swift
│   │   │   ├── DictionaryMatcherCandidateEvaluator.swift
│   │   │   ├── DictionaryMatcherModels.swift
│   │   │   ├── DictionaryMatcherOverlapResolver.swift
│   │   │   ├── DictionaryMatcherSplitJoinEvaluator.swift
│   │   │   ├── DictionaryMatcherTokenizer.swift
│   │   │   ├── DictionaryStore.swift
│   │   │   └── TextNormalization.swift
│   │   ├── CustomVocabularyNormalizer.swift
│   │   ├── PhoneticEncoder.swift
│   │   ├── PronunciationLexicon.swift
│   │   └── ReplacementScorer.swift
│   ├── Lists/
│   │   ├── ListFormattingEngine.swift
│   │   ├── ListFormattingTypes.swift
│   │   ├── ListPatternDetector.swift
│   │   ├── ListPatternMarker.swift
│   │   ├── ListPatternMarkerParser.swift
│   │   ├── ListPatternRunSelector.swift
│   │   ├── ListPatternTrailingSplitter.swift
│   │   └── ListRenderer.swift
│   ├── Audio/
│   │   ├── AudioCaptureClassification.swift
│   │   ├── AudioRecorder+PostProcessing.swift
│   │   ├── AudioRecorder+Session.swift
│   │   ├── AudioRecorder+Streaming.swift
│   │   ├── AudioRecorder+Thresholds.swift
│   │   ├── AudioRecorder.swift
│   │   ├── AudioSignalMetrics.swift
│   │   └── AudioSilencePolicy.swift
│   ├── AudioDeviceManager.swift
│   ├── KeyboardMonitor.swift
│   ├── ModelDownloader/
│   │   ├── ModelDownloadTransport.swift
│   │   ├── ModelDownloader+DownloadLifecycle.swift
│   │   ├── ModelDownloader+Validation.swift
│   │   └── ModelDownloader.swift
│   ├── Overlay/
│   │   ├── OverlayFlingPhysics.swift
│   │   ├── OverlayManager.swift
│   │   ├── OverlayMotionController.swift
│   │   ├── OverlayPanel.swift
│   │   ├── OverlayScreenPersistence.swift
│   │   └── OverlayTypes.swift
│   ├── Transcription/
│   │   ├── DictationPipeline.swift
│   │   ├── DictationPromptEchoGuard.swift
│   │   └── TranscriptionManager.swift
│   └── TranscriptionPostProcessor.swift
├── Views/
│   ├── Components/
│   │   ├── ConfirmDeletePromptView.swift
│   │   ├── KeyVoxLogo.swift
│   │   ├── OnboardingMicrophonePickerView.swift
│   │   └── UIComponents.swift
│   ├── Settings/
│   │   ├── DictionaryWordEditorView.swift
│   │   ├── SettingsComponents.swift
│   │   ├── SettingsView+Audio.swift
│   │   ├── SettingsView+Dictionary.swift
│   │   ├── SettingsView+DictionarySection.swift
│   │   ├── SettingsView+General.swift
│   │   ├── SettingsView+Legal.swift
│   │   ├── SettingsView+ModelSection.swift
│   │   ├── SettingsView+More.swift
│   │   ├── SettingsView+Sidebar.swift
│   │   └── SettingsView.swift
│   ├── Warnings/
│   │   ├── PasteFailureRecoveryOverlayView.swift
│   │   ├── WarningKind.swift
│   │   ├── WarningManager.swift
│   │   └── WarningOverlayView.swift
│   ├── OnboardingMicrophoneStepController.swift
│   ├── OnboardingView.swift
│   ├── RecordingOverlay.swift
│   ├── StatusMenuView.swift
│   └── UpdatePromptOverlay.swift
├── Packages/
│   └── KeyVoxWhisper/
│       ├── Package.swift
│       ├── README.md
│       ├── Sources/KeyVoxWhisper/
│           ├── Segment.swift
│           ├── Whisper.swift
│           ├── WhisperError.swift
│           ├── WhisperLanguage.swift
│           └── WhisperParams.swift
│       └── Tests/KeyVoxWhisperTests/
│           ├── WhisperCoreTests.swift
│           └── WhisperParamsTests.swift
├── KeyVoxTests/
│   ├── AI/
│   │   └── Dictionary/
│   ├── App/
│   ├── Core/
│   ├── Fixtures/Updates/
│   ├── Services/
│   ├── TestSupport/
│   ├── Lists/
│   └── Views/
├── Resources/
│   ├── Assets.xcassets/
│   ├── Pronunciation/
│   │   ├── LICENSES.md
│   │   ├── common-words-v1.txt
│   │   ├── lexicon-v1.tsv
│   │   └── sources.lock.json
│   ├── KeyVox.entitlements
│   ├── Kanit-Medium.ttf
│   ├── Credits.rtf
│   ├── logo.png
│   └── keyvox.icon/
├── Tools/
│   ├── README.md
│   ├── ExploreAX.swift
│   ├── ExploreAXApps.swift
│   ├── ExplorePasteSignal.sh
│   ├── ObservePasteAXNotifications.swift
│   ├── Quality/
│   │   ├── check_core_coverage.sh
│   │   └── coverage_summary.sh
│   ├── UpdateFeed/
│   │   ├── configure_local_feed.sh
│   │   └── update-feed.override.example.json
│   └── Pronunciation/
│       ├── benchmarks/
│       │   ├── coverage-corpus.txt
│       │   ├── dictionary-entries.txt
│       │   ├── evaluate/
│       │   │   ├── EvaluateBenchmarkIO.swift
│       │   │   ├── EvaluateBenchmarkRunner.swift
│       │   │   └── EvaluateMatcherCore.swift
│       │   ├── evaluate_matcher.swift
│       │   ├── positive-cases.tsv
│       │   ├── run_quality_gates.sh
│       │   └── safety-cases.txt
│       ├── build_lexicon.sh
│       ├── train_g2p.sh
│       └── verify_licenses.sh
├── .github/workflows/
│   └── tests.yml
├── Docs/
│   ├── CODEMAP.md
│   └── ENGINEERING.md
├── KeyVox.xcodeproj/
├── LICENSE.md
├── THIRD_PARTY_NOTICES.md
├── README.md
└── release_dmg_notarize.sh
```

## Core Runtime Flow

1. `Core/KeyboardMonitor.swift` publishes trigger/shift/escape state.
2. `Core/Transcription/TranscriptionManager.swift` drives app state: `idle -> recording -> transcribing -> idle`.
3. `Core/Audio/AudioRecorder.swift` captures live audio as mono float frames at 16kHz.
4. `Core/Services/WhisperAudioParagraphChunker.swift` detects long internal silence and computes conservative chunk boundaries.
5. `Core/Services/WhisperService.swift` transcribes each chunk through `KeyVoxWhisper` and stitches chunks with paragraph or space separators.
6. `Core/TranscriptionPostProcessor.swift` applies dictionary correction, email normalization/repair, list formatting, and final punctuation/whitespace normalization by render mode.
7. `Core/Services/Paste/PasteService.swift` inserts text via Accessibility first, then menu-bar Paste fallback.
8. `Core/Overlay/OverlayManager.swift` owns overlay lifecycle orchestration and delegates motion/persistence helpers.
9. `Views/RecordingOverlay.swift` and `Views/Components/KeyVoxLogo.swift` provide branded visual identity rendering only.

## Key Components

### App Layer

- `App/KeyVoxApp.swift`
  - App entry point and menu bar scene.
  - Owns onboarding/settings windows via `WindowManager`.
  - Cancels app termination once to close Settings first when the Settings window is visible.
- `App/AppSettingsStore.swift`
  - Centralized persisted user-preference owner (`triggerBinding`, `autoParagraphsEnabled`, sound settings, onboarding, selected microphone, update prompt timestamps, weekly word count).
  - Single in-memory observable source consumed by settings UI and runtime managers.
- `App/UserDefaultsKeys.swift`
  - Single source of truth for app preference keys.
- `Views/OnboardingView.swift`
  - Onboarding step orchestration UI.
  - Delegates microphone Step 1 flow logic to `OnboardingMicrophoneStepController`.
- `Views/OnboardingMicrophoneStepController.swift`
  - Owns onboarding microphone authorization and no-built-in gating behavior.
  - Drives microphone-step completion state and prompt visibility.
- `Views/Components/OnboardingMicrophonePickerView.swift`
  - Presentation-only onboarding modal for required microphone selection confirmation.

### Core Managers

- `Core/Transcription/TranscriptionManager.swift`
  - Orchestrates recording, transcription, and paste.
  - Routes transcribe -> post-process -> paste through internal `DictationPipeline` for boundary-testability.
  - Handles hands-free lock mode and escape cancellation.
  - Chooses list render mode (`multiline` vs `singleLineInline`) from focused target context before post-processing.
- `Core/Transcription/DictationPipeline.swift`
  - Boundary helper for transcribe -> post-process -> paste orchestration with injected dependencies for smoke/integration tests.
- `Core/Transcription/DictationPromptEchoGuard.swift`
  - Gates dictionary-hint prompt use for short/low-confidence captures to reduce prompt-echo hallucination behavior.
- `Core/KeyboardMonitor.swift`
  - Global/local key monitors with left/right modifier specificity.
  - Default trigger binding is `rightOption`.
  - Mirrors persisted trigger binding from `AppSettingsStore`; owns runtime key state only.
- `Core/Overlay/OverlayManager.swift`
  - Floating overlay lifecycle orchestration and visibility.
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
- `Core/Audio/AudioCaptureClassification.swift`
  - Centralized per-capture classification (absolute silence, long true silence, likely-silence rejection).
- `Core/Audio/AudioSilencePolicy.swift`
  - Shared thresholds/rules for low-confidence capture rejection and long true-silence detection.
- `Core/Audio/AudioSignalMetrics.swift`
  - Pure signal metrics (RMS, peak, true-silence window ratio) used by capture classification.

### Service Layer (`Core/Services`)

- `Core/Services/WhisperAudioParagraphChunker.swift`
  - Splits long captures into paragraph-sized chunks using deterministic RMS silence windows.
  - Uses configurable chunk-size and silence-run guardrails to avoid over-splitting.
- `Core/Services/WhisperService.swift`
  - Loads model from Application Support and runs inference.
  - Uses automatic language detection (`.auto`).
  - Supports optional auto-paragraph stitching via `enableAutoParagraphs`.

### Post-Processing (`Core` + `Core/AI` + `Core/Lists`)

- `Core/AI/Dictionary/DictionaryMatcher.swift`
  - Orchestrates dictionary matching flow and delegates tokenizer/candidate/split-join/overlap helpers.
  - Maintains a domain-indexed email dictionary for spoken/literal email recovery.
- `Core/AI/Dictionary/Email/DictionaryEmailEntry.swift`
  - Canonical email entry model and sanitizer for dictionary phrases that are valid email addresses.
- `Core/AI/Dictionary/Email/DictionaryMatcherEmailNormalization.swift`
  - Detects spoken (`name at domain`), compact (`nameatdomain`), and literal email candidates and rewrites them using dictionary-backed resolution.
- `Core/AI/Dictionary/Email/DictionaryMatcherEmailResolution.swift`
  - Resolves local/domain candidates with deterministic exact/near-match guards, overflow handling, and fuzzy domain recovery.
- `Core/AI/Dictionary/DictionaryMatcherTokenizer.swift`
  - Token extraction and range construction helpers used by matcher runtime.
- `Core/AI/Dictionary/DictionaryMatcherCandidateEvaluator.swift`
  - Standard 1-4 token candidate scoring with thresholds, ambiguity, common-word, and short-token guards.
- `Core/AI/Dictionary/DictionaryMatcherSplitJoinEvaluator.swift`
  - Split-token to single-entry matching path with plural/possessive handling.
- `Core/AI/Dictionary/DictionaryMatcherOverlapResolver.swift`
  - Deterministic overlap pruning with confidence-first ordering.
- `Core/AI/Dictionary/TextNormalization.swift`
  - Shared phrase/token normalization used by dictionary matching and pronunciation lexicon loading.
  - Adds deterministic email literal cleanup (casing, punctuation spacing, sentence-boundary repair, ellipsis normalization).
- `Core/AI/Dictionary/DictionaryStore.swift`
  - Persistent custom dictionary storage, validation, and backup recovery.
  - Exposes warning-clear helper for settings lifecycle cleanup.
- `Core/AI/Dictionary/DictionaryEntry.swift`
  - Canonical dictionary entry model.
- `Core/AI/PronunciationLexicon.swift`
  - Loads bundled pronunciation signatures and common-word safety list from app resources.
- `Core/AI/PhoneticEncoder.swift`
  - Uses lexicon lookups first, then deterministic fallback encoding for unknown words.
- `Core/AI/ReplacementScorer.swift`
  - Centralizes score weights, thresholds, ambiguity margin, and similarity math.
- `Core/Lists/ListFormattingEngine.swift`
  - Applies conservative numeric list formatting only when reliable list patterns are detected.
- `Core/Lists/ListPatternDetector.swift`
  - Detects monotonic list markers (digits + spoken English number cues) with false-positive guards.
  - Splits leading/list/trailing segments to preserve non-list prose around list blocks.
- `Core/Lists/ListPatternMarkerParser.swift`
  - Parses spoken/typed marker tokens into canonical marker metadata used by list detection.
  - Handles markers attached to domains, spoken `to` as list marker 2 in email-list shapes, and time-component false-positive suppression.
- `Core/Lists/ListPatternRunSelector.swift`
  - Selects best monotonic list run and enforces confidence guards before formatting.
- `Core/Lists/ListPatternTrailingSplitter.swift`
  - Splits trailing prose off list items while preserving valid list item content.
  - Uses scored deterministic split candidates with email-boundary-aware preference.
- `Core/Lists/ListPatternMarker.swift`
  - Shared marker model for parser/detector/run-selection helpers.
- `Core/Lists/ListRenderer.swift`
  - Renders detected lists as multiline (`1. ...`) or single-line inline (`1. ...; 2. ...`) based on target context.
- `Core/Lists/ListFormattingTypes.swift`
  - Shared types for list render mode and detected list segments/items.
- `Tools/Pronunciation/build_lexicon.sh`
  - Maintainer pipeline for pinned-source regeneration of lexicon/common-word resources.
  - Enforces row targets and writes `Resources/Pronunciation/sources.lock.json`.
- `Tools/Pronunciation/train_g2p.sh`
  - Build-time Phonetisaurus/OpenFst G2P generation for OOV pronunciation candidates.
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
  - Orchestrates paste pipeline (AX injection, menu fallback, recovery, clipboard restore).
  - Determines preferred list render mode from focused AX role for single-line graceful fallback.
- `Core/Services/Paste/PasteFailureRecoveryCoordinator.swift`
  - Manages active paste-failure recovery session lifecycle, timers, and Command-V detection.
- `Core/Services/Paste/PasteAXInspector.swift`
  - Shared AX inspection helpers used by spacing, injector, and fallback verification.
- `Core/Services/Paste/PasteAccessibilityInjector.swift`
  - Direct AX selected-text insertion path with outcome classification.
- `Core/Services/Paste/PasteMenuFallbackExecutor.swift`
  - Orchestrates menu fallback execution and verification decisions.
  - Coordinates AX snapshot verification, undo-state fallback checks, and live AX session verification.
- `Core/Services/Paste/PasteMenuFallbackCoordinator.swift`
  - Coordinates menu-fallback decision flow from `PasteService` and computes fallback result flags.
  - Owns first-success warmup suppression bookkeeping and menu fallback transport normalization.
  - Binds live AX value-change verification to runtime frontmost PID (with captured target fallback).
- `Core/Services/Paste/PasteMenuScanner.swift`
  - Encapsulates menu traversal/discovery for Paste and Undo menu items.
  - Keeps AX identifier/shortcut/title matching and menu-item attribute readers.
- `Core/Services/Paste/PasteAXLiveSession.swift`
  - Encapsulates AXObserver lifecycle used for live value-change verification during menu fallback.
- `Core/Services/Paste/PasteClipboardSnapshot.swift`
  - Full-fidelity clipboard snapshot capture/restore utilities.
- `Core/Services/Paste/PasteSpacingHeuristics.swift`
  - Smart leading separator logic and cross-dictation spacing heuristics.
- `Core/Services/Paste/PastePolicies.swift`
  - Static policy helpers for list render mode and failure-recovery decisions.
- `Core/Services/Paste/PasteModels.swift`
  - Shared internal model/enums for paste pipeline collaborators.
- `Core/Services/UpdateFeedConfig.swift`
  - Centralized update feed owner/repo defaults.
  - Supports optional local override file at `~/Library/Application Support/KeyVox/update-feed.override.json`.
- `Core/Services/AppUpdateLogic.swift`
  - Pure helpers for release mapping, host allowlist checks, version normalization, and version comparison.
- `Core/Services/AppUpdateService.swift`
  - Fetches latest release metadata from GitHub Releases API.
  - Endpoint is composed from resolved update feed config.
  - Maps `tag_name` to app version comparison and `body` to prompt message content.
  - Prefers `.dmg` `browser_download_url`, then falls back to release `html_url`.
  - Supports timer-based checks and manual checks.
  - Fails silently on network/decoding errors.
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
  - Routes model-missing actions into the More tab where model controls now live.
- `Views/OnboardingView.swift`
  - First-run setup for permissions and model download.
  - Accessibility step lowers onboarding z-order during system prompt flow and restores floating state on grant.
- `Views/Settings/*`
  - Split settings tabs and reusable settings components.
- `Views/Settings/SettingsView+Dictionary.swift`
  - Dictionary tab container and English-only support footer text.
- `Views/Settings/SettingsView+DictionarySection.swift`
  - Dictionary management UI plus A-Z/Recently Added list sort toggle (hidden when no entries exist).
  - Updated copy explicitly calls out email-address support.
- `Views/Settings/SettingsView+ModelSection.swift`
  - Model install/remove row extracted for reuse in More tab.
- `Views/Settings/SettingsView+More.swift`
  - More tab now hosts both startup toggle and model installer controls.
- `Views/Warnings/*`
  - Warning UI and panel orchestration for both system warnings and paste-failure recovery.
- `Views/Warnings/WarningManager.swift`
  - Owns warning panel lifecycle and paste-failure recovery panel presentation/update/dismiss.
  - Adds hover-aware auto-dismiss scheduling and animated slide/fade exit transitions.
- `Views/Warnings/PasteFailureRecoveryOverlayView.swift`
  - Lightweight interactive paste-failure recovery view with explicit `⌘ Cmd + V` guidance and indigo progress bar.
- `Views/UpdatePromptOverlay.swift`
  - In-app update prompt UI.

## Branch Delta From `main`

- Dictionary + email normalization hardening:
  - `Core/AI/Dictionary/DictionaryMatcher.swift`
  - `Core/AI/Dictionary/DictionaryStore.swift`
  - `Core/AI/Dictionary/TextNormalization.swift`
  - `Core/AI/Dictionary/Email/DictionaryEmailEntry.swift`
  - `Core/AI/Dictionary/Email/DictionaryMatcherEmailNormalization.swift`
  - `Core/AI/Dictionary/Email/DictionaryMatcherEmailResolution.swift`
  - `KeyVoxTests/AI/Dictionary/DictionaryMatcherTests.swift`
  - `KeyVoxTests/Core/TranscriptionPostProcessorTests.swift`
  - Adds dictionary-driven spoken/literal email normalization, fuzzy domain recovery, and expanded deterministic coverage.
- List parsing and trailing-split robustness:
  - `Core/Lists/ListPatternDetector.swift`
  - `Core/Lists/ListPatternMarkerParser.swift`
  - `Core/Lists/ListPatternTrailingSplitter.swift`
  - `KeyVoxTests/Lists/ListPatternDetectorTests.swift`
  - Strengthens marker parsing for glued markers/email contexts, suppresses time false positives, and improves trailing prose extraction from email-heavy lists.
- Post-processing pipeline polish:
  - `Core/TranscriptionPostProcessor.swift`
  - `KeyVoxTests/Services/DictationPipelineSmokeTests.swift`
  - Adds pre/post email normalization stages, debug-stage observability, and sentence-final punctuation handling for formatted terminal times.
- Settings and warning UX restructuring:
  - `Views/Settings/SettingsComponents.swift`
  - `Views/Settings/SettingsView.swift`
  - `Views/Settings/SettingsView+Dictionary.swift`
  - `Views/Settings/SettingsView+DictionarySection.swift` (renamed from `Views/Settings/SettingsView+ModelDictionary.swift`)
  - `Views/Settings/SettingsView+ModelSection.swift` (renamed from `Views/Settings/SettingsView+Model.swift`)
  - `Views/Settings/SettingsView+More.swift`
  - `Views/StatusMenuView.swift`
  - `Views/Warnings/WarningKind.swift`
  - `Views/Warnings/WarningManager.swift`
  - Reorganizes settings tabs (dictionary as first-class tab, model controls moved to More), updates warning routing, and adds auto-dismiss/animation behavior for warning overlays.
- Build graph/project wiring:
  - `KeyVox.xcodeproj/project.pbxproj`
  - Registers new dictionary email sources and updated settings file structure in the Xcode project graph.

## Persistence & Defaults

- Centralized persisted preferences owner: `App/AppSettingsStore.swift`
  - trigger binding, auto paragraphs toggle, sound enable/volume, selected microphone UID, onboarding completion, update prompt timestamps, weekly word counters
- Preference key catalog: `App/UserDefaultsKeys.swift`
- Paragraph style preference key: `KeyVox.AutoParagraphsEnabled`
- Audio-device initialization marker: `KeyVox.HasInitializedMicrophoneDefault` (owned in `Core/AudioDeviceManager.swift`)
- Weekly word-counter keys:
  - `KeyVox.App.WordsThisWeekCount`
  - `KeyVox.App.WordsThisWeekWeekStart`
- Overlay placement:
  - preferred display key: `KeyVox.RecordingOverlayPreferredDisplayKey`
  - origins by display map: `KeyVox.RecordingOverlayOriginsByDisplay`
  - legacy read-only migration key: `KeyVox.RecordingOverlayOrigin`

## System / Build Facts

- Compatibility target: **macOS Ventura (13.5) and newer**
- App type: menu bar app (`MenuBarExtra`)
- Local model artifact name: `ggml-base.bin`
- Package dependency: local `Packages/KeyVoxWhisper` wrapper over `whisper.cpp`
