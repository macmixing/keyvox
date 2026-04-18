# KeyVox iOS Engineering Notes

This document captures the current implementation rules and maintainer-facing architecture for the iOS app, keyboard extension, and widget extension.

**Last Updated: 2026-04-16**

## Design Philosophy

KeyVox iOS keeps the same trust model as the Mac app while adapting to iOS process boundaries:

- No hidden speech collection.
- No silent text insertion.
- No transcription logic inside the keyboard extension.

Speech stays local.
The containing app owns privileged work.
Shared state must stay explicit, deterministic, and recoverable.
The keyboard extension remains intentionally thin.
The widget extension remains presentation-only.
The share extension remains extraction and handoff only.
Convenience matters, but not more than predictable behavior.

## Target Boundaries

### Containing App

The containing app owns:

- onboarding state and routing
- app-owned haptics
- settings and iCloud sync
- model installation, validation, and recovery
- copied-text playback voice installation and validation
- microphone capture and session warmth
- interrupted-capture recovery
- dictation pipeline ownership
- copied-text TTS request ownership
- copied-text playback, replay, and pause/resume state
- playback-preparation and return-to-host readiness gating
- weekly word stats
- Live Activity coordination
- the SwiftUI app shell

### Keyboard Extension

The keyboard extension owns:

- visible keyboard UI
- presentation-scoped keyboard view-tree lifecycle
- toolbar mode selection and warning presentation
- warm/cold launch handoff into the containing app
- keyboard-owned copied-text speak control and transport state
- text insertion into host apps
- keyboard-only interaction helpers like trackpad mode, delete repeat, and haptics

The keyboard extension does **not** own:

- model lifecycle
- microphone permissions
- model downloads
- dictionary logic
- transcription post-processing policy
- onboarding progression

### Widget Extension

The widget extension owns:

- lock screen Live Activity rendering
- Dynamic Island rendering
- the stop-session App Intent

The widget extension does **not** own session policy, dictation state, or business logic beyond presenting the current mirrored session state.

### Share Extension

The share extension owns:

- extraction of directly shared text
- extraction of text from shared URLs and web payloads
- extraction of selectable text from shared PDFs with rendered-page OCR fallback
- OCR extraction for shared images
- staging a TTS request into App Group storage
- launching the containing app into the TTS route
- lightweight visual feedback while extraction is running

The share extension does **not** own:

- PocketTTS runtime initialization
- voice install validation
- synthesis
- playback state
- replay caching

## Platform and Target Requirements

- Supported deployment target: iOS 18.6 and newer for the app, keyboard, widget, and tests.
- The containing app declares:
  - `UIBackgroundModes = ["audio"]`
  - `BGTaskSchedulerPermittedIdentifiers = ["com.cueit.keyvox.model-download"]`
  - URL scheme `keyvoxios`
- The keyboard extension declares:
  - `NSExtensionPointIdentifier = com.apple.keyboard-service`
  - `RequestsOpenAccess = true`
- The share extension declares:
  - `NSExtensionPointIdentifier = com.apple.share-services`
- Both the app and keyboard extension require the App Group entitlement:
  - `group.com.cueit.keyvox`
- The share extension also requires the App Group entitlement:
  - `group.com.cueit.keyvox`
- The widget target also depends on the shared code/project wiring needed for ActivityKit and the shared App Group-backed session state.

## Composition Root

`AppServiceRegistry` is the only sanctioned composition root for the containing app.

It builds and wires:

- `DictionaryStore`
- `AppSettingsStore`
- `OnboardingStore`
- `WeeklyWordStatsStore`
- `AppTabRouter`
- `AppHaptics`
- `WhisperService`
- `ParakeetService`
- `SwitchableDictationProvider`
- `TranscriptionPostProcessor`
- `ModelManager`
- `KeyVoxKeyboardBridge`
- `TranscriptionManager`
- `TTSPreviewPlayer`
- `PocketTTSEngine`
- `PocketTTSModelManager`
- `TTSPurchaseController`
- `KeyVoxSpeakIntroController`
- `TTSPlaybackCoordinator`
- `TTSManager`
- `AudioModeCoordinator`
- `AppUpdateCoordinator`
- `CloudSyncCoordinator`
- `WeeklyWordStatsCloudSync`
- `KeyVoxSessionLiveActivityCoordinator`
- `KeyVoxURLRouter`

Service ownership rules:

- Managers own runtime state.
- Views present state and call actions, but do not become alternate sources of truth.
- IPC contracts remain centralized in `KeyVoxIPCBridge`.
- Haptic-emission policy stays app-owned; pure decision helpers decide when feedback should fire, and `AppHaptics` owns the UIKit bridge.
- `AppServiceRegistry` wires PocketTTS services and normalizes voice selection, but it must not proactively prewarm the PocketTTS runtime; playback owns runtime load and unload.

### Containing App Source Layout

`KeyVox iOS/App/` is grouped by responsibility so the composition root stays readable:

- `Lifecycle/` owns the app entry point plus UIKit delegate bridges.
- `Composition/` owns `AppServiceRegistry` and shared rooted path helpers.
- `Routing/` owns cold-launch URL capture and route parsing/dispatch.
- `Integration/` owns App Group and keyboard-bridge contracts.
- `Feedback/` owns app-scoped haptics and copy-feedback interaction state.
- `LiveActivity/` owns the ActivityKit mirror layer.
- `KeyVoxSpeak/` owns the post-onboarding intro controller and copied-text playback purchase gate.
- `Stats/` owns app-local weekly usage aggregation.
- `Onboarding/`, `Shortcuts/`, `iCloud/`, and `AppUpdate/` remain isolated feature folders.

## Root Routing and Onboarding Contract

`AppRootView` is the top-level route owner.

Current root behavior:

