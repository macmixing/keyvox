# KeyVox iOS Code Map
**Last Updated: 2026-04-16**

## Project Overview

KeyVox iOS ships as four cooperating targets:

- The containing app owns onboarding, settings, model lifecycle, PocketTTS voice installs, copied-text playback, microphone capture, interrupted-capture recovery, session policy, weekly stats, iCloud sync, and the SwiftUI shell.
- The keyboard extension owns the visible custom keyboard, warm/cold app handoff, copied-text speak transport, text insertion, warning-toolbar presentation, and keyboard-only interaction behavior.
- The share extension owns shared text/URL/PDF extraction, OCR for shared images and rendered PDF pages, TTS request handoff to the main app, and visual feedback during share processing.
- The widget extension owns the Live Activity and Dynamic Island presentation plus the stop-session App Intent.

Shared speech and text behavior still lives in `../Packages/KeyVoxCore`, including `DictationPipeline`, shared provider seams, dictionary persistence primitives, and post-processing order.
The local PocketTTS runtime now lives in `../Packages/KeyVoxTTS`.

The current default runtime flow is:

1. On first launch, the app routes through onboarding instead of dropping directly into tabs.
2. The setup screen lets the user work through model download and microphone access in parallel, but keeps keyboard setup gated until both prerequisites are complete.
3. When the user leaves setup for Settings, the app records a pending keyboard-tour handoff and later resumes into the keyboard tour after reactivation.
4. The keyboard tour autofocuses a text field, waits for the KeyVox keyboard to be shown, and only enables completion after the first non-empty tour transcription completes.
5. Finishing the keyboard tour completes onboarding directly; there is no separate customize-app screen on the current branch.
6. After onboarding, the main app shell owns ongoing model management, style/settings changes, weekly usage, and session controls.
7. When the user taps the mic in the keyboard extension, the extension decides between warm Darwin signaling and cold URL launch.
8. The containing app records and processes audio, runs the shared dictation pipeline, and publishes `transcribing`, `transcriptionReady`, or `noSpeech` back through the App Group bridge.
9. The extension inserts the returned text into the focused host app using conservative spacing and capitalization heuristics.
10. When the user triggers copied-text playback, the containing app owns PocketTTS synthesis, explicit model load/unload lifetime, deterministic playback preparation, replay caching, pause/resume/stop transport state, and return-to-host readiness.
11. If the user keeps the session active, the Live Activity coordinator mirrors session state and weekly-word updates into the widget extension.

## Architecture

- **`KeyVox iOS/`**: app lifecycle, grouped app composition/routing/integration surfaces, onboarding state, app haptics, App Group storage, iCloud sync, model background downloads, PocketTTS install ownership and playback-scoped runtime ownership, audio capture, transcription/session management, Live Activity coordination, and the SwiftUI shell.
- **`KeyVox Keyboard/`**: custom keyboard controller, presentation-scoped keyboard view lifecycle, toolbar modes, copied-text speak transport, keyboard playback pause/resume/stop controls, call-aware warning detection, key grid UI, full-access instructional surface, live indicator rendering, host-app launch handoff, haptics, cursor trackpad behavior, and final insertion heuristics.
- **`KeyVox Widget/`**: ActivityKit/WidgetKit surface for the lock screen and Dynamic Island, plus the stop-session App Intent.
- **`../Packages/KeyVoxCore/`**: shared dictation pipeline, provider seams, dictionary store, post-processing order, silence heuristics, and list formatting behavior.
- **`../Packages/KeyVoxTTS/`**: PocketTTS runtime actor, Core ML inference helpers, tokenizer support, text normalization, chunk planning, audio-frame streaming contract, and package tests for deterministic text preparation behavior.
- **`KeyVoxiOSTests/`**: deterministic tests for onboarding state, keyboard-tour routing, settings persistence, iCloud sync, weekly stats, model lifecycle, copied-text playback policy and lifecycle, model download recovery, microphone permission handling, text input helpers, cursor-trackpad behavior, and transcription/session orchestration.
- **`iOS/Docs/`**: iOS-local source of truth. `CODEMAP.md` tracks file ownership; `ENGINEERING.md` tracks invariants, contracts, and operational policy.

## Contributor Notes

- Keep iOS-only platform behavior inside the iOS targets. Reusable speech, text, and dictionary logic should remain in `KeyVoxCore`.
- Keep the keyboard extension thin. It should transport commands, render keyboard UI, and insert final text, not become an alternate owner of model, microphone, or onboarding state.
- Keep app-extension and app-widget contracts centralized in `KeyVoxIPCBridge`; do not duplicate App Group keys, timestamps, or Darwin notification names.
- Keep onboarding state separate from settings state. `OnboardingStore` is the routing owner for onboarding progress and launch flags.
- Keep the keyboard root layout stable. The warning toolbar is intentionally layered as an overlay instead of participating in the main keyboard stack layout.
- Update [`ENGINEERING.md`](ENGINEERING.md) whenever lifecycle rules, IPC contracts, onboarding routing, Live Activity behavior, or model recovery behavior change.

## Directory Index

This is the curated iOS structure map, including the direct shared package dependency.

