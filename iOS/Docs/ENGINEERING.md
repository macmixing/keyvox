# KeyVox iOS Engineering Notes

This document captures the current implementation rules and maintainer-facing architecture for the iOS app and keyboard extension.

**Last Updated: 2026-03-11**

## Design Philosophy

KeyVox iOS keeps the same trust model as the Mac app while adapting to iOS process boundaries:

- No hidden speech collection.
- No silent text insertion.
- No transcription logic inside the keyboard extension.
- No ambiguous app-extension state during warm, cold, cancel, or timeout flows.

Speech stays local.  
The containing app owns privileged work.  
Shared state must stay explicit, deterministic, and recoverable.
The keyboard extension remains intentionally thin.
Convenience matters, but not more than predictable behavior.

## Architecture Overview

KeyVox iOS is organized by responsibility:

- `KeyVox iOS/App/`: app lifecycle, composition root, App Group storage, URL routing, IPC bridge, model lifecycle, weekly stats, and iCloud sync.
- `KeyVox iOS/Core/Audio/`: monitoring mode, capture session setup, live PCM conversion, metering, interruption handoff, and stop-time silence classification.
- `KeyVox iOS/Core/Transcription/`: iOS runtime state machine, session lifecycle, watchdog policy, and the boundary into `KeyVoxCore.DictationPipeline`.
- `KeyVox iOS/Views/`: tabbed SwiftUI shell with Home, Dictionary, Style, and Settings surfaces.
- `KeyVox Keyboard/`: custom keyboard UI, toolbar controls, warm/cold app handoff, cancel flow, live indicator rendering, cursor trackpad support, and final text insertion.
- `../Packages/KeyVoxCore/`: shared dictation pipeline, Whisper integration, dictionary persistence primitives, shared post-processing order, silence heuristics, and list formatting logic.
- `KeyVoxiOSTests/`: deterministic tests around paths, routing, iCloud sync, weekly stats, model lifecycle, stop-time capture processing, keyboard interaction helpers, and transcription/session behavior.

For file ownership and placement, see [`CODEMAP.md`](CODEMAP.md).

## Platform Compatibility

- Supported deployment target: iOS 18.6 and newer for the app, extension, and test target.
- The containing app declares:
  - `UIBackgroundModes = ["audio"]`
  - `BGTaskSchedulerPermittedIdentifiers = ["com.cueit.keyvox.model-download"]`
  - URL scheme `keyvoxios`
- The keyboard extension declares:
  - `NSExtensionPointIdentifier = com.apple.keyboard-service`
  - `RequestsOpenAccess = true`
- Both targets require the App Group entitlement:
  - `group.com.cueit.keyvox`

## Shared Storage and IPC Contract

`KeyVoxIPCBridge` is the only source of truth for the app-extension coordination contract.

### App Group `UserDefaults` Keys

- `recordingState`
- `recordingState_timestamp`
- `latestTranscription`
- `session_timestamp`

### App Group Settings Keys

- `KeyVox.TriggerBinding`
  - App-owned settings state.
  - Persisted and synced through `iOSAppSettingsStore` and `iOSiCloudSyncCoordinator`.
  - Present in the iOS settings store even though the current iOS UI does not expose a trigger-binding control.
- `KeyVox.AutoParagraphsEnabled`
  - App-owned style setting.
  - Consumed by `iOSTranscriptionManager` through injected providers.
- `KeyVox.ListFormattingEnabled`
  - App-owned style setting.
  - Consumed by `iOSTranscriptionManager` through injected providers.
- `KeyVox.CapsLockEnabled`
  - Extension-owned UI latch.
  - Written by the keyboard toolbar control.
  - Read by the containing app at dictation time so the shared all-caps override stays in `KeyVoxCore`.
  - Intentionally local-only and not synced through iCloud.

### App Group File Transport

- `live-meter-state.bin`
  - Written atomically by the containing app.
  - Read by the extension to animate the toolbar indicator while recording.
  - Treated as ephemeral transport state, not durable storage.

### Darwin Notification Names

- `com.cueit.keyvox.startRecording`
- `com.cueit.keyvox.stopRecording`
- `com.cueit.keyvox.cancelRecording`
- `com.cueit.keyvox.recordingStarted`
- `com.cueit.keyvox.transcribingStarted`
- `com.cueit.keyvox.transcriptionReady`
- `com.cueit.keyvox.noSpeech`

### Shared Recording States

- `idle`
- `waitingForApp`
- `recording`
- `transcribing`

### Warm-Session Rule

