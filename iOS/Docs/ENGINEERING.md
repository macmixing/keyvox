# KeyVox iOS Engineering Notes

This document captures the current implementation rules and maintainer-facing architecture for the iOS app, keyboard extension, and widget extension.

**Last Updated: 2026-03-30**

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
Convenience matters, but not more than predictable behavior.

## Target Boundaries

### Containing App

The containing app owns:

- onboarding state and routing
- settings and iCloud sync
- model installation, validation, and recovery
- microphone capture and session warmth
- interrupted-capture recovery
- dictation pipeline ownership
- weekly word stats
- Live Activity coordination
- the SwiftUI app shell

### Keyboard Extension

The keyboard extension owns:

- visible keyboard UI
- toolbar mode selection and warning presentation
- warm/cold launch handoff into the containing app
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

## Platform and Target Requirements

- Supported deployment target: iOS 18.6 and newer for the app, keyboard, widget, and tests.
- The containing app declares:
  - `UIBackgroundModes = ["audio"]`
  - `BGTaskSchedulerPermittedIdentifiers = ["com.cueit.keyvox.model-download"]`
  - URL scheme `keyvoxios`
- The keyboard extension declares:
  - `NSExtensionPointIdentifier = com.apple.keyboard-service`
  - `RequestsOpenAccess = true`
- Both the app and keyboard extension require the App Group entitlement:
  - `group.com.cueit.keyvox`
- The widget target also depends on the shared code/project wiring needed for ActivityKit and the shared App Group-backed session state.

## Composition Root

`AppServiceRegistry` is the only sanctioned composition root for the containing app.

It builds and wires:

- `DictionaryStore`
- `AppSettingsStore`
- `OnboardingStore`
- `WeeklyWordStatsStore`
- `WhisperService`
- `ParakeetService`
- `SwitchableDictationProvider`
- `TranscriptionPostProcessor`
- `ModelManager`
- `KeyVoxKeyboardBridge`
- `TranscriptionManager`
- `CloudSyncCoordinator`
- `WeeklyWordStatsCloudSync`
- `KeyVoxSessionLiveActivityCoordinator`
- `KeyVoxURLRouter`

Service ownership rules:

- Managers own runtime state.
- Views present state and call actions, but do not become alternate sources of truth.
- IPC contracts remain centralized in `KeyVoxIPCBridge`.

## Root Routing and Onboarding Contract

`AppRootView` is the top-level route owner.

Current root behavior:

- hold on a neutral background until the initial launch context is resolved
- show onboarding when `OnboardingStore.shouldShowOnboarding` is `true`
- otherwise show the main tab shell
- `ReturnToHostView` may appear only when onboarding is not being suppressed by the onboarding store for the current launch
- a cold `keyvoxios://record/start` launch may preselect `ReturnToHostView` before the first real SwiftUI route render

### Onboarding Store Rules

`OnboardingStore` owns:

- `hasCompletedOnboarding`
- `hasCompletedWelcomeScreen`
- `isForceOnboardingLaunch`
- `hasPendingKeyboardTour`
- `hasCompletedKeyboardTourThisLaunch`
- `hasPassedWelcomeScreenThisLaunch`
- `isPendingKeyboardTourRouteArmed`
- `isIgnoringPersistedPendingKeyboardTourThisLaunch`
- `hasCompletedOnboardingThisLaunch`

### Force-Onboarding Runtime Flag

The only supported runtime flag is:

- `KEYVOX_FORCE_ONBOARDING`

Accepted truthy values:

- `1`
- `true`
- `yes`

Behavior:

- a cold launch with the flag set must always begin at the welcome screen
- the flag must still allow in-launch progression through the flow
- persisted onboarding completion must not block the forced flow
- stale persisted keyboard-tour handoff state must not skip setup during a forced run

### Onboarding Screen Order

Current onboarding order is:

1. welcome
2. setup
3. keyboard tour
4. customize app

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

### Keyboard Tour Contract

The keyboard tour is a resumed onboarding step after the user leaves setup for Settings.

Rules:

- it is full-screen, not a sheet
- it autofocuses a text field so the KeyVox keyboard can appear immediately
- it uses `KeyboardObserver` height to pin the input above the keyboard
- it is driven by `OnboardingKeyboardTourState` scene progression (`a` -> `b` -> `c`)
- `Next` is disabled until the user has both shown the KeyVox keyboard and completed a first non-empty transcription while the tour is active
- stale old keyboard-ready state must not be enough to finish onboarding
- completing the keyboard tour clears the pending keyboard-tour handoff, but onboarding itself finishes on the following customize-app screen