```text
iOS/
├── Docs/
│   ├── CODEMAP.md
│   └── ENGINEERING.md
├── KeyVox iOS.xcodeproj/
├── KeyVox iOS.xctestplan
├── app-update-policy.json
├── KeyVox iOS/
│   ├── App/
│   │   ├── AppUpdate/
│   │   │   ├── AppUpdateConfiguration.swift
│   │   │   ├── AppUpdateCoordinator.swift
│   │   │   ├── AppUpdatePolicy.swift
│   │   │   ├── AppUpdateService.swift
│   │   │   └── AppVersion.swift
│   │   ├── Composition/
│   │   │   ├── AppServiceRegistry.swift
│   │   │   └── SharedPaths.swift
│   │   ├── Feedback/
│   │   │   ├── AppHaptics.swift
│   │   │   ├── AppHapticsDecisions.swift
│   │   │   └── CopyFeedbackController.swift
│   │   ├── Integration/
│   │   │   ├── KeyVoxIPCBridge.swift
│   │   │   ├── KeyVoxTTSRequest.swift
│   │   │   └── KeyVoxKeyboardBridge.swift
│   │   ├── KeyVoxSpeak/
│   │   │   ├── KeyVoxSpeakIntroController.swift
│   │   │   └── TTSPurchaseController.swift
│   │   ├── Lifecycle/
│   │   │   ├── AppDelegate.swift
│   │   │   ├── AppSceneDelegate.swift
│   │   │   └── KeyVoxiOSApp.swift
│   │   ├── LiveActivity/
│   │   │   ├── KeyVoxSessionLiveActivityAttributes.swift
│   │   │   └── KeyVoxSessionLiveActivityCoordinator.swift
│   │   ├── Onboarding/
│   │   │   ├── OnboardingDownloadNetworkMonitor.swift
│   │   │   ├── OnboardingKeyboardAccessProbe.swift
│   │   │   ├── OnboardingKeyboardTourHandoffState.swift
│   │   │   ├── OnboardingKeyboardTourState.swift
│   │   │   ├── OnboardingMicrophonePermissionController.swift
│   │   │   ├── OnboardingSetupState.swift
│   │   │   ├── OnboardingStore.swift
│   │   │   └── RuntimeFlags.swift
│   │   ├── Presentation/
│   │   │   ├── InlineWarningRules.swift
│   │   │   └── KeyVoxSpeakFlowRules.swift
│   │   ├── Routing/
│   │   │   ├── AppLaunchRouteStore.swift
│   │   │   ├── KeyVoxURLRoute.swift
│   │   │   └── KeyVoxURLRouter.swift
│   │   ├── Shortcuts/
│   │   │   ├── KeyVoxSpeakShortcutIntent.swift
│   │   │   └── KeyVoxSpeakShortcutsProvider.swift
│   │   ├── Stats/
│   │   │   └── WeeklyWordStatsStore.swift
│   │   └── iCloud/
│   │       ├── AppSettingsStore.swift
│   │       ├── KeyVoxPlaybackVoice.swift
│   │       ├── UserDefaultsKeys.swift
│   │       ├── WeeklyWordStatsCloudSync.swift
│   │       ├── CloudSyncCoordinator.swift
│   │       ├── KeyVoxiCloudKeys.swift
│   │       └── KeyVoxiCloudPayloads.swift
│   ├── Core/
│   │   ├── Audio/
│   │   │   ├── AudioBluetoothRoutePolicy.swift
│   │   │   ├── LiveInputSignalState.swift
│   │   │   ├── AudioRecorder.swift
│   │   │   ├── AudioRecorder+Session.swift
│   │   │   ├── AudioRecorder+StopPipeline.swift
│   │   │   └── AudioRecorder+Streaming.swift
│   │   ├── ModelDownloader/
│   │   │   ├── DictationModelCatalog.swift
│   │   │   ├── InstalledDictationModelLocator.swift
│   │   │   ├── ModelBackgroundDownloadCoordinator.swift
│   │   │   ├── ModelBackgroundDownloadJob.swift
│   │   │   ├── ModelBackgroundDownloadJobStore.swift
│   │   │   ├── ModelDownloadBackgroundTasks.swift
│   │   │   ├── ModelDownloadURLs.swift
│   │   │   ├── ModelInstallManifest.swift
│   │   │   ├── ModelInstallState.swift
│   │   │   ├── ModelManager.swift
│   │   │   ├── ModelManager+InstallLifecycle.swift
│   │   │   ├── ModelManager+Support.swift
│   │   │   └── ModelManager+Validation.swift
│   │   ├── TTS/
│   │   │   ├── AudioModeCoordinator.swift
│   │   │   ├── PocketTTSAssetLocator.swift
│   │   │   ├── PocketTTSEngine.swift
│   │   │   ├── PocketTTSInstallManifest.swift
│   │   │   ├── PocketTTSModelCatalog.swift
│   │   │   ├── PocketTTSModelManager+InstallLifecycle.swift
│   │   │   ├── PocketTTSModelManager+Support.swift
│   │   │   ├── PocketTTSModelManager.swift
│   │   │   ├── TTSEngine.swift
│   │   │   ├── TTSPreviewPlayer.swift
│   │   │   ├── TTSReplayCache.swift
│   │   │   ├── TTSSystemPlaybackController.swift
│   │   │   ├── TTSManager/
│   │   │   │   ├── TTSManager.swift
│   │   │   │   ├── TTSManager+AppLifecycle.swift
│   │   │   │   ├── TTSManager+Playback.swift
│   │   │   │   ├── TTSManager+RuntimeUnload.swift
│   │   │   │   ├── TTSManager+State.swift
│   │   │   │   ├── TTSManager+SystemPlayback.swift
│   │   │   │   └── TTSManagerPolicy.swift
│   │   │   └── TTSPlaybackCoordinator/
│   │   │       ├── TTSPlaybackCoordinator.swift
│   │   │       ├── TTSPlaybackCoordinator+Lifecycle.swift
│   │   │       ├── TTSPlaybackCoordinator+Progress.swift
│   │   │       ├── TTSPlaybackCoordinator+Scheduling.swift
│   │   │       └── TTSPlaybackCoordinatorBufferingPolicy.swift
│   │   └── Transcription/
│   │       ├── DictationService.swift
│   │       ├── InterruptedCaptureRecovery.swift
│   │       ├── InterruptedCaptureRecoveryStore.swift
│   │       ├── SessionPolicy.swift
│   │       ├── TranscriptionManager.swift
│   │       ├── TranscriptionManager+InterruptedCaptureRecovery.swift
│   │       └── TranscriptionManager+SessionLifecycle.swift
│   ├── Info.plist
│   ├── KeyVoxiOS.entitlements
│   ├── Resources/
│   │   ├── Assets.xcassets/
│   │   ├── Kanit-Light.ttf
│   │   ├── Kanit-Medium.ttf
│   │   ├── KeyVoxSpeak.storekit
│   │   ├── ReturnToHost.mov
│   │   ├── TTSVoicePreviews/
│   │   └── keyvox.icon/
│   ├── Views/
│   │   ├── AppRootView.swift
│   │   ├── ContainingAppTab.swift
│   │   ├── MainTabView.swift
│   │   ├── PlaybackPreparationView.swift
│   │   ├── ReturnToHostView.swift
│   │   ├── SettingsTabView/
│   │   │   ├── SettingsRow.swift
│   │   │   ├── SettingsTabView+About.swift
│   │   │   ├── SettingsTabView+General.swift
│   │   │   ├── SettingsTabView+Models.swift
│   │   │   ├── SettingsTabView+TTS.swift
│   │   │   └── SettingsTabView.swift
│   │   ├── StyleTabView.swift
│   │   ├── ThirdPartyNoticesView.swift
│   │   ├── Components/
│   │   │   ├── App/
│   │   │   │   ├── AppActionButton.swift
│   │   │   │   ├── AppCard.swift
│   │   │   │   ├── AppIconTile.swift
│   │   │   │   ├── AppScrollMetrics.swift
│   │   │   │   ├── AppScrollScreen.swift
│   │   │   │   ├── AppTheme.swift
│   │   │   │   ├── AppTintedScrollIndicator.swift
│   │   │   │   ├── AppTintedScrollView.swift
│   │   │   │   └── AppToolbarContent.swift
│   │   │   ├── AutoFocusTextField.swift
│   │   │   ├── DeletionConfirmation.swift
│   │   │   ├── InlineWarningRow.swift
│   │   │   ├── LogoBarView.swift
│   │   │   ├── LoopingVideoPlayer.swift
│   │   │   ├── ModelDownloadProgress.swift
│   │   │   ├── NativeActivityIndicator.swift
│   │   │   ├── PlaybackVoicePickerMenu.swift
│   │   ├── DictionaryTabView/
│   │   │   ├── DictionaryEntryRowView.swift
│   │   │   ├── DictionaryFloatingAddButton.swift
│   │   │   ├── DictionarySortMode.swift
│   │   │   ├── DictionaryTabView.swift
│   │   │   ├── DictionaryWordEditorMode.swift
│   │   │   └── DictionaryWordEditorView.swift
│   │   ├── HomeTabView/
│   │   │   ├── HomeTabView.swift
│   │   │   ├── LastTranscriptionCardView.swift
│   │   │   └── TTS/
│   │   │       ├── HomeTabView+TTS.swift
│   │   │       ├── HomeTabView+TTSPresentation.swift
│   │   │       ├── HomeTabView+TTSTranscript.swift
│   │   │       ├── HomeTabView+TTSTransport.swift
│   │   │       └── TTSReplayScrubber.swift
│   │   ├── KeyVoxSpeak/
│   │   │   ├── KeyVoxSpeakIntroSheetView.swift
│   │   │   ├── KeyVoxSpeakInstallCardView.swift
│   │   │   ├── KeyVoxSpeakSceneAView.swift
│   │   │   ├── KeyVoxSpeakSceneBView.swift
│   │   │   ├── KeyVoxSpeakSceneCView.swift
│   │   │   ├── KeyVoxSpeakSheetView.swift
│   │   │   ├── KeyVoxSpeakUnlockScene.swift
│   │   │   └── TTSUnlockSheetView.swift
│   │   ├── Onboarding/
│   │   │   ├── OnboardingStepRow.swift
│   │   │   ├── OnboardingFlowView.swift
│   │   │   ├── OnboardingLogoPopInSequence.swift
│   │   │   ├── OnboardingSetupScreen.swift
│   │   │   ├── OnboardingWelcomeScreen.swift
│   │   │   └── Tour/
│   │   │       ├── OnboardingKeyboardTourSceneAView.swift
│   │   │       ├── OnboardingKeyboardTourSceneBView.swift
│   │   │       ├── OnboardingKeyboardTourSceneCView.swift
│   │   │       ├── OnboardingKeyboardTourScreen.swift
│   │   │       └── KeyboardMenuSequence.swift
├── KeyVox Keyboard/
│   ├── App/
│   │   ├── KeyboardContainingAppLauncher.swift
│   │   ├── KeyboardViewController+Debug.swift
│   │   ├── KeyboardViewController+PresentationLifecycle.swift
│   │   └── KeyboardViewController.swift
│   ├── Core/
│   │   ├── Dictation/
│   │   │   ├── AudioIndicatorDriver.swift
│   │   │   ├── KeyboardCallObserver.swift
│   │   │   └── KeyboardDictationController.swift
│   │   ├── Feedback/
│   │   │   ├── KeyboardHapticsSettingsStore.swift
│   │   │   ├── KeyboardInteractionHaptics.swift
│   │   │   └── KeyboardKeypressHaptics.swift
│   │   ├── Input/
│   │   │   ├── KeyboardCursorTrackpadSupport.swift
│   │   │   ├── KeyboardSpecialKeyInteractionSupport.swift
│   │   │   └── KeyboardTextInputController.swift
│   │   ├── Text/
│   │   │   ├── KeyboardCapsLockStateStore.swift
│   │   │   ├── KeyboardDictionaryCasingStore.swift
│   │   │   ├── KeyboardInsertionCapitalizationHeuristics.swift
│   │   │   └── KeyboardInsertionSpacingHeuristics.swift
│   │   ├── Transport/
│   │   │   ├── KeyboardIPCManager.swift
│   │   │   ├── KeyboardTransportDisplayState.swift
│   │   │   └── KeyboardTTSController.swift
│   │   ├── KeyboardLayoutGeometry.swift
│   │   ├── KeyboardModelAvailability.swift
│   │   ├── KeyboardState.swift
│   │   ├── KeyboardStyle.swift
│   │   ├── KeyboardSymbolLayout.swift
│   │   ├── KeyboardToolbarMode.swift
│   │   └── KeyboardTypography.swift
│   ├── Info.plist
│   ├── KeyVoxKeyboard.entitlements
│   └── Views/
│       ├── FullAccessView.swift
│       ├── KeyboardInputHostView.swift
│       ├── KeyboardRootView.swift
│       └── Components/
│           ├── KeyboardCancelButton.swift
│           ├── KeyboardCapsLockButton.swift
│           ├── KeyboardHitTargetButton.swift
│           ├── KeyboardKeyGridView.swift
│           ├── KeyboardKeyPopupView.swift
│           ├── KeyboardKeyView.swift
│           ├── KeyboardLogoBarView.swift
│           ├── KeyboardRoundedBorderRenderer.swift
│           └── KeyboardSpeakButton.swift
├── KeyVox Share/
│   ├── Base.lproj/
│   │   └── MainInterface.storyboard
│   ├── ContentExtractor/
│   │   ├── KeyVoxShareContentExtractor.swift
│   │   ├── KeyVoxShareContentExtractorDiagnostics.swift
│   │   ├── KeyVoxShareImageItemLoader.swift
│   │   ├── KeyVoxShareItemProviderLoader.swift
│   │   ├── KeyVoxShareOCRPipeline.swift
│   │   ├── KeyVoxShareOCRRenderingPolicy.swift
│   │   ├── KeyVoxSharePDFExtractor.swift
│   │   ├── KeyVoxShareTextSupport.swift
│   │   └── KeyVoxShareWebExtractor.swift
│   ├── Views/
│   │   └── ShareFeedbackView.swift
│   ├── Info.plist
│   ├── KeyVoxShare.entitlements
│   ├── KeyVoxShareAppLauncher.swift
│   ├── KeyVoxShareBridge.swift
│   └── ShareViewController.swift
├── KeyVox Widget/
│   ├── AppIntent.swift
│   ├── Assets.xcassets/
│   ├── Info.plist
│   ├── KeyVox Widget.entitlements
│   ├── KeyVox_WidgetBundle.swift
│   └── KeyVox_WidgetLiveActivity.swift
├── KeyVoxiOSTests/
│   ├── App/
│   │   ├── AppUpdatePolicyEvaluatorTests.swift
│   │   ├── AppHapticsDecisionTests.swift
│   │   ├── AppSettingsStoreTests.swift
│   │   ├── CloudSyncCoordinatorTests.swift
│   │   ├── KeyVoxSessionLiveActivityCoordinatorTests.swift
│   │   ├── KeyVoxURLRouterTests.swift
│   │   ├── KeyVoxURLRouteTests.swift
│   │   ├── ModelManagerTests.swift
│   │   ├── OnboardingKeyboardAccessProbeTests.swift
│   │   ├── OnboardingKeyboardTourHandoffStateTests.swift
│   │   ├── OnboardingKeyboardTourStateTests.swift
│   │   ├── OnboardingMicrophonePermissionControllerTests.swift
│   │   ├── OnboardingDownloadNetworkMonitorTests.swift
│   │   ├── OnboardingSetupStateTests.swift
│   │   ├── OnboardingStoreTests.swift
│   │   ├── SharedPathsTests.swift
│   │   ├── TTSPurchaseControllerTests.swift
│   │   ├── WeeklyWordStatsCloudSyncTests.swift
│   │   └── WeeklyWordStatsStoreTests.swift
│   ├── Core/
│   │   ├── Audio/
│   │   │   ├── AudioBluetoothRoutePolicyTests.swift
│   │   │   ├── AudioInputPreferenceResolverTests.swift
│   │   │   └── StoppedCaptureProcessorTests.swift
│   │   ├── Keyboard/
│   │   │   ├── KeyboardCursorTrackpadSupportTests.swift
│   │   │   ├── KeyboardDictationControllerTests.swift
│   │   │   ├── KeyboardInteractionHapticsTests.swift
│   │   │   ├── KeyboardToolbarModeTests.swift
│   │   │   ├── KeyboardTextInputControllerTests.swift
│   │   │   └── KeyboardViewControllerTests.swift
│   │   ├── TTS/
│   │   │   ├── TTSManager/
│   │   │   │   ├── TTSManagerLifecycleTests.swift
│   │   │   │   └── TTSManagerPolicyTests.swift
│   │   │   ├── PocketTTSEngineTests.swift
│   │   │   ├── TTSPlaybackCoordinatorBufferingPolicyTests.swift
│   │   │   └── TTSSystemPlaybackTests.swift
│   │   └── Transcription/
│   │       └── TranscriptionManagerTests.swift
│   └── KeyVoxiOSTests.swift
├── Launch Screen.storyboard
└── LaunchLogo.png

Packages/
├── KeyVoxCore/
│   ├── Sources/KeyVoxCore/
│   └── Tests/KeyVoxCoreTests/
└── KeyVoxTTS/
    ├── Package.swift
    ├── Sources/KeyVoxTTS/
    │   ├── CoreMLPredictionCompatibility.swift
    │   ├── KeyVoxPocketTTSRuntime/
    │   │   ├── KeyVoxPocketTTSComputeModeController.swift
    │   │   ├── KeyVoxPocketTTSRuntime.swift
    │   │   ├── KeyVoxPocketTTSRuntime+Assets.swift
    │   │   └── KeyVoxPocketTTSStreamGenerator.swift
    │   ├── KeyVoxTTSAssetLayout.swift
    │   ├── KeyVoxTTSAudioFrame.swift
    │   ├── KeyVoxTTSError.swift
    │   ├── KeyVoxTTSVoice.swift
    │   ├── PocketTTSAssetLoader.swift
    │   ├── PocketTTSChunkPlanner.swift
    │   ├── PocketTTSConstants.swift
    │   ├── PocketTTSFlowInference.swift
    │   ├── PocketTTSInferenceTypes.swift
    │   ├── PocketTTSInferenceUtilities.swift
    │   ├── PocketTTSKVCacheInference.swift
    │   ├── PocketTTSLogger.swift
    │   ├── PocketTTSMimiInference.swift
    │   ├── PocketTTSTextNormalizer.swift
    │   ├── SentencePieceModelParser.swift
    │   └── SentencePieceTokenizer.swift
    └── Tests/KeyVoxTTSTests/
        └── PocketTTSChunkPlannerTests.swift
```