- hold on a neutral background until the initial launch context is resolved
- show `ReturnToHostView` only when onboarding is not being suppressed and a cold start route or explicit return-to-host presentation is active
- allow `ReturnToHostView` to dismiss itself back to the Home surface without tearing down the underlying app route or session owner
- keep the main tab shell mounted whenever the app is in the onboarding-or-main path
- layer onboarding on top of the main shell when `OnboardingStore.shouldShowOnboarding` is `true`
- `ReturnToHostView` may appear only when onboarding is not being suppressed by the onboarding store for the current launch
- a cold `keyvoxios://record/start` launch may preselect `ReturnToHostView` before the first real SwiftUI route render
- the post-onboarding `KeyVoxSpeakIntroSheetView` may appear only while the resolved root destination is truly `.main`, and must never interrupt onboarding, `ReturnToHostView`, or `PlaybackPreparationView`
- app update prompts may appear only while the resolved root destination is truly `.main`, and must never interrupt launch hold, onboarding, `ReturnToHostView`, or `PlaybackPreparationView`

### Onboarding Store Rules

`OnboardingStore` owns:

- `hasCompletedOnboarding`
- `hasCompletedWelcomeScreen`
- `isForceOnboardingLaunch`
- `hasPendingKeyboardTour`
- `hasPassedWelcomeScreenThisLaunch`
- `isPendingKeyboardTourRouteArmed`
- `isIgnoringPersistedPendingKeyboardTourThisLaunch`
- `hasCompletedOnboardingThisLaunch`

### Runtime Flags

The supported runtime flags are:

- `KEYVOX_FORCE_ONBOARDING`
- `KEYVOX_BYPASS_TTS_FREE_SPEAK_LIMIT`
- `KEYVOX_FORCE_KEYVOX_SPEAK_INTRO`

Accepted truthy values:

- `1`
- `true`
- `yes`

Behavior:

- a cold launch with the flag set must always begin at the welcome screen
- the flag must still allow in-launch progression through the flow
- persisted onboarding completion must not block the forced flow
- stale persisted keyboard-tour handoff state must not skip setup during a forced run

### TTS Free-Speak Bypass Runtime Flag

Accepted truthy values:

- `1`
- `true`
- `yes`

Behavior:

- the flag bypasses the phase-one limit of two free new copied-text playback generations per local calendar day
- the flag is for development and testing only and must not change production monetization policy
- the flag only applies to new PocketTTS generation gating and does not change replay behavior
- `TTSManager` still consumes a free speak only after a new PocketTTS generation has actually started, but no use is consumed while the bypass flag is enabled

### KeyVox Speak Intro Runtime Flag

Accepted truthy values:

- `1`
- `true`
- `yes`

Behavior:

- the flag forces the post-onboarding KeyVox Speak intro to present for development and design work
- the flag does not change the underlying seen-state or feature-used suppression rules for production behavior
- the intro still routes through the main app surface and must not appear over onboarding, `ReturnToHostView`, or `PlaybackPreparationView`

### Onboarding Screen Order

Current onboarding order is:

1. welcome
2. setup
3. keyboard tour

### Setup Screen Contract

The setup screen owns three real requirements:

- model ready
- microphone permission granted
- keyboard access confirmed

Rules:

- keyboard setup stays gated until the model install state is `.ready` and microphone permission is granted
- microphone permission may be completed while the model download is still running
- model download may continue while the user works through the other visible steps
- when microphone access is denied, onboarding must route the user to app settings rather than pretending the permission can still be requested in place
- the setup screen records a pending keyboard-tour handoff before opening KeyVox settings
- the setup screen records and arms the keyboard-tour handoff when the model is ready, microphone access is granted, and the keyboard is already enabled, even if the user enabled the keyboard during a microphone settings trip or before the model finished downloading

### Keyboard Tour Contract

The keyboard tour is a resumed onboarding step after the user leaves setup for Settings.

Rules:

- it is full-screen, not a sheet
- it autofocuses a text field so the KeyVox keyboard can appear immediately
- it uses `KeyboardObserver` height to pin the input above the keyboard
- it is driven by `OnboardingKeyboardTourState` scene progression (`a` -> `b` -> `c`)
- the final completion action is disabled until the user has both shown the KeyVox keyboard and completed a first non-empty transcription while the tour is active
- stale old keyboard-ready state must not be enough to finish onboarding
- completing the keyboard tour clears the pending keyboard-tour handoff and completes onboarding directly
- `ReturnToHostView` remains suppressed for the rest of that launch after onboarding completion

### Keyboard Access Detection

Keyboard onboarding detection is deliberately split across three signals:

- app-side detection that the keyboard is enabled in system settings
- extension-side confirmation that the keyboard was presented
- extension-side confirmation that the keyboard launched with Full Access through the App Group bridge

`OnboardingKeyboardAccessProbe` is the app-side read surface for:

- `AppleKeyboards` enablement
- `keyboardOnboardingPresentation_timestamp`
- `keyboardOnboardingHasFullAccess`
- `keyboardOnboardingAccess_timestamp`

## Shared Storage and IPC Contract

`KeyVoxIPCBridge` is the only source of truth for app-extension and app-widget coordination.

### App Group `UserDefaults` Transport Keys

- `recordingState`
- `recordingState_timestamp`
- `latestTranscription`
- `session_timestamp`
- `sessionHasBluetoothAudioRoute`
- `recentTTSPlayback_timestamp`
- `ttsState`
- `ttsState_timestamp`
- `ttsIsPaused`
- `ttsPlaybackProgress`
- `ttsErrorMessage`
- `keyboardOnboardingPresentation_timestamp`
- `keyboardOnboardingAccess_timestamp`
- `keyboardOnboardingHasFullAccess`
- `appUpdateRequired`
- `pendingURLRoute`

### App Group Settings Keys

- `KeyVox.TriggerBinding`
- `KeyVox.AutoParagraphsEnabled`
- `KeyVox.ListFormattingEnabled`
- `KeyVox.CapsLockEnabled`
- `KeyVox.KeyboardHapticsEnabled`
- `KeyVox.PreferBuiltInMicrophone`
- `KeyVox.LiveActivitiesEnabled`
- `KeyVox.SessionDisableTiming`
- `KeyVox.TTSVoice`
- `KeyVox.FastPlaybackModeEnabled`

### App-Owned Persistent Defaults Keys

