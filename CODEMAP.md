# KeyVox Code Map
**Last Updated: 2026-02-14**

## Project Overview

KeyVox is a macOS menu bar dictation app that records speech while a trigger key is held, transcribes locally with Whisper, and inserts text into the focused app. The default trigger is **Right Option (⌥)**.

## Architecture

- **App**: app entry point, window lifecycle, shared defaults keys
- **Core**: state machine, audio pipeline, keyboard monitoring, overlay orchestration, model management
- **Core/AI**: dictionary storage + post-transcription normalization/matching helpers
- **Core/TextProcessing**: deterministic text formatting (list detection/rendering)
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
│   ├── KeyVoxApp.swift
│   └── UserDefaultsKeys.swift
├── Core/
│   ├── Services/
│   │   ├── AppUpdateLogic.swift
│   │   ├── AppUpdateService.swift
│   │   ├── PasteService.swift
│   │   ├── UpdatePromptPresenting.swift
│   │   ├── UpdateFeedConfig.swift
│   │   └── WhisperService.swift
│   ├── AI/
│   │   ├── CustomVocabularyNormalizer.swift
│   │   ├── DictionaryMatcher.swift
│   │   ├── DictionaryEntry.swift
│   │   ├── DictionaryStore.swift
│   │   ├── PhoneticEncoder.swift
│   │   ├── PronunciationLexicon.swift
│   │   └── ReplacementScorer.swift
│   ├── TextProcessing/
│   │   ├── ListFormattingEngine.swift
│   │   ├── ListFormattingTypes.swift
│   │   ├── ListPatternDetector.swift
│   │   └── ListRenderer.swift
│   ├── AudioDeviceManager.swift
│   ├── AudioRecorder.swift
│   ├── KeyboardMonitor.swift
│   ├── ModelDownloader.swift
│   ├── OverlayManager.swift
│   ├── TranscriptionPostProcessor.swift
│   └── TranscriptionManager.swift
├── Views/
│   ├── Components/
│   │   ├── ConfirmDeletePromptView.swift
│   │   ├── KeyVoxLogo.swift
│   │   └── UIComponents.swift
│   ├── Settings/
│   │   ├── DictionaryWordEditorView.swift
│   │   ├── SettingsComponents.swift
│   │   ├── SettingsView+Audio.swift
│   │   ├── SettingsView+General.swift
│   │   ├── SettingsView+Information.swift
│   │   ├── SettingsView+Legal.swift
│   │   ├── SettingsView+ModelDictionary.swift
│   │   ├── SettingsView+Model.swift
│   │   ├── SettingsView+Sidebar.swift
│   │   └── SettingsView.swift
│   ├── Warnings/
│   │   ├── WarningKind.swift
│   │   ├── WarningManager.swift
│   │   └── WarningOverlayView.swift
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
│   ├── Core/
│   ├── Fixtures/Updates/
│   ├── Services/
│   ├── TestSupport/
│   └── TextProcessing/
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
│   ├── Quality/
│   │   └── check_core_coverage.sh
│   ├── UpdateFeed/
│   │   ├── configure_local_feed.sh
│   │   └── update-feed.override.example.json
│   └── Pronunciation/
│       ├── benchmarks/
│       │   ├── coverage-corpus.txt
│       │   ├── dictionary-entries.txt
│       │   ├── evaluate_matcher.swift
│       │   ├── positive-cases.tsv
│       │   ├── run_quality_gates.sh
│       │   └── safety-cases.txt
│       ├── build_lexicon.sh
│       ├── train_g2p.sh
│       └── verify_licenses.sh
├── .github/workflows/
│   └── tests.yml
├── KeyVox.xcodeproj/
├── LICENSE.md
├── README.md
└── CODEMAP.md
```

## Core Runtime Flow

1. `Core/KeyboardMonitor.swift` publishes trigger/shift/escape state.
2. `Core/TranscriptionManager.swift` drives app state: `idle -> recording -> transcribing -> idle`.
3. `Core/AudioRecorder.swift` captures live audio as mono float frames at 16kHz.
4. `Core/Services/WhisperService.swift` transcribes locally through `KeyVoxWhisper`.
5. `Core/TranscriptionPostProcessor.swift` applies dictionary correction, then deterministic list formatting.
6. `Core/Services/PasteService.swift` inserts text via Accessibility first, then menu-bar Paste fallback.
7. `Core/OverlayManager.swift` owns overlay panel lifecycle, drag persistence, and per-display position restore.
8. `Views/RecordingOverlay.swift` and `Views/Components/KeyVoxLogo.swift` provide branded visual identity rendering only.

## Key Components

### App Layer

- `App/KeyVoxApp.swift`
  - App entry point and menu bar scene.
  - Owns onboarding/settings windows via `WindowManager`.
- `App/UserDefaultsKeys.swift`
  - Single source of truth for app preference keys.

### Core Managers

- `Core/TranscriptionManager.swift`
  - Orchestrates recording, transcription, and paste.
  - Handles hands-free lock mode and escape cancellation.
  - Chooses list render mode (`multiline` vs `singleLineInline`) from focused target context before post-processing.
- `Core/KeyboardMonitor.swift`
  - Global/local key monitors with left/right modifier specificity.
  - Default trigger binding is `rightOption`.
- `Core/OverlayManager.swift`
  - Floating overlay panel management and visibility.
  - Per-display persistence using preferred-display key + origins-by-display map.
- `Core/AudioDeviceManager.swift`
  - Microphone discovery, persistence, and selection policy.
- `Core/ModelDownloader.swift`
  - Downloads `ggml-base.bin` plus CoreML encoder zip and validates readiness.
- `Core/AudioRecorder.swift`
  - AVCapture pipeline, live input signal classification, normalization.

### Service Layer (`Core/Services`)

- `Core/Services/WhisperService.swift`
  - Loads model from Application Support and runs inference.
  - Uses automatic language detection (`.auto`).

### Post-Processing (`Core` + `Core/AI` + `Core/TextProcessing`)

- `Core/AI/DictionaryMatcher.swift`
  - Performs balanced n-gram matching (1-4 tokens) against dictionary entries.
  - Uses weighted text + phonetic + context scoring with ambiguity guardrails.
  - Resolves overlap conflicts by highest-confidence replacement wins.
- `Core/AI/PronunciationLexicon.swift`
  - Loads bundled pronunciation signatures and common-word safety list from app resources.
- `Core/AI/PhoneticEncoder.swift`
  - Uses lexicon lookups first, then deterministic fallback encoding for unknown words.
- `Core/AI/ReplacementScorer.swift`
  - Centralizes score weights, thresholds, ambiguity margin, and similarity math.
- `Core/TextProcessing/ListFormattingEngine.swift`
  - Applies conservative numeric list formatting only when reliable list patterns are detected.
- `Core/TextProcessing/ListPatternDetector.swift`
  - Detects monotonic list markers (digits + spoken English number cues) with false-positive guards.
  - Splits leading/list/trailing segments to preserve non-list prose around list blocks.
- `Core/TextProcessing/ListRenderer.swift`
  - Renders detected lists as multiline (`1. ...`) or single-line inline (`1. ...; 2. ...`) based on target context.
- `Core/TextProcessing/ListFormattingTypes.swift`
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
- `Core/Services/PasteService.swift`
  - Smart whitespace handling and robust clipboard restore.
  - Determines preferred list render mode from focused AX role for single-line graceful fallback.
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

### UI Layer

- `Views/StatusMenuView.swift`
  - Menu bar UI, status rendering, warning actions.
- `Views/OnboardingView.swift`
  - First-run setup for permissions and model download.
- `Views/Settings/*`
  - Split settings tabs and reusable settings components.
- `Views/Warnings/*`
  - Blocking warning overlay and resolution actions.
- `Views/UpdatePromptOverlay.swift`
  - In-app update prompt UI.

## Persistence & Defaults

- Trigger binding and sound settings: `UserDefaults`
- Microphone selection and initialization marker: `UserDefaults`
- Overlay placement:
  - preferred display key: `KeyVox.RecordingOverlayPreferredDisplayKey`
  - origins by display map: `KeyVox.RecordingOverlayOriginsByDisplay`
  - legacy read-only migration key: `KeyVox.RecordingOverlayOrigin`

## System / Build Facts

- App target deployment: **macOS 15.6**
- App type: menu bar app (`MenuBarExtra`)
- Local model artifact name: `ggml-base.bin`
- Package dependency: local `Packages/KeyVoxWhisper` wrapper over `whisper.cpp`