## Current Runtime Map

### App Lifecycle and Composition

- `KeyVox iOS/App/Lifecycle/KeyVoxiOSApp.swift`
  - SwiftUI app entry point.
  - Injects all app-wide environment objects.
  - Registers model-download background tasks.
  - Handles scene activation/background callbacks for transcription recovery, model recovery, onboarding keyboard-tour arming, and shortcut-route consumption.
  - Consumes any cold-launch URL route that was captured before SwiftUI rendered and pre-presents `ReturnToHostView` without animation before routing `keyvoxios://record/start`.
- `KeyVox iOS/App/Composition/SharedPaths.swift`
  - Centralizes rooted app-group, cache, and install filesystem locations used by app-owned services.
- `KeyVox iOS/App/Shortcuts/KeyVoxSpeakShortcutIntent.swift`
  - App-owned `Speak Copied Text` App Intent for the official KeyVox Speak shortcut.
  - Stages the existing `keyvoxios://tts/start` route into shared app-group state and relies on the containing app to consume and route it on activation.
- `KeyVox iOS/App/Shortcuts/KeyVoxSpeakShortcutsProvider.swift`
  - Registers the KeyVox Speak App Shortcut phrases surfaced in the Shortcuts system.
- `KeyVox iOS/App/Lifecycle/AppDelegate.swift`
  - Receives background `URLSession` callbacks for model downloads and forwards them into `ModelManager`.
