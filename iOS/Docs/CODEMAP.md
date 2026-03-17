# KeyVox iOS Code Map
**Last Updated: 2026-03-16**

## Project Overview

KeyVox iOS ships as three cooperating targets:

- The containing app owns onboarding, settings, model lifecycle, microphone capture, interrupted-capture recovery, session policy, weekly stats, iCloud sync, and the SwiftUI shell.
- The keyboard extension owns the visible custom keyboard, warm/cold app handoff, text insertion, full-access warning UI, and keyboard-only interaction behavior.
- The widget extension owns the Live Activity and Dynamic Island presentation plus the stop-session App Intent.

Shared speech and text behavior still lives in `../Packages/KeyVoxCore`, including `DictationPipeline`, `WhisperService`, dictionary persistence primitives, and post-processing order.

The current default runtime flow is:

1. On first launch, the app routes through onboarding instead of dropping directly into tabs.
2. The setup screen lets the user work through model download and microphone access in parallel, but keeps keyboard setup gated on model readiness.
3. When the user leaves setup for Settings, the app records a pending keyboard-tour handoff and later resumes into the keyboard tour after reactivation.
4. The keyboard tour autofocuses a text field, waits for the KeyVox keyboard to be shown, and advances only after the first non-empty tour transcription completes.
5. After the keyboard tour, onboarding finishes on the customize-app screen rather than ending inside the tour itself.
6. After onboarding, the main app shell owns ongoing model management, style/settings changes, weekly usage, and session controls.
7. When the user taps the mic in the keyboard extension, the extension decides between warm Darwin signaling and cold URL launch.
8. The containing app records and processes audio, runs the shared dictation pipeline, and publishes `transcribing`, `transcriptionReady`, or `noSpeech` back through the App Group bridge.
9. The extension inserts the returned text into the focused host app using conservative spacing and capitalization heuristics.
10. If the user keeps the session active, the Live Activity coordinator mirrors session state and weekly-word updates into the widget extension.

## Architecture

- **`KeyVox iOS/`**: app lifecycle, composition root, onboarding state, URL routing, App Group storage, iCloud sync, model background downloads, audio capture, transcription/session management, Live Activity coordination, and the SwiftUI shell.
- **`KeyVox Keyboard/`**: custom keyboard controller, toolbar modes, key grid UI, full-access instructional surface, live indicator rendering, host-app launch handoff, haptics, cursor trackpad behavior, and final insertion heuristics.
- **`KeyVox Widget/`**: ActivityKit/WidgetKit surface for the lock screen and Dynamic Island, plus the stop-session App Intent.
- **`../Packages/KeyVoxCore/`**: shared dictation pipeline, Whisper integration, dictionary store, post-processing order, silence heuristics, and list formatting behavior.
- **`KeyVoxiOSTests/`**: deterministic tests for onboarding state, keyboard-tour routing, settings persistence, iCloud sync, weekly stats, model lifecycle, model download recovery, microphone permission handling, text input helpers, cursor-trackpad behavior, and transcription/session orchestration.
- **`iOS/Docs/`**: iOS-local source of truth. `CODEMAP.md` tracks file ownership; `ENGINEERING.md` tracks invariants, contracts, and operational policy.

## Contributor Notes

