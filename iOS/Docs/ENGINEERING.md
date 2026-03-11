# KeyVox iOS Engineering Notes

This document contains implementation and maintainer-focused details for the iOS app and keyboard extension.

**Last Updated: 2026-03-11**

## Design Philosophy

KeyVox iOS follows the same trust model as the Mac app, adapted to iOS platform constraints:

- No hidden speech collection.
- No silent text insertion.
- No transcription inside the keyboard extension when the containing app is the safe/runtime-capable owner.
- No ambiguous app-extension state when the user taps the mic.

User speech stays local.  
The keyboard extension remains intentionally thin.  
The containing app owns the expensive and privileged work.  
Shared state must stay explicit, deterministic, and recoverable.

Convenience matters, but not more than predictable behavior.

## Architecture Overview

KeyVox iOS is organized by responsibility:

- `KeyVox iOS/App/`: app lifecycle, dependency composition, App Group paths, keyboard/app IPC contract, URL routing, model management, and app-owned weekly stats state.
- `KeyVox iOS/App/iCloud/`: dedicated iCloud KVS sync helpers and payloads. `iOSiCloudSyncCoordinator` remains focused on dictionary/settings sync, while `iOSWeeklyWordStatsCloudSync` owns weekly usage convergence separately.
- `KeyVox iOS/Core/Audio/`: `AVAudioSession` setup, engine lifecycle, streaming conversion, and stop-time classification.
- `KeyVox iOS/Core/Transcription/`: iOS runtime state machine and the boundary between capture, shared-package dictation, and keyboard notifications.
- `KeyVox iOS/Views/`: minimal containing-app UI for model controls and debug/runtime status.
- `KeyVox Keyboard/`: custom keyboard controller, toolbar-owned keyboard UI, warm/cold start coordination, and final text insertion.
- `../Packages/KeyVoxCore/`: shared dictation pipeline, Whisper integration, dictionary persistence, list formatting, post-processing order, and audio silence heuristics used by both platforms.
- `KeyVoxiOSTests/`: deterministic iOS-specific tests around pathing, routing, install lifecycle, capture processing, and transcription orchestration.

File-level ownership and locations are intentionally maintained in one place: [`CODEMAP.md`](CODEMAP.md).

## Platform Compatibility

- Supported deployment target: iOS 18.6 and newer for the containing app, keyboard extension, and test target.
- The containing app declares:
  - `UIBackgroundModes = ["audio"]`
  - `BGTaskSchedulerPermittedIdentifiers = ["com.cueit.keyvox.model-download"]`
  - URL scheme `keyvoxios`
- The keyboard extension declares:
  - `NSExtensionPointIdentifier = com.apple.keyboard-service`
  - `RequestsOpenAccess = true`
- Both targets require the App Group entitlement:
  - `group.com.cueit.keyvox`

For the full file-level map, see [`CODEMAP.md`](CODEMAP.md).

## Shared Storage and IPC Contract

`KeyVoxIPCBridge` is the single source of truth for the app-extension coordination contract.

### App Group `UserDefaults` Keys

- `recordingState`
- `latestTranscription`
- `session_timestamp`

### Shared App Group Settings Keys

- `KeyVox.CapsLockEnabled`
  - Owned by the iOS keyboard/app pair rather than `KeyVoxCore`.
  - Written by the keyboard extension toolbar toggle.
  - Read by the containing app at dictation time so the shared all-caps override can stay in `KeyVoxCore`.
  - Persisted locally in the App Group container and intentionally not synced through iCloud.

### Darwin Notification Names

- `com.cueit.keyvox.startRecording`
- `com.cueit.keyvox.stopRecording`
- `com.cueit.keyvox.recordingStarted`
- `com.cueit.keyvox.transcriptionReady`
- `com.cueit.keyvox.noSpeech`

### Shared Recording States

- `idle`
- `waitingForApp`
- `recording`
- `transcribing`

### Warm-Session Rule

