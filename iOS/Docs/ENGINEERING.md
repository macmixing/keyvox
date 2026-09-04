# KeyVox iOS Engineering Notes

This document captures the current implementation rules and maintainer-facing architecture for the iOS app, keyboard extension, and widget extension.

**Last Updated: 2026-09-04**

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
- Dictation Shortcut background coordination, installation, and guided setup presentation
- app-owned haptics
- settings and iCloud sync
- model installation, validation, and recovery
- dictation model update eligibility and update-prompt actions
- local Vibes model installation, validation, bundled adapter lookup, and inference
- KeyVox Vibes AI download/delete/repair surfaces in Settings and Vibes Scene C
- copied-text playback voice installation and validation
- microphone capture and session warmth
- interrupted-capture recovery
- dictation pipeline ownership
- KeyVox Vibes style rewrite coordination
- keyboard-originated Vibes rewrite IPC handling
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
- lightweight active-provider artifact inspection for missing-versus-repair warning state
- warm/cold launch handoff into the containing app
- keyboard-owned copied-text speak control and transport state
- text insertion into host apps
- Vibes selection/status UI
- latest-insertion Vibes revert/restyle transport through the containing app
- keyboard-only interaction helpers like trackpad mode, delete repeat, and haptics

The keyboard extension does **not** own:

- model lifecycle
- microphone permissions
- model downloads
- local Vibes model loading or inference
- KeyVox Vibes AI downloads, deletion, or repair
- dictionary logic
- transcription post-processing policy
- KeyVox Vibes style rewrite policy
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
- KeyVox Vibes runs through the local Vibes model and LoRA adapter path, so it is supported on the app's iOS 18.6+ deployment target.
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
- `DictationShortcutSetupIntroController`
- `WeeklyWordStatsStore`
- `AppTabRouter`
- `AppHaptics`
- `WhisperService`
- `ParakeetService`
- `SwitchableDictationProvider`
- `TranscriptionPostProcessor`
- `ModelManager`
- `LocalRewriteModelManager`
- `LocalRewriteInferenceService`
- `LocalStyleRewriteTextTransformer`
- `KeyVoxKeyboardBridge`
- `TranscriptionManager`
- `ShortcutDictationCoordinator`
- `StyleRewritePipelineCoordinator`
- `StyleRewriteLatestArtifactStore`
- `TTSPreviewPlayer`
- `PocketTTSEngine`
- `PocketTTSModelManager`
- `TTSPurchaseController`
- `KeyVoxSpeakIntroController`
- `KeyVoxVibesPurchaseController`
- `KeyVoxVibesIntroController`
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
- `AppServiceRegistry` wires KeyVox Vibes into `TranscriptionManager` through narrow callbacks for output transformation, latest-artifact recording, prewarm, and prewarm release. It also wires keyboard style rewrite IPC into the same app-owned local inference path. The app owns branded feature lifecycle and model runtime ownership; the packages own reusable transform and local inference mechanics.
- `AppServiceRegistry` wires PocketTTS services and normalizes voice selection, but it must not proactively prewarm the PocketTTS runtime; playback owns runtime load and unload.
- `AppServiceRegistry` applies `AppSettingsStore.whisperDictationLanguage` when creating `WhisperService` and keeps later device-local selection changes synchronized with the service.

### Containing App Source Layout

`KeyVox iOS/App/` is grouped by responsibility so the composition root stays readable:

- `Lifecycle/` owns the app entry point plus UIKit delegate bridges.
- `Composition/` owns `AppServiceRegistry` and shared rooted path helpers.
- `Routing/` owns cold-launch URL capture and route parsing/dispatch.
- `Integration/` owns App Group and keyboard-bridge contracts.
- `Feedback/` owns app-scoped haptics and copy-feedback interaction state.
- `LiveActivity/` owns the ActivityKit mirror layer.
- `KeyVoxSpeak/` owns the post-onboarding intro controller and copied-text playback purchase gate.
- `KeyVoxVibes/` owns the post-onboarding intro controller, shared local trial policy, trial time formatting, local trial state, and purchase gate for KeyVox Vibes.
- `Purchases/` owns shared StoreKit non-consumable plumbing used by app-owned purchase controllers.
- `Stats/` owns app-local weekly usage aggregation.
- `Onboarding/` owns full onboarding route state and prerequisites.
- `Shortcuts/` owns background dictation intent coordination, signed-workflow installation handoffs, system Settings opening, and one-time Dictation Shortcut introduction state.
- `iCloud/` and `AppUpdate/` remain isolated feature folders.

`KeyVox iOS/Core/` owns app runtime services that are not view or composition concerns:

- `Downloads/` owns the reusable foreground/background transfer mechanism: paired sessions, task identity, resume-data handoffs, lifecycle transition serialization, and raw transport callbacks. It must remain independent of any model family’s catalog, persisted job schema, install paths, retry policy, scheduling policy, or finalization.
- `ModelDownloader/` owns dictation model install, validation, recovery, and background download behavior.
- `LocalRewriteModel/` owns the Vibes rewrite base model catalog, foreground install state, manifest validation, SHA-256 checks, bundled adapter lookup, and installed-model invalidation.
- `StyleRewrite/` owns the app adapter from dictation output and keyboard IPC requests into the reusable style rewrite and local inference packages.
- `TTS/`, `Audio/`, and `Transcription/` remain isolated by runtime domain.

`Views/Components/ModelUpdatePrompt.swift` owns only the Parakeet artifact-update prompt presentation and its Download/Later callbacks. Model version policy, readiness, and install work remain with the model-management layer.

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
- the one-time existing-user Dictation Shortcut guide may appear only while the resolved root destination is truly `.main`, after previously completed onboarding, and never during the launch that just completed onboarding
- the post-onboarding `KeyVoxSpeakIntroSheetView` may appear only while the resolved root destination is truly `.main`, and must never interrupt onboarding, `ReturnToHostView`, or `PlaybackPreparationView`
- an unhandled Dictation Shortcut guide has automatic-presentation priority over KeyVox Vibes and KeyVox Speak; presenting or browsing the guide defers those lower-priority introductions to a later eligible launch
- app update prompts may appear only while the resolved root destination is truly `.main`, and must never interrupt launch hold, onboarding, `ReturnToHostView`, or `PlaybackPreparationView`

### Onboarding Store Rules

`OnboardingStore` owns:

- `hasCompletedOnboarding`
- `hasCompletedWelcomeScreen`
- `hasCompletedLanguageSelection`
- `onboardingDictationLanguage`
- `isForceOnboardingLaunch`
- `isForceDictationShortcutSetupLaunch`
- `hasPendingKeyboardTour`
- `hasPendingDictationShortcutSetup`
- `hasPassedWelcomeScreenThisLaunch`
- `hasPassedLanguageSelectionThisLaunch`
- `isPendingKeyboardTourRouteArmed`
- `isIgnoringPersistedPendingKeyboardTourThisLaunch`
- `hasCompletedOnboardingThisLaunch`

Rules:

- the onboarding language value is persisted separately from language-step completion so returning from setup restores the exact prior selection
- entering the guided Shortcut flow records a pending Shortcut setup route; continuing from Action Button Demo Handoff replaces it with the pending keyboard-tour handoff
- completing onboarding clears both pending routes and marks the Dictation Shortcut introduction handled so a new user is not shown the same guide again after onboarding
- forced Dictation Shortcut setup enters that route directly without replaying welcome or language selection

### Runtime Flags

The supported runtime flags are:

- `KEYVOX_FORCE_ONBOARDING`
- `KEYVOX_FORCE_DICTATION_SHORTCUT_SETUP`
- `KEYVOX_BYPASS_TTS_FREE_SPEAK_LIMIT`
- `KEYVOX_FORCE_KEYVOX_SPEAK_INTRO`
- `KEYVOX_FORCE_TTS_REGENERATION`
- `KEYVOX_BYPASS_VIBES_TRIAL`
- `KEYVOX_VIBES_TRIAL_DURATION_SECONDS`
- `KEYVOX_RESET_VIBES_TRIAL`
- `KEYVOX_FORCE_KEYVOX_VIBES_INTRO`
- `KEYVOX_USE_LOCAL_PROMOTION_MANIFEST`
- `KEYVOX_PROMOTION_PREVIEW_CAMPAIGN_ID`

### Force Onboarding Runtime Flag

Accepted truthy values:

- `1`
- `true`
- `yes`

Behavior:

- a cold launch with the flag set must always begin at the welcome screen
- the flag must still allow in-launch progression through the flow
- persisted onboarding completion must not block the forced flow
- stale persisted keyboard-tour handoff state must not skip setup during a forced run

### Dictation Shortcut Setup Runtime Flag

Accepted truthy values:

- `1`
- `true`
- `yes`

Behavior:

- `KEYVOX_FORCE_DICTATION_SHORTCUT_SETUP` launches directly into the guided eight-page Shortcut/Action Button flow
- it bypasses welcome and language selection for that launch without changing the user's stored language
- completing or returning from the forced guide clears the forced route through `OnboardingStore`

The promotion flags are debug presentation tools: `KEYVOX_USE_LOCAL_PROMOTION_MANIFEST` selects the bundled local manifest, while `KEYVOX_PROMOTION_PREVIEW_CAMPAIGN_ID` selects a non-empty campaign identifier. Production builds ignore both values.

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