- `KeyVox iOS/App/Lifecycle/AppSceneDelegate.swift`
  - Captures cold-launch scene connection URLs before the first root render and forwards them into the launch-route store.
- `KeyVox iOS/App/Routing/AppLaunchRouteStore.swift`
  - Small launch-scoped routing owner for early cold-start URL presentation and later route consumption.
- `KeyVox iOS/App/Routing/KeyVoxURLRoute.swift`
  - Typed app route surface for cold-start recording and copied-text playback launches.
- `KeyVox iOS/App/Routing/KeyVoxURLRouter.swift`
  - App-owned URL parsing and route dispatch owner for record, TTS, and return-to-host flows.
- `KeyVox iOS/App/Composition/AppServiceRegistry.swift`
  - Main composition root.
  - Builds dictionary, onboarding, settings, weekly stats, app haptics, the shared app-tab router, Whisper, Parakeet, the active-provider router, post-processing, model, keyboard bridge, transcription, PocketTTS runtime services, the TTS unlock gate, the KeyVox Speak intro controller, the App Store update coordinator, iCloud sync, Live Activity, and URL-routing services.
  - Normalizes the persisted active provider back to a ready model when install state changes.
  - Normalizes copied-text playback voice selection when PocketTTS install state changes, but does not prewarm PocketTTS; playback owns runtime preparation and teardown.
- `app-update-policy.json`
  - Public minimum-supported-version manifest consumed by the iOS update service.
  - The App Store remains the latest-version source; this file only controls forced-update eligibility.
- `KeyVox iOS/App/AppUpdate/`
  - Isolated update module for App Store release lookup, policy-manifest fetch, version comparison, cached decision state, cold-launch reminder behavior, and App Store opening.