- Heartbeat freshness is controlled by `session_timestamp`.
- `KeyVoxIPCBridge.heartbeatFreshnessWindow` is `5` seconds.
- The recorder or app-side bridge refreshes the heartbeat while the containing app is active enough to be considered warm.
- The extension treats the app as warm only when the latest heartbeat is newer than that window.
- Warm path:
  - write `waitingForApp`
  - post `startRecording`
  - wait briefly for `.recording`
  - fall back to URL launch if the app does not take ownership quickly
- Cold path:
  - open `keyvoxios://record/start` immediately

Warm-session freshness is separate from the user-facing "Keep Session Active" idle timeout described below.

## Shared Container Layout

The App Group container is the stable cross-process boundary:

- `Models/ggml-base.bin`
- `Models/ggml-base-encoder.mlmodelc/`
- `Models/ggml-base-encoder.mlmodelc.zip` during install only
- `Models/model-install-manifest.json`
- `KeyVoxCore/` for dictionary persistence
- `live-meter-state.bin` for transient keyboard indicator transport

If the App Group container is unavailable, dictionary persistence falls back to:

- `Application Support/KeyVoxFallback/`

Model installation does not use a fallback path; missing App Group access is an install failure.

## End-to-End Runtime Flow

1. The user can optionally enable "Keep Session Active" from the Home tab, which starts monitoring mode in the containing app to prepare the keyboard.
2. The keyboard renders the cancel button and Caps Lock control outside the key grid so they align with the top row without moving the centered logo or changing keyboard height.
3. When the user taps Caps Lock, the extension immediately updates `KeyVox.CapsLockEnabled` in App Group defaults.
4. The user taps the mic in `KeyboardViewController`.
5. The extension reconciles stale shared state, writes `waitingForApp`, and checks the heartbeat freshness window.
6. If the session is warm, the extension posts `startRecording` and waits up to 500 ms for `.recording`.
7. If the session is cold, or the warm grace period fails, the extension launches `keyvoxios://record/start`.
8. `KeyVoxKeyboardBridge` or `KeyVoxURLRouter` forwards the start command to `iOSTranscriptionManager`.
9. `iOSTranscriptionManager` transitions `idle -> recording`, clears stale errors and snapshots, refreshes model availability, and starts recording.
10. `iOSAudioRecorder` records live 16 kHz mono float samples, updates heartbeat state, and streams live meter snapshots back through `KeyVoxIPCBridge`.
11. If the user taps the cancel button, the extension posts `cancelRecording`, the manager cancels the active utterance, and both sides return to `idle`.
12. On stop, the manager transitions to `processingCapture`, asks the recorder for an `iOSStoppedCapture`, and short-circuits to `noSpeech` when output frames are empty.
13. If output frames exist and the model is installed, the manager transitions to `transcribing`, warms Whisper, and runs `KeyVoxCore.DictationPipeline`.
14. The pipeline reads current style toggles and the App Group-backed Caps Lock value through injected providers.
15. The manager transitions back to `idle` and publishes either `transcriptionReady` or `noSpeech`.
16. The keyboard receives the callback, applies `KeyboardInsertionSpacingHeuristics`, and inserts the final text into the focused host app.
17. Final processed dictation text also updates the local weekly stats store, which then converges current-week device counts through iCloud KVS.

## Session Lifecycle and Safety Policy

`iOSTranscriptionManager` owns session policy through `iOSSessionPolicy`.

### Default Session Policy

- idle timeout: `300` seconds
- no-speech abandonment timeout: `45` seconds
- post-speech inactivity timeout: `180` seconds
- emergency utterance cap: `900` seconds

### Session Rules

- Monitoring mode and active dictation are separate concepts.
- `enableMonitoring()` can keep the audio engine warm without starting a recording.
- The Home tab toggle controls monitoring mode through `handleEnableSessionCommand()` and `handleDisableSessionCommand()`.
- If the user disables the session while idle, shutdown happens immediately.
- If the user disables the session during an utterance, shutdown is deferred until the current recording or transcription finishes.
- While idle and active, the session arms an idle timeout and exposes `sessionExpirationDate` to the Home tab.

### Utterance Safety Rules

- If no meaningful speech is detected for too long, the manager cancels the utterance and returns to idle without transcribing.
- If meaningful speech has already occurred and the capture then goes inactive for too long, the manager cancels the utterance.
- If the utterance exceeds the emergency cap, the manager cancels it.
- Cancellation keeps the session alive unless a deferred shutdown was already pending.

## Audio Capture Contract

`iOSAudioRecorder` owns iOS-specific audio behavior.