### TTS Force-Regeneration Runtime Flag

Accepted truthy values:

- `1`
- `true`
- `yes`

Behavior:

- `KEYVOX_FORCE_TTS_REGENERATION` asks `TTSManager` to generate a fresh copied-text playback request even when the request text matches the replayable cached transcript
- the flag is for development and debugging only
- the flag must not change entitlement, free-speak consumption, replay-cache persistence, pause/resume, or playback ownership rules

### KeyVox Vibes Trial Bypass Runtime Flag

Accepted truthy values:

- `1`
- `true`
- `yes`

Behavior:

- `KEYVOX_BYPASS_VIBES_TRIAL` bypasses the Vibes trial/unlock gate in debug builds
- the flag allows the app and keyboard extension to use Vibes without starting the local 72-hour trial
- the flag must not change production monetization policy
- local rewrite model availability still gates whether model-backed Vibes can run

### KeyVox Vibes Trial Duration Runtime Flag

Behavior:

- `KEYVOX_VIBES_TRIAL_DURATION_SECONDS` overrides the local Vibes trial duration in debug builds
- the value is parsed as a positive number of seconds
- when the user starts a trial while the flag is active, the debug duration is persisted so restarts keep evaluating the same short test window
- production builds ignore the override and use the duration from `KeyVoxVibesTrialPolicy`

### KeyVox Vibes Trial Reset Runtime Flag

Behavior:

- `KEYVOX_RESET_VIBES_TRIAL` removes only `KeyVox.App.VibesTrialStartedAt.v2` and the debug Vibes trial duration override in debug builds
- the flag does not clear purchase state, intro state, selected Vibe, or other Vibes defaults
- production builds ignore the reset flag

### KeyVox Vibes Intro Runtime Flag

Accepted truthy values:

- `1`
- `true`
- `yes`

Behavior:

- `KEYVOX_FORCE_KEYVOX_VIBES_INTRO` forces the full A/B/C KeyVox Vibes intro flow for development and design work
- the flag does not start the trial or unlock Vibes
- the forced intro still uses the normal app-owned Vibes sheet surface

### Onboarding Screen Order

Current onboarding order is:

1. welcome
2. language selection
3. model and microphone setup
4. Dictation Shortcut and Action Button guide
5. keyboard enablement
6. keyboard tour

### Language Selection Contract

- onboarding lists the Whisper Base language catalog plus Auto Detect before model download
- the selected language is persisted through both `OnboardingStore.onboardingDictationLanguage` and `AppSettingsStore.whisperDictationLanguage`
- returning from setup must restore the prior selection and checkmark rather than defaulting or re-resolving it
- when search has focus, Continue dismisses the keyboard before advancing; the language screen remains visually unchanged while the setup screen moves over it
- the short advance lock prevents repeat input but must clear when `shouldShowLanguageSelectionScreen` becomes active again

### Setup Screen Contract

The setup screen owns two prerequisites:

- model ready
- microphone permission granted

Rules:

- the combined keyboard-and-Shortcut setup handoff stays gated until the model install state is `.ready` and microphone permission is granted
- microphone permission may be completed while the model download is still running
- model download may continue while the user works through the other visible steps
- tapping the onboarding model download action must present an explicit download confirmation with the Whisper Base model name and approximate size before `ModelManager` starts the download
- when microphone access is denied, onboarding must route the user to app settings rather than pretending the permission can still be requested in place
- Continue records a pending Dictation Shortcut setup route and advances into the guided Shortcut pages
- keyboard enablement is intentionally deferred until after the Shortcut/Action Button guide

### Dictation Shortcut and Action Button Setup Contract

The same eight-page content model is reused in three presentation modes:

- onboarding mode is controlled with Back, Skip, and a single bottom CTA; page swiping and page-indicator navigation are not enabled
- existing-user introduction mode is freely swipeable, retains the guided CTA sequence, exposes close before the final step, and uses Finish on Action Button Demo Handoff
- Settings reference mode is freely swipeable with close available throughout; only Add Shortcut exposes its installation action and Action Button Shortcut Selection exposes Open Settings

Shared rules:

- `DictationShortcutSetupPage` owns page order, accessibility descriptions, bundled video names, native media dimensions, and optional viewport width
- all eight bundled videos live under `Resources/DictationShortcutSetup/`; `ShortcutHero.mov` supplies the centered Dictate Anywhere brand animation, while the seven semantically named instructional assets cover Shortcut installation, Action Button setup, and both dictation demonstrations
- only the selected page may actively play; videos loop and restart through `LoopingVideoPlayer` when their page becomes active
- Add Shortcut invokes `DictationShortcutInstaller`; after the first request, the guided CTA becomes Next so returning from Shortcuts does not reopen installation automatically
- Open Settings invokes `DictationShortcutSettingsOpener`; after the first request, the guided CTA becomes Next so returning from Settings preserves progress
- onboarding Skip and Action Button Demo Handoff's Set Up Keyboard action both clear the pending Shortcut route and record the pending keyboard-tour handoff
- page indicator navigation moves only one page per action and exposes VoiceOver adjustable previous/next behavior

### Existing-User Introduction Contract

- `DictationShortcutSetupIntroController` presents the guide once to users who completed onboarding before the current launch and have not handled the guide
- automatic guide scheduling is suppressed during onboarding, return-to-host, playback preparation, update-prompt presentation, and competing feature sheets
- completing new-user onboarding marks the guide handled because those users already saw the same content in-flow
- opening the guide from Settings also marks the automatic introduction handled
- the Dictation Shortcut guide has automatic priority over KeyVox Vibes and KeyVox Speak introductions

### Keyboard Enablement Contract

- `OnboardingEnableKeyboardScreen` owns the explicit KeyVox keyboard and Allow Full Access instructions after the Shortcut guide
- the bundled `Resources/Onboarding/EnableKeyboard.mov` animation demonstrates the system-settings steps
- opening Settings clears stale keyboard-onboarding presentation state before leaving the app
- when the app becomes active, `OnboardingKeyboardAccessProbe` refreshes enablement and arms the pending keyboard-tour route once the KeyVox keyboard is enabled
- Back returns to Action Button Demo Handoff without discarding the pending setup journey

### Download Confirmation Contract

Any user-facing model or voice download must be confirmed before the manager starts work.

Rules:

- `DownloadConfirmation.swift` owns the shared confirmation styling and the per-resource title/message copy.
- Confirmation copy must stay specific to the requested resource: Whisper Base, Parakeet TDT v3, KeyVox Vibes AI, the shared Speak engine, an individual Speak voice, or the combined first-use Speak engine plus selected voice.
- Confirmations must disclose the pinned approximate download size for that resource path.
- Home and Settings must route download requests through the `MainTabView`-owned confirmation overlay so the overlay covers tab content, the navigation toolbar, and the tab bar.
- The KeyVox Speak and KeyVox Vibes sheets must own their own sheet-level confirmation overlays so scene content, the pinned bottom CTA section, and sheet chrome are covered while confirmation is active.
- Vibes Scene C and `KeyVoxSpeakInstallCardView` must request confirmation from their sheet instead of starting downloads directly.
- When the shared Speak engine is already ready, the KeyVox Speak install card must request the voice-only confirmation; it should request the combined engine-plus-voice confirmation only when the shared Speak engine is missing.
- Repair actions may continue to run through the existing repair paths; this confirmation contract is for user-started downloads.

### Keyboard Tour Contract

The keyboard tour resumes after the user returns from keyboard enablement in Settings.

Rules:

- it is full-screen, not a sheet
- it autofocuses a text field so the KeyVox keyboard can appear immediately
- it uses `KeyboardObserver` height to pin the input above the keyboard
- it is driven by `OnboardingKeyboardTourState` scene progression (`a` -> `b` -> `c`)
- scene A uses the bundled `Resources/Onboarding/KeyVoxKeyboardSelection.mov` animation; the removed keyboard-menu image sequence is not part of the current flow
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
- `KeyVox.LeftHandedKeyboardLayoutEnabled`
- `KeyVox.CompactKeysEnabled`
- `KeyVox.CompactKeysActive`
- `KeyVox.PreferBuiltInMicrophone`
- `KeyVox.LiveActivitiesEnabled`
- `KeyVox.SessionDisableTiming`
- `KeyVox.SpeakTimeoutTiming`
- `KeyVox.TTSVoice`
- `KeyVox.FastPlaybackModeEnabled`
- `KeyVox.SelectedVibe`

### App-Owned Persistent Defaults Keys

- `KeyVox.App.WeeklyWordStatsPayload`
- `KeyVox.App.WeeklyWordStatsInstallationID`
- `KeyVox.App.HasCompletedOnboarding`
- `KeyVox.App.HasCompletedOnboardingWelcome`
- `KeyVox.App.HasCompletedOnboardingLanguageSelection`
- `KeyVox.App.OnboardingDictationLanguage`
- `KeyVox.App.HasPendingKeyboardTour`
- `KeyVox.App.HasPendingDictationShortcutSetup`
- `KeyVox.App.HasSeenDictationShortcutSetup`
- `KeyVox.App.ActiveDictationProvider`
- `KeyVox.App.WhisperDictationLanguage`
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
- `KeyVox.App.ShouldShowKeyVoxSpeakIntroOnNextEligibleLaunch`
- `KeyVox.App.IsVibesUnlocked`
- `KeyVox.App.VibesTrialStartedAt.v2`
  - stores the versioned Vibes trial start date; bumping this key grants a fresh local trial without changing intro, interaction, unlock, model, or selected-Vibe state