- `KeyVox iOS/App/KeyVoxSpeak/KeyVoxSpeakIntroController.swift`
  - App-owned post-onboarding KeyVox Speak intro owner.
  - Tracks whether the intro has been seen, whether the user has already used KeyVox Speak organically, the eligible-open counter for delayed presentation, and the development-only force-presentation path.
- `KeyVox iOS/App/KeyVoxSpeak/TTSPurchaseController.swift`
  - App-owned one-time unlock and daily-usage owner for copied-text playback.
  - Loads the placeholder StoreKit non-consumable product, owns purchase and restore flows, caches last-known unlock state, tracks two free new speaks per local day, and exposes the shared unlock-sheet presentation state.
- `KeyVox iOS/App/Presentation/KeyVoxSpeakFlowRules.swift`
  - Pure scene-selection and scene-fallback rules shared by the intro sheet, unlock sheet, and the Home help presentation path so branch coverage stays deterministic in tests.
- `KeyVox iOS/App/Presentation/InlineWarningRules.swift`
  - Pure warning-visibility rules shared by onboarding, KeyVox Speak setup, Home copied-text playback, and Settings install surfaces so Wi-Fi warning coverage stays deterministic in iOS tests.
- `KeyVox iOS/App/Stats/WeeklyWordStatsStore.swift`
  - App-owned local weekly usage aggregator consumed by Home, settings-adjacent surfaces, and Live Activity mirroring.
- `KeyVox iOS/App/Feedback/AppHaptics.swift`
  - App-owned UIKit haptic emitter injected through the SwiftUI environment.
- `KeyVox iOS/App/Feedback/AppHapticsDecisions.swift`
  - Pure decision helpers for onboarding step completion, tab selection, edge-swipe, session-toggle, and dictionary-save haptics.

### Onboarding and Root Routing

- `KeyVox iOS/Views/AppRootView.swift`
  - Root router for launch hold vs return-to-host vs onboarding overlay vs main app.
  - Keeps `MainTabView` mounted under the onboarding overlay so onboarding can fade into the live shell without re-rooting the scene tree.
  - Suppresses `ReturnToHostView` whenever onboarding is active or was just completed during the same launch.
  - Also owns post-onboarding KeyVox Speak intro-sheet presentation so the intro can only appear on the true `.main` route, never over onboarding, return-to-host, or playback-preparation flows.
  - Also owns the system update alert presentation and keeps update prompts scoped to the `.main` route so launch-hold, onboarding, return-to-host, and playback-preparation flows remain uninterrupted.
- `KeyVox iOS/App/Onboarding/OnboardingStore.swift`
  - Persisted onboarding state, welcome completion, pending keyboard-tour handoff, and force-onboarding launch behavior.
  - Also owns launch-scoped routing flags for welcome progression, pending-tour arming, persisted-tour ignore behavior, and post-completion suppression.
  - Records and arms the keyboard-tour handoff once app-level prerequisites say the model is ready, microphone access is granted, and the keyboard is enabled.
- `KeyVox iOS/Views/Onboarding/OnboardingFlowView.swift`
  - Ordered onboarding router: welcome -> setup -> keyboard tour.
- `KeyVox iOS/Views/Onboarding/OnboardingSetupScreen.swift`
  - Model download, microphone permission, and keyboard-settings handoff screen.
  - Gates keyboard setup until both the model is ready and microphone access has been granted, while allowing those two setup tasks to proceed in parallel.
  - Records the pending keyboard-tour handoff before opening Settings and reconciles completed app-level requirements on return from Settings or model completion.
  - Uses app-owned haptics for warning/success step feedback.
- `KeyVox iOS/Views/Onboarding/OnboardingStepRow.swift`
  - Shared onboarding setup card row with step state, optional action button, trailing status content, and extra content below the description.
  - Keeps the onboarding setup presentation consistent while the screen owns step-specific button state and copy.
- `KeyVox iOS/Views/Components/ModelDownloadProgress.swift`
  - Reusable onboarding download progress bar with the app accent styling and an optional percent label.
- `KeyVox iOS/Views/KeyVoxSpeak/TTSUnlockSheetView.swift`
  - Thin unlock-mode wrapper around the shared KeyVox Speak sheet surface used by the copied-text playback purchase flow.
- `KeyVox iOS/Views/Onboarding/Tour/OnboardingKeyboardTourScreen.swift`
  - Full-screen post-Settings handoff screen that autofocuses a text field and keeps the input pinned above the keyboard.
  - Advances through three tour scenes (`a`, `b`, `c`) and only enables the final completion action after the KeyVox keyboard has been shown and a first non-empty transcription has completed.
  - Completes onboarding directly when the final `Finish` action runs.
- `KeyVox iOS/App/Onboarding/OnboardingKeyboardTourState.swift`
  - Small state machine that drives tour scene A/B/C progression and completion gating.
- `KeyVox iOS/App/Onboarding/OnboardingKeyboardTourHandoffState.swift`
  - Small app-level gate for starting the keyboard tour once the model is ready, microphone access is granted, and the keyboard is enabled in system settings.
- `KeyVox iOS/App/Onboarding/OnboardingKeyboardAccessProbe.swift`
  - App-side probe for keyboard enablement, keyboard presentation, and keyboard-reported Full Access confirmation.
- `KeyVox iOS/App/Onboarding/OnboardingMicrophonePermissionController.swift`
  - App-side microphone permission surface for onboarding.
- `KeyVox iOS/App/Onboarding/OnboardingDownloadNetworkMonitor.swift`
  - Cellular vs non-cellular detection for onboarding download copy.
- `KeyVox iOS/App/Onboarding/RuntimeFlags.swift`
  - Reads `KEYVOX_FORCE_ONBOARDING`, `KEYVOX_BYPASS_TTS_FREE_SPEAK_LIMIT`, and `KEYVOX_FORCE_KEYVOX_SPEAK_INTRO`.

### Shared State, IPC, and Session Surfaces

- `KeyVox iOS/App/Integration/KeyVoxIPCBridge.swift`
  - Source of truth for App Group defaults keys, TTS playback state and request state, replay-related shared request storage, shortcut-staged pending route storage, keyboard onboarding presentation/access timestamps, shared live-meter file transport, shared forced-update state, and Darwin notification names.
- `KeyVox iOS/App/Integration/KeyVoxTTSRequest.swift`
  - Dependency-free shared copied-text playback request model and enums used by both the containing app and share extension to keep the JSON handoff contract compile-time safe.
- `KeyVox iOS/App/iCloud/UserDefaultsKeys.swift`
  - Includes the app-owned cached TTS unlock state plus the local day token and free-speak usage count used by the phase-one copied-text playback gate.
  - Also includes the post-onboarding KeyVox Speak intro keys for seen-state, feature-used state, the delayed eligible-open counter, and the app-owned cached update decision keys used for cold-launch reminders.