- `KeyVox.App.WeeklyWordStatsPayload`
- `KeyVox.App.WeeklyWordStatsInstallationID`
- `KeyVox.App.HasCompletedOnboarding`
- `KeyVox.App.HasCompletedOnboardingWelcome`
- `KeyVox.App.HasPendingKeyboardTour`
- `KeyVox.App.ActiveDictationProvider`
- `KeyVox.App.CachedAppStoreReleaseURL`
- `KeyVox.App.CachedAppStoreReleaseVersion`
- `KeyVox.App.CachedAppUpdateUrgency`
- `KeyVox.App.LastAppUpdateCheckTime`
- `KeyVox.App.IsTTSTranscriptExpanded`
- `KeyVox.App.IsTTSUnlocked`
- `KeyVox.App.TTSFreeSpeakUsageDayStart`
- `KeyVox.App.TTSFreeSpeakUsageCount`
- `KeyVox.App.HasSeenKeyVoxSpeakIntro`
- `KeyVox.App.HasUsedKeyVoxSpeak`
- `KeyVox.App.KeyVoxSpeakEligibleOpenCount`

### App Group File Transport

- `live-meter-state.bin`
  - written atomically by the containing app
  - read by the keyboard extension only
  - ephemeral transport, not durable storage
- `TTS/request.json`
  - staged by the containing app, keyboard extension, and share extension
  - consumed by the containing app as the single source of truth for pending copied-text playback requests
- `TTS/last-replay.json`
  - durable replay metadata containing the request, rendered sample count, and optional paused replay sample offset
- `TTS/last-replay.pcm`
  - durable replay audio payload for the last replayable copied-text playback

## App Update Contract

The containing app owns update policy. The keyboard only consumes the shared forced-update result.

Current rules:

- `AppUpdateService` fetches the latest public version from the App Store lookup endpoint and fetches the minimum supported version from the public `iOS/app-update-policy.json` manifest in the repository
- the App Store is the only source of truth for the latest release version
- the policy manifest is only allowed to decide the minimum supported version; it must not duplicate latest-version state
- `AppUpdatePolicyEvaluator` maps:
  - current version >= latest App Store version -> no prompt
  - current version < latest App Store version and current version >= minimum supported version -> optional update
  - current version < minimum supported version -> forced update
- `AppUpdateCoordinator` caches the last resolved decision in app-owned defaults so optional updates can reappear on cold launch without requiring a fresh network fetch every time
- optional updates are dismissible only for the current process lifetime and should reappear on the next cold launch while the cached decision remains valid
- forced updates are never dismissible
- forced update state is mirrored into `KeyVoxIPCBridge` through the shared `appUpdateRequired` flag so the keyboard toolbar can route into its warning mode
- the containing app may present update UI only on the true `.main` route
- the keyboard must not evaluate App Store or policy-manifest state directly

### Darwin Notification Names

- `com.cueit.keyvox.startRecording`
- `com.cueit.keyvox.stopRecording`
- `com.cueit.keyvox.cancelRecording`
- `com.cueit.keyvox.disableSession`
- `com.cueit.keyvox.recordingStarted`
- `com.cueit.keyvox.transcribingStarted`
- `com.cueit.keyvox.transcriptionReady`
- `com.cueit.keyvox.noSpeech`
- `com.cueit.keyvox.startTTS`
- `com.cueit.keyvox.stopTTS`
- `com.cueit.keyvox.pauseTTS`
- `com.cueit.keyvox.resumeTTS`
- `com.cueit.keyvox.ttsPreparing`
- `com.cueit.keyvox.ttsPlaying`
- `com.cueit.keyvox.ttsPaused`
- `com.cueit.keyvox.ttsResumed`
- `com.cueit.keyvox.ttsFinished`
- `com.cueit.keyvox.ttsStopped`
- `com.cueit.keyvox.ttsFailed`

### Shared Recording States

- `idle`
- `waitingForApp`
- `recording`
- `transcribing`

### Shared TTS States

- `idle`
- `preparing`
- `generating`
- `playing`
- `finished`
- `error`

## Shared Container Layout

The App Group container is the stable cross-process boundary:

- `Models/whisper/ggml-base.bin`
- `Models/whisper/ggml-base-encoder.mlmodelc/`
- `Models/whisper/ggml-base-encoder.mlmodelc.zip` during install only
- `Models/whisper/install-manifest.json`
- `Models/parakeet/config.json`
- `Models/parakeet/parakeet_vocab.json`
- `Models/parakeet/Encoder.mlmodelc/`
- `Models/parakeet/Decoder.mlmodelc/`
- `Models/parakeet/JointDecision.mlmodelc/`
- `Models/parakeet/install-manifest.json`
- `Models/tts/pockettts/Model/`
- `Models/tts/pockettts/Voices/<voice>/audio_prompt.bin`
- `Models/.staging/whisper-base/` during staged Whisper download only
- `Models/.staging/parakeet-tdt-v3/` during staged Parakeet download only
- `Models/model-download-job.json`
- `InterruptedCapture/pending-interrupted-capture.plist`
- `KeyVoxCore/` for dictionary persistence
- `TTS/request.json`
- `TTS/last-replay.json`
- `TTS/last-replay.pcm`
- `live-meter-state.bin` for transient keyboard indicator transport

If the App Group container is unavailable:

- dictionary persistence falls back to `Application Support/KeyVoxFallback/`
- model installation does **not** fall back and must fail loudly

## Warm Session and App Launch Contract

Warmth is controlled by `session_timestamp`.

Rules:

- `KeyVoxIPCBridge.heartbeatFreshnessWindow` is `5` seconds
- `KeyVoxIPCBridge.recentTTSWarmStartWindow` is `8` seconds
- the recorder or keyboard bridge refreshes the heartbeat while the app is active enough to be considered warm
- the extension treats the app as warm only when the heartbeat is newer than that window
- the keyboard may use a longer warm grace period when the shared state reports a Bluetooth route or recent TTS playback

Warm path:

1. keyboard writes `waitingForApp`
2. keyboard posts `startRecording`
3. keyboard waits briefly for `.recording`
4. keyboard falls back to URL launch if the app does not take ownership quickly

Cold path:

1. keyboard launches `keyvoxios://record/start`
2. `AppSceneDelegate` captures the scene connection URL before the first root render
3. `AppRootView` holds on a neutral background until launch routing resolves
4. the app presents `ReturnToHostView`
5. the user returns to the host app once the session is active

`ReturnToHostView` must never interrupt onboarding.

## Session Lifecycle and Safety Policy

`TranscriptionManager` owns session policy through `SessionPolicy`.

