# KeyVox iOS Code Map
**Last Updated: 2026-03-10**

## Project Overview

KeyVox iOS is split across a containing app and a custom keyboard extension:

- The containing app owns microphone access, background audio capture, model installation, shared dictionary state, and the Whisper-backed transcription pipeline.
- The containing app also owns synced weekly word stats state, with the combined total surfaced in the Home tab and per-device counts kept internal.
- The keyboard extension owns the user-facing mic button, warm/cold app handoff, and final `textDocumentProxy.insertText(...)` insertion into the focused text field.
- Shared text-processing, silence classification, dictionary correction, list rendering, and Whisper integration live in `../Packages/KeyVoxCore`.

The default iOS interaction is:

1. User taps the mic in the custom keyboard.
2. The extension signals the containing app over App Group state + Darwin notifications.
3. The containing app records, classifies, transcribes, and post-processes audio.
4. The final text is written back through shared state.
5. The extension inserts the text into the current host app.

## Architecture

- **`KeyVox iOS/`**: containing-app entry point, dependency registry, App Group/IPC bridge, model downloader, audio recorder, transcription manager, and minimal app UI.
- **`KeyVox Keyboard/`**: keyboard extension UI, keyboard state machine, IPC client, and text insertion heuristics.
- **`../Packages/KeyVoxCore/`**: shared dictation pipeline, post-processing, Whisper service, audio silence policy, and dictionary persistence logic reused from the Mac app.
- **`KeyVoxiOSTests/`**: deterministic tests covering routing, shared paths, model lifecycle, capture processing, and transcription state transitions.
- **`docs/`**: iOS-local source of truth for architecture and file ownership. `CODEMAP.md` owns structure; `ENGINEERING.md` owns invariants and operational policy.

## Contributor Notes

- Keep iOS-specific platform behavior in the `iOS/` targets; keep reusable speech/text logic in `KeyVoxCore`.
- The keyboard extension should remain thin. If new behavior can live in shared state, IPC, or `KeyVoxCore`, prefer that over expanding extension-only business logic.
- The containing app is intentionally minimal in UI today. Most complexity belongs in the runtime managers, not in `AppRootView`.
- Unit tests focus on deterministic seams: URL parsing, state transitions, install validation, and capture classification. Device routing, extension launch timing, and actual text injection remain integration scope.
- This file is the curated ownership map for the iOS app. Runtime rules, IPC contracts, and operational workflows belong in [`ENGINEERING.md`](ENGINEERING.md).

## Directory Index

This is a curated map of the iOS repo area and its direct shared dependency.