- The containing app updates `session_timestamp` with a throttled heartbeat.
- The live recorder session is the main heartbeat source while the monitoring engine is warm; app-side bridge events also refresh the timestamp during major state transitions.
- `KeyVoxIPCBridge.sessionTimeout` is `5` seconds.
- The extension treats the app as warm only when the latest heartbeat is newer than that timeout.
- Warm path: post Darwin notification first, wait briefly for `.recording`, and only then fall back to launching the app.
- Cold path: open `keyvoxios://record/start` immediately to preserve touch-context intent.

## Shared Container Layout

The App Group container is used as the stable cross-process storage boundary:

- `Models/ggml-base.bin`
- `Models/ggml-base-encoder.mlmodelc/`
- `Models/model-install-manifest.json`
- `KeyVoxCore/` for dictionary persistence owned by `DictionaryStore`

If the App Group container is unavailable, dictionary persistence falls back to:

- `Application Support/KeyVoxFallback/`

The model install path does not use the fallback; missing App Group access is treated as an install failure.

## End-to-End Runtime Flow

1. The keyboard extension renders Caps Lock as a toolbar-owned control outside the key grid so it can visually align with the top row without changing keyboard height or moving the centered logo.
2. When the user taps the Caps Lock key, the extension updates the App Group-backed `KeyVox.CapsLockEnabled` latch immediately.
3. The user taps the mic in `KeyboardViewController`.
4. The keyboard sets shared state to `waitingForApp`.
5. If the session is warm, the extension posts `startRecording` and waits up to 500ms for the app to enter `.recording`.
6. If the session is cold, or the grace period expires, the extension opens `keyvoxios://record/start`.
7. `KeyVoxURLRouter` or `KeyVoxKeyboardBridge` forwards the start command to `iOSTranscriptionManager`.
8. `iOSTranscriptionManager` transitions `idle -> recording`, clears stale UI/debug state, refreshes model availability, and starts the recorder.
9. `iOSAudioRecorder` ensures the `AVAudioEngine` is warm, requests microphone permission, and records live 16kHz mono float samples.
10. On stop, the manager transitions `recording -> processingCapture`, asks the recorder for a processed capture, and uses the resulting output frames directly for model gating and transcription.
11. Empty or rejected output frames short-circuit back to `idle` with a `noSpeech` publish.
12. If output frames are present and the model exists, the manager transitions to `transcribing`, warms Whisper, and runs `DictationPipeline`.
13. The dictation pipeline reads the latest iOS-owned Caps Lock value through the injected provider and applies the existing shared all-caps override only when that latch is enabled.
14. The manager transitions back to `idle` and publishes either `transcriptionReady` or `noSpeech`.
15. The keyboard receives the callback, applies insertion spacing heuristics, and calls `textDocumentProxy.insertText(...)`.
16. Successful final dictation text is also recorded into the containing app's weekly stats store, which syncs hidden per-device totals through iCloud KVS and exposes only the combined total to the Home tab.

## Audio Capture Contract

`iOSAudioRecorder` owns the iOS-specific audio behavior.

- Audio session category: `.playAndRecord`
- Audio session options: `.defaultToSpeaker`, `.mixWithOthers`, `.allowBluetoothHFP`
- Preferred sample rate: `16000`
- Output format: mono float PCM, non-interleaved
- Engine lifetime:
  - The engine is kept running after stop so the containing app stays warm and background-capable.
  - `isMonitoring` remains true after a completed capture unless the process is torn down externally.

### Live Metering

The streaming path tracks:

- `audioLevel`
- `LiveInputSignalState` (`dead`, `quiet`, `active`)
- `maxActiveSignalRunDuration`
- whether any non-dead signal was observed during the capture

These values are UI/debug aids and also feed the stop-time capture classification path.

### Stop-Time Capture Processing

When recording stops:

1. The raw snapshot is collected from the accumulator.
2. `AudioPostProcessing.removeInternalGaps(...)` removes internal silent regions for classification support.
3. `AudioCaptureClassifier.classify(...)` decides:
   - `isAbsoluteSilence`
   - `hadActiveSignal`
   - `shouldRejectLikelySilence`
   - `isLongTrueSilence`