- `KeyVox iOS/App/iCloud/KeyVoxPlaybackVoice.swift`
  - Dependency-free shared playback-voice catalog used by both `AppSettingsStore` and the share extension when resolving canonical TTS voice IDs and display names.
- `KeyVox iOS/App/Integration/KeyVoxKeyboardBridge.swift`
  - App-side IPC endpoint for start/stop/cancel/disable-session commands and extension-facing state publishing.
- `KeyVox iOS/App/LiveActivity/KeyVoxSessionLiveActivityCoordinator.swift`
  - App-side owner that mirrors session state and weekly-word count into the widget extension through ActivityKit.
- `KeyVox iOS/App/LiveActivity/KeyVoxSessionLiveActivityAttributes.swift`
  - Shared ActivityKit attributes and content state.
- `KeyVox Widget/AppIntent.swift`
  - `EndSessionIntent` that posts the shared disable-session Darwin notification.
- `KeyVox Widget/KeyVox_WidgetLiveActivity.swift`
  - Lock screen and Dynamic Island UI for the live activity.

### Model Installation and Recovery

- `KeyVox iOS/Core/ModelDownloader/ModelManager.swift`
  - Observable owner of per-model install state, active-install gating, user-facing download/delete/repair actions, and relaunch recovery.
  - Enforces one active download/install at a time and keeps provider selection persistence outside the model manager.
- `KeyVox iOS/Core/ModelDownloader/DictationModelCatalog.swift`
  - iOS-local model descriptor catalog for `Whisper Base` and `Parakeet TDT v3`, including artifact metadata and rooted install layout rules.
- `KeyVox iOS/Core/ModelDownloader/InstalledDictationModelLocator.swift`
  - Rooted install/staging locator plus legacy Whisper migration and lightweight installed-model resolution helpers for Whisper and Parakeet.
- `KeyVox iOS/Core/ModelDownloader/ModelBackgroundDownloadCoordinator.swift`
  - Background `URLSession` owner for staged model artifact downloads.
- `KeyVox iOS/Core/ModelDownloader/ModelBackgroundDownloadJob.swift`
  - Durable representation of per-model, per-artifact progress and finalization state.
- `KeyVox iOS/Core/ModelDownloader/ModelBackgroundDownloadJobStore.swift`
  - Persistence seam for the background download job file.
- `KeyVox iOS/Core/ModelDownloader/ModelManager+InstallLifecycle.swift`
  - Finalization, extraction, manifest writes, staged-file cleanup, model-specific warmup/preload sequencing, and safe delete/repair coordination after downloads complete.
- `KeyVox iOS/Core/ModelDownloader/ModelManager+Validation.swift`
  - Strict readiness validation for rooted installed artifacts and install manifests.
- `KeyVox iOS/Core/ModelDownloader/ModelDownloadBackgroundTasks.swift`
  - App-side background repair task registration and scheduling.

### Copied Text Playback and PocketTTS

- `KeyVox iOS/Core/TTS/PocketTTSModelCatalog.swift`
  - PocketTTS shared-runtime and per-voice artifact metadata plus approximate voice download sizes used by settings.
- `KeyVox iOS/Core/TTS/PocketTTSModelManager.swift`
  - Observable owner of shared PocketTTS Core ML install state and independent per-voice install state.
  - Keeps the public install-state surface, readiness queries, and queue state for the follow-up voice install flow.
- `KeyVox iOS/Core/TTS/PocketTTSModelManager+InstallLifecycle.swift`
  - Install, repair, delete, and queued follow-up voice install sequencing for PocketTTS runtime and voice assets.
- `KeyVox iOS/Core/TTS/PocketTTSModelManager+Support.swift`
  - Shared staging, manifest, filesystem replacement, download, and install-helper utilities used by the PocketTTS manager lifecycle split.
- `KeyVox iOS/Core/TTS/PocketTTSEngine.swift`
  - App-owned streaming TTS engine wrapper around the local PocketTTS runtime.
  - Owns the app-side runtime injection seam, explicit prepare/unload lifecycle, prepared-runtime compute-mode guards, and debug load/unload visibility.
- `KeyVox iOS/Core/TTS/TTSPlaybackCoordinator/`
  - Split playback transport owner for deterministic startup runway, background-safe continuation, replay capture, pause and resume, metering, progress publishing, playback scheduling, and preserved-TTS route-family selection.
- `KeyVox iOS/Core/TTS/TTSManager/`
  - Split high-level copied-text playback owner for request lifecycle, preparation progress, replay state, paused replay restoration, lifecycle observation, system playback command routing, App Group TTS state publishing, and the consume-on-success free-speak hook used by phase-one monetization.
  - Owns user-configured Speak Timeout behavior by unloading the PocketTTS runtime immediately, after the selected warm-retention window, or never after generated playback has demand-warmed the runtime.
- `KeyVox iOS/Core/TTS/TTSSystemPlaybackController.swift`
  - Public `MediaPlayer` integration owner for lock screen and Control Center now-playing metadata, replay scrubber command exposure, and remote transport command wiring.
- `KeyVox iOS/Core/TTS/TTSReplayCache.swift`
  - Persistence layer for the last replayable rendered playback and paused replay sample offsets.
- `KeyVox iOS/Core/TTS/TTSPreviewPlayer.swift`
  - Shared bundled-preview playback owner used by both the Voice Model settings section and the KeyVox Speak intro demo.
- `KeyVox iOS/Core/TTS/AudioModeCoordinator.swift`
  - Single arbitration surface for dictation-versus-TTS transitions, including pause/resume/replay transport.
  - Also enforces the copied-text playback entitlement gate for every new TTS start path before playback begins.
- `KeyVox iOS/Views/PlaybackPreparationView.swift`
  - Cold-launch playback-preparation screen shown before returning to the host app.

### Audio and Transcription Runtime

- `KeyVox iOS/Core/Audio/AudioRecorder.swift`
  - Public recorder and monitoring surface.
  - Tracks session warmth, meter state, and last capture facts.
- `KeyVox iOS/Core/Audio/AudioRecorder+Session.swift`
  - Owns `AVAudioSession` configuration, warm-engine setup, route-recovery retries, interruption observation, and monitoring lifecycle.
- `KeyVox iOS/Core/Audio/AudioRecorder+Streaming.swift`
  - Owns input-buffer conversion, capture accumulation, and live meter/signal-state updates.
- `KeyVox iOS/Core/Audio/AudioBluetoothRoutePolicy.swift`
  - Shared preserved-TTS Bluetooth route-family policy.
  - Maps the built-in microphone setting to the playback route family without changing the recorder baseline warm-session contract.
- `KeyVox iOS/Core/Audio/AudioRecorder+StopPipeline.swift`
  - Owns stop-time and interruption-time capture finalization, produces cleaned `StoppedCapture` values, and rejects silence before inference.