```text
iOS/
├── KeyVox iOS.xcodeproj
├── KeyVox iOS.xctestplan
├── KeyVox iOS/
│   ├── App/
│   │   ├── KeyVoxiOSApp.swift
│   │   ├── iOSAppServiceRegistry.swift
│   │   ├── iOSWeeklyWordStatsStore.swift
│   │   ├── iOSSharedPaths.swift
│   │   ├── KeyVoxIPCBridge.swift
│   │   ├── KeyVoxKeyboardBridge.swift
│   │   ├── KeyVoxURLRoute.swift
│   │   ├── KeyVoxURLRouter.swift
│   │   ├── iCloud/
│   │   │   ├── iOSWeeklyWordStatsCloudSync.swift
│   │   │   ├── iOSiCloudSyncCoordinator.swift
│   │   │   ├── iOSAppSettingsStore.swift
│   │   │   ├── iOSUserDefaultsKeys.swift
│   │   │   ├── KeyVoxiCloudKeys.swift
│   │   │   └── KeyVoxiCloudPayloads.swift
│   │   └── ModelDownloader/
│   │       ├── iOSModelManager.swift
│   │       ├── iOSModelManager+InstallLifecycle.swift
│   │       ├── iOSModelManager+Support.swift
│   │       ├── iOSModelManager+Validation.swift
│   │       ├── iOSModelDownloadBackgroundTasks.swift
│   │       ├── iOSModelDownloadURLs.swift
│   │       ├── iOSModelInstallManifest.swift
│   │       └── iOSModelInstallState.swift
│   ├── Core/
│   │   ├── Audio/
│   │   │   ├── iOSAudioRecorder.swift
│   │   │   ├── iOSAudioRecorder+Session.swift
│   │   │   ├── iOSAudioRecorder+Streaming.swift
│   │   │   ├── iOSAudioRecorder+StopPipeline.swift
│   │   │   ├── LiveInputSignalState.swift
│   │   └── Transcription/
│   │       ├── iOSTranscriptionManager.swift
│   │       ├── iOSDictationService.swift
│   │       └── iOSTranscriptionDebugSnapshot.swift
│   ├── Views/
│   │   └── AppRootView.swift
│   ├── Assets.xcassets/
│   ├── Info.plist
│   └── KeyVoxiOS.entitlements
├── KeyVox Keyboard/
│   ├── KeyboardViewController.swift
│   ├── KeyboardIPCManager.swift
│   ├── KeyboardRootView.swift
│   ├── KeyboardState.swift
│   ├── KeyboardStyle.swift
│   ├── KeyboardInsertionSpacingHeuristics.swift
│   ├── Info.plist
│   └── KeyVoxKeyboard.entitlements
├── KeyVoxiOSTests/
│   ├── App/
│   └── Core/
└── docs/
    ├── CODEMAP.md
    └── ENGINEERING.md

Packages/
└── KeyVoxCore/
    ├── Sources/KeyVoxCore/
    └── Tests/KeyVoxCoreTests/
```

## Core Runtime Flow

1. `KeyVox Keyboard/KeyboardViewController.swift` handles the mic tap and decides between warm-session IPC and cold-start app launch via `keyvoxios://record/start`.
2. `KeyVox Keyboard/KeyboardIPCManager.swift` writes shared recording state and posts Darwin notifications to the containing app.
3. `KeyVox iOS/App/KeyVoxKeyboardBridge.swift` receives start/stop commands, updates shared heartbeat/state, and publishes app-to-extension events.
4. `KeyVox iOS/Core/Audio/iOSAudioRecorder.swift` and its extensions keep an `AVAudioEngine` warm, record at 16kHz mono float PCM, and collect live signal metrics.
5. `KeyVox iOS/Core/Audio/iOSAudioRecorder+StopPipeline.swift` removes internal gaps, classifies silence/no-speech using `KeyVoxCore`, and emits output frames for inference.
6. `KeyVox iOS/Core/Transcription/iOSTranscriptionManager.swift` takes the processed capture, gates on model availability, and runs `KeyVoxCore.DictationPipeline`, which delegates transcription to `WhisperService` and post-processing to `TranscriptionPostProcessor`.
7. `KeyVoxKeyboardBridge` publishes either `transcriptionReady` or `noSpeech`, and `KeyboardViewController` inserts the cleaned text with `KeyboardInsertionSpacingHeuristics`.

## Key Components

### App Layer

- `KeyVox iOS/App/KeyVoxiOSApp.swift`
  - iOS app entry point.
  - Pulls singleton services from `iOSAppServiceRegistry`.
  - Registers model background tasks and routes incoming `keyvoxios://` URLs.
- `KeyVox iOS/App/iOSAppServiceRegistry.swift`
  - Composition root for the containing app.
  - Wires `DictionaryStore`, `iOSWeeklyWordStatsStore`, `WhisperService`, `iOSModelManager`, `TranscriptionPostProcessor`, `iOSAudioRecorder`, `iOSTranscriptionManager`, and `KeyVoxURLRouter`.
  - Connects keyboard-bridge start/stop callbacks to the transcription manager.
- `KeyVox iOS/App/iOSWeeklyWordStatsStore.swift`
  - Dedicated local weekly-usage store for combined weekly word count plus hidden per-installation contribution totals.
  - Persists a stable installation identifier, current-week snapshot, and rollover behavior outside the settings store.
