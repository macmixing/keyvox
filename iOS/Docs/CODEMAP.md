# KeyVox iOS Code Map
**Last Updated: 2026-03-11**

## Project Overview

KeyVox iOS ships as a containing app plus a custom keyboard extension:

- The containing app owns microphone access, warm-session monitoring, model installation, dictionary/settings sync, weekly word stats, audio capture, and Whisper-backed transcription.
- The keyboard extension owns the visible keyboard UI, mic and cancel controls, live activity indicator rendering, warm/cold app handoff, and final `textDocumentProxy` insertion.
- Shared speech and text behavior still lives in `../Packages/KeyVoxCore`, including `DictationPipeline`, `WhisperService`, post-processing, silence heuristics, and dictionary persistence primitives.

The default runtime flow is:

1. The user taps the mic in the keyboard extension.
2. The extension decides between warm Darwin signaling and cold URL launch.
3. The containing app records and processes audio, then runs the shared dictation pipeline.
4. The app publishes `transcribing`, `transcriptionReady`, or `noSpeech` back through the App Group bridge.
5. The extension inserts the returned text into the focused host app using conservative spacing heuristics.

## Architecture

- **`KeyVox iOS/`**: app lifecycle, dependency composition, App Group storage, IPC bridge, iCloud sync, model downloader, audio recorder, transcription/session manager, and the SwiftUI app shell.
- **`KeyVox Keyboard/`**: custom keyboard controller, toolbar and key grid UI, indicator animation, cursor trackpad behavior, delete-repeat behavior, and insertion heuristics.
- **`../Packages/KeyVoxCore/`**: shared dictation pipeline, Whisper integration, dictionary store, post-processing order, silence classification helpers, and list formatting behavior.
- **`KeyVoxiOSTests/`**: deterministic tests for routing, shared paths, iCloud sync, weekly stats, model lifecycle, stop-time capture processing, keyboard cursor support, and transcription/session orchestration.
- **`iOS/Docs/`**: iOS-local source of truth. `CODEMAP.md` tracks file ownership; `ENGINEERING.md` tracks invariants, contracts, and operational policy.

## Contributor Notes

- Keep iOS-only platform behavior inside the iOS targets. Reusable speech, text, and dictionary logic should remain in `KeyVoxCore`.
- Keep the keyboard extension thin. It should transport commands, render keyboard UI, and insert final text, not accumulate app-owned business logic.
- Keep IPC details centralized in `KeyVoxIPCBridge`; do not duplicate notification names, shared-state keys, or heartbeat assumptions.
- Keep app UI ownership narrow. Views should present state from managers, not become alternate sources of truth for model, capture, or transcription behavior.
- Update [`ENGINEERING.md`](ENGINEERING.md) whenever lifecycle rules, IPC contracts, or session behavior change.

## Directory Index

This is the curated iOS structure map, including the direct shared package dependency.