- `KeyVox iOS/Core/Transcription/DictationService.swift`
  - iOS-local transcription-service abstraction used by the runtime manager.
- `KeyVox iOS/Core/Transcription/TranscriptionManager.swift`
  - Primary iOS runtime state machine and dictation owner.
- `KeyVox iOS/Core/Transcription/TranscriptionManager+SessionLifecycle.swift`
  - Idle shutdown, user-configured session timeout scheduling including Never, deferred disable-session handling, and watchdog cleanup.
- `KeyVox iOS/Core/Transcription/TranscriptionManager+InterruptedCaptureRecovery.swift`
  - Interrupted-capture staging and recovery on app reactivation.
- `KeyVox iOS/Core/Transcription/InterruptedCaptureRecoveryStore.swift`
  - Durable storage for interrupted captures that need to be resumed later.
- `KeyVox iOS/Core/Transcription/SessionPolicy.swift`
  - Session safety thresholds and timeout policy.

### App UI

- `KeyVox iOS/Views/MainTabView.swift`
  - Four-tab container: Home, Dictionary, Style, Settings.
  - Adds edge-swipe tab navigation on top of `TabView` and still owns the unlock-sheet presentation surface for the TTS monetization flow.
- `KeyVox iOS/Views/ContainingAppTab.swift`
  - Source of truth for app-tab ordering, titles, and previous/next navigation.
- `KeyVox iOS/Views/HomeTabView/`
  - Filesystem-grouped Home feature surface.
  - `HomeTabView.swift` owns the weekly stats card, last transcription card, Home-level state, and debug-only diagnostics.
  - `KeyVox iOS/Views/Components/App/AppTintedScrollView.swift`, `KeyVox iOS/Views/Components/App/AppScrollMetrics.swift`, and `KeyVox iOS/Views/Components/App/AppTintedScrollIndicator.swift` own the reusable hidden-native-scroll-indicator wrapper and custom tinted scroll thumb used by Home scrollable text surfaces.
  - `TTS/HomeTabView+TTS.swift` owns the main copied-text playback card layout, first-line title/help alignment, loading-spinner handoff, and progress-slot rendering.
  - `TTS/HomeTabView+TTSTranscript.swift` owns transcript toggle behavior, staged expanded transcript presentation, transcript copy affordance, idle transcript dismissal, and the Home-specific content passed into the shared tinted scroller.
  - `TTS/HomeTabView+TTSTransport.swift` owns the live transport ring, replay transport button, replay scrubber gating, badge state, status copy, playback error presentation, and the idle monetization messaging for remaining free speaks or locked state.
  - `TTS/HomeTabView+TTSPresentation.swift` owns preparation presentation state, loading-spinner/progress thresholds, warm-runtime indicator state, button titles, shared installed-voice selection binding, the hidden Home voice-picker shortcut, the unlock-title fallback, the question-mark KeyVox Speak help presentation selection, and Home-scoped TTS actions.
  - `TTS/TTSReplayScrubber.swift` owns the replay timeline scrubber view.
- `KeyVox iOS/App/Feedback/CopyFeedbackController.swift`
  - Shared app-scoped copy interaction state for pasteboard writes, success haptics, copied-state timing, and reset behavior used by multiple UI surfaces without forcing them into one visual component.
- `KeyVox iOS/Views/HomeTabView/LastTranscriptionCardView.swift`
  - Latest transcription card plus its shared tinted transcription scroller and trailing copy action, backed by the shared copy-feedback interaction controller instead of view-local pasteboard logic.
- `KeyVox iOS/Views/Components/PlaybackVoicePickerMenu.swift`
  - Reusable installed-voice picker menu used by both the Settings Voice Model section and the hidden Home copied-text playback shortcut.
- `KeyVox iOS/Views/Components/InlineWarningRow.swift`
  - Shared yellow warning row treatment for inline caution copy, including the reused cellular-download warning shown across onboarding, KeyVox Speak setup, Home copied-text playback, and Settings model surfaces.
- `KeyVox iOS/Views/Components/NativeActivityIndicator.swift`
  - UIKit-backed spinner used when SwiftUI's default progress presentation is not visually centered enough for fixed-size controls.
- `KeyVox iOS/Views/ThirdPartyNoticesView.swift`
  - Non-dismissable legal notices sheet with the shared top-right close affordance, rendering the bundled repo-root `THIRD_PARTY_NOTICES.md` markdown inside app-styled readable text.
- `KeyVox iOS/Views/KeyVoxSpeak/`
  - Dedicated feature folder for the shared KeyVox Speak presentation surface.
  - `KeyVoxSpeakSheetView.swift` owns the shared shell, pager state, pinned bottom CTA area, unlock action, restore action, and mode-specific chrome.
  - `KeyVoxSpeakSceneAView.swift`, `KeyVoxSpeakSceneBView.swift`, and `KeyVoxSpeakSceneCView.swift` own the three swipeable pages, matching the onboarding-scene split pattern.
  - `KeyVoxSpeakUnlockScene.swift` owns the shared unlock-mode scene model so unlock copy and CTA rules stay centralized across wrappers.
  - `KeyVoxSpeakInstallCardView.swift` owns the shared PocketTTS setup card used by scene C, including shared-model install, featured-voice install, progress, and repair actions.
  - `KeyVoxSpeakIntroSheetView.swift` is the thin post-onboarding intro wrapper around the shared sheet.
  - `TTSUnlockSheetView.swift` is the thin unlock-mode wrapper around the same shared sheet for Home and Settings purchase entry points.
- `KeyVox iOS/Views/DictionaryTabView/DictionaryTabView.swift`
  - Dictionary UI plus editor flow built around the shared `AutoFocusTextField`, feature-local sort state, and the app-owned `KeyboardObserver`.
- `KeyVox iOS/Views/StyleTabView.swift`
  - User-facing dictation style toggles.
- `KeyVox iOS/Views/SettingsTabView/SettingsTabView.swift`
  - Top-level settings composition, shared disclosure state, third-party notices sheet presentation, and cross-section coordination for the extracted settings surface.
- `KeyVox Keyboard/Core/KeyboardToolbarMode.swift`
  - Central warning-priority resolver for the keyboard toolbar.
  - Also maps shared forced-update state into the existing warning surface so the branded toolbar does not remain active while an update is required.
- `KeyVox iOS/Views/SettingsTabView/SettingsTabView+General.swift`
  - Session timeout, Speak Timeout, Live Activities, keyboard haptics, and audio preference sections extracted from the settings root view.
- `KeyVox iOS/Views/SettingsTabView/SettingsTabView+Models.swift`
  - Release-facing `Dictation Model` section, provider selection, per-model install actions, and not-installed size labels.