### Public Session State

- `idle`
- `recording`
- `processingCapture`
- `transcribing`

### Default Policy

- idle timeout: `300` seconds
- no-speech abandonment timeout: `45` seconds
- post-speech inactivity timeout: `180` seconds
- emergency utterance cap: `900` seconds

### Session Rules

- monitoring mode and active dictation are separate concepts
- enabling a session warms the recorder without starting an utterance
- disabling a session while idle tears down immediately
- disabling a session during an utterance defers shutdown until the current work finishes
- the Home/Settings surfaces read and configure session timing, but `TranscriptionManager` remains the runtime owner

### Safety Rules

- likely silence short-circuits to `noSpeech`
- long no-speech or post-speech inactivity cancels the utterance
- the emergency utterance cap cancels runaway recordings
- cancellation keeps the session alive unless a deferred shutdown was already pending

## Audio Capture Contract

`AudioRecorder` owns iOS-specific audio behavior.

- audio session category: `.playAndRecord`
- audio session options: `.defaultToSpeaker`, `.mixWithOthers`, `.allowBluetoothHFP`
- active session sample rate: keep the hardware route's native sample rate
- downstream recorder output format: mono float PCM, non-interleaved, `16000` Hz

Recorder file split:

- `AudioRecorder+Session.swift` owns session setup, engine lifecycle, route recovery, and interruption observation
- `AudioRecorder+Streaming.swift` owns buffer conversion, accumulation, and live metering
- `AudioRecorder+StopPipeline.swift` owns stop-time and interruption-time capture finalization plus silence rejection

Bluetooth routing rule:

- the recorder baseline stays on the historical HFP-capable warm-session contract
- preserved TTS playback does not share that exact category-option set
- this inconsistency is intentional: moving the recorder baseline onto the preserved-TTS route-family policy caused Bluetooth `newDeviceAvailable` interruptions to tear down the warm session before TTS began
- `AudioBluetoothRoutePolicy` is therefore scoped only to preserved TTS playback, where it maps:
  - built-in microphone preferred -> `.allowBluetoothA2DP`
  - built-in microphone disabled -> `.allowBluetoothHFP`
- do not merge the recorder baseline and preserved-TTS policy owners unless logs prove the recorder warm session survives the route-family change

Engine lifetime rules:

- monitoring mode can keep the engine warm after a completed dictation
- stopping a single utterance does not necessarily shut down monitoring
- full shutdown happens only through explicit session teardown or external process loss

### Live Metering

The recorder publishes:

- `audioLevel`
- `LiveInputSignalState`
- `maxActiveSignalRunDuration`
- whether meaningful speech has been observed during the current capture

The keyboard never samples the recorder directly. It only consumes `live-meter-state.bin` through `KeyboardIPCManager` and `AudioIndicatorDriver`.

### Stop-Time Processing

When recording stops:

1. raw frames are collected
2. internal gaps are removed
3. silence classification runs
4. true silence and likely silence clear `outputFrames`
5. accepted captures become `StoppedCapture.outputFrames`

Interrupted captures follow the same post-stop processing rules before they are staged for recovery.

## Interrupted Capture Recovery

Interrupted capture recovery is now a first-class iOS runtime feature.

`TranscriptionManager+InterruptedCaptureRecovery` owns:

- staging accepted interrupted captures
- persisting recovery payloads
- resuming recovery on app activation
- marking failed recovery attempts

Rules:

- only captures with non-empty `outputFrames` are staged
- recovery requires model readiness
- recovery runs through the shared `DictationPipeline`
- successful recovery updates `latestTranscription`
- failed recovery stays visible to the app instead of being silently discarded

## Model Installation, Background Downloads, and Recovery

`ModelManager` is the source of truth for install lifecycle.

The current iOS app treats models as rooted installs keyed by `DictationModelID`:

- `.whisperBase` installs into `Models/whisper`
- `.parakeetTdtV3` installs into `Models/parakeet`

The active provider is persisted locally through `AppSettingsStore.ActiveDictationProvider`.
It is intentionally app-local and is not synchronized through iCloud.

### Install Flow

1. resolve App Group install and staging paths for the target `DictationModelID`
2. ensure directories and free space are available
3. start or resume the persisted background download job for that model’s artifact set
4. validate staged artifacts against the descriptor’s expected hashes
5. move staged downloads into the rooted final install location
6. run model-specific post-install work
7. write `install-manifest.json`
8. revalidate the final rooted install
9. warm or preload the installed model before reporting it ready

Current model-specific post-install work:

- Whisper extracts `ggml-base-encoder.mlmodelc.zip`, removes the zip, and warms `WhisperService`
- Parakeet preloads the installed Core ML directory set through `ParakeetService`

### Readiness Contract

An install is only `ready` when all of the following are true:

- the rooted install directory for that `DictationModelID` exists
- `install-manifest.json` exists and uses a supported manifest version
- manifest hashes match the expected descriptor artifact versions
- all retained installed artifacts for that model exist

Additional Whisper-specific readiness requirements:

- `ggml-base.bin` exists
- the GGML file meets the minimum size threshold
- `ggml-base-encoder.mlmodelc/` exists and is structurally non-empty
- `ggml-base-encoder.mlmodelc.zip` has been removed

Additional Parakeet-specific readiness requirements:

- the manifest-backed rooted Core ML artifact set is present under `Models/parakeet`

Partial installs are never treated as ready.

## Copied Text Playback and PocketTTS Contract

The copied-text playback stack is app-owned even when initiated from the keyboard.

The local synthesis runtime itself lives in the separate `Packages/KeyVoxTTS` package.
That package owns:

- the PocketTTS runtime actor
- runtime asset loading
- compute-mode ownership
- text normalization
- sentence and chunk planning
- SentencePiece tokenizer parsing and tokenization
- Core ML inference helpers
- streamed `KeyVoxTTSAudioFrame` emission

Primary owners:

- `PocketTTSModelManager` owns shared PocketTTS Core ML runtime install state plus per-voice install state.
- `PocketTTSModelCatalog` owns shared-runtime artifact metadata plus approximate per-voice download size metadata used by settings.
- `PocketTTSEngine` owns PocketTTS runtime access, app-side runtime injection, explicit preparation/unload, prepared-runtime compute-mode guards, debug load/unload visibility, and streaming synthesis.
- `TTSPurchaseController` owns the one-time copied-text playback unlock, cached entitlement state, the two-free-speaks-per-day local usage policy, and the placeholder unlock-sheet presentation state.
- `TTSPlaybackCoordinator` owns audio-engine playback, deterministic runway gating, background-safe continuation, replayable-audio capture, replay seeking, and pause/resume.
- `AudioBluetoothRoutePolicy` owns the preserved-TTS Bluetooth route-family decision and is the only owner allowed to translate the built-in microphone preference into A2DP-vs-HFP playback behavior.
- `TTSManager` owns request lifecycle, playback-preparation progress, home-card replay state, replay cache persistence, paused replay restoration, system playback coordination / metadata assembly, remote transport command routing, App Group TTS state publishing, and the free-speak consumption point once a new generation has actually started.
- `TTSManager` is responsible for unloading the PocketTTS runtime once live generation is no longer needed: after generated playback becomes replayable, after explicit stop, or after playback error.
- `TTSSystemPlaybackController` owns MediaPlayer API integration and publication of transport & now-playing metadata for lock screen and Control Center transport.
- `AudioModeCoordinator` is the only owner allowed to arbitrate dictation-versus-TTS transitions and to enforce the copied-text playback gate before new TTS starts.
- the keyboard playback transport is intentionally split:
  - center logo toggles pause/resume for active playback
  - cancel and speak stop active playback completely
  - shared playback transport state is carried through `ttsState`, `ttsIsPaused`, and `ttsPlaybackProgress`
  - the keyboard logo ring reads shared playback progress and overlays an indigo transport arc on top of the yellow ring
  - dictation indicator animation remains separate from copied-text playback transport state
- the trademark-protected keyboard logo implementation must stay visual-only:
  - proprietary drawing, layout, and animation stay in `KeyboardLogoBarView.swift`
  - state application, transport/accessibility mapping, and other non-visual behavior must live in `KeyVox Keyboard/Core/Transport/KeyboardTransportDisplayState.swift`, not under `Views/`

### PocketTTS Install Rules

- PocketTTS is split into one shared `PocketTTS CoreML` runtime install plus independently downloaded voice prompt installs.
- deleting the shared PocketTTS runtime removes the entire PocketTTS install root, including any downloaded voices
- the selected playback voice is persisted in `AppSettingsStore`
- the settings UI may surface approximate voice download sizes, but install validation still depends on the manifest-backed artifact set
- bundled voice preview clips are app resources and are intentionally separate from downloadable PocketTTS voice assets
- the downloaded PocketTTS runtime artifacts and voice prompts are not bundled in the repository and remain third-party licensed model assets

### Runtime Structure Rules

- `PocketTTSModelManager` is split by concern into `PocketTTSModelManager.swift`, `PocketTTSModelManager+InstallLifecycle.swift`, and `PocketTTSModelManager+Support.swift`
- `PocketTTSEngine` owns the app-side runtime wrapper seam around `KeyVoxPocketTTSRuntime` so tests can verify runtime creation, preparation, compute-mode requests, and unload behavior without instantiating real Core ML assets.
- `TTSManager` is split by concern into `TTSManager.swift`, `TTSManager+Playback.swift`, `TTSManager+State.swift`, `TTSManager+SystemPlayback.swift`, `TTSManager+AppLifecycle.swift`, and `TTSManagerPolicy.swift`
  - `TTSManager+SystemPlayback.swift` should stay as the TTSManager-facing adapter layer that translates internal playback state and events into system playback intent, assembles metadata, and decides when the system surface should update.
- `TTSPlaybackCoordinator` is split by concern into `TTSPlaybackCoordinator.swift`, `TTSPlaybackCoordinator+Lifecycle.swift`, `TTSPlaybackCoordinator+Scheduling.swift`, `TTSPlaybackCoordinator+Progress.swift`, and `TTSPlaybackCoordinatorBufferingPolicy.swift`
- `AudioBluetoothRoutePolicy.swift` stays separate from both recorder input preference resolution and TTS playback lifecycle code so Bluetooth route-family mapping remains isolated and testable.
- `TTSSystemPlaybackController.swift` is the concrete platform integration layer that performs `MediaPlayer` API calls, remote command configuration, and transport / now-playing metadata publication.
- system playback coordination and metadata assembly belong in `TTSManager` / `TTSPlaybackCoordinator`; platform-specific side effects belong in `TTSSystemPlaybackController.swift`, not in view code or app lifecycle routing
- `KeyVoxPocketTTSRuntime` is split by concern into runtime orchestration, asset loading, compute-mode control, and stream generation files under `Packages/KeyVoxTTS/Sources/KeyVoxTTS/KeyVoxPocketTTSRuntime/`
- text cleanup policy for copied-text playback belongs in `PocketTTSTextNormalizer.swift`, not back inside chunk-planning logic

### PocketTTS Runtime Lifetime Rules

- PocketTTS runtime preparation is demand-driven by playback, not proactively warmed by `AppServiceRegistry`.
- `PocketTTSEngine.prepareIfNeeded()` creates and prepares the runtime for installed assets, then marks the runtime prepared.
- `PocketTTSEngine.unloadIfNeeded()` releases the runtime, clears the prepared flag, and clears loaded asset identity so the next generation rebuilds from the current installed assets.
- Foreground/background compute-mode changes may only run against an existing prepared runtime.
- Immediate compute-mode request helpers are hints for already prepared runtimes; they must not instantiate or prepare the runtime by themselves.
- Runtime unload must happen when the current generation is no longer needed, while replayable rendered audio stays available through the replay cache and playback coordinator.

### Fast Mode and Normal Mode Rules

- `AppSettingsStore.fastPlaybackModeEnabled` is the only persisted user-facing mode switch for copied-text playback startup behavior
- normal mode is background safe immediately once playback begins
- fast mode is allowed to begin earlier but must use deterministic buffering and deterministic background-safety calculation rather than reactive guessing
- replay is treated as a separate transport state and should not reuse live-stream background-safety badge meaning
- live transport status should surface blue for background-safe playback and green once the current request has finalized into replay-ready audio
- replay-ready persistence happens when stream generation completes, not only when audible playback has fully drained