- Audio session category: `.playAndRecord`
- Audio session options: `.defaultToSpeaker`, `.mixWithOthers`, `.allowBluetoothHFP`
- Preferred sample rate: `16000`
- Output format: mono float PCM, non-interleaved
- Engine lifetime:
  - monitoring mode keeps the engine warm after a completed dictation
  - stopping a single utterance does not necessarily stop monitoring
  - full shutdown happens only through session teardown or external process loss

### Live Metering

The recorder publishes:

- `audioLevel`
- `LiveInputSignalState` (`dead`, `quiet`, `active`)
- `maxActiveSignalRunDuration`
- whether meaningful speech has been observed during the current capture

The keyboard does not sample the recorder directly. It only consumes the App Group `live-meter-state.bin` transport through `KeyboardIPCManager` and `AudioIndicatorDriver`.

### Stop-Time Capture Processing

When recording stops:

1. The raw capture snapshot is collected.
2. `AudioPostProcessing.removeInternalGaps(...)` is used to improve classification quality.
3. `AudioCaptureClassifier.classify(...)` evaluates absolute silence, active signal presence, likely silence, and long true silence.
4. True silence and likely-silence captures clear `outputFrames`.
5. Accepted captures return normalized transcription frames in `iOSStoppedCapture.outputFrames`.

Interrupted captures can also be handed back through `audioInterruptedCaptureHandler`, and the transcription manager processes them through the same completion path.

## Inference Model

The current iOS runtime uses the same base Whisper model family as the shared Mac runtime:

- GGML model: `ggml-base.bin`
- accelerator bundle: `ggml-base-encoder.mlmodelc`

`WhisperService` comes from `KeyVoxCore`, but the iOS app owns:

- model path resolution
- install readiness
- download, delete, and repair actions
- post-install unload and warmup behavior

## Model Installation and Integrity Rules

`iOSModelManager` is the source of truth for install lifecycle.

### Install Flow

1. Resolve App Group model paths.
2. Ensure the models directory exists.
3. Ensure enough free disk space is available.
4. Download the GGML model and Core ML zip in parallel.
5. Move the downloads into `Models/`.
6. SHA-256 validate both downloaded artifacts.
7. Extract the Core ML bundle.
8. Validate that the extracted bundle is structurally non-empty.
9. Remove the Core ML zip after successful extraction.
10. Write `model-install-manifest.json`.
11. Re-validate the final install.
12. Unload and warm Whisper so the runtime can use the new artifacts immediately.

### Install Progress Contract

Progress is phase-aware rather than a fake single percentage:

- byte-driven progress during parallel downloads
- explicit install phases for file moves, hashing, extraction, validation, manifest writing, and model warmup

### Validation Rules

An install is only `ready` when all of the following are true:

- `ggml-base.bin` exists
- `ggml-base.bin` meets the minimum size threshold
- `ggml-base-encoder.mlmodelc/` exists
- `ggml-base-encoder.mlmodelc.zip` has been removed
- `model-install-manifest.json` exists and is readable
- the manifest version is supported
- manifest hashes match the expected artifact hashes
- the extracted Core ML bundle is structurally non-empty

Partial installs are never treated as ready.

### Failure Policy

- User-facing errors collapse to actionable text rather than raw storage or network detail.
- Failed installs schedule a background repair task.
- `deleteModel()` unloads Whisper before removing artifacts.
- `repairModelIfNeeded()` removes partial state and performs a clean reinstall when validation is not ready.

## Dictionary, Style, and Sync Contract

The containing app owns live dictionary and style state, while the dictation pipeline remains shared.

### Dictionary Rules

- `iOSAppServiceRegistry` creates `DictionaryStore` with the App Group-backed dictionary base directory.
- `iOSTranscriptionManager` observes `dictionaryStore.$entries`.
- Dictionary changes immediately refresh:
  - `TranscriptionPostProcessor`
  - the Whisper hint prompt
- Hint prompts are bounded to:
  - newest entries only
  - up to `200` phrases
  - up to `1200` characters

### Style Rules

- `autoParagraphsEnabled` and `listFormattingEnabled` are app-owned runtime toggles.
- `StyleTabView` is the current user-facing surface for those toggles.
- `iOSTranscriptionManager` injects those settings into the shared `DictationPipeline` at runtime.

### iCloud Sync Rules

- `iOSiCloudSyncCoordinator` syncs:
  - dictionary payloads
  - trigger binding timestamps
  - auto paragraphs timestamps
  - list formatting timestamps
- `iOSWeeklyWordStatsCloudSync` syncs only the current-week word snapshot payload.
- Weekly stats merge by taking the maximum count seen for each device ID within the same week.
- Caps Lock state is intentionally excluded from iCloud sync.