- `KeyVox iOS/Views/SettingsTabView/SettingsTabView+TTS.swift`
  - Release-facing `KeyVox Speak` section for PocketTTS runtime install state, per-voice install actions, voice previews, playback voice selection, and the `KeyVox Speak Unlimited` unlock row placed beneath the model section, including the shared installed-voice picker menu.
- `KeyVox iOS/Views/SettingsTabView/SettingsTabView+About.swift`
  - Rate-and-review, GitHub support, restore-purchases, version footer, and third-party notices launcher extracted from the settings root view.
- `KeyVox iOS/Views/Components/DeletionConfirmation.swift`
  - Shared destructive-delete confirmation component used by the settings model sections.
- `KeyVox iOS/Views/ReturnToHostView.swift`
  - One-time post-cold-launch host-return guidance screen during a live session handoff.
  - Includes a top-right dismiss control for returning to the Home surface without waiting for an external host-app switch.

### Keyboard Extension

- `KeyVox Keyboard/App/KeyboardViewController.swift`
  - Extension controller and top-level keyboard surface owner.
  - Owns toolbar mode switching, call-aware warning presentation, full-access instructions presentation, warm/cold app launch behavior, onboarding presentation reporting, Caps Lock, symbol page, trackpad mode, and insertion.
- `KeyVox Keyboard/App/KeyboardContainingAppLauncher.swift`
  - Responder-chain URL launcher used by the extension whenever it needs to wake the containing app for cold dictation or copied-text playback handoff.
- `KeyVox Keyboard/App/KeyboardViewController+PresentationLifecycle.swift`
  - Presentation-tree creation, per-presentation binding, teardown, and extension-host lifecycle observation.
  - Pauses the active presentation during host backgrounding, refreshes it on host foregrounding, and tears the tree down only for real dismissal and globe-key presentation swaps.
  - Keeps the keyboard view hierarchy disposable across globe-key presentation swaps.
- `KeyVox Keyboard/App/KeyboardViewController+Debug.swift`
  - Debug-only presentation lifecycle counters and controller test hooks.
- `KeyVox Keyboard/Core/Dictation/KeyboardCallObserver.swift`
  - Tracks active phone-call state through `CallKit` so the keyboard can warn before dictation is attempted during a call.
- `KeyVox Keyboard/Core/Dictation/KeyboardDictationController.swift`
  - Keyboard-local state machine for shared recording state and app launch handoff.
- `KeyVox Keyboard/Core/Transport/KeyboardTTSController.swift`
  - Keyboard-local copied-text playback transport owner that stages TTS requests and reacts to shared TTS state.
- `KeyVox Keyboard/Core/Feedback/KeyboardInteractionHaptics.swift`
  - Keyboard-owned interaction haptic coordinator that respects the extension’s local haptics preference.
- `KeyVox Keyboard/Core/Transport/KeyboardIPCManager.swift`
  - Extension-side App Group/Darwin client plus stale shared-state reconciliation.
- `KeyVox Keyboard/Core/Input/KeyboardTextInputController.swift`
  - Host-app text insertion, key dispatch, double-space period behavior, and cursor movement.
- `KeyVox Keyboard/Core/Input/KeyboardCursorTrackpadSupport.swift`
  - Cursor-trackpad delta handling used by the space-bar trackpad interaction.
- `KeyVox Keyboard/Core/Text/KeyboardInsertionSpacingHeuristics.swift`
  - Conservative smart-spacing before inserted dictation text.
- `KeyVox Keyboard/Core/Text/KeyboardInsertionCapitalizationHeuristics.swift`
  - Host-text capitalization preservation for direct typing and inserted dictation paths.
- `KeyVox Keyboard/Core/KeyboardModelAvailability.swift`
  - Lightweight rooted-install gate used by the extension toolbar for Whisper and Parakeet availability.
- `KeyVox Keyboard/Core/KeyboardLayoutGeometry.swift`
  - Unified row-geometry helper for keyboard-specific sizing rules that should not live in `KeyboardRootView` or `KeyboardKeyGridView`.
  - Owns top-row accessory alignment plus row 3 and row 4 live width calculations driven from the measured key grid.
- `KeyVox Keyboard/Views/KeyboardRootView.swift`
  - Stable keyboard chrome and key grid.
  - Hosts the branded toolbar row and the shared warning overlay for Full Access, microphone permission, and active phone calls.
- `KeyVox Keyboard/Views/Components/KeyboardSpeakButton.swift`
  - Keyboard speak control used for copied-text playback transport in the top-row accessory area.
- `KeyVox Keyboard/Views/Components/KeyboardLogoBarView.swift`
  - Proprietary keyboard logo-bar rendering and animation surface protected by the KeyVox branding license.
  - Intentionally limited to visual drawing, layout, and animation behavior only.
- `KeyVox Keyboard/Core/Transport/KeyboardTransportDisplayState.swift`
  - Non-visual keyboard logo transport state, accessibility labels, and playback/dictation presentation inputs kept separate from the proprietary logo-bar rendering file.
- `KeyVox Keyboard/Views/Components/KeyboardKeyGridView.swift`
  - Builds the symbol-key rows, keeps the first two rows equal-width, and delegates row 3 and row 4 special-key sizing to the unified keyboard layout helper.
- `KeyVox Keyboard/Views/FullAccessView.swift`
  - Full-screen keyboard-only instructional view shown when the user needs to enable Full Access.

### Tests

- `KeyVoxiOSTests/App/`
  - Onboarding state, onboarding keyboard-tour state, keyboard access probing, app haptics decisions, settings persistence, shared paths, iCloud sync, weekly stats, Live Activity coordination, URL routing, and model manager behavior across rooted Whisper migration and Parakeet installs.
- `KeyVoxiOSTests/App/TTSPurchaseControllerTests.swift`
  - Deterministic copied-text playback monetization coverage for cached unlock state, two-free-speaks-per-day accounting, local day resets, and purchase or restore state transitions through the placeholder store abstraction.
- `KeyVoxiOSTests/Core/Audio/`
  - Audio input preference resolution and stop-time capture processing.
- `KeyVoxiOSTests/Core/Keyboard/`
  - Keyboard dictation control, controller presentation lifecycle coverage, toolbar warning precedence, interaction haptics, text insertion behavior, and cursor-trackpad helpers.
- `KeyVoxiOSTests/Core/TTS/`
  - Deterministic copied-text playback coverage for PocketTTS engine runtime lifecycle, TTS manager lifecycle handoff rules, system playback integration, and buffering policy behavior.
- `KeyVoxiOSTests/Core/Transcription/`
  - Transcription/session lifecycle and interrupted-capture recovery behavior.

## Change Tracking

- Update this file when iOS file ownership, target boundaries, or top-level runtime flow changes.
- Use [`ENGINEERING.md`](ENGINEERING.md) for lifecycle rules, onboarding contracts, IPC details, session behavior, and operational/testing policy.
- These two docs are the maintained iOS source of truth in this repo today.