```text
iOS/
├── KeyVox iOS.xcodeproj
├── KeyVox iOS.xctestplan
├── Docs/
│   ├── CODEMAP.md
│   └── ENGINEERING.md
├── KeyVox iOS/
│   ├── App/
│   │   ├── KeyVoxiOSApp.swift
│   │   ├── iOSAppServiceRegistry.swift
│   │   ├── iOSSharedPaths.swift
│   │   ├── KeyVoxIPCBridge.swift
│   │   ├── KeyVoxKeyboardBridge.swift
│   │   ├── KeyVoxURLRoute.swift
│   │   ├── KeyVoxURLRouter.swift
│   │   ├── iOSWeeklyWordStatsStore.swift
│   │   ├── ModelDownloader/
│   │   │   ├── iOSModelManager.swift
│   │   │   ├── iOSModelManager+InstallLifecycle.swift
│   │   │   ├── iOSModelManager+Support.swift
│   │   │   ├── iOSModelManager+Validation.swift
│   │   │   ├── iOSModelDownloadBackgroundTasks.swift
│   │   │   ├── iOSModelDownloadURLs.swift
│   │   │   ├── iOSModelInstallManifest.swift
│   │   │   └── iOSModelInstallState.swift
│   │   └── iCloud/
│   │       ├── iOSAppSettingsStore.swift
│   │       ├── iOSiCloudSyncCoordinator.swift
│   │       ├── iOSUserDefaultsKeys.swift
│   │       ├── iOSWeeklyWordStatsCloudSync.swift
│   │       ├── KeyVoxiCloudKeys.swift
│   │       └── KeyVoxiCloudPayloads.swift
│   ├── Core/
│   │   ├── Audio/
│   │   │   ├── iOSAudioRecorder.swift
│   │   │   ├── iOSAudioRecorder+Session.swift
│   │   │   ├── iOSAudioRecorder+Streaming.swift
│   │   │   ├── iOSAudioRecorder+StopPipeline.swift
│   │   │   └── LiveInputSignalState.swift
│   │   └── Transcription/
│   │       ├── iOSDictationService.swift
│   │       ├── iOSSessionPolicy.swift
│   │       ├── iOSTranscriptionDebugSnapshot.swift
│   │       ├── iOSTranscriptionManager.swift
│   │       └── iOSTranscriptionManager+SessionLifecycle.swift
│   ├── Views/
│   │   ├── AppRootView.swift
│   │   ├── MainTabView.swift
│   │   ├── HomeTabView.swift
│   │   ├── DictionaryTabView.swift
│   │   ├── StyleTabView.swift
│   │   └── SettingsTabView.swift
│   ├── Assets.xcassets/
│   ├── Info.plist
│   └── KeyVoxiOS.entitlements
├── KeyVox Keyboard/
│   ├── App/
│   │   └── KeyboardViewController.swift
│   ├── Core/
│   │   ├── AudioIndicatorDriver.swift
│   │   ├── KeyboardCapsLockStateStore.swift
│   │   ├── KeyboardCursorTrackpadSupport.swift
│   │   ├── KeyboardInsertionSpacingHeuristics.swift
│   │   ├── KeyboardIPCManager.swift
│   │   ├── KeyboardSpecialKeyInteractionSupport.swift
│   │   ├── KeyboardState.swift
│   │   ├── KeyboardStyle.swift
│   │   └── KeyboardSymbolLayout.swift
│   ├── Views/
│   │   ├── KeyboardInputHostView.swift
│   │   ├── KeyboardRootView.swift
│   │   └── Components/
│   │       ├── KeyboardCancelButton.swift
│   │       ├── KeyboardCapsLockButton.swift
│   │       ├── KeyboardKeyGridView.swift
│   │       ├── KeyboardKeyPopupView.swift
│   │       ├── KeyboardKeyView.swift
│   │       └── KeyboardLogoBarView.swift
│   ├── Info.plist
│   └── KeyVoxKeyboard.entitlements
└── KeyVoxiOSTests/
    ├── App/
    └── Core/

Packages/
└── KeyVoxCore/
    ├── Sources/KeyVoxCore/
    └── Tests/KeyVoxCoreTests/
```

## Core Runtime Flow

1. `KeyVox Keyboard/App/KeyboardViewController.swift` handles mic, cancel, Caps Lock, symbol page toggling, cursor trackpad gestures, and host-text insertion.
2. `KeyVox Keyboard/Core/KeyboardIPCManager.swift` writes shared recording state, posts Darwin notifications, reads heartbeat state, and reads live meter samples from the App Group container.
3. `KeyVox iOS/App/KeyVoxKeyboardBridge.swift` receives start, stop, and cancel commands from the extension and republishes recording, transcribing, ready, and no-speech events back to the extension.
4. `KeyVox iOS/Core/Audio/iOSAudioRecorder.swift` can keep the engine warm in monitoring mode, stream 16 kHz mono PCM, publish live signal state, and hand interrupted captures back to the transcription manager.
5. `KeyVox iOS/Core/Audio/iOSAudioRecorder+StopPipeline.swift` classifies silence and produces cleaned `outputFrames` for inference.
6. `KeyVox iOS/Core/Transcription/iOSTranscriptionManager.swift` owns the iOS runtime state machine, session policy, model gating, dictionary prompt updates, weekly word counting, and `DictationPipeline` execution.
7. `KeyVoxCore.DictationPipeline` performs transcription and post-processing, then hands the final text back through `pasteText`.
8. `KeyVoxKeyboardBridge` publishes either `transcriptionReady` or `noSpeech`, and the extension inserts the final text with `KeyboardInsertionSpacingHeuristics`.

## Key Components

### App Lifecycle and Composition

- `KeyVox iOS/App/KeyVoxiOSApp.swift`
  - SwiftUI app entry point.
  - Registers the model-download background task.
  - Injects app-wide environment objects and routes incoming `keyvoxios://` URLs.