- `KeyVox iOS/App/iOSSharedPaths.swift`
  - Central source of truth for App Group paths.
  - Resolves model files, Core ML bundle locations, install manifest, and dictionary storage base directory.
  - Provides a local Application Support fallback for dictionary persistence when the App Group container is unavailable.
- `KeyVox iOS/App/KeyVoxIPCBridge.swift`
  - Shared-state contract used by both app and extension.
  - Stores `recordingState`, `latestTranscription`, and heartbeat/session timestamp in App Group `UserDefaults`.
  - Defines the Darwin notification names used for start/stop/ready/no-speech signaling.
- `KeyVox iOS/App/KeyVoxKeyboardBridge.swift`
  - Containing-app side of the keyboard bridge.
  - Subscribes to Darwin start/stop notifications.
  - Publishes recording, transcribing, transcription-ready, and no-speech updates back to the extension.
  - Refreshes the shared heartbeat during major app-side state transitions; the live recorder session is the primary warm-session heartbeat source.
- `KeyVox iOS/App/KeyVoxURLRoute.swift`
  - Parses supported `keyvoxios://record/start` and `keyvoxios://record/stop` routes.
- `KeyVox iOS/App/KeyVoxURLRouter.swift`
  - Maps parsed routes to `iOSTranscriptionManager` commands.
  - Used for cold-start app launch from the keyboard extension.

### Model Management

- `KeyVox iOS/App/ModelDownloader/iOSModelManager.swift`
  - Observable owner of install state, readiness, error messaging, and async install/delete/repair entry points.
  - Injected with path resolvers, free-space provider, download closure, and unzip closure for testability.
- `KeyVox iOS/App/ModelDownloader/iOSModelManager+InstallLifecycle.swift`
  - Implements download, delete, and repair flows.
  - Downloads GGML and Core ML artifacts in parallel, validates integrity, extracts the Core ML bundle, writes the install manifest, and warms Whisper.
- `KeyVox iOS/App/ModelDownloader/iOSModelManager+Validation.swift`
  - Validates install completeness and artifact integrity expectations.
  - Enforces the presence of the GGML binary, extracted Core ML bundle, cleanup of the zip, and a supported install manifest.
- `KeyVox iOS/App/ModelDownloader/iOSModelManager+Support.swift`
  - Shared helpers for file moves/removal, manifest IO, SHA-256 hashing, zip extraction, and free-space checks.
  - Includes debug logging and progress aggregation utilities.
- `KeyVox iOS/App/ModelDownloader/iOSModelDownloadBackgroundTasks.swift`
  - Registers and schedules a background repair task identifier for failed installs.
- `KeyVox iOS/App/ModelDownloader/iOSModelDownloadURLs.swift`
  - Source-of-truth URLs for model artifacts.
- `KeyVox iOS/App/ModelDownloader/iOSModelInstallManifest.swift`
  - Persisted versioned description of the installed artifact hashes.
- `KeyVox iOS/App/ModelDownloader/iOSModelInstallState.swift`
  - UI-facing install state and phase enums.
  - Separates byte-driven download progress from install phases like hashing, extraction, validation, manifest writing, and model warmup so the app can show smooth progress through the full lifecycle.

### Audio Capture

- `KeyVox iOS/Core/Audio/iOSAudioRecorder.swift`
  - Public recorder interface and state holder for the containing app.
  - Tracks published meter state, current device label, and last capture classification facts.
- `KeyVox iOS/Core/Audio/iOSAudioRecorder+Session.swift`
  - Configures `AVAudioSession` for `.playAndRecord` with background-friendly options.
  - Starts and maintains the `AVAudioEngine`, requests microphone permission, resets capture state, and keeps the warm-session heartbeat alive.
- `KeyVox iOS/Core/Audio/iOSAudioRecorder+Streaming.swift`
  - Converts live input to 16kHz mono PCM through `AVAudioConverter`.
  - Buffers frames, computes RMS/peak-based meter state, and tracks active-signal run duration.
- `KeyVox iOS/Core/Audio/iOSAudioRecorder+StopPipeline.swift`
  - Transforms a raw snapshot into an `iOSStoppedCapture`.
  - Uses `KeyVoxCore` post-processing and `AudioCaptureClassifier` to reject likely silence before inference.