4. If the capture is true silence or likely silence, output frames are cleared.
5. Otherwise, the raw snapshot is normalized for transcription and returned as output frames.

The containing app does not persist stop-time capture artifacts. Once the recorder returns an `iOSStoppedCapture`, the manager either rejects it as silence/no-speech or passes its output frames directly into transcription.

## Inference Model

KeyVox iOS currently uses the same base Whisper model family as the shared Mac runtime:

- GGML model: `ggml-base.bin`
- Companion accelerator artifact: `ggml-base-encoder.mlmodelc`

`WhisperService` is resolved through `KeyVoxCore`, but the iOS app owns:

- model-path resolution
- install readiness
- model download/delete/repair actions
- warmup/unload timing around install state transitions

## Model Installation and Integrity Rules

`iOSModelManager` is the source of truth for model install lifecycle.

### Install Flow

1. Resolve App Group paths.
2. Ensure the models directory exists.
3. Ensure enough free disk space is available.
4. Download GGML and Core ML zip in parallel.
5. Move both downloads into `Models/`.
6. SHA-256 validate both artifacts against baked-in expected hashes.
7. Unzip the Core ML archive.
8. Validate the extracted Core ML bundle is structurally non-empty.
9. Remove the Core ML zip after successful extraction.
10. Write `model-install-manifest.json`.
11. Re-validate the final install.
12. Unload and warm Whisper so the runtime sees the new artifacts immediately.

### Install Progress Contract

The model manager exposes a phase-aware progress model rather than a single fake progress number.

- Download progress is byte-driven across:
  - `ggml-base.bin`
  - `ggml-base-encoder.mlmodelc.zip`
- Install progress is phase-aware across:
  - moving files
  - verifying the GGML artifact
  - verifying the Core ML archive
  - extracting the Core ML bundle
  - validating the extracted bundle
  - writing the install manifest
  - warming the model

This keeps the progress bar smooth and deterministic enough for production UI without overfitting every tiny operation into a separate UI concept.

### Validation Rules

An install is only `ready` when all of the following are true:

- `ggml-base.bin` exists
- `ggml-base.bin` meets the minimum size threshold
- `ggml-base-encoder.mlmodelc/` exists
- `ggml-base-encoder.mlmodelc.zip` has been removed
- `model-install-manifest.json` exists and is readable
- the manifest version is supported
- the manifest hashes match the expected artifact hashes
- the extracted Core ML bundle is structurally non-empty

Anything less than this must report `.failed(...)` or `.notInstalled`; partial readiness is not allowed.

### Failure Policy

- User-facing install failures collapse to actionable text rather than raw underlying errors.
- Failed installs schedule a background repair task.
- `deleteModel()` unloads Whisper first, then removes the installed artifacts.
- `repairModelIfNeeded()` removes partial artifacts and performs a clean reinstall when validation is not `.ready`.

## Dictionary and Prompt Contract

The containing app owns the live `DictionaryStore`, but the dictation pipeline is shared with the Mac app.

- `iOSAppServiceRegistry` creates the `DictionaryStore` with an App Group-backed base directory.
- `iOSTranscriptionManager` observes `dictionaryStore.$entries`.
- Dictionary updates immediately:
  - refresh `TranscriptionPostProcessor`
  - rebuild the Whisper hint prompt
- Hint prompts are bounded:
  - newest entries only
  - up to `200` phrases
  - up to `1200` characters

The iOS app should continue to treat dictionary updates as hot-reloadable runtime state, not as an app-restart feature.

## Post-Processing Order

The iOS app uses `KeyVoxCore.DictationPipeline` and therefore follows the shared post-processing order:

1. `WhisperService` transcribes the supplied frames.
2. `TranscriptionPostProcessor` runs shared cleanup and formatting.
3. Email literal normalization runs before dictionary correction.
4. Dictionary correction and dictionary-backed email recovery run next.
5. Colon normalization and math normalization run before list formatting.
6. List formatting, laughter cleanup, repeated-character cleanup, time normalization, and website/domain normalization follow.
7. Whitespace normalization, capitalization guards, terminal punctuation finishing, and the final all-caps override complete the output.
8. The all-caps override is driven on iOS by the shared App Group `capsLockEnabled` value rather than by keyboard-extension-local text transformation.
9. The iOS runtime captures the final text from the pipeline and sends it back to the keyboard extension instead of pasting directly.