- `KeyVox iOS/App/iOSAppServiceRegistry.swift`
  - Main composition root.
  - Builds `DictionaryStore`, `iOSAppSettingsStore`, `iOSWeeklyWordStatsStore`, `WhisperService`, `iOSModelManager`, `iOSTranscriptionManager`, `iOSiCloudSyncCoordinator`, and `iOSWeeklyWordStatsCloudSync`.
  - Wires recorder heartbeat and live-meter callbacks into the keyboard bridge.
- `KeyVox iOS/App/iOSSharedPaths.swift`
  - Source of truth for App Group paths.
  - Resolves model artifacts, install manifest, and dictionary storage directories.
  - Provides the Application Support fallback used only for dictionary persistence.
- `KeyVox iOS/App/KeyVoxURLRoute.swift`
  - Parses supported `keyvoxios://record/start` and `keyvoxios://record/stop` URLs.
- `KeyVox iOS/App/KeyVoxURLRouter.swift`
  - Maps parsed URL routes onto transcription-manager commands.

### Shared State, Settings, and Sync

- `KeyVox iOS/App/KeyVoxIPCBridge.swift`
  - Shared contract for App Group `UserDefaults`, live meter file IO, and Darwin notification names.
  - Owns shared recording state, latest transcription text, heartbeat timestamps, and `live-meter-state.bin`.
- `KeyVox iOS/App/KeyVoxKeyboardBridge.swift`
  - App-side IPC endpoint for start, stop, and cancel.
  - Publishes recording, transcribing, ready, cancelled/no-speech, and live meter updates back to the keyboard.
- `KeyVox iOS/App/iCloud/iOSAppSettingsStore.swift`
  - Observable settings store backed by App Group `UserDefaults`.
  - Persists trigger binding, auto paragraphs, list formatting, and Caps Lock state.
- `KeyVox iOS/App/iCloud/iOSiCloudSyncCoordinator.swift`
  - iCloud KVS sync owner for dictionary entries plus settings timestamps and last-writer-wins reconciliation.
- `KeyVox iOS/App/iOSWeeklyWordStatsStore.swift`
  - Local weekly spoken-word snapshot store keyed by stable installation ID.
  - Exposes only the combined weekly total to the UI.
- `KeyVox iOS/App/iCloud/iOSWeeklyWordStatsCloudSync.swift`
  - iCloud KVS merge layer for weekly word stats.
  - Merges device counts by taking the maximum per device for the current week.

### Model Management

- `KeyVox iOS/App/ModelDownloader/iOSModelManager.swift`
  - Observable owner of install state, errors, and user-facing download/delete/repair actions.
- `KeyVox iOS/App/ModelDownloader/iOSModelManager+InstallLifecycle.swift`
  - Parallel download, integrity verification, extraction, manifest writing, and warmup sequencing.
- `KeyVox iOS/App/ModelDownloader/iOSModelManager+Validation.swift`
  - Strict readiness checks for the GGML file, extracted Core ML bundle, zip cleanup, and manifest compatibility.
- `KeyVox iOS/App/ModelDownloader/iOSModelManager+Support.swift`
  - Shared helpers for file operations, hashing, manifest IO, free-space checks, and progress aggregation.
- `KeyVox iOS/App/ModelDownloader/iOSModelDownloadBackgroundTasks.swift`
  - Registers and schedules the background repair task `com.cueit.keyvox.model-download`.
- `KeyVox iOS/App/ModelDownloader/iOSModelInstallState.swift`
  - UI-facing install state and phase model used by the Settings tab.

### Audio and Transcription Runtime

- `KeyVox iOS/Core/Audio/iOSAudioRecorder.swift`
  - Public recorder and monitoring surface.
  - Tracks capture duration, meter state, device label, and last-capture classification facts.
- `KeyVox iOS/Core/Audio/iOSAudioRecorder+Session.swift`
  - Configures `AVAudioSession`, starts and maintains the engine, and supports warm monitoring mode.
- `KeyVox iOS/Core/Audio/iOSAudioRecorder+Streaming.swift`
  - Converts live audio into 16 kHz mono PCM and drives UI/debug metering.
- `KeyVox iOS/Core/Audio/iOSAudioRecorder+StopPipeline.swift`
  - Produces `iOSStoppedCapture` values and rejects likely silence before inference.
- `KeyVox iOS/Core/Transcription/iOSTranscriptionManager.swift`
  - Primary iOS state machine: `idle -> recording -> processingCapture -> transcribing -> idle`.
  - Coordinates recorder commands, model checks, shared pipeline execution, weekly stats, and keyboard notifications.