### Customize-App Contract

The customize-app screen is the final onboarding step.

Rules:

- it appears only after the keyboard tour completes during the current launch
- its `Finish` action marks onboarding complete
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
- `keyboardOnboardingPresentation_timestamp`
- `keyboardOnboardingAccess_timestamp`
- `keyboardOnboardingHasFullAccess`

### App Group Settings Keys

- `KeyVox.TriggerBinding`
- `KeyVox.AutoParagraphsEnabled`
- `KeyVox.ListFormattingEnabled`
- `KeyVox.CapsLockEnabled`
- `KeyVox.KeyboardHapticsEnabled`
- `KeyVox.PreferBuiltInMicrophone`
- `KeyVox.LiveActivitiesEnabled`
- `KeyVox.SessionDisableTiming`

### App-Owned Persistent Defaults Keys

- `KeyVox.App.WeeklyWordStatsPayload`
- `KeyVox.App.WeeklyWordStatsInstallationID`
- `KeyVox.App.HasCompletedOnboarding`
- `KeyVox.App.HasCompletedOnboardingWelcome`
- `KeyVox.App.HasPendingKeyboardTour`
- `KeyVox.App.ActiveDictationProvider`

### App Group File Transport

- `live-meter-state.bin`
  - written atomically by the containing app
  - read by the keyboard extension only
  - ephemeral transport, not durable storage

### Darwin Notification Names

- `com.cueit.keyvox.startRecording`
- `com.cueit.keyvox.stopRecording`
- `com.cueit.keyvox.cancelRecording`
- `com.cueit.keyvox.disableSession`
- `com.cueit.keyvox.recordingStarted`
- `com.cueit.keyvox.transcribingStarted`
- `com.cueit.keyvox.transcriptionReady`
- `com.cueit.keyvox.noSpeech`

### Shared Recording States

- `idle`
- `waitingForApp`
- `recording`
- `transcribing`

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
- `Models/.staging/whisper-base/` during staged Whisper download only
- `Models/.staging/parakeet-tdt-v3/` during staged Parakeet download only
- `Models/model-download-job.json`
- `InterruptedCapture/pending-interrupted-capture.plist`
- `KeyVoxCore/` for dictionary persistence
- `live-meter-state.bin` for transient keyboard indicator transport

If the App Group container is unavailable:

- dictionary persistence falls back to `Application Support/KeyVoxFallback/`
- model installation does **not** fall back and must fail loudly

## Warm Session and App Launch Contract

Warmth is controlled by `session_timestamp`.

Rules:

- `KeyVoxIPCBridge.heartbeatFreshnessWindow` is `5` seconds
- the recorder or keyboard bridge refreshes the heartbeat while the app is active enough to be considered warm
- the extension treats the app as warm only when the heartbeat is newer than that window

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
- preferred sample rate: `16000`
- output format: mono float PCM, non-interleaved

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
- toolbar mode switching
- call-state observation for warning presentation
- full-access instructions presentation
- keyboard state transitions
- warm/cold app handoff
- cancel flow
- host-text insertion
- cursor movement and key-repeat interactions

### Toolbar and Layout Rules

Toolbar modes are:

- hidden
- branded
- full-access warning
- microphone warning
- phone-call warning

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

These remain extension-facing conveniences, not app-owned business logic.

## App UI Contract

The containing app is intentionally thin, but it is no longer a minimal debug shell.

Current app-owned surfaces:

- `HomeTabView`: weekly stats, last transcription, debug diagnostics
- `DictionaryTabView`: dictionary browsing/editing
- `StyleTabView`: dictation style toggles
- `SettingsTabView`: session timeout, Live Activities toggle, keyboard haptics, mic preference, and the release-facing `Active Model` section for provider selection plus per-model install actions
- `ReturnToHostView`: one-time host-return guidance after a cold keyboard launch
- onboarding screens: welcome, setup, keyboard tour, customize app

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
- shared path construction
- settings persistence
- iCloud sync coordination
- weekly stats storage and merge behavior
- Live Activity coordination
- model manager validation and repair behavior
- stop-time capture processing
- keyboard dictation controller behavior
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
- `Docs/KEYVOX_IOS.md` remains historical design context rather than the current source of truth.