- `KeyVox iOS/Core/Audio/LiveInputSignalState.swift`
  - UI-facing enum describing live signal states (`dead`, `quiet`, `active`).

### Transcription and Post-Processing

- `KeyVox iOS/Core/Transcription/iOSTranscriptionManager.swift`
  - Main iOS state machine: `idle -> recording -> processingCapture -> transcribing -> idle`.
  - Coordinates recorder start/stop, model availability checks, dictionary prompt updates, `DictationPipeline` execution, and keyboard notifications.
  - Records spoken-word totals through `iOSWeeklyWordStatsStore` from final processed dictation output.
  - Stores the latest debug snapshot and surfaced error for the app UI.
- `KeyVox iOS/Core/Transcription/iOSDictationService.swift`
  - Minimal protocol seam over `WhisperService` for warmup, cancellation, hint-prompt updates, and transcription.
- `KeyVox iOS/Core/Transcription/iOSTranscriptionDebugSnapshot.swift`
  - Debug model containing raw text, final text, no-speech classification, timings, and capture facts from the last completed dictation.

### Containing-App UI

- `KeyVox iOS/Views/AppRootView.swift`
  - Minimal diagnostic/control UI for model state and transcription state.
  - Exposes model download/delete/repair actions and DEBUG-only runtime diagnostics.
- `KeyVox iOS/Views/HomeTabView.swift`
  - Displays the synced combined weekly word total in plain text.
  - Keeps device-level counts internal to the weekly stats store.

### Keyboard Extension

- `KeyVox Keyboard/KeyboardViewController.swift`
  - Keyboard extension controller and mic-button state machine.
  - Chooses warm Darwin signaling when the app heartbeat is fresh, otherwise opens the containing app immediately through the URL scheme.
  - Handles insertion of completed text into the host app.
- `KeyVox Keyboard/KeyboardIPCManager.swift`
  - Extension-side App Group + Darwin notification client.
  - Sends start/stop commands, reads shared recording state, checks warm-session heartbeat, and receives transcription/no-speech callbacks.
- `KeyVox Keyboard/KeyboardRootView.swift`
  - UIKit keyboard surface with globe button, status label, and mic button.
- `KeyVox Keyboard/KeyboardState.swift`
  - Small presentational state machine controlling labels, mic enablement, and icon/color treatment.
- `KeyVox Keyboard/KeyboardStyle.swift`
  - Visual constants for the keyboard surface.
- `KeyVox Keyboard/KeyboardInsertionSpacingHeuristics.swift`
  - Applies a conservative leading-space heuristic before insertion so dictated text does not collide with the existing document context.

### Tests

- `KeyVoxiOSTests/App/KeyVoxURLRouteTests.swift`
  - Verifies supported URL routes and rejection of invalid routes.
- `KeyVoxiOSTests/App/iOSSharedPathsTests.swift`
  - Verifies App Group path construction and fallback behavior.
- `KeyVoxiOSTests/App/iOSModelManagerTests.swift`
  - Covers install validation, download lifecycle, delete/repair behavior, and low-disk-space handling.
- `KeyVoxiOSTests/Core/Audio/iOSStoppedCaptureProcessorTests.swift`
  - Verifies speech acceptance and silence rejection rules for stop-time capture processing.
- `KeyVoxiOSTests/Core/Transcription/iOSTranscriptionManagerTests.swift`
  - Exercises state transitions, model gating, no-speech handling, and dictionary-prompt propagation.
- `../Packages/KeyVoxCore/Tests/KeyVoxCoreTests/`
  - Holds the deeper shared-package tests for `DictationPipeline`, `TranscriptionPostProcessor`, dictionary logic, list formatting, audio silence policy, and Whisper behavior.

## Historical Context

- `../Docs/KEYVOX_IOS.md` is the original full implementation plan and migration blueprint.
- This document reflects the current implemented structure of the iOS targets and should stay aligned with the code as the app evolves.