- `KeyVox iOS/Core/Transcription/iOSTranscriptionManager+SessionLifecycle.swift`
  - Owns idle shutdown, cancel flow, abandonment watchdogs, and session cleanup behavior.
- `KeyVox iOS/Core/Transcription/iOSSessionPolicy.swift`
  - Centralizes idle timeout, no-speech abandonment, post-speech inactivity, and emergency utterance cap thresholds.
- `KeyVox iOS/Core/Transcription/iOSDictationService.swift`
  - Small protocol seam over `WhisperService`.
- `KeyVox iOS/Core/Transcription/iOSTranscriptionDebugSnapshot.swift`
  - Debug surface for raw text, final text, timings, hint-prompt usage, and capture facts.

### Containing-App UI

- `KeyVox iOS/Views/AppRootView.swift`
  - Small root shell that currently routes directly to the main tab UI.
- `KeyVox iOS/Views/MainTabView.swift`
  - Tab container for Home, Dictionary, Style, and Settings.
- `KeyVox iOS/Views/HomeTabView.swift`
  - Shows combined weekly word count and the "Keep Session Active" toggle.
  - Surfaces debug diagnostics only in `DEBUG`.
- `KeyVox iOS/Views/DictionaryTabView.swift`
  - Read-only list of current dictionary entries from `DictionaryStore`.
- `KeyVox iOS/Views/StyleTabView.swift`
  - User-facing toggles for auto paragraphs and list formatting.
- `KeyVox iOS/Views/SettingsTabView.swift`
  - Model install status plus download, repair, and delete actions.

### Keyboard Extension

- `KeyVox Keyboard/App/KeyboardViewController.swift`
  - Extension controller and top-level state machine.
  - Owns warm/cold launch behavior, cancel flow, Caps Lock persistence, cursor movement via the spacebar trackpad interaction, and final insertion.
- `KeyVox Keyboard/Core/KeyboardIPCManager.swift`
  - Extension-side App Group + Darwin client.
  - Handles shared recording state reconciliation, heartbeat freshness, commands, and callback delivery.
- `KeyVox Keyboard/Core/AudioIndicatorDriver.swift`
  - Smooths App Group live-meter samples into UI-friendly animation state for the toolbar indicator.
- `KeyVox Keyboard/Core/KeyboardCapsLockStateStore.swift`
  - App Group-backed latch for the extension-owned Caps Lock state consumed by the app at dictation time.
- `KeyVox Keyboard/Core/KeyboardState.swift`
  - Maps extension runtime states into indicator phases and cancel-button visibility.
- `KeyVox Keyboard/Core/KeyboardCursorTrackpadSupport.swift`
  - Cursor stepping logic for the long-press spacebar trackpad interaction.
- `KeyVox Keyboard/Core/KeyboardSpecialKeyInteractionSupport.swift`
  - Spacebar activation timing and delete-key repeat behavior.
- `KeyVox Keyboard/Core/KeyboardSymbolLayout.swift`
  - Source of truth for the two-page symbol keyboard layout.
- `KeyVox Keyboard/Core/KeyboardInsertionSpacingHeuristics.swift`
  - Conservative smart-space insertion before pasted dictation text.
- `KeyVox Keyboard/Views/KeyboardRootView.swift`
  - Keyboard chrome with a centered logo bar, leading cancel button, trailing Caps Lock button, and the symbol key grid.
- `KeyVox Keyboard/Views/Components/KeyboardLogoBarView.swift`
  - Mic button plus animated live audio indicator surface.
- `KeyVox Keyboard/Views/Components/KeyboardKeyGridView.swift`
  - Gesture-driven key grid with popup support, delete repeat, and spacebar trackpad handoff.

### Tests

- `KeyVoxiOSTests/App/`
  - Route parsing, shared paths, settings persistence, iCloud sync coordination, weekly stats storage/sync, and model manager behavior.
- `KeyVoxiOSTests/Core/`
  - Stop-time capture processing, keyboard cursor-trackpad support, and transcription/session manager lifecycle tests.

## Change Tracking

- Update this file when iOS file ownership, major system placement, or top-level runtime flow changes.
- Use [`ENGINEERING.md`](ENGINEERING.md) for lifecycle rules, state-machine invariants, IPC contracts, and testing policy.
- Keep `Docs/KEYVOX_IOS.md` as historical design context rather than the current iOS source of truth.