- `KeyVox.Debug.VibesTrialDuration`
  - stores the debug Vibes trial duration used by the Vibes controller and is cleared when the debug trial is reset
- `KeyVox.App.HasSeenKeyVoxVibesIntro`
- `KeyVox.App.HasInteractedWithKeyVoxVibes`
- `KeyVox.App.ShouldShowKeyVoxVibesIntroOnNextEligibleLaunch`

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
- `com.cueit.keyvox.vibeSelectionChanged`
- `com.cueit.keyvox.listFormattingChanged`
- `com.cueit.keyvox.autoParagraphsChanged`

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

## Background Dictation Shortcut Contract

The Toggle Dictation App Shortcut is another controller for the existing shared dictation session. It does not own a recorder, transcription provider, or parallel session state.

The signed workflow can run from Shortcuts and can be assigned by the user to system surfaces such as the Action Button or Control Center. KeyVox owns the intent, workflow, installer, and guidance; iOS owns those system assignments.

### Intent and Coordination

- `ToggleKeyVoxDictationIntent` conforms to `AudioRecordingIntent` and `LiveActivityIntent`, uses `openAppWhenRun = false`, and supports background execution on system releases that expose background intent modes.
- `ShortcutDictationCoordinator` reads the state owned by `TranscriptionManager`: idle starts recording, recording stops it, and capture processing or transcription returns busy.
- Shortcut recording starts with `isFromURL = false`; it must not present the keyboard cold-launch `ReturnToHostView` flow.
- `TranscriptionStartCommandResult` and `TranscriptionStopCommandResult` are the typed boundary between the coordinator and transcription owner.
- Live Activity preparation must complete before background microphone startup. Disabled Live Activities or failed preparation prevent recording from starting, and failed recorder startup releases the pending activity state.

### Result Delivery

- Starting a recording returns no shortcut value.
- Stopping with no speech returns no shortcut value.
- A completed stop returns the final processed transcript.
- Busy and operational failures become App Intent errors rather than text output.
- The signed workflow checks whether the intent returned a value before running completion actions; completed text is copied to the clipboard, included in the notification, and followed by completion vibration.
- If the KeyVox keyboard is visible, it observes the same `transcribingStarted` and `transcriptionReady` IPC events and inserts the current result through the existing keyboard composition pipeline. Starting any new recording clears the previously published IPC transcript so reconciliation cannot insert an older result.

### Optional Immediate Microphone Release

`Release Mic Immediately` is an App Intent parameter and defaults to `false`.

- Off preserves normal warm-session behavior and lets the configured session timing decide when monitoring ends.
- On attempts to stop monitoring immediately after audio capture, while transcription continues from the captured frames.
- A failed first release attempt must never discard or replace the user's transcription.
- After transcription finishes, `TranscriptionManager` retries the immediate release once.
- If the retry also fails, the session stays active and the configured idle timeout is re-armed for later cleanup.

### Shared-State Reconciliation

- The keyboard may temporarily observe a cold heartbeat immediately after microphone release even though transcription is still active.
- A recording or transcribing state whose timestamp remains inside `heartbeatFreshnessWindow` must be preserved during that gap.
- A cold recording or transcribing state with an expired or missing timestamp is stale and must be cleared.
- The heartbeat write throttle resets when session activity is cleared so the next legitimate heartbeat can recreate shared warmth immediately.

### Installation Ownership

- `iOS/Shortcuts/Toggle KeyVox Dictation.wflow` is the editable workflow source.
- `KeyVox iOS/Resources/Shortcuts/Toggle KeyVox Dictation.shortcut` is the signed distributable bundled with the app.
- The Dictation Shortcut row in Settings opens the reusable eight-page reference guide rather than installing immediately.
- Add Shortcut is the app-owned installation entry point in onboarding, the existing-user introduction, and Settings reference modes.
- `DictationShortcutInstaller` opens the bundled shortcut directly where supported and otherwise presents the standard system share sheet, which exposes Shortcuts and Save to Files.
- Open Settings on Action Button Shortcut Selection uses `DictationShortcutSettingsOpener` to open system Settings while the guide explains the Action Button selection steps.
- Installation or Settings-opening failures remain guide presentation errors; they do not alter dictation session state.

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
- session timing may disable monitoring immediately, after the configured idle timeout, or never; changing from `Never` to a timed preset must re-arm an idle timeout when an active idle session is currently monitored/idle
- KeyVox Vibes warmth hooks are tied to an utterance lifecycle, not the whole session lifecycle; a user may keep monitoring alive indefinitely, so prewarm/release calls must stay utterance-scoped and must not become session-level model retention policy

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

### Whisper Voice-Activity Gate

Accepted recorder output still passes through a shared whole-capture VAD gate before Whisper decoding:

- `KeyVoxWhisper.WhisperVoiceActivityDetector` owns the actor-isolated whisper.cpp VAD context and loads the package-bundled `ggml-silero-v5.1.2.bin` model.
- `WhisperService+ModelLifecycle` creates the VAD detector during Whisper warmup and releases it when the Whisper model is unloaded.
- `WhisperService+TranscriptionCore` analyzes the full accepted capture before paragraph chunking.
- a capture with no detected speech completes as likely no-speech without entering the decoder
- when speech is detected, the complete original capture continues to chunking and decoding; VAD segments are classification evidence, not trimming boundaries
- if the bundled detector cannot be created or analysis fails, transcription continues through the existing decoder no-speech safeguards
- iOS targets must not copy the Silero resource or implement a second platform-local VAD policy

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

### Dictation Language Selection

- `DictationLanguage`, `DictationLanguageDisplayNameFormatter`, and `WhisperBaseLanguageCatalog` in `KeyVoxCore` are the shared source of truth for stable identifiers, localized display names, and the languages exposed for Whisper Base. Platform apps must not maintain duplicate language lists.
- `KeyVoxWhisper.WhisperLanguage` owns the iterable identifiers accepted by the pinned Whisper runtime. `WhisperBaseLanguageCatalog` derives the app-facing subset from that package metadata.
- `AppSettingsStore.whisperDictationLanguage` is a device-local UserDefaults preference. It defaults to Auto Detect, survives ordinary launches, and is intentionally excluded from iCloud sync so each device can use a different language.
- Missing or unsupported persisted identifiers resolve to Auto Detect. Settings controls must validate selections against `WhisperBaseLanguageCatalog` before persistence.
- `WhisperService` applies the configured language during model setup and again before each transcription request so an already-loaded model observes later setting changes.
- Parakeet TDT v3 remains automatic-detection-only. Its settings row stays visible, reports Auto Detect, provides FAQ guidance for supported languages, and does not offer a forced-language list.
- Switching providers does not discard the saved Whisper selection; returning to Whisper restores that device's previous choice.

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

### Update and Keyboard Repair Presentation

- `PendingModelUpdatePrompt` and the `modelUpdatePrompt` view modifier own presentation of the Parakeet artifact-update choice only; callers own whether an update is pending and route Download into `ModelManager`.
- `KeyboardDictationModelStatus` performs a lightweight App Group artifact check for the active provider so the extension can distinguish not installed from action required.
- the keyboard check is warning policy, not authoritative install validation: `ModelManager` remains the owner of manifest validation, downloads, deletion, and repair.

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
- `TTSManager` is responsible for applying the user-facing Speak Timeout setting to PocketTTS runtime lifetime once live generation is no longer needed: immediate unload for the `Immediately` preset, delayed unload after the selected warm-retention window, or indefinite retention for `Never` after playback has demand-warmed the runtime.
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
- Settings downloads the shared Speak engine by itself; the user chooses and downloads a voice separately.
- Home and the shared Speak setup surface request a combined first-use install, but this remains two ordered jobs: install the shared engine first, then start the queued selected voice.
- deleting the shared PocketTTS runtime removes the entire PocketTTS install root, including any downloaded voices
- the selected playback voice is persisted in `AppSettingsStore`
- the settings UI may surface approximate voice download sizes, but install validation still depends on the manifest-backed artifact set
- user-started PocketTTS downloads must pass through the shared download confirmation path with separate copy for the shared Speak engine, individual voices, and combined first-use engine-plus-voice setup
- bundled voice preview clips are app resources and are intentionally separate from downloadable PocketTTS voice assets
- the downloaded PocketTTS runtime artifacts and voice prompts are not bundled in the repository and remain third-party licensed model assets

### Runtime Structure Rules

- `PocketTTSModelManager` is split by concern into `PocketTTSModelManager.swift`, `PocketTTSModelManager+BackgroundLifecycle.swift`, `PocketTTSModelManager+InstallLifecycle.swift`, and `PocketTTSModelManager+Support.swift`.
- Speak background download ownership is split by concern:
  - `PocketTTSBackgroundDownloadCoordinator.swift` owns Speak job reconciliation and artifact preparation.
  - `PocketTTSBackgroundDownloadCoordinator+Transport.swift` adapts shared transport handoffs into Speak scheduling.
  - `PocketTTSBackgroundDownloadCoordinator+TransportDelegate.swift` handles transport events and claims completed temporary files into Speak staging.
  - `PocketTTSBackgroundDownloadCoordinator+DownloadState.swift` owns persisted artifact state changes.
  - `PocketTTSBackgroundDownloadCoordinator+Scheduling.swift` advances sequential foreground work.
  - `PocketTTSBackgroundDownloadCoordinator+RateLimit.swift` owns HTTP 429 retry timing and retry scheduling.
  - `PocketTTSBackgroundDownloadJob.swift` and `PocketTTSBackgroundDownloadJobStore.swift` own the durable Speak job and its atomic JSON persistence.