For the deeper shared implementation details, see the top-level Mac docs and `../Packages/KeyVoxCore/`.

## Keyboard Extension Contract

The extension is a transport and insertion surface, not the transcription owner.

- `KeyboardViewController` should only manage:
  - mic taps
  - toolbar-owned special control state
  - state-driven UI updates
  - app launching fallback
  - insertion of final text
- The extension must not own model lifecycle, microphone capture, or post-processing policy.
- Toolbar-owned special keys are intentionally kept outside `KeyboardKeyGridView` so they can match top-row key widths without pushing the centered logo upward or increasing keyboard height.
- The Caps Lock latch is extension-owned UI state stored in the App Group and consumed by the app at dictation time; the extension does not uppercase text on its own.
- Caps Lock should reset when the user leaves this keyboard for another active keyboard surface, but it should not clear just because the host app temporarily resigns active.
- `KeyboardInsertionSpacingHeuristics` is intentionally conservative:
  - do not prepend a space after existing whitespace
  - do not prepend a space before incoming punctuation
  - do prepend a space after word-like or trigger punctuation contexts when needed

`RequestsOpenAccess = true` is a required part of the current design because the extension depends on App Group communication with the containing app.

## App UI Contract

`AppRootView` is intentionally small and operational:

- It exposes model status and install actions.
- In `DEBUG`, it surfaces transcription state and the latest runtime error.
- It is not the source of truth for recorder/model/transcription logic.

If the iOS app grows a fuller user-facing settings surface later, the runtime ownership should stay in the managers rather than drifting into the view layer.

## Testing and Quality Gates

- iOS app tests:
  `xcodebuild -project "iOS/KeyVox iOS.xcodeproj" -scheme "KeyVox iOS DEBUG" -destination 'platform=iOS Simulator,name=<installed simulator>' test`
- Shared package tests:
  `swift test --package-path Packages/KeyVoxCore`

### iOS-Focused Test Coverage

- URL route parsing
- App Group path construction
- model install validation and repair flows
- stop-time silence classification
- transcription-manager state transitions and model gating
- App Group-backed Caps Lock settings persistence and uppercase pipeline wiring

### Integration-Only Exclusions

- actual microphone hardware routing and Bluetooth behavior
- real host-app keyboard insertion across third-party apps
- process wake timing between extension and containing app
- background execution longevity under iOS memory pressure
- App Store review behavior around extension/app launching UX

These remain device/integration/manual-test territory by design.

## Dependencies

- Local package:
  - `../Packages/KeyVoxCore`
- Remote package:
  - `ZIPFoundation` for Core ML archive extraction
- System frameworks:
  - `AVFoundation`
  - `BackgroundTasks`
  - `UIKit`
  - `SwiftUI`
  - `CoreFoundation`

## Contributor Notes

- Keep the app-extension contract centralized in `KeyVoxIPCBridge`; do not duplicate keys or notification names in scattered files.
- Keep model integrity checks strict. Partial install acceptance would create hard-to-debug runtime failures.
- Keep the recorder warm-session behavior explicit. If future work changes engine lifetime, update both this doc and the keyboard warm/cold assumptions.
- Prefer adding test seams through injected closures/protocols, as `iOSModelManager` and `iOSTranscriptionManager` already do.
- When shared dictation behavior changes, update the iOS docs only if the iOS runtime contract changes too; otherwise prefer the shared package docs/tests as the deeper source of truth.

## Change Tracking

- `ENGINEERING.md` captures stable iOS architecture, invariants, and operational/testing policy, not per-commit file churn.
- `CODEMAP.md` captures iOS-specific file ownership and major-system placement.
- `../Docs/KEYVOX_IOS.md` remains the historical implementation blueprint, not the primary source of truth for the current runtime.
- Keep this doc updated only when architecture, invariants, IPC contracts, or operational/testing policy changes.