### Playback Rules

- copied-text playback requests are serialized through `KeyVoxTTSRequest`
- the official iOS `Speak Copied Text` App Shortcut stages the existing `keyvoxios://tts/start` route in shared app-group state and still routes through the containing app as the single playback owner
- keyboard-initiated playback stages the request in shared storage and uses the containing app as the synthesis owner
- share-extension initiated playback also stages the request in shared storage and uses the containing app as the synthesis owner
- phase-one monetization allows two free new copied-text playback generations per local calendar day before the one-time unlock is required
- `KEYVOX_BYPASS_TTS_FREE_SPEAK_LIMIT` bypasses that daily-generation gate for development and testing only
- replay remains free for already generated playback and must not consume daily free uses
- only new copied-text playback generations are gated; replay, pause, resume, scrubbing, replay restore, and transcript viewing remain outside the monetization gate
- playback-preparation progress is deterministic and gates the return-to-host path before audio starts
- Home preparation UI keeps the stop button in a native loading-spinner state until preparation progress crosses the visible-progress threshold, then fades in the progress slot.
- the success haptic for playback preparation completion must fire before the intentional pre-playback delay begins
- the last completed rendered playback is cached independently of the clipboard and may be replayed later from the Home tab
- paused replay state, including sample offset, is durable across app relaunches
- replay transport uses a dedicated scrubber while cached replay is active
- lock screen and Control Center transport must stay enabled for active replay playback through public `MediaPlayer` APIs only
- live stream transport in system playback controls is play/pause only; replay transport may expose elapsed time, duration, and scrubbing
- a paused replay scrub must restamp paused replay state without rebuilding a live autoplaying transport
- `TTSManager` consumes a free daily speak only after the new PocketTTS generation has successfully begun, not on button tap alone
- no free speak is consumed while the TTS free-speak bypass runtime flag is enabled
- `AudioModeCoordinator` must remain the transition owner for:
  - start dictation
  - start copied-text playback
  - pause/resume/replay playback
  - stop playback

### Warm Dictation and TTS Interaction

- when dictation is already warm, TTS may use a recording-preserving playback audio-session mode
- the post-TTS handoff keeps recent-TTS state in shared IPC so the keyboard can choose the right warm-start grace period
- Bluetooth-aware warm-start behavior is keyboard-facing policy only; the containing app still owns actual recorder and TTS session transitions

### Home Routing Rules for TTS

- TTS starts coming from the keyboard or URL routes must move the containing app back to the Home tab before the copied-text playback UI becomes active
- `AppTabRouter` is the shared tab-selection source of truth for that behavior
- the same coordinator path must enforce the copied-text playback gate for Home, keyboard, URL, App Shortcut, and share-driven TTS starts so shortcuts cannot bypass the daily limit

### Background Download Rules

`ModelBackgroundDownloadCoordinator` owns the background `URLSession`.

Rules:

- each model download is tracked inside a single persisted background job that carries its `modelID`
- rediscovered background tasks are resumed on relaunch, not just relabeled
- missing tasks are demoted back to `.pending` so the manager can restart them
- finalization remains foreground-owned even when downloads finished in the background
- app activation must attempt interrupted-download recovery on the first relaunch after a kill
- only one model download/install may be active at a time on iOS

Important force-quit nuance:

- iOS will not transparently continue a user-force-quit app's background transfer work
- the correct behavior is to restart or resume the persisted job on relaunch
- this is why `ModelManager.handleAppDidBecomeActive()` and `ModelBackgroundDownloadCoordinator.synchronizeWithSystemTasks()` exist

### Failure Policy

- user-facing model errors collapse to actionable install/repair messages
- failed installs schedule a background repair task
- `deleteModel(withID:)` unloads the targeted lifecycle owner before artifact deletion
- delete must cancel any active background job for the same model before clearing persisted job state and removing rooted install directories
- `repairModelIfNeeded(for:)` clears partial state and performs a clean reinstall when validation is not ready, but must not interrupt another model’s active download/install

## Dictionary, Style, and Sync Contract

The containing app owns live dictionary and style state, while the dictation pipeline remains shared.

### Dictionary Rules

- `DictionaryStore` is created with the App Group-backed base directory
- `TranscriptionManager` observes dictionary entries and refreshes the post-processor plus the currently selected provider’s hint prompt
- hint prompts are bounded to the newest entries, up to `200` phrases and `1200` characters

### Style Rules

- `autoParagraphsEnabled` and `listFormattingEnabled` are app-owned toggles
- `StyleTabView` is the current user-facing surface
- the runtime injects those values into the shared `DictationPipeline` at transcription time

### iCloud Sync Rules

`CloudSyncCoordinator` syncs:

- dictionary payloads
- trigger binding timestamps
- auto paragraphs timestamps
- list formatting timestamps

`WeeklyWordStatsCloudSync` syncs only the current-week usage snapshot.

Weekly word stats merge by taking the maximum count seen for each device ID within the same week.

Excluded from iCloud sync:

- Caps Lock latch
- keyboard haptics
- microphone preference
- onboarding state
- pending keyboard-tour handoff

## Share Extension Extraction Contract

The share extension is allowed to do best-effort extraction work before launching the containing app.

Current extraction order is:

1. selectable PDF extraction with rendered-page OCR fallback
2. web extraction for shared URL and HTML style payloads
3. directly shared text
4. OCR extraction for shared images

Rules:

- extraction should stop at the first non-empty useful result
- `KeyVoxShareOCRRenderingPolicy` owns OCR render width and tile geometry shared by image OCR and PDF page OCR; PDF fallback must render tiles through that policy instead of allocating whole-page bitmaps or inventing separate caps
- the share extension writes the shared `KeyVoxTTSRequest` payload through `KeyVoxShareBridge`
- the canonical playback-voice catalog for both the app and share extension lives in `KeyVoxPlaybackVoice`; the share extension must not depend on `AppSettingsStore`
- the share extension must not initialize the PocketTTS runtime or own playback state
- all actual playback still belongs to the containing app after `keyvoxios://tts/start`

## Live Activity Contract

The app owns Live Activity state; the widget renders it.

### App-Side Rules

`KeyVoxSessionLiveActivityCoordinator` mirrors:

- `isSessionActive`
- `sessionDisablePending`
- `liveActivitiesEnabled`
- combined weekly word count

The Live Activity should be shown only when:

- session is active
- session disable is not pending
- the user setting `liveActivitiesEnabled` is `true`

Turning the toggle off must end any active Live Activity immediately.

### Widget-Side Rules

`KeyVox_WidgetLiveActivity` owns:

- lock screen presentation
- Dynamic Island presentation
- stop button rendering

The widget stop action must use the shared `disableSession` Darwin notification through `EndSessionIntent`.

The widget is presentation-only:

- no session policy
- no state mutation beyond the stop action
- no app-owned business logic

## Keyboard Extension Contract

The extension is a transport and insertion surface, not the transcription owner.

`KeyboardViewController` should own only:

- UI event handling
- presentation lifecycle coordination
- toolbar mode switching
- call-state observation for warning presentation
- full-access instructions presentation
- keyboard state transitions
- warm/cold app handoff
- keyboard-owned copied-text speak/replay transport presentation
- cancel flow
- host-text insertion
- cursor movement and key-repeat interactions

### Keyboard Presentation Lifecycle Rules

The keyboard presentation tree is intentionally disposable.

Rules:

- `KeyboardViewController` may be preloaded before the keyboard is actually shown, so it must **not** build the presentation tree in `viewDidLoad`
- the keyboard presentation tree is created only on the appearance path
- teardown must run on real keyboard dismissal and presentation-swap boundaries while the extension host is active, including `viewWillDisappear`
- extension-host resign-active notifications must pause the active presentation without destroying the current tree so host app background/foreground does not blank the keyboard
- `deinit` is not a safe ownership boundary for keyboard cleanup
- teardown must remove the presentation tree, popup overlay, full-access overlay, IPC observers, and indicator callbacks
- host lifecycle observers are controller-scoped and remain installed until controller teardown
- rebuild must preserve the same visuals, toolbar behavior, warning precedence, haptics, and insertion rules as a fresh keyboard presentation

Implementation split:

- `KeyboardViewController.swift` owns the controller-facing event and state surface
- `KeyboardViewController+PresentationLifecycle.swift` owns presentation-tree creation, binding, teardown, and host-lifecycle observation
- `KeyboardViewController+Debug.swift` owns debug-only lifecycle counters and testing hooks
- `KeyboardTTSController.swift` owns keyboard-side copied-text speak transport state and the App Group request/start-stop coordination surface
- keyboard `Core` is grouped by domain:
  - `Dictation/` owns recording-state handoff, live indicator driving, and call gating
  - `Feedback/` owns extension-local haptics configuration and dispatch
  - `Input/` owns text insertion, special-key interaction, and cursor trackpad behavior
  - `Text/` owns casing and spacing heuristics for inserted text
  - `Transport/` owns shared playback IPC plus non-visual keyboard transport state
  - cross-cutting layout, style, typography, and high-level keyboard state primitives stay at the `Core/` root
- `KeyboardLayoutGeometry.swift` belongs in `Core/`, not `Views/`, because it is shared layout math rather than a renderable view

### Toolbar and Layout Rules

Toolbar modes are:

- hidden
- branded
- full-access warning
- microphone warning
- phone-call warning
- update-required warning

The keyboard root layout has an important invariant:

- the stable non-flashing keyboard structure lives in the main keyboard stack
- the warning UI is layered as an overlay on top of the toolbar row
- the warning must **not** be moved into the root arranged-subview layout path again

That separation exists because putting the warning UI into the main root layout reintroduced the keyboard launch flash.

### Symbol Keyboard Layout Rules

Keyboard-specific row geometry must stay separated by responsibility:

- `KeyboardRootView` owns the stable keyboard shell, toolbar stacking, and the top-row accessory button containers
- `KeyboardKeyGridView` owns row creation and key interaction wiring
- `KeyboardLayoutGeometry` owns live measurement-based row sizing and accessory alignment rules

Do not push special-case row width math back into `KeyboardSymbolLayout` when the requirement depends on the rendered keyboard width.

Current symbol layout rules:

- rows 1 and 2 stay equal-width
- row 3 side keys use a 1.5-key span
- row 3 middle keys evenly divide the remaining width
- row 4 side keys use a 2.5-key span
- the space bar consumes the remaining row-4 width
- top-row cancel and caps lock alignment is derived from the live `1` and `0` key geometry instead of guessed offsets

The important implementation detail is that these widths are measured from the live top-row grid, so portrait and landscape can share the same ratios without mixing keyboard shell concerns into the symbol model layer.

### Warning Toolbar Rules

The branded toolbar requires:

- installed model
- `hasFullAccess == true`
- microphone permission granted
- no active phone call reported by `KeyboardCallObserver`

When the model is installed but Full Access is missing:

- keep the key grid visible
- hide the branded toolbar controls
- show the red warning toolbar
- allow the user to open the full-screen `FullAccessView`

When the model is installed and Full Access is granted but microphone permission is missing:

- keep the key grid visible
- hide the branded toolbar controls
- show the red warning toolbar with the microphone message
- do not show the Full Access instructional button

When the model is installed, Full Access is granted, microphone permission is granted, and an active phone call is reported:

- keep the key grid visible
- hide the branded toolbar controls
- show the red warning toolbar with `Use KeyVox after this call.`
- do not launch any separate instructional surface

Warning precedence must remain:

1. model unavailable -> hidden toolbar
2. Full Access missing -> full-access warning
3. microphone permission missing -> microphone warning
4. active phone call -> phone-call warning
5. otherwise -> branded toolbar

`FullAccessView` is keyboard-only instructional UI. It does not route through onboarding state or the containing app.

### Text Insertion Rules

`KeyboardInsertionSpacingHeuristics` stays intentionally conservative:

- do not prepend a space after existing whitespace
- do not prepend a space before incoming punctuation
- do prepend a space after word-like or trigger-punctuation contexts when needed

`KeyboardInsertionCapitalizationHeuristics` stays keyboard-only and does not replace the shared all-caps override owned by the pipeline.

### Keyboard-Owned Local State

The keyboard extension locally owns:

- Caps Lock latch
- haptics preference
- dictionary casing preservation helpers
- interaction-haptics execution