- `PocketTTSEngine` owns the app-side runtime wrapper seam around `KeyVoxPocketTTSRuntime` so tests can verify runtime creation, preparation, compute-mode requests, and unload behavior without instantiating real Core ML assets.
- `TTSManager` is split by concern into `TTSManager.swift`, `TTSManager+Playback.swift`, `TTSManager+State.swift`, `TTSManager+RuntimeUnload.swift`, `TTSManager+SystemPlayback.swift`, `TTSManager+AppLifecycle.swift`, and `TTSManagerPolicy.swift`
  - `TTSManager+RuntimeUnload.swift` owns Speak Timeout scheduling, cancellation on new playback, memory-warning unloads, asset-invalidation unloads, and debug unload-reason logging.
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
- Runtime unload after playback must follow `AppSettingsStore.speakTimeoutTiming`: `Immediately` unloads on replayable-audio readiness, explicit stop, finish, or error; timed presets keep the prepared runtime warm until the selected timeout expires; `Never` keeps the runtime warm indefinitely after playback has demand-warmed it.
- Changing Speak Timeout from `Never` to a timed preset must immediately replace indefinite retention with the selected timeout for an already warm, inactive runtime.
- Starting a new generated Speak request cancels any pending timed runtime unload and starts a new timeout window after that playback ends.
- Memory warnings and PocketTTS shared-model or voice asset invalidation must unload immediately regardless of the user-selected Speak Timeout.
- Warm-runtime UI indicators must represent only that the PocketTTS runtime has cleared the cold-load path; they must not imply first audio is ready, and `Never` must not show its indefinite-warm indicator until the runtime is actually warm.

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

Dictation, Speak, and Vibes have separate model-family coordinators. Each family uses the reusable `ResumableDownloadTransport` through its own coordinator while retaining its own catalog, persistence, staging, installation, retry, and public-state policies.

#### Reusable Handoff Transport

`ResumableDownloadTransport` is the shared mechanism for production-speed foreground downloads plus continued background transfer.

Rules:

- each model family receives its own transport instance and unique background-session identifier; tasks from one family must never cancel, replace, or reconcile against another family
- transport and underlying URL session creation must be serialized so one app process cannot create duplicate sessions for a family identifier
- task identity is the universal `jobID` plus `artifactID` descriptor stored in `URLSessionTask.taskDescription`
- the foreground session uses the default URLSession configuration so an active-app download follows the normal foreground network path
- the background session enables launch events, waits for connectivity, uses the App Group container, and remains non-discretionary when started while the app still has foreground execution time
- foreground-to-background handoff begins on `.inactive`, not after `.background`; waiting until `.background` can cause iOS to treat newly created background transfers as discretionary and leave them parked
- background-to-foreground handoff begins on `.active`
- handoff cancels source tasks with `cancel(byProducingResumeData:)`, gives those resume tokens to the owning family, and recreates work in the destination session without resetting persisted aggregate progress
- lifecycle changes that occur during a handoff are serialized; after the current transition finishes, the transport immediately follows the newest requested phase
- the owning family must synchronously move a completed URLSession temporary file into its own staging location during the completion callback
- the transport must not select install paths, define artifact order, interpret HTTP retry policy, mutate a family’s persisted job, or finalize an installation
- any configured download server used with resumable handoff must honor byte-range requests
- the abstraction supports simultaneous downloads across model families because each family has an independent instance and session namespace; it intentionally does not add multi-job support within one family
- the transport is reusable across independent download families without owning or coupling their model-specific behavior

#### Speak Download Policy

- `PocketTTSBackgroundDownloadJob` persists the target, dynamic artifact URLs, byte counts, per-artifact state, `retryNotBefore`, finalization state, and optional queued voice
- the active job is stored as `Models/tts/pockettts/background-download-job.json`; final engine and voice locations remain `Models/tts/pockettts/Model/` and `Models/tts/pockettts/Voices/<voice>/`
- foreground Speak transfer schedules one artifact at a time, matching the original foreground behavior and avoiding a burst of resolver requests
- background Speak transfer schedules the remaining persisted artifact set into the Speak background session so iOS can continue it while the app is suspended
- moving between sessions preserves the previously recorded byte count when URLSession briefly reports a smaller task-local value, preventing visible progress from dropping during handoff
- HTTP 429 responses persist their retry date from `Retry-After` or `RateLimit`; the coordinator recreates the retry task in the background session instead of failing the entire install immediately
- download completion is not installation completion: staged artifacts are finalized only while the app is active
- shared-engine finalization writes and validates the existing manifest at the existing model root; voice finalization writes and validates the selected voice root
- a Settings shared-engine request ends after engine finalization; a combined Home/setup request then starts its explicitly queued voice download
- there is no legacy foreground fallback path: active downloads use the foreground side of the reusable transport and inactive downloads use its background side

#### Vibes Download Policy

- `LocalRewriteBackgroundDownloadJob` persists the fixed Vibes artifact identity, remote URL, expected byte count, transfer progress, task identity, error, and finalization state
- the active job is stored as `Models/rewrite/background-download-job.json`
- the installed model remains `Models/rewrite/qwen2-5-0-5b-instruct/`, and incomplete work remains under `Models/rewrite/.staging/qwen2-5-0-5b-instruct/`
- Vibes owns a dedicated transport instance and background session named `com.cueit.keyvox.vibes-download.background-session`; it does not reuse or cancel Speak or Dictation tasks
- an active-app request uses the foreground session, `.inactive` begins the handoff to the Vibes background session, and `.active` hands an unfinished transfer back to the foreground session
- persisted completed bytes never decrease when a recreated URLSession task initially reports a smaller task-local byte count
- app activation serializes job reconciliation and restart so repeated active events cannot schedule duplicate tasks for the same persisted job
- a completed URLSession temporary file is moved into Vibes staging during the delegate callback; non-2xx HTTP responses become download failures instead of staged integrity failures
- download completion is not installation completion: SHA-256 validation, manifest creation, and installation remain foreground-owned
- finalization builds the complete artifact and manifest in staging before atomically replacing an existing installed model, preserving the current valid installation if replacement fails
- delete and repair cancel only Vibes-owned URLSession tasks, clear the Vibes job, and retain the existing user-facing install-state flow
- there is no legacy foreground downloader: both foreground and background transfers use the reusable transport

#### Dictation Download Policy

`ModelBackgroundDownloadCoordinator` owns Dictation’s reusable foreground/background transport integration. Its responsibilities follow the same extension-file structure as Speak and Vibes:

- `ModelBackgroundDownloadCoordinator.swift` owns Dictation job reconciliation, artifact preparation, cancellation, and the family-specific transport instance
- `ModelBackgroundDownloadCoordinator+Transport.swift` adapts transport handoffs into Dictation artifact scheduling
- `ModelBackgroundDownloadCoordinator+TransportDelegate.swift` handles transport events and claims completed temporary files into Dictation staging
- `ModelBackgroundDownloadCoordinator+State.swift` serializes persisted job and artifact mutations and publishes state changes

Rules:

- each model download is tracked inside a single persisted job carrying a stable UUID, its `modelID`, per-artifact state, and a monotonic aggregate progress floor
- the active job remains stored at `Models/model-download-job.json`; incomplete artifacts remain under `Models/.staging/<model-id>/`, and final Whisper and Parakeet locations are unchanged
- every URLSession task uses the shared `jobID` plus artifact-relative-path descriptor so multi-artifact Dictation jobs can be reconciled independently
- Dictation retains the existing `com.cueit.keyvox.model-download.background-session` namespace and never reuses or cancels Speak or Vibes tasks
- an active-app request uses the foreground session, `.inactive` begins the handoff to the Dictation background session, and `.active` hands unfinished artifacts back to the foreground session before recovery continues
- persisted per-artifact bytes and aggregate progress never decrease when recreated URLSession tasks initially report smaller task-local values
- rediscovered foreground or background tasks are resumed on relaunch, not just relabeled
- missing tasks are demoted back to `.pending` so the manager can restart them
- completed temporary files are moved into Dictation staging during the delegate callback; non-2xx HTTP responses become download failures
- finalization remains foreground-owned even when downloads finished in the background
- app activation must attempt interrupted-download recovery on the first relaunch after a kill
- only one model download/install may be active at a time on iOS
- there is no legacy coordinator-owned downloader: both foreground and background transfers use the reusable transport

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
- only visible, persisted dictionary entries participate in prompt generation and post-processing; the shared engine does not merge hidden app or product entries
- hint prompts are bounded to the newest entries, up to `200` phrases and `1200` characters

### Shared Post-Processing Rules

`KeyVoxCore` owns the shared post-processing order used by iOS and macOS.

Current order:

1. normalize literal email text before dictionary matching
2. apply dictionary matching using the entries supplied by the persisted user dictionary
3. normalize lightweight idioms and spoken colons
4. group spoken quantity forms before math normalization
5. normalize math expressions through the split math normalization helpers
6. apply list formatting when enabled
7. run late cleanup for laughter, character spam, provider asterisk artifacts, time expressions, dates, email boundaries, website/domain casing, and numeric grouping
8. run render-mode whitespace cleanup, sentence capitalization, spoken terminal punctuation, terminal-time punctuation completion, and the all-caps override

`TimeExpressionNormalizer` is the single owner of compact numeric time shaping. Meridiem matches that continue an already colon-separated number must be ignored so compact inputs such as `810 PM` normalize once to `8:10 PM`, never a second time to `8:10:00 PM`.

### Style Rules

- `autoParagraphsEnabled` and `listFormattingEnabled` are app-owned toggles
- `StyleTabView` is the current user-facing surface
- the runtime injects those values into the shared `DictationPipeline` at transcription time

### KeyVox Vibes Rules

KeyVox Vibes is the iOS user-facing name for the style rewrite feature.
The reusable implementation package remains `KeyVoxStyleRewrite`, matching the same branded-app-surface / technical-package split used by KeyVox Speak and `KeyVoxTTS`.

Current styles:

- `None`: bypasses style rewrite and inserts the normal post-processed dictation text.
- `Casual`: local LoRA cleanup. It removes clear filler except the word `like`, preserves slang, profanity, grammar, meaning, lists, and paragraph breaks, and formats clear numbers, dates, money, and percentages.
- `Polished`: local LoRA copyedit. It performs a medium readability pass that removes spoken filler and false starts, converts `ain't` to standard English, preserves meaning, structure, lists, and paragraph breaks, and uses numerals where appropriate.
- `Chill`: casual local LoRA cleanup plus deterministic formatting. The casual adapter performs the cleanup pass, then `ChillHeuristicFormatter` lowercases and applies the limited-punctuation Chill output shape.

Ordering is intentionally `None`, `Casual`, `Polished`, `Chill`.
The Style tab remains named `Style` because it also owns list and paragraph settings; the feature card inside the tab is branded `KeyVox Vibes`.

The keyboard extension can also change the selected vibe from the Vibes key.
That selector must use `StyleRewriteStyle` from `KeyVoxStyleRewrite` for ordering and display names so the keyboard does not duplicate style labels or identifiers.
The keyboard writes `KeyVox.SelectedVibe` in the App Group defaults and posts the shared Vibes selection-change Darwin notification.
The containing app observes that notification and refreshes `AppSettingsStore.selectedVibe` from shared defaults so the Style tab reflects keyboard-side changes.
Tap changes only the selected Vibe.
Before the local trial starts or the unlock is owned, selecting a paid Vibe from the Style tab must leave the selected Vibe as `None` and present the app-owned KeyVox Vibes intro sheet.
Before access is active, tapping the keyboard Vibes key emits the keyboard's medium no-op haptic and opens `keyvoxios://vibes/open`; the keyboard does not cycle to a paid Vibe.
Before the local Vibes model is installed, tapping the keyboard Vibes key keeps the selected Vibe resolved to `None`, emits the medium no-op haptic, and opens `keyvoxios://vibes/model-recovery`.

The containing app owns access-aware recovery routing for that URL: unlocked users receive the model-gated continue recovery, active-trial users receive the Scene C install recovery with remaining-trial context, and users without active access enter the trial-start intro path. The keyboard must not choose those scenes itself.
Vibes access requires `KeyVoxVibesPurchaseController.canUseVibes`; model-backed rewrites also require a ready local rewrite model and the required adapter.
When access is unavailable or an active local trial expires, the resolved selected Vibe is forced to `None`.
Long press may change the latest untouched KeyVox dictation insertion by reading the latest artifact, asking the containing app to regenerate from the original base text when a model-backed Vibe is needed, and replacing the active insertion.
The keyboard does not transform arbitrary selected host-app text because the iOS text proxy can provide incomplete selected/context text.
The keyboard still does not own prompt configuration, general rewrite policy, local rewrite model loading, recording, or app-level artifact creation.

The keyboard Lists key writes `KeyVox.ListFormattingEnabled` in App Group defaults and posts the shared list-formatting Darwin notification.
The containing app observes that notification and refreshes `AppSettingsStore.listFormattingEnabled` so the Style tab remains in sync.
The keyboard Paragraphs key writes `KeyVox.AutoParagraphsEnabled` in App Group defaults and posts the shared auto-paragraphs Darwin notification.
The containing app observes that notification and refreshes `AppSettingsStore.autoParagraphsEnabled` so the Style tab remains in sync.
The keys use the same symbols as the Style tab and show setting state through icon tint instead of a permanently pressed toggle state.

### Style Rewrite Package Ownership

`Packages/KeyVoxStyleRewrite` owns reusable transform mechanics:

- `StyleRewriteStyle` and `StyleRewriteDictationConfiguration` define style identifiers, display names, descriptions, and request construction.
- `TextTransformRequest` carries base text, style identifier, instructions, prompt wrapper, context token limit, expected output expansion ratio, safety margin, and optional maximum response tokens.
- `TextTransformResult` carries final text, style identifier, duration, applied flag, chunk count, per-chunk timings, typed error summaries, and processing mode metadata.
- `TextTransformChunkPlanner` budgets every model call as instructions + prompt wrapper + input chunk + expected output + safety margin.
- chunk planning prefers semantic boundaries first, then word-level splits when a segment exceeds budget.
- `StyleRewriteTextTransformTokenCounter` uses conservative approximate token counting for local model chunk planning.
- `StyleRewriteTextTransformer` owns chunk execution through an injected chunk responder, full fallback policy, style-specific processing modes, Casual cleanup metadata, deterministic output repair, prompt-leak fallback, and the Chill cleanup-plus-heuristic path.
- `StyleRewritePromptLeakGuard` falls back to the original base text when generated output leaks significant prompt/instruction text.
- `OutputRepair` runs deterministic post-model repair after the local model touches text.
- `PunctuationRepair` preserves punctuation facts before more specific fact repair runs.
- `TerminalPunctuationBoundaryRepair` preserves source-backed terminal `!` and `?!` boundaries across model rewrites and Chill heuristic formatting.
- `AddressFactRepair` preserves source-backed address facts before money and number repair.
- `NumberEvidence` is the shared factual number evidence source used by general number repair and money repair.
- `NumberEvidenceRepair.repair` coordinates factual number preservation in changed -> deleted -> separator order, with `NumberSeparatorEvidenceRepair` owning decimal-vs-time separator evidence after changed/deleted number repair runs.
- `MoneyFactRepair` owns currency-specific repair while relying on shared number evidence for amount values.
- `APStyleNumberRepair` owns AP-style number presentation only after factual number evidence has been repaired.
- `ChillHeuristicFormatter` owns deterministic Chill casing and punctuation after optional local-model cleanup.
- `DictationUtteranceArtifact` and `DictationTextVariantArtifact` are package-owned serializable models so the app can cache the latest utterance without inventing iOS-only artifact shapes.

`Packages/KeyVoxLocalInference` owns reusable local model mechanics:

- `LlamaLocalLanguageModel` wraps llama.cpp local inference for GGUF chat models and optional LoRA adapters.
- generation requests can use either a raw prompt or a system/user chat prompt.
- model loading is cached per `LlamaLocalLanguageModel` instance, explicit prepare can load the model and adapter before generation, and each generation clears llama memory before running.
- the package installs quiet llama logging, supports task cancellation, attaches LoRA adapters, performs prompt-too-long checks, uses greedy decoding, exposes load/prefill/decode/total timing metrics, and supports explicit unload.

`Packages/KeyVoxVibesAdapters` owns bundled KeyVox-trained adapter assets:

- `KeyVoxVibesAdapterCatalog` exposes typed descriptors for Polished and Casual adapters.
- adapter descriptors include adapter kind, adapter ID, filename, and compatible base model ID.
- adapter resources live under `Resources/Adapters`, are copied by SwiftPM, and resolve through `Bundle.module`.
- this package owns product-specific adapter artifacts; `KeyVoxLocalInference` remains a generic local inference runtime.

### Dictation Pipeline Style Hook

The shared `KeyVoxCore` dictation pipeline owns the stable hook point:

1. provider inference returns raw text
2. post-processing produces the canonical base text, including shared provider-artifact repair
3. the app-provided `processOutputText` closure may transform that base text
4. Caps Lock casing override is applied after transformation
5. final text is recorded and inserted

`DictationPipelineResult` exposes raw provider text, base text, selected pre-Caps final text, selected final text, inference duration, transform duration, transform applied flag, selected style identifier, transform chunk count, transform errors, transform processing mode, and paste duration.
This keeps the keyboard insertion path unchanged while still making speed-profile and artifact data explicit.

Failure policy:

- no selected request, `None`, unavailable local rewrite model, missing required adapter, generation failure, prompt-too-long, prompt-leak detection, or required full fallback inserts the post-processed base text
- chunk-level failures that do not require full fallback use the base text for only the failed chunk and record the error
- model errors must never replace user dictation with an error or diagnostic string

### iOS KeyVox Vibes Runtime Ownership

`StyleRewritePipelineCoordinator` is the iOS adapter between `TranscriptionManager` and `KeyVoxStyleRewrite`.
It owns:

- reading the selected Vibe from `AppSettingsStore`
- building `TextTransformRequest` values through `StyleRewriteDictationConfiguration`
- invoking the app-owned local style rewrite transformer
- translating `TextTransformResult` into `DictationPipelineTextProcessingResult`
- writing latest-utterance artifacts through `StyleRewriteLatestArtifactStore`
- handling keyboard style rewrite IPC requests through the same transformer path
- forwarding prewarm and release calls through the transformer contract

`LocalRewriteModelManager` is the containing-app owner for the local Vibes rewrite base model.

- current base model: `Qwen2.5-0.5B-Instruct`
- current source repository: `Qwen/Qwen2.5-0.5B-Instruct-GGUF`
- current artifact: `qwen2.5-0.5b-instruct-q4_k_m.gguf`
- expected installed artifact size: `491,400,032` bytes
- install readiness requires the model file plus `install-manifest.json` with matching model ID, artifact filename, expected SHA-256, and installed SHA-256
- delete invalidates the installed local model and asks the local inference service to unload
- Settings exposes the main `KeyVox Vibes AI` download/delete/repair card beneath the dictation model card
- Vibes Scene C exposes a compact install card when the model is not ready, using sheet-owned download confirmation before starting a user-requested download

LoRA adapter ownership:

- adapters are resources in `Packages/KeyVoxVibesAdapters/Sources/KeyVoxVibesAdapters/Resources/Adapters`
- Polished uses `polished-alpha-027-lora.gguf`
- Casual and Chill share `casual-alpha-9-lora.gguf`
- adapter URLs resolve from `KeyVoxVibesAdapters` first, with installed-directory fallback for development/repair paths
- a missing required adapter is a model-load failure for that Vibe, not permission to silently run a different prompt path

`LocalRewriteInferenceService` owns the app-local inference cache.

- it builds `LlamaLocalLanguageModel` with the installed base model URL and requested adapter URL
- it keeps one cached model identity at a time, keyed by base model URL plus adapter URL
- it unloads when the local rewrite model is invalidated or when the utterance-scoped Vibes rewrite lifecycle is released

`LocalStyleRewriteTextTransformer` maps style requests into local inference:

- Polished maps to the polished adapter and the short polished LoRA system prompt
- Casual maps to the casual adapter and the short casual LoRA system prompt
- Chill maps to the casual adapter and the short casual LoRA system prompt before deterministic Chill formatting
- prewarm maps the selected Vibe to the same adapter as generation and calls local inference prepare without producing text
- release cancels any pending prewarm task and unloads the local rewrite inference cache
- local generation uses the style request context limit, two CPU threads, two batch threads, and a batch token cap up to 512
- debug logs use `[StyleRewriteLocal]` and include prewarm load/cache state plus generation style, chunk index, adapter label, load state, input/output tokens, prefill/decode/total timing, and decode tokens per second

`StyleRewriteLatestArtifactStore` persists one latest utterance in App Group defaults under the style rewrite artifact key.
The artifact includes raw provider text, post-processed base text, selected inserted text, selected pre-Caps text, selected style identifier, deterministic paragraph/list variants, variant text/timing/errors, inference duration, transform duration, and creation date.
When providers supply audio-derived paragraph and inline text, deterministic paragraph variants preserve those forms so the keyboard can apply paragraph changes later without inferring sentence breaks locally.
The keyboard consumes this artifact for long-press Vibes revert/restyle, paragraph/list deterministic swaps, and Caps Lock reversal on the latest untouched KeyVox dictation insertion.

### KeyVox Vibes Purchase Ownership

`KeyVoxVibesTrialPolicy` is the shared source of truth for the local Vibes trial duration.

- the policy is compiled into the containing app, keyboard extension, and iOS tests
- app and keyboard trial gates must read the policy instead of duplicating duration constants
- UI copy that displays the total trial length derives from this policy

`KeyVoxVibesTrialRemainingTimeFormatter` owns display formatting for Vibes trial durations.

- remaining time uses adaptive units: days and hours while days remain, hours and minutes below one day, and minutes below one hour
- zero-value units are omitted
- views own their own surrounding sentence copy and call the formatter only for the formatted time value

`KeyVoxVibesPurchaseController` is the containing-app owner for Vibes access.

- the unlocked product identifier is `com.cueit.keyvox.vibes.unlocked`
- the product is a non-consumable unlock named `KeyVox Vibes Unlock`
- the local trial starts only when the user taps `Try Now`
- trial resets are handled by versioning the trial-start defaults key, not by clearing intro, interaction, unlock, model, or selected-Vibe defaults
- `canUseVibes` is true only while the unlock is owned or the local trial is active
- trial expiration immediately resolves selected Vibe to `None`
- unlock state, trial start date, intro state, and interacted state are app-local defaults, not iCloud-synced settings
- model-recovery presentation differs by access state: an active trial with missing Vibes AI opens Scene C directly with the install card and remaining-trial context, while an unlocked user with missing Vibes AI opens the unlock scene directly with a model-gated continue CTA

`KeyVoxVibesIntroController` owns cold-launch intro scheduling.

- Vibes follows the same delayed cold-launch philosophy as KeyVox Speak
- Vibes never presents over onboarding, return-to-host, playback preparation, or recording launch flows
- when KeyVox Speak and KeyVox Vibes both want the same eligible launch, Vibes presents first and Speak is deferred to the next eligible launch
- a usage-only Scene B presentation path is kept available for future help/info entry points

`KeyVoxVibesSheetView` owns the shared Vibes sheet shell.

- intro mode shows scenes A, B, and C
- when Vibes AI is installed, each intro scene shows `Try Now` and starts the local trial as before
- when Vibes AI is missing, scene A advances with `Get Started`, scene B advances with `Next`, and scene C keeps `Try Now` disabled until install readiness arrives
- info mode shows the usage refresher with a `Vibe Now` CTA that dismisses the sheet for already-unlocked users
- Scene C owns the inline Vibes AI install card and routes user-started downloads through the sheet-level confirmation overlay
- active-trial missing-model recovery starts on Scene C and swaps the first detail subtitle to the same remaining-trial semantic used by the Style tab card
- unlock mode normally shows the usage refresher scene and the unlock scene with a dynamic App Store price button
- direct unlock-scene recovery is reserved for missing-model paths that should skip the refresher page: expired trials without the model still purchase from the unlock scene, while already-unlocked users get a `Continue` CTA that stays disabled until Vibes AI is ready
- per-sheet restore checks the Vibes entitlement

Settings restore is shared across KeyVox Speak and KeyVox Vibes.
The restore card remains visible until both unlocks are owned.

`KeyVoxVibesAccessMatrix` is the semantic source of truth for the Style tab Vibes card.

- inputs are Vibes access state, local Vibes AI install state, and the selected Vibe
- outputs are main-card content, visible card control, card action, destination start, destination dynamic text class, and destination CTA class
- tests assert the matrix semantics instead of raw UI copy so copy edits do not break behavior coverage
- the Style tab maps the matrix output back to user-facing copy and controller calls

### KeyVox Vibes AI Settings Surface

`SettingsTabView+VibesAI` owns the release-facing `KeyVox Vibes AI` card.

- the card lives directly below the dictation model card
- not-installed copy tells the user to install Vibes AI first and includes the pinned approximate size
- ready copy confirms Vibes AI is installed and ready
- download requests set the shared `PendingDownloadConfirmation.keyVoxVibesAI` value before `LocalRewriteModelManager.downloadModel()` starts
- ready state exposes a destructive delete action through the shared deletion confirmation path
- failed state exposes repair through the local rewrite model manager
- downloading and installing states show status text, a right-aligned yellow percentage, and `ModelDownloadProgress`
- the progress area measures its own height and collapses after a delay so completion does not snap the card closed

### Keyboard App Settings Runtime Ownership

`KeyboardAppSettingsStore` owns keyboard-side settings that mirror containing-app settings:

- reads and writes `KeyVox.SelectedVibe` from App Group defaults
- derives display text from `StyleRewriteStyle`
- cycles through `None`, `Casual`, `Polished`, `Chill` only when Vibes access and local Vibes AI readiness are both available
- posts the shared Vibes selection-change Darwin notification
- exposes Vibes platform availability as always true now that the Foundation-only gate is gone
- exposes Vibes access state from app-local unlock/trial defaults and the shared Vibes trial duration policy so locked keyboard taps open the containing-app Vibes sheet instead of changing selection
- checks local Vibes AI install readiness from the rooted model artifact and manifest so missing-model taps open the dedicated model-recovery route instead of cycling
- reads and writes `KeyVox.ListFormattingEnabled` from App Group defaults
- posts the shared list-formatting Darwin notification so the containing app refreshes its settings UI
- reads and writes `KeyVox.AutoParagraphsEnabled` from App Group defaults
- posts the shared auto-paragraphs Darwin notification so the containing app refreshes its settings UI
- reads Compact Keys availability from `KeyVox.CompactKeysEnabled`, defaulting to enabled
- reads and writes the separate `KeyVox.CompactKeysActive` presentation preference, defaulting to the full keyboard

`AppSettingsStore` owns the containing-app Compact Keys availability toggle. Turning availability off must also clear `KeyVox.CompactKeysActive`, so enabling the feature again never revives a stale compact presentation.