- Keep iOS-only platform behavior inside the iOS targets. Reusable speech, text, and dictionary logic should remain in `KeyVoxCore`.
- Keep the keyboard extension thin. It should transport commands, render keyboard UI, and insert final text, not become an alternate owner of model, microphone, or onboarding state.
- Keep app-extension and app-widget contracts centralized in `KeyVoxIPCBridge`; do not duplicate App Group keys, timestamps, or Darwin notification names.
- Keep onboarding state separate from settings state. `OnboardingStore` is the routing owner for onboarding progress and launch flags.
- Keep the keyboard root layout stable. The full-access warning is intentionally layered as an overlay instead of participating in the main keyboard stack layout.
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
├── KeyVox iOS/
│   ├── App/
│   │   ├── AppDelegate.swift
│   │   ├── AppServiceRegistry.swift
│   │   ├── SharedPaths.swift
│   │   ├── WeeklyWordStatsStore.swift
│   │   ├── KeyVoxIPCBridge.swift
│   │   ├── KeyVoxKeyboardBridge.swift
│   │   ├── KeyVoxSessionLiveActivityAttributes.swift
│   │   ├── KeyVoxSessionLiveActivityCoordinator.swift
│   │   ├── KeyVoxURLRoute.swift
│   │   ├── KeyVoxURLRouter.swift
│   │   ├── KeyVoxiOSApp.swift
│   │   ├── Onboarding/
│   │   │   ├── OnboardingDownloadNetworkMonitor.swift
│   │   │   ├── OnboardingKeyboardAccessProbe.swift
│   │   │   ├── OnboardingKeyboardTourState.swift
│   │   │   ├── OnboardingMicrophonePermissionController.swift
│   │   │   ├── OnboardingSetupState.swift
│   │   │   ├── OnboardingStore.swift
│   │   │   └── RuntimeFlags.swift
│   │   └── iCloud/
│   │       ├── AppSettingsStore.swift
│   │       ├── UserDefaultsKeys.swift
│   │       ├── WeeklyWordStatsCloudSync.swift
│   │       ├── CloudSyncCoordinator.swift
│   │       ├── KeyVoxiCloudKeys.swift
│   │       └── KeyVoxiCloudPayloads.swift
│   ├── Assets.xcassets/
│   ├── Core/
│   │   ├── Audio/
│   │   │   ├── LiveInputSignalState.swift
│   │   │   ├── AudioRecorder.swift
│   │   │   ├── AudioRecorder+Session.swift
│   │   │   ├── AudioRecorder+StopPipeline.swift
│   │   │   └── AudioRecorder+Streaming.swift
│   │   ├── ModelDownloader/
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
│   │   ├── Kanit-Light.ttf
│   │   ├── Kanit-Medium.ttf
│   │   ├── ReturnToHost.mov
│   │   ├── ReturnToHostPlaceholder.png
│   │   └── ReturnToHost_FullRange.mov
│   ├── Views/
│   │   ├── AppRootView.swift
│   │   ├── ContainingAppTab.swift
│   │   ├── DictionaryTabView.swift
│   │   ├── HomeTabView.swift
│   │   ├── MainTabView.swift
│   │   ├── ReturnToHostView.swift
│   │   ├── SettingsTabView.swift
│   │   ├── StyleTabView.swift
│   │   ├── Components/
│   │   │   ├── LoopingVideoPlayer.swift
│   │   │   ├── AppActionButton.swift
│   │   │   ├── AppCard.swift
│   │   │   ├── AppIconTile.swift
│   │   │   ├── AppScrollScreen.swift
│   │   │   ├── AppTheme.swift
│   │   │   ├── AppToolbarContent.swift
│   │   │   ├── AppTypography.swift
│   │   │   ├── LastTranscriptionCardView.swift
│   │   │   └── LogoBarView.swift
│   │   ├── Dictionary/
│   │   │   ├── AutoFocusTextField.swift
│   │   │   ├── DictionaryEntryRowView.swift
│   │   │   ├── DictionaryFloatingAddButton.swift
│   │   │   ├── DictionaryHeaderCardView.swift
│   │   │   ├── DictionarySortMode.swift
│   │   │   ├── DictionaryWordEditorMode.swift
│   │   │   ├── DictionaryWordEditorView.swift
│   │   │   └── KeyboardObserver.swift
│   │   └── Onboarding/
│   │       ├── OnboardingCustomizeAppScreen.swift
│   │       ├── OnboardingFlowView.swift
│   │       ├── OnboardingRequirementRow.swift
│   │       ├── OnboardingSetupScreen.swift
│   │       ├── OnboardingWelcomeScreen.swift
│   │       └── Tour/
│   │           ├── OnboardingKeyboardTourSceneAView.swift
│   │           ├── OnboardingKeyboardTourSceneBView.swift
│   │           ├── OnboardingKeyboardTourSceneCView.swift
│   │           └── OnboardingKeyboardTourScreen.swift
│   └── keyvox.icon/
├── KeyVox Keyboard/
│   ├── App/
│   │   ├── KeyboardContainingAppLauncher.swift
│   │   └── KeyboardViewController.swift
│   ├── Core/
│   │   ├── AudioIndicatorDriver.swift
│   │   ├── KeyboardCapsLockStateStore.swift
│   │   ├── KeyboardCursorTrackpadSupport.swift
│   │   ├── KeyboardDictationController.swift
│   │   ├── KeyboardDictionaryCasingStore.swift
│   │   ├── KeyboardHapticsSettingsStore.swift
│   │   ├── KeyboardIPCManager.swift
│   │   ├── KeyboardInsertionCapitalizationHeuristics.swift
│   │   ├── KeyboardInsertionSpacingHeuristics.swift
│   │   ├── KeyboardKeypressHaptics.swift
│   │   ├── KeyboardModelAvailability.swift
│   │   ├── KeyboardSpecialKeyInteractionSupport.swift
│   │   ├── KeyboardState.swift
│   │   ├── KeyboardStyle.swift
│   │   ├── KeyboardSymbolLayout.swift
│   │   ├── KeyboardTextInputController.swift
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
│           └── KeyboardRoundedBorderRenderer.swift
├── KeyVox Widget/
│   ├── AppIntent.swift
│   ├── Assets.xcassets/
│   ├── Info.plist
│   ├── KeyVox Widget.entitlements
│   ├── KeyVox_WidgetBundle.swift
│   └── KeyVox_WidgetLiveActivity.swift
├── KeyVoxiOSTests/
│   ├── App/
│   │   ├── KeyVoxSessionLiveActivityCoordinatorTests.swift
│   │   ├── KeyVoxURLRouteTests.swift
│   │   ├── AppSettingsStoreTests.swift
│   │   ├── ModelManagerTests.swift
│   │   ├── OnboardingKeyboardAccessProbeTests.swift
│   │   ├── OnboardingKeyboardTourStateTests.swift
│   │   ├── OnboardingMicrophonePermissionControllerTests.swift
│   │   ├── OnboardingSetupStateTests.swift
│   │   ├── OnboardingStoreTests.swift
│   │   ├── SharedPathsTests.swift
│   │   ├── WeeklyWordStatsCloudSyncTests.swift
│   │   ├── WeeklyWordStatsStoreTests.swift
│   │   └── CloudSyncCoordinatorTests.swift
│   ├── Core/
│   │   ├── Audio/
│   │   │   ├── AudioInputPreferenceResolverTests.swift
│   │   │   └── StoppedCaptureProcessorTests.swift
│   │   ├── Keyboard/
│   │   │   ├── KeyboardCursorTrackpadSupportTests.swift
│   │   │   ├── KeyboardDictationControllerTests.swift
│   │   │   └── KeyboardTextInputControllerTests.swift
│   │   └── Transcription/
│   │       └── TranscriptionManagerTests.swift
│   └── KeyVoxiOSTests.swift
├── Launch Screen.storyboard
└── LaunchLogo.png