## Post-Processing Order

The iOS app uses `KeyVoxCore.DictationPipeline`, so it follows the shared post-processing order:

1. `WhisperService` transcribes the supplied frames.
2. `TranscriptionPostProcessor` performs shared cleanup and formatting.
3. Email literal normalization runs before dictionary correction.
4. Dictionary correction and dictionary-backed email recovery run next.
5. Colon normalization and math normalization run before list formatting.
6. List formatting, laughter cleanup, repeated-character cleanup, time normalization, and website/domain normalization follow.
7. Whitespace normalization, capitalization guards, terminal punctuation finishing, and the final all-caps override complete the output.
8. On iOS, the all-caps override is controlled by the App Group `KeyVox.CapsLockEnabled` latch rather than keyboard-side text mutation.
9. The iOS runtime captures final pipeline output and sends it back to the keyboard extension instead of pasting directly.

## Keyboard Extension Contract

The extension is a transport and insertion surface, not the transcription owner.

- `KeyboardViewController` should own only:
  - UI event handling
  - keyboard state transitions
  - warm/cold app handoff
  - cancel flow
  - host-text insertion
  - cursor movement and key-repeat interactions
- The extension must not own model lifecycle, microphone capture, shared post-processing policy, or dictionary logic.
- Toolbar controls remain outside `KeyboardKeyGridView` so they can visually align with the top row while keeping the centered logo fixed.
- The live indicator is purely a rendering client over shared meter snapshots; it must not invent recording state.
- Caps Lock remains an extension-owned latch whose effect is applied later by the shared pipeline in the app.
- Caps Lock resets when the user leaves this keyboard for another active keyboard surface, but not merely because the host app briefly resigns active.
- `KeyboardInsertionSpacingHeuristics` stays intentionally conservative:
  - do not prepend a space after existing whitespace
  - do not prepend a space before incoming punctuation
  - do prepend a space after word-like or trigger punctuation contexts when needed
- The spacebar long-press trackpad and delete-repeat behaviors are keyboard-only interaction helpers and should stay separate from IPC concerns.

`RequestsOpenAccess = true` remains required because the extension depends on App Group communication with the containing app.

## App UI Contract

The containing app is no longer a single diagnostic view, but it is still intentionally thin:

- `MainTabView` owns the four-tab shell only.
- `HomeTabView` shows weekly usage and session activity controls.
- `DictionaryTabView` presents current dictionary entries.
- `StyleTabView` exposes dictation style toggles.
- `SettingsTabView` owns model install actions and status.
- Debug diagnostics remain conditional and view-only.

Views may surface manager state, but runtime ownership must stay in the managers and services.

## Testing and Quality Gates

- iOS app tests:
  `xcodebuild -project "iOS/KeyVox iOS.xcodeproj" -scheme "KeyVox iOS DEBUG" -destination 'platform=iOS Simulator,name=<installed simulator>' test`
- Shared package tests:
  `swift test --package-path Packages/KeyVoxCore`

### iOS-Focused Test Coverage

- URL route parsing
- App Group path construction
- App Group-backed settings persistence
- iCloud sync coordination for dictionary and style settings
- weekly stats storage and iCloud convergence
- model install validation and repair flows
- stop-time silence classification
- keyboard cursor-trackpad support
- transcription-manager session lifecycle, cancellation, timeout, and model gating

### Integration-Only Exclusions

- actual microphone hardware routing and Bluetooth behavior
- real host-app keyboard insertion across third-party apps
- process wake timing between extension and containing app
- long-running background execution under iOS memory pressure
- App Store review behavior around extension-to-app launch UX

Those remain device, integration, or manual-test territory by design.

## Contributor Notes

- Keep the app-extension contract centralized in `KeyVoxIPCBridge`; do not hand-roll duplicate keys, timestamps, or notification names elsewhere.
- Keep session rules explicit. If idle timeout, watchdog thresholds, or warm-session behavior change, update this document and the keyboard assumptions together.
- Keep model integrity checks strict. Accepting partial installs would create hard-to-debug runtime failures.
- Prefer injectable seams for time, storage, downloads, and services, following the existing `iOSModelManager`, sync coordinators, and transcription manager patterns.
- When shared `KeyVoxCore` behavior changes, update this document only if the iOS runtime contract changes as well.

## Change Tracking

- `ENGINEERING.md` tracks stable iOS architecture, IPC contracts, lifecycle rules, and operational/testing policy.
- `CODEMAP.md` tracks iOS file ownership and major system placement.
- `Docs/KEYVOX_IOS.md` remains historical design context rather than the primary source of truth for the current implementation.