`KeyboardDictationChangeController` owns keyboard-side long-press changes for KeyVox insertions:

- records the latest inserted dictation session from `KeyboardTextInsertionResult` plus `DictationUtteranceArtifact`
- treats `None` as the original post-processed base text
- stores the current insertion text, current Vibe, deterministic paragraph/list state, Caps Lock display-transform state, and cached rendered variants
- delegates deterministic paragraph/list state transitions and source selection to `KeyVoxCore.DictationDeterministicVariantResolver`
- delegates paragraph collapse, ordered-list line preservation, and post-rewrite layout adjustment to `KeyVoxCore.DictationDeterministicTextFormatter`
- regenerates Vibe variants from the current deterministic base text by sending style rewrite IPC to the containing app rather than morphing from the currently displayed style
- applies paragraph/list long-press changes from deterministic artifact variants outside the KeyVox Vibes entitlement boundary, including persisted paragraph variants captured even when Paragraphs was disabled during recording
- applies Caps Lock long-press changes locally from the current untouched insertion and the artifact's selected pre-Caps text, preserving Caps display state across Vibes and deterministic paragraph/list changes
- accepts a transformer result as usable replacement text even when `applied == false`, because `applied` only means “different from the base request,” not “different from the currently displayed style”
- replaces only when the active insertion still matches the untouched session
- clears the active session on mismatch to avoid data loss
- returns success/failure so the controller can emit success or medium haptics

Long-press rules:

- if the selected Vibe matches the current inserted style, long press reverts to `None`
- if the selected Vibe differs, long press restyles from the original base text
- cached variants replace instantly
- generated variants may temporarily drive the logo indicator into processing state
- if the user edits, deletes, moves away from, or otherwise invalidates the active insertion, long press no-ops

`KeyboardModelAvailability` remains a lightweight file-presence gate for extension UI decisions.
For Vibes AI it only checks the App Group rooted install manifest and GGUF artifact; it does not load, validate, or run the local rewrite model.

`KeyboardLocalStyleRewriteTextTransformer` is the keyboard-side transport for long-press model-backed Vibes rewrites.

- it writes `KeyVoxStyleRewriteIPCRequest` through `KeyVoxIPCBridge`
- it waits for the matching `KeyVoxStyleRewriteIPCResponse`
- it reports processing mode `app-ipc`
- it falls back to the request base text on timeout, cancellation, empty response, or error
- it does not load the local rewrite model or adapters inside the keyboard extension

### Local Rewrite Warmth Lifecycle

Prewarm is best-effort and utterance-scoped at the transformer contract level:

- after `AudioRecorder.startRecording()` succeeds, `TranscriptionManager` asks the style coordinator to prewarm for the selected style
- prewarm never blocks mic activation, URL handling, recorder startup, or audio capture
- `None` skips prewarm
- local rewrite prewarm prepares the selected style's base model and adapter without generating text
- successful prewarm consumes the cold-load duration so the following generation reports the model as cached
- after dictation output is published, `TranscriptionManager` releases the utterance-scoped Vibes lifecycle so the local rewrite model does not remain resident for the warm monitoring session
- stale, empty, unavailable-model, and cancelled utterance paths also release the same lifecycle
- model invalidation still explicitly unloads the local model cache
- repeated prewarm/release calls must remain harmless because `TranscriptionManager` owns the lifecycle hooks

### KeyVox Vibes Instrumentation

Debug speed-profile output stays in the existing transcription log slot.
It reports:

- provider inference duration
- text transformation duration
- applied flag
- error summary when present
- style identifier
- processing mode such as `local-model`, `local-model-cleanup`, `local-model-cleanup+heuristic`, `local-model-cleanup-failed+heuristic`, `app-ipc`, or `heuristic`
- chunk count
- final inserted text when `KVX_DEBUG_LOG_RAW_TEXT=1`
- injection trigger duration and total end-to-end latency

`LocalStyleRewriteTextTransformer` also logs `[StyleRewriteLocal]` lines in debug builds with style, chunk, LoRA label, load duration or cached state, token counts, prefill/decode/total time, and decode tokens per second.

### iCloud Sync Rules

`CloudSyncCoordinator` syncs:

- dictionary payloads
- shared KeyVox installation history used to protect existing users from initial-entry seeding
- trigger binding timestamps
- auto paragraphs timestamps
- list formatting timestamps

`KeyVox` is created as an ordinary dictionary entry only when onboarding is incomplete and no local dictionary snapshot, synchronized dictionary payload, or shared installation history exists. Existing installations record shared installation history without changing their dictionaries. The entry remains user-owned after creation, so deleting it is synchronized normally and does not cause it to be recreated later.

`WeeklyWordStatsCloudSync` syncs only the current-week usage snapshot.

Weekly word stats merge by taking the maximum count seen for each device ID within the same week.

Excluded from iCloud sync:

- Caps Lock latch
- keyboard haptics
- microphone preference
- KeyVox Vibes selected style
- KeyVox Vibes unlock cache
- KeyVox Vibes local trial state
- KeyVox Vibes intro/interacted state
- latest KeyVox Vibes utterance artifact
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

Background dictation intents require the coordinator to prepare or update the Live Activity before recorder startup. The coordinator keeps that preparation pending until startup resolves, then reconciles against the actual session state so a failed start cannot leave an orphaned activity.

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
- rebuild must resolve Compact Keys mode from App Group defaults before presentation setup so the extension returns to the user's persisted mode after a keyboard switch

Implementation split:

- `KeyboardViewController.swift` owns the controller-facing event and state surface
- `KeyboardViewController+PresentationLifecycle.swift` owns presentation-tree creation, binding, teardown, and host-lifecycle observation
- `KeyboardViewController+Debug.swift` owns debug-only lifecycle counters and testing hooks
- `KeyboardTTSController.swift` owns keyboard-side copied-text speak transport state and the App Group request/start-stop coordination surface
- `KeyboardAppSettingsStore.swift` owns keyboard-side App Group settings persistence and notification dispatch for controls that mirror containing-app settings
- `KeyboardKeysMode.swift` owns full/compact resolution, visible row count, and height selection
- `Input/KeyboardCompactKeysHoldController.swift` owns the cancellable activation timer for the `#+=` long press
- `DictationChange/` groups the latest untouched insertion long-press feature files
- `DictationChange/KeyboardDictationChangeController.swift` owns the artifact-scoped latest-insertion change facade, display-facing state, collaborators, and current session reference
- `DictationChange/KeyboardDictationChangeController+Actions.swift` owns long-press action entry points for Vibes, Paragraphs, Lists, and Caps Lock
- `DictationChange/KeyboardDictationChangeController+Session.swift` owns latest untouched insertion session construction from keyboard insertion results and app-published artifacts
- `DictationChange/KeyboardDictationChangeController+Variants.swift` owns deterministic state resolution, Vibes replacement lookup/generation, rendered variant caching, Caps display text handling, and shared preparation/debug helpers
- `DictationChange/KeyboardDictationChangeSession.swift` owns the latest-insertion session and rendered-variant value types
- `DictationChange/KeyboardDictationChangeArtifactStore.swift` owns lightweight App Group artifact reads for keyboard-side latest-insertion changes
- `KeyVoxCore.DictationDeterministicState` and `DictationDeterministicControlKind` are the shared paragraph/list state and action vocabulary used by iOS and macOS latest-insertion changes
- `KeyVoxCore.DictationDeterministicVariantResolver` owns target-state selection and saved-versus-rendered deterministic source selection
- `KeyVoxCore.DictationDeterministicTextFormatter` owns paragraph collapse, ordered-list line preservation, and post-rewrite layout adjustment
- keyboard `Core` is grouped by domain:
  - `Dictation/` owns recording-state handoff, live indicator driving, call gating, and latest-insertion long-press changes
  - `Feedback/` owns extension-local haptics configuration and dispatch
  - `Input/` owns text insertion, special-key interaction, and cursor trackpad behavior
  - `Settings/` owns App Group-backed keyboard controls that mirror containing-app settings
  - `Text/` owns casing and spacing heuristics for inserted text
  - `Transport/` owns shared playback IPC plus non-visual keyboard transport state
  - Vibes-specific keyboard UI lives in the top-row button component, while latest-insertion long-press behavior lives with dictation because paragraph/list undo is not part of the Vibes entitlement boundary
  - cross-cutting layout, style, typography, and high-level keyboard state primitives stay at the `Core/` root
- `KeyboardLayoutGeometry.swift` and `KeyboardTopRowAccessoryLayout.swift` belong in `Core/`, not `Views/`, because they are shared layout math rather than renderable views

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
- `KeyboardRootView.apply` must invalidate layout when branded-toolbar Vibes visibility changes, including when a call warning disappears, so the measured accessory geometry is restored instead of retaining warning-mode spacing

That separation exists because putting the warning UI into the main root layout reintroduced the keyboard launch flash.

### Symbol Keyboard Layout Rules

Keyboard-specific row geometry must stay separated by responsibility:

- `KeyboardRootView` owns the stable keyboard shell, toolbar stacking, and the top-row accessory button containers
- `KeyboardKeyGridView` owns row creation and key interaction wiring
- `KeyboardLayoutGeometry` owns live measurement-based row sizing, while `KeyboardTopRowAccessoryLayout` owns accessory alignment rules