Packages/
└── KeyVoxCore/
    ├── Sources/KeyVoxCore/
    └── Tests/KeyVoxCoreTests/
```

## Current Runtime Map

### App Lifecycle and Composition

- `KeyVox iOS/App/KeyVoxiOSApp.swift`
  - SwiftUI app entry point.
  - Injects all app-wide environment objects.
  - Registers model-download background tasks.
  - Handles scene activation/background callbacks for transcription recovery, model recovery, and onboarding keyboard-tour arming.
  - Pre-presents `ReturnToHostView` without animation before routing `keyvoxios://record/start`.
- `KeyVox iOS/App/AppDelegate.swift`
  - Receives background `URLSession` callbacks for model downloads and forwards them into `ModelManager`.
- `KeyVox iOS/App/AppServiceRegistry.swift`
  - Main composition root.
  - Builds dictionary, onboarding, settings, weekly stats, Whisper, post-processing, model, keyboard bridge, transcription, iCloud sync, Live Activity, and URL-routing services.

### Onboarding and Root Routing

- `KeyVox iOS/Views/AppRootView.swift`
  - Root router for onboarding vs main app.
  - Suppresses `ReturnToHostView` whenever onboarding is active or was just completed during the same launch.
- `KeyVox iOS/App/Onboarding/OnboardingStore.swift`
  - Persisted onboarding state, welcome completion, pending keyboard-tour handoff, and force-onboarding launch behavior.
  - Also owns launch-scoped routing flags for welcome progression, pending-tour arming, persisted-tour ignore behavior, and post-completion suppression.
- `KeyVox iOS/Views/Onboarding/OnboardingFlowView.swift`
  - Ordered onboarding router: welcome -> setup -> keyboard tour -> customize app.
- `KeyVox iOS/Views/Onboarding/OnboardingSetupScreen.swift`
  - Model download, microphone permission, and keyboard-settings handoff screen.
  - Gates keyboard setup on model readiness while allowing the other setup tasks to proceed in parallel.
