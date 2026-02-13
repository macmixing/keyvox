# KeyVox Code Map
**Last Updated: 2026-02-13**

## Project Overview

KeyVox is a macOS menu bar dictation app that records speech while a trigger key is held, transcribes locally with Whisper, and inserts text into the focused app. The default trigger is **Right Option (⌥)**.

## Architecture

- **App**: app entry point, window lifecycle, shared defaults keys
- **Core**: state machine, audio pipeline, keyboard monitoring, overlay orchestration, model management
- **Core/Services**: reusable integration services (Whisper, paste/injection, update checking)
- **Views**: SwiftUI UI layer (menu, onboarding, settings, overlays, warnings, branded visuals)
- **Resources**: assets, entitlements, bundled fonts/icons
- **Packages**: local Swift package wrapping `whisper.cpp`

## File Tree

```text
KeyVox/
├── App/
│   ├── KeyVoxApp.swift
│   └── UserDefaultsKeys.swift
├── Core/
│   ├── Services/
│   │   ├── AppUpdateService.swift
│   │   ├── PasteService.swift
│   │   └── WhisperService.swift
│   ├── AudioDeviceManager.swift
│   ├── AudioRecorder.swift
│   ├── KeyboardMonitor.swift
│   ├── ModelDownloader.swift
│   ├── OverlayManager.swift
│   └── TranscriptionManager.swift
├── Views/
│   ├── Components/
│   │   ├── KeyVoxLogo.swift
│   │   └── UIComponents.swift
│   ├── Settings/
│   │   ├── SettingsComponents.swift
│   │   ├── SettingsView+Audio.swift
│   │   ├── SettingsView+General.swift
│   │   ├── SettingsView+Information.swift
│   │   ├── SettingsView+Legal.swift
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
│       └── Sources/KeyVoxWhisper/
│           ├── Segment.swift
│           ├── Whisper.swift
│           ├── WhisperError.swift
│           ├── WhisperLanguage.swift
│           └── WhisperParams.swift
├── Resources/
│   ├── Assets.xcassets/
│   ├── KeyVox.entitlements
│   ├── Kanit-Medium.ttf
│   ├── Credits.rtf
│   ├── logo.png
│   └── keyvox.icon/
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
5. `Core/Services/PasteService.swift` inserts text via Accessibility first, then menu-bar Paste fallback.
6. `Core/OverlayManager.swift` owns overlay panel lifecycle, drag persistence, and per-display position restore.
7. `Views/RecordingOverlay.swift` and `Views/Components/KeyVoxLogo.swift` provide branded visual identity rendering only.

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
- `Core/Services/PasteService.swift`
  - Smart whitespace handling and robust clipboard restore.
- `Core/Services/AppUpdateService.swift`
  - Fetches remote version metadata.
  - Supports timer-based checks and manual checks.
  - Triggers `UpdatePromptOverlay` through prompt manager.

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