Do not push special-case row width math back into `KeyboardSymbolLayout` when the requirement depends on the rendered keyboard width.

Current symbol layout rules:

- rows 1 and 2 stay equal-width
- row 3 side keys use a 1.5-key span
- row 3 middle keys evenly divide the remaining width
- row 4 side keys use a 2.5-key span
- the space bar consumes the remaining row-4 width
- the left accessory slot is derived from the live `1` key geometry and swaps statically between Settings and Cancel
- with Vibes available, top-row Speak aligns over `2`, Dictionary aligns over `3`, Paragraphs aligns over `4`, Lists aligns over `5`, Caps Lock aligns over `6`, the Vibes selector spans `7` and `8`, and the logo bar sits over the far-right `9`/`0` area
- with the Vibes feature unavailable, the Vibes key is removed and the remaining top-row accessories compact rightward against the logo area
- with Vibes available but Vibes AI not installed, the Vibes key stays visible and taps route to the app-owned, access-aware model-recovery flow instead of cycling styles
- the left-handed keyboard layout setting mirrors the control strip while leaving typed symbol order unchanged
- top-row accessory slots are allocated from the logo edge inward so adding or removing feature keys does not leave empty holes
- top-row accessory buttons use normal key palette/pressed outline behavior unless their dedicated component intentionally says otherwise
- keyboard settings toggles should indicate setting state without looking permanently pressed

Compact Keys rules:

- feature availability defaults on, but the keyboard itself defaults to full mode
- a half-second long press on the primary-page `#+=` key activates compact mode and emits the same success-style interaction haptic used by keyboard long-press actions
- compact mode omits the first two symbol rows and keeps the final punctuation/action row plus the bottom row
- the compact row's leading key becomes the `keyboard` SF Symbol and restores the full keyboard with one tap and a medium interaction haptic
- normal `#+=` behavior remains unchanged when the hold does not activate or the feature is unavailable
- both modes must use explicit required controller-view heights: 286 points for full and 174 points for compact
- `KeyboardStyle` owns those height constants; do not infer either height from transient host bounds
- `KeyboardKeysMode` owns visible row count and derived key-grid height, while `KeyboardSymbolLayout` owns which rows and restore key appear
- active mode is persisted separately from availability and survives keyboard-extension recreation
- disabling availability forces full mode and clears the persisted compact-active flag

iOS may briefly display a host-cached frame while recreating a third-party keyboard at a different height. The extension must still establish the resolved mode and explicit height before presentation setup; it cannot control the host's cached transition frame.

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

`KeyVoxTextComposition` owns the deterministic editor-adjacent capitalization, leading spacing, quotation-mark, sentence-boundary, terminal-punctuation, and trailing-separator policy shared with macOS. It accepts platform-neutral adjacent-text context and never reads `UITextDocumentProxy` or inserts text.

`KeyboardInsertionSpacingCoordinator` converts the keyboard's preceding-text snapshot into the shared context and stays intentionally thin:

- do not prepend a space after existing whitespace
- do not prepend a space before incoming punctuation
- do prepend a space after word-like or trigger-punctuation contexts when needed

`KeyboardInsertionCapitalizationCoordinator` supplies the keyboard's preceding-text snapshot and casing-preservation decision to the shared policy. It does not replace the all-caps override owned by the dictation pipeline.

`TerminalPunctuationCompositionPolicy` resolves finalized dictation against the first character following the insertion or selected span:

- an incoming terminal period is removed when supported non-quote punctuation already follows
- a matching incoming question or exclamation mark is removed so the existing mark is reused
- a differing incoming question or exclamation mark signals that the following punctuation must be replaced

`TrailingSeparatorCompositionPolicy` then resolves the punctuation-normalized dictation against that same following character:

- append one space when the dictation has no trailing whitespace and a following letter, number, or emoji would otherwise be joined to it
- preserve dictation that already ends in whitespace
- do not add a separator before following punctuation, symbols, whitespace, or the end of the document

`KeyboardTextInputController` remains the insertion owner. It calls the capitalization and leading-spacing coordinators, captures the document proxy's following character once, applies the shared punctuation result followed by the shared trailing-separator result, and inserts the finalized text. When punctuation replacement is required, it first replaces the selected text, then advances over and deletes the old following punctuation so selection semantics remain correct.

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
- `DownloadConfirmation`: shared non-destructive confirmation overlay for user-started model and voice downloads; app-shell surfaces route through `MainTabView`, while KeyVox Speak and KeyVox Vibes sheets own sheet-level instances so pinned CTA controls are covered
- `ModelDownloaderCardView`: compact reusable model-download card for portable install surfaces, with title/action alignment, optional subtitle, status row, right-aligned progress percentage, progress bar, and error text
- `AppUpdatePrompt`: shared custom update overlay presented from `AppRootView` so optional and forced update prompts match the app modal style and cover the mounted app shell instead of using the native system alert
- `ThirdPartyNoticesView`: shared legal-notices sheet that renders the bundled repo-root `THIRD_PARTY_NOTICES.md` markdown with app-owned styling and explicit close-only dismissal
- `DictionaryTabView`: dictionary browsing/editing
- `StyleTabView`: dictation style toggles
- `SettingsTabView`: top-level settings composition, shared disclosure state, third-party notices presentation, full-screen Dictation Shortcut reference-guide presentation, and cross-section coordination
- `SettingsTabView+General`: session timeout, Live Activities, Dictation Shortcut setup-guide entry, Speak Timeout, keyboard haptics, and audio preference sections extracted from the settings root view
- `SettingsTabView+Models`: release-facing `Dictation Model` section for provider selection, per-model install actions, uninstalled model size display, and the attached language section driven by the shared Whisper catalog or Parakeet Auto Detect guidance
- `SettingsTabView+TTS`: release-facing `KeyVox Speak` section for PocketTTS runtime install state, per-voice install actions, previews, voice selection, and the `KeyVox Speak Unlimited` unlock row placed beneath the model section
- `SettingsTabView+VibesAI`: release-facing `KeyVox Vibes AI` section for local rewrite model install state, confirmed download/delete actions, repair, progress, and animated progress collapse
- `SettingsTabView+About`: rate-and-review, GitHub support, restore-purchases, version footer, and third-party notices launcher extracted from the settings root view
- `PlaybackPreparationView`: keyboard cold-launch playback-preparation surface shown before returning to the host app
- `ReturnToHostView`: one-time host-return guidance after a cold keyboard launch, with a top-right dismiss affordance that returns the app to Home while preserving the containing app as the route/session owner
- onboarding screens: welcome, searchable language selection, model/microphone setup, the guided Dictation Shortcut and Action Button flow, keyboard enablement, and keyboard tour
- `DictationShortcutSetupBrowsingView`: shared freely swipeable existing-user introduction and Settings reference presentation for the same eight-page guide
- `AppPageIndicator`: shared page position control with optional one-step navigation and VoiceOver adjustable behavior

`AppHaptics` is the app-owned feedback bridge for these surfaces, while `AppHapticsDecisions` keeps the trigger rules deterministic and testable.

Views may surface manager state, but runtime ownership stays in the managers and services.

## Testing and Quality Gates

- Do not treat the absence of an iOS simulator run as proof that a runtime contract changed safely.
- Prefer deterministic store/manager/probe tests for app-owned state and manual device validation for cross-process behavior.

### iOS-Focused Test Coverage

- onboarding store persistence and routing state
- Dictation Shortcut existing-user intro eligibility, delay, cancellation, and handled-state behavior
- onboarding keyboard access probe behavior
- onboarding keyboard-tour state transitions
- onboarding microphone permission refresh behavior
- onboarding setup-state gating
- app haptics decision rules
- shared path construction
- settings persistence
- Compact Keys availability, active-mode resolution, row selection, hold cancellation, and explicit mode heights
- iCloud sync coordination
- weekly stats storage and merge behavior
- Live Activity coordination
- background shortcut dictation coordination and Live Activity preparation
- model manager validation and repair behavior
- KeyVox Vibes intro scheduling, access matrix semantics, and purchase/trial behavior
- PocketTTS engine runtime preparation, unload, and prepared-runtime compute-mode behavior
- TTS manager engine-unload behavior on replayable completion, explicit stop, and playback error
- Home copied-text playback preparation presentation policy
- stop-time capture processing
- keyboard dictation controller behavior
- keyboard deterministic dictation formatting and latest-insertion change behavior
- keyboard interaction haptics
- keyboard controller presentation teardown and rebuild behavior
- keyboard text input helpers
- keyboard cursor-trackpad support
- transcription manager lifecycle, typed shortcut command outcomes, immediate microphone-release retry and timeout fallback, and interruption handling

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
- When `KeyVoxTextComposition` changes its context contract or insertion-facing policy, update the keyboard insertion section and `CODEMAP.md` without moving document-proxy ownership into the package.
- When `KeyVoxStyleRewrite` changes style identifiers, artifact fields, fallback policy, prewarm lifecycle, or transform metadata consumed by iOS, update this document and `CODEMAP.md`.

## Change Tracking

- `ENGINEERING.md` tracks stable iOS architecture, onboarding rules, IPC contracts, lifecycle rules, and operational/testing policy.
- `CODEMAP.md` tracks file ownership and major system placement.
- These two docs are the maintained iOS source of truth in this repo today.