- `KeyVox iOS/Views/Onboarding/Tour/OnboardingKeyboardTourScreen.swift`
  - Full-screen post-Settings handoff screen that autofocuses a text field and keeps the input pinned above the keyboard.
  - Advances through three tour scenes and enables `Next` only after the KeyVox keyboard has been shown and a first non-empty transcription has completed.
- `KeyVox iOS/App/Onboarding/OnboardingKeyboardTourState.swift`
  - Small state machine that drives tour scene A/B/C progression and completion gating.
- `KeyVox iOS/Views/Onboarding/OnboardingCustomizeAppScreen.swift`
  - Final onboarding step.
  - Owns the explicit `Finish` action that completes onboarding.
- `KeyVox iOS/App/Onboarding/OnboardingKeyboardAccessProbe.swift`
  - App-side probe for keyboard enablement, keyboard presentation, and keyboard-reported Full Access confirmation.
- `KeyVox iOS/App/Onboarding/OnboardingMicrophonePermissionController.swift`
  - App-side microphone permission surface for onboarding.
- `KeyVox iOS/App/Onboarding/OnboardingDownloadNetworkMonitor.swift`
  - Cellular vs non-cellular detection for onboarding download copy.
- `KeyVox iOS/App/Onboarding/RuntimeFlags.swift`
  - Reads `KEYVOX_FORCE_ONBOARDING`.

### Shared State, IPC, and Session Surfaces

- `KeyVox iOS/App/KeyVoxIPCBridge.swift`
  - Source of truth for App Group defaults keys, keyboard onboarding presentation/access timestamps, shared live-meter file transport, and Darwin notification names.
- `KeyVox iOS/App/KeyVoxKeyboardBridge.swift`
  - App-side IPC endpoint for start/stop/cancel/disable-session commands and extension-facing state publishing.
- `KeyVox iOS/App/KeyVoxSessionLiveActivityCoordinator.swift`
  - App-side owner that mirrors session state and weekly-word count into the widget extension through ActivityKit.
- `KeyVox iOS/App/KeyVoxSessionLiveActivityAttributes.swift`
  - Shared ActivityKit attributes and content state.
- `KeyVox Widget/AppIntent.swift`
  - `EndSessionIntent` that posts the shared disable-session Darwin notification.
- `KeyVox Widget/KeyVox_WidgetLiveActivity.swift`
  - Lock screen and Dynamic Island UI for the live activity.

### Model Installation and Recovery

- `KeyVox iOS/Core/ModelDownloader/ModelManager.swift`
  - Observable owner of install state, user-facing download/delete/repair actions, and relaunch recovery.
- `KeyVox iOS/Core/ModelDownloader/ModelBackgroundDownloadCoordinator.swift`
  - Background `URLSession` owner for staged model artifact downloads.
- `KeyVox iOS/Core/ModelDownloader/ModelBackgroundDownloadJob.swift`
  - Durable representation of per-artifact progress and finalization state.
- `KeyVox iOS/Core/ModelDownloader/ModelBackgroundDownloadJobStore.swift`
  - Persistence seam for the background download job file.
- `KeyVox iOS/Core/ModelDownloader/ModelManager+InstallLifecycle.swift`
  - Finalization, extraction, manifest writes, staged-file cleanup, and Whisper warmup sequencing after downloads complete.
- `KeyVox iOS/Core/ModelDownloader/ModelManager+Validation.swift`
  - Strict readiness validation for installed artifacts and the manifest.
- `KeyVox iOS/Core/ModelDownloader/ModelDownloadBackgroundTasks.swift`
  - App-side background repair task registration and scheduling.

### Audio and Transcription Runtime

- `KeyVox iOS/Core/Audio/AudioRecorder.swift`
  - Public recorder and monitoring surface.
  - Tracks session warmth, meter state, and last capture facts.
- `KeyVox iOS/Core/Audio/AudioRecorder+StopPipeline.swift`
  - Produces cleaned `StoppedCapture` values and rejects silence before inference.
- `KeyVox iOS/Core/Transcription/DictationService.swift`
  - iOS-local transcription-service abstraction used by the runtime manager.
- `KeyVox iOS/Core/Transcription/TranscriptionManager.swift`
  - Primary iOS runtime state machine and dictation owner.