These remain extension-facing conveniences, not app-owned business logic.

## App UI Contract

The containing app is intentionally thin, but it is no longer a minimal debug shell.

Current app-owned surfaces:

- `HomeTabView`: filesystem-grouped Home feature with `HomeTabView.swift` for the main Home composition and a dedicated `HomeTabView/TTS/` split for copied-text playback layout, transport presentation, transcript behavior, and replay scrubber UI
- Home copied-text playback UI stages status/warning rows, spinner-to-progress handoff, transcript expansion/collapse, and preparation progress so content does not snap, drift, or bleed through card animations.
- Scrollable Home text surfaces that need a tinted indicator should use the shared `AppTintedScrollView`, `AppScrollMetrics`, and `AppTintedScrollIndicator` components under `Views/Components/App/`. These components keep SwiftUI's native scroll indicator hidden and derive thumb progress from `ScrollGeometry.visibleRect` rather than raw offset guesses so the thumb reaches the scroll box endpoints deterministically.
- `CopyFeedbackController`: shared app-scoped interaction helper for pasteboard writes, success haptics, copied-state timing, and reset behavior used by multiple UI surfaces without forcing a shared button component
- `PlaybackVoicePickerMenu`: reusable installed-voice menu surface shared between the release-facing Settings Voice Model section and the hidden Home copied-text playback shortcut
- `InlineWarningRules`: pure shared visibility rules under `App/Presentation/` for Wi-Fi caution rows across onboarding, KeyVox Speak setup, Home copied-text playback, and Settings install flows
- `KeyVoxSpeakIntroController`: post-onboarding feature-introduction owner that waits until onboarding is complete, delays presentation until a later eligible app open, and suppresses the intro after real KeyVox Speak usage
- `TTSPreviewPlayer`: shared bundled-preview playback owner used by both Settings voice previews and the KeyVox Speak intro demo clip
- `KeyVoxSpeak` presentation surface: shared intro-and-unlock sheet content under `Views/KeyVoxSpeak/`, including the shared sheet shell, scene A/B/C files, the extracted `KeyVoxSpeakInstallCardView`, the post-onboarding intro wrapper, and the unlock wrapper; the pure `KeyVoxSpeakFlowRules` resolver now lives under `App/Presentation/` so scene selection and fallback behavior stay separate from component rendering
- `ThirdPartyNoticesView`: shared legal-notices sheet that renders the bundled repo-root `THIRD_PARTY_NOTICES.md` markdown with app-owned styling and explicit close-only dismissal
- `DictionaryTabView`: dictionary browsing/editing
- `StyleTabView`: dictation style toggles
- `SettingsTabView`: top-level settings composition, shared disclosure state, third-party notices presentation, and cross-section coordination
- `SettingsTabView+General`: session timeout, Live Activities, keyboard haptics, and audio preference sections extracted from the settings root view
- `SettingsTabView+Models`: release-facing `Dictation Model` section for provider selection plus per-model install actions and uninstalled model size display
- `SettingsTabView+TTS`: release-facing `KeyVox Speak` section for PocketTTS runtime install state, per-voice install actions, previews, voice selection, and the `KeyVox Speak Unlimited` unlock row placed beneath the model section
- `SettingsTabView+About`: rate-and-review, GitHub support, restore-purchases, version footer, and third-party notices launcher extracted from the settings root view
- `PlaybackPreparationView`: keyboard cold-launch playback-preparation surface shown before returning to the host app
- `ReturnToHostView`: one-time host-return guidance after a cold keyboard launch, with a top-right dismiss affordance that returns the app to Home while preserving the containing app as the route/session owner
- onboarding screens: welcome, setup, keyboard tour

`AppHaptics` is the app-owned feedback bridge for these surfaces, while `AppHapticsDecisions` keeps the trigger rules deterministic and testable.

Views may surface manager state, but runtime ownership stays in the managers and services.

## Testing and Quality Gates

- Do not treat the absence of an iOS simulator run as proof that a runtime contract changed safely.
- Prefer deterministic store/manager/probe tests for app-owned state and manual device validation for cross-process behavior.

### iOS-Focused Test Coverage

- onboarding store persistence and routing state
- onboarding keyboard access probe behavior
- onboarding keyboard-tour state transitions
- onboarding microphone permission refresh behavior
- onboarding setup-state gating
- app haptics decision rules
- shared path construction
- settings persistence
- iCloud sync coordination
- weekly stats storage and merge behavior
- Live Activity coordination
- model manager validation and repair behavior
- PocketTTS engine runtime preparation, unload, and prepared-runtime compute-mode behavior
- TTS manager engine-unload behavior on replayable completion, explicit stop, and playback error
- stop-time capture processing
- keyboard dictation controller behavior
- keyboard interaction haptics
- keyboard controller presentation teardown and rebuild behavior
- keyboard text input helpers
- keyboard cursor-trackpad support
- transcription manager lifecycle and interruption handling

### Integration-Only Exclusions

- actual microphone hardware routing and Bluetooth behavior
- real host-app text insertion across third-party apps
- keyboard-extension wake timing under device memory pressure
- exact process relaunch timing between extension and containing app
- App Store review behavior around extension-to-app launch UX
- widget rendering differences across iOS releases

Those remain device, integration, or manual-test territory by design.

## Contributor Notes

- Keep the app-extension contract centralized in `KeyVoxIPCBridge`; do not hand-roll duplicate keys, timestamps, or notification names elsewhere.
- Keep onboarding state separate from app settings and keyboard runtime state.
- Keep session rules explicit. If idle timeout, watchdog thresholds, or warm-session behavior change, update this document and the keyboard assumptions together.
- Keep model integrity checks strict. Accepting partial installs creates hard-to-debug runtime failures.
- Prefer injectable seams for time, storage, downloads, permissions, and services, following the existing onboarding, model, and transcription manager patterns.
- When `KeyVoxCore` behavior changes, update this document only if the iOS runtime contract or target boundaries change as well.

## Change Tracking

- `ENGINEERING.md` tracks stable iOS architecture, onboarding rules, IPC contracts, lifecycle rules, and operational/testing policy.
- `CODEMAP.md` tracks file ownership and major system placement.
- These two docs are the maintained iOS source of truth in this repo today.