- `KeyVox iOS/Core/Transcription/TranscriptionManager+SessionLifecycle.swift`
  - Idle shutdown, deferred disable-session handling, and watchdog cleanup.
- `KeyVox iOS/Core/Transcription/TranscriptionManager+InterruptedCaptureRecovery.swift`
  - Interrupted-capture staging and recovery on app reactivation.
- `KeyVox iOS/Core/Transcription/InterruptedCaptureRecoveryStore.swift`
  - Durable storage for interrupted captures that need to be resumed later.
- `KeyVox iOS/Core/Transcription/SessionPolicy.swift`
  - Session safety thresholds and timeout policy.

### App UI

- `KeyVox iOS/Views/MainTabView.swift`
  - Four-tab container: Home, Dictionary, Style, Settings.
  - Adds edge-swipe tab navigation on top of `TabView`.
- `KeyVox iOS/Views/ContainingAppTab.swift`
  - Source of truth for app-tab ordering, titles, and previous/next navigation.
- `KeyVox iOS/Views/HomeTabView.swift`
  - Weekly stats, last transcription card, and debug-only diagnostics.
- `KeyVox iOS/Views/DictionaryTabView.swift`
  - Dictionary UI plus editor flow built around `AutoFocusTextField`, sort state, and `KeyboardObserver`.
- `KeyVox iOS/Views/StyleTabView.swift`
  - User-facing dictation style toggles.
- `KeyVox iOS/Views/SettingsTabView.swift`
  - Session timeout, Live Activities toggle, keyboard haptics, audio preference, and model actions.
- `KeyVox iOS/Views/ReturnToHostView.swift`
  - One-time post-cold-launch host-return guidance screen during a live session handoff.

### Keyboard Extension

- `KeyVox Keyboard/App/KeyboardViewController.swift`
  - Extension controller and top-level keyboard surface owner.
  - Owns toolbar mode switching, full-access instructions presentation, warm/cold app launch behavior, onboarding presentation reporting, Caps Lock, symbol page, trackpad mode, and insertion.
- `KeyVox Keyboard/Core/KeyboardDictationController.swift`
  - Keyboard-local state machine for shared recording state and app launch handoff.
- `KeyVox Keyboard/Core/KeyboardIPCManager.swift`
  - Extension-side App Group/Darwin client plus stale shared-state reconciliation.
- `KeyVox Keyboard/Core/KeyboardTextInputController.swift`
  - Host-app text insertion, key dispatch, double-space period behavior, and cursor movement.
- `KeyVox Keyboard/Core/KeyboardCursorTrackpadSupport.swift`
  - Cursor-trackpad delta handling used by the space-bar trackpad interaction.
- `KeyVox Keyboard/Core/KeyboardInsertionSpacingHeuristics.swift`
  - Conservative smart-spacing before inserted dictation text.
- `KeyVox Keyboard/Core/KeyboardInsertionCapitalizationHeuristics.swift`
  - Host-text capitalization preservation for direct typing and inserted dictation paths.
- `KeyVox Keyboard/Core/KeyboardModelAvailability.swift`
  - Lightweight installed-model gate used by the extension toolbar.
- `KeyVox Keyboard/Views/KeyboardRootView.swift`
  - Stable keyboard chrome and key grid.
  - Hosts the branded toolbar row and the full-access warning overlay.
- `KeyVox Keyboard/Views/FullAccessView.swift`
  - Full-screen keyboard-only instructional view shown when the user needs to enable Full Access.

### Tests

- `KeyVoxiOSTests/App/`
  - Onboarding state, onboarding keyboard-tour state, keyboard access probing, settings persistence, shared paths, iCloud sync, weekly stats, Live Activity coordination, URL routing, and model manager behavior.
- `KeyVoxiOSTests/Core/Audio/`
  - Audio input preference resolution and stop-time capture processing.
- `KeyVoxiOSTests/Core/Keyboard/`
  - Keyboard dictation control, text insertion behavior, and cursor-trackpad helpers.
- `KeyVoxiOSTests/Core/Transcription/`
  - Transcription/session lifecycle and interrupted-capture recovery behavior.

## Change Tracking

- Update this file when iOS file ownership, target boundaries, or top-level runtime flow changes.
- Use [`ENGINEERING.md`](ENGINEERING.md) for lifecycle rules, onboarding contracts, IPC details, session behavior, and operational/testing policy.
- Keep `Docs/KEYVOX_IOS.md` as historical design context rather than the current iOS source of truth.
