# KeyVox iOS Code Map
**Last Updated: 2026-03-15**

## Project Overview

KeyVox iOS now ships as three cooperating targets:

- The containing app owns onboarding, settings, model lifecycle, microphone capture, interrupted-capture recovery, session policy, weekly stats, iCloud sync, and the SwiftUI shell.
- The keyboard extension owns the visible custom keyboard, warm/cold app handoff, text insertion, full-access warning UI, and keyboard-only interaction behavior.
- The widget extension owns the Live Activity and Dynamic Island presentation plus the stop-session App Intent.

Shared speech and text behavior still lives in `../Packages/KeyVoxCore`, including `DictationPipeline`, `WhisperService`, dictionary persistence primitives, and post-processing order.

The current default runtime flow is:

1. On first launch, the app routes through onboarding instead of dropping directly into tabs.
2. The onboarding setup screen gates keyboard setup behind model readiness and records a pending keyboard-tour handoff before sending the user to Settings.
3. The keyboard tour screen autofocuses a text field, summons the keyboard, and waits for a fresh keyboard-side full-access confirmation before enabling onboarding completion.
4. After onboarding, the main app shell owns ongoing model management, style/settings changes, weekly usage, and session controls.
5. When the user taps the mic in the keyboard extension, the extension decides between warm Darwin signaling and cold URL launch.
6. The containing app records and processes audio, runs the shared dictation pipeline, and publishes `transcribing`, `transcriptionReady`, or `noSpeech` back through the App Group bridge.
7. The extension inserts the returned text into the focused host app using conservative spacing and capitalization heuristics.
8. If the user keeps the session active, the Live Activity coordinator mirrors that session state into the widget extension.

## Architecture

- **`KeyVox iOS/`**: app lifecycle, composition root, onboarding state, URL routing, App Group storage, iCloud sync, model background downloads, audio capture, transcription/session management, Live Activity coordination, and the SwiftUI shell.
- **`KeyVox Keyboard/`**: custom keyboard controller, toolbar modes, key grid UI, full-access instructional surface, live indicator rendering, host-app launch handoff, haptics, cursor trackpad behavior, and final insertion heuristics.
- **`KeyVox Widget/`**: ActivityKit/WidgetKit surface for the lock screen and Dynamic Island, plus the stop-session App Intent.
- **`../Packages/KeyVoxCore/`**: shared dictation pipeline, Whisper integration, dictionary store, post-processing order, silence heuristics, and list formatting behavior.
- **`KeyVoxiOSTests/`**: deterministic tests for onboarding state, settings persistence, iCloud sync, weekly stats, model lifecycle, model download recovery, keyboard probes, microphone permission handling, text input helpers, and transcription/session orchestration.
- **`iOS/Docs/`**: iOS-local source of truth. `CODEMAP.md` tracks file ownership; `ENGINEERING.md` tracks invariants, contracts, and operational policy.

## Contributor Notes

- Keep iOS-only platform behavior inside the iOS targets. Reusable speech, text, and dictionary logic should remain in `KeyVoxCore`.
- Keep the keyboard extension thin. It should transport commands, render keyboard UI, and insert final text, not become an alternate owner of model, microphone, or onboarding state.
- Keep app-extension and app-widget contracts centralized in `KeyVoxIPCBridge`; do not duplicate App Group keys, timestamps, or Darwin notification names.
- Keep onboarding state separate from settings state. `iOSOnboardingStore` is the routing owner for onboarding progress and launch flags.
- Keep the keyboard root layout stable. The full-access warning is intentionally layered as an overlay instead of participating in the main keyboard stack layout.
- Update [`ENGINEERING.md`](ENGINEERING.md) whenever lifecycle rules, IPC contracts, onboarding routing, Live Activity behavior, or model recovery behavior change.

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
│   │   ├── iOSAppDelegate.swift
│   │   ├── KeyVoxiOSApp.swift
│   │   ├── iOSAppServiceRegistry.swift
│   │   ├── iOSSharedPaths.swift
│   │   ├── KeyVoxIPCBridge.swift
│   │   ├── KeyVoxKeyboardBridge.swift
│   │   ├── KeyVoxSessionLiveActivityAttributes.swift
│   │   ├── KeyVoxSessionLiveActivityCoordinator.swift
│   │   ├── KeyVoxURLRoute.swift
│   │   ├── KeyVoxURLRouter.swift
│   │   ├── iOSWeeklyWordStatsStore.swift
│   │   ├── Onboarding/
│   │   │   ├── iOSOnboardingStore.swift
│   │   │   ├── iOSOnboardingSetupState.swift
│   │   │   ├── iOSOnboardingKeyboardAccessProbe.swift
│   │   │   ├── iOSOnboardingMicrophonePermissionController.swift
│   │   │   ├── iOSOnboardingDownloadNetworkMonitor.swift
│   │   │   └── iOSRuntimeFlags.swift
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
│   │   ├── ModelDownloader/
│   │   │   ├── iOSModelManager.swift
│   │   │   ├── iOSModelManager+InstallLifecycle.swift
│   │   │   ├── iOSModelManager+Support.swift
│   │   │   ├── iOSModelManager+Validation.swift
│   │   │   ├── iOSModelBackgroundDownloadCoordinator.swift
│   │   │   ├── iOSModelBackgroundDownloadJob.swift
│   │   │   ├── iOSModelBackgroundDownloadJobStore.swift
│   │   │   ├── iOSModelDownloadBackgroundTasks.swift
│   │   │   ├── iOSModelDownloadURLs.swift
│   │   │   ├── iOSModelInstallManifest.swift
│   │   │   └── iOSModelInstallState.swift
│   │   └── Transcription/
│   │       ├── iOSDictationService.swift
│   │       ├── iOSSessionPolicy.swift
│   │       ├── iOSInterruptedCaptureRecovery.swift
│   │       ├── iOSInterruptedCaptureRecoveryStore.swift
│   │       ├── iOSTranscriptionManager.swift
│   │       ├── iOSTranscriptionManager+InterruptedCaptureRecovery.swift
│   │       └── iOSTranscriptionManager+SessionLifecycle.swift
│   ├── Views/
│   │   ├── AppRootView.swift
│   │   ├── ReturnToHostView.swift
│   │   ├── MainTabView.swift
│   │   ├── HomeTabView.swift
│   │   ├── DictionaryTabView.swift
│   │   ├── StyleTabView.swift
│   │   ├── SettingsTabView.swift
│   │   ├── Onboarding/
│   │   │   ├── OnboardingFlowView.swift
│   │   │   ├── OnboardingScreenScaffold.swift
│   │   │   ├── OnboardingWelcomeScreen.swift
│   │   │   ├── OnboardingSetupScreen.swift
│   │   │   ├── OnboardingKeyboardTourScreen.swift
│   │   │   └── OnboardingRequirementRow.swift
│   │   ├── Dictionary/
│   │   │   ├── AutoFocusTextField.swift
│   │   │   ├── KeyboardObserver.swift
│   │   │   ├── DictionaryWordEditorView.swift
│   │   │   ├── DictionaryEntryRowView.swift
│   │   │   └── DictionaryHeaderCardView.swift
│   │   └── Components/
│   │       ├── iOSAppTheme.swift
│   │       ├── iOSAppTypography.swift
│   │       ├── iOSAppToolbarContent.swift
│   │       ├── iOSAppCard.swift
│   │       ├── iOSAppScrollScreen.swift
│   │       ├── iOSLogoBarView.swift
│   │       ├── iOSLastTranscriptionCardView.swift
│   │       └── LoopingVideoPlayer.swift
│   ├── Assets.xcassets/
│   ├── Resources/
│   ├── Info.plist
│   └── KeyVoxiOS.entitlements
├── KeyVox Keyboard/
│   ├── App/
│   │   ├── KeyboardContainingAppLauncher.swift
│   │   └── KeyboardViewController.swift
│   ├── Core/
│   │   ├── AudioIndicatorDriver.swift
│   │   ├── KeyboardCapsLockStateStore.swift
│   │   ├── KeyboardDictationController.swift
│   │   ├── KeyboardDictionaryCasingStore.swift
│   │   ├── KeyboardHapticsSettingsStore.swift
│   │   ├── KeyboardInsertionCapitalizationHeuristics.swift
│   │   ├── KeyboardInsertionSpacingHeuristics.swift
│   │   ├── KeyboardIPCManager.swift
│   │   ├── KeyboardKeypressHaptics.swift
│   │   ├── KeyboardModelAvailability.swift
│   │   ├── KeyboardSpecialKeyInteractionSupport.swift
│   │   ├── KeyboardState.swift
│   │   ├── KeyboardStyle.swift
│   │   ├── KeyboardSymbolLayout.swift
│   │   ├── KeyboardTextInputController.swift
│   │   ├── KeyboardToolbarMode.swift
│   │   └── KeyboardTypography.swift
│   ├── Views/
│   │   ├── KeyboardInputHostView.swift
│   │   ├── KeyboardRootView.swift
│   │   ├── FullAccessView.swift
│   │   └── Components/
│   │       ├── KeyboardCancelButton.swift
│   │       ├── KeyboardCapsLockButton.swift
│   │       ├── KeyboardHitTargetButton.swift
│   │       ├── KeyboardKeyGridView.swift
│   │       ├── KeyboardKeyPopupView.swift
│   │       ├── KeyboardKeyView.swift
│   │       ├── KeyboardLogoBarView.swift
│   │       └── KeyboardRoundedBorderRenderer.swift
│   ├── Info.plist
│   └── KeyVoxKeyboard.entitlements
├── KeyVox Widget/
│   ├── AppIntent.swift
│   ├── KeyVox_WidgetBundle.swift
│   ├── KeyVox_WidgetLiveActivity.swift
│   ├── Assets.xcassets/
│   ├── Info.plist
│   └── KeyVox Widget.entitlements
└── KeyVoxiOSTests/
    ├── App/
    └── Core/

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
  - Handles scene activation/background callbacks for transcription recovery, model download recovery, and onboarding keyboard-tour arming.
- `KeyVox iOS/App/iOSAppDelegate.swift`
  - Receives background `URLSession` callbacks for model downloads and forwards them into `iOSModelManager`.
- `KeyVox iOS/App/iOSAppServiceRegistry.swift`
  - Main composition root.
  - Builds dictionary, onboarding, settings, model, transcription, weekly stats, iCloud sync, and Live Activity services.

### Onboarding and Root Routing

- `KeyVox iOS/Views/AppRootView.swift`
  - Root router for onboarding vs main app.
  - Prevents `ReturnToHostView` from interrupting onboarding.
- `KeyVox iOS/App/Onboarding/iOSOnboardingStore.swift`
  - Persisted onboarding state, welcome completion, pending keyboard-tour handoff, and force-onboarding launch behavior.
- `KeyVox iOS/Views/Onboarding/OnboardingFlowView.swift`
  - Ordered onboarding router: welcome -> setup -> keyboard tour.
- `KeyVox iOS/Views/Onboarding/OnboardingSetupScreen.swift`
  - Model download, microphone permission, and keyboard-settings handoff screen.
  - Gates keyboard setup on model readiness.
- `KeyVox iOS/Views/Onboarding/OnboardingKeyboardTourScreen.swift`
  - Full-screen post-Settings handoff screen that autofocuses a text field, summons the keyboard, and waits for fresh keyboard confirmation before finishing onboarding.
- `KeyVox iOS/App/Onboarding/iOSOnboardingKeyboardAccessProbe.swift`
  - App-side probe for keyboard enablement and keyboard-reported full-access confirmation.
- `KeyVox iOS/App/Onboarding/iOSOnboardingMicrophonePermissionController.swift`
  - App-side microphone permission surface for onboarding.
- `KeyVox iOS/App/Onboarding/iOSOnboardingDownloadNetworkMonitor.swift`
  - Cellular vs non-cellular detection for onboarding download copy.
- `KeyVox iOS/App/Onboarding/iOSRuntimeFlags.swift`
  - Reads `KEYVOX_FORCE_ONBOARDING`.

### Shared State, IPC, and Session Surfaces

- `KeyVox iOS/App/KeyVoxIPCBridge.swift`
  - Source of truth for App Group defaults keys, keyboard onboarding keys, shared live-meter file transport, and Darwin notification names.
- `KeyVox iOS/App/KeyVoxKeyboardBridge.swift`
  - App-side IPC endpoint for start/stop/cancel/disable-session commands and extension-facing state publishing.
- `KeyVox iOS/App/KeyVoxSessionLiveActivityCoordinator.swift`
  - App-side owner that mirrors session state into the widget extension through ActivityKit.
- `KeyVox iOS/App/KeyVoxSessionLiveActivityAttributes.swift`
  - Shared ActivityKit attributes and content state.
- `KeyVox Widget/AppIntent.swift`
  - `EndSessionIntent` that posts the shared disable-session Darwin notification.
- `KeyVox Widget/KeyVox_WidgetLiveActivity.swift`
  - Lock screen and Dynamic Island UI for the live activity.

### Model Installation and Recovery

- `KeyVox iOS/Core/ModelDownloader/iOSModelManager.swift`
  - Observable owner of install state, user-facing download/delete/repair actions, and relaunch recovery.
- `KeyVox iOS/Core/ModelDownloader/iOSModelBackgroundDownloadCoordinator.swift`
  - Background `URLSession` owner for staged model artifact downloads.
- `KeyVox iOS/Core/ModelDownloader/iOSModelBackgroundDownloadJob.swift`
  - Durable representation of per-artifact progress and finalization state.
- `KeyVox iOS/Core/ModelDownloader/iOSModelBackgroundDownloadJobStore.swift`
  - Persistence seam for the background download job file.
- `KeyVox iOS/Core/ModelDownloader/iOSModelManager+InstallLifecycle.swift`
  - Finalization, extraction, manifest writes, and warmup sequencing after downloads complete.
- `KeyVox iOS/Core/ModelDownloader/iOSModelManager+Validation.swift`
  - Strict readiness validation for installed artifacts and the manifest.
- `KeyVox iOS/Core/ModelDownloader/iOSModelDownloadBackgroundTasks.swift`
  - App-side background repair task registration and scheduling.

### Audio and Transcription Runtime

- `KeyVox iOS/Core/Audio/iOSAudioRecorder.swift`
  - Public recorder and monitoring surface.
  - Tracks session warmth, meter state, and last capture facts.
- `KeyVox iOS/Core/Audio/iOSAudioRecorder+StopPipeline.swift`
  - Produces cleaned `iOSStoppedCapture` values and rejects silence before inference.
- `KeyVox iOS/Core/Transcription/iOSTranscriptionManager.swift`
  - Primary iOS runtime state machine and dictation owner.
- `KeyVox iOS/Core/Transcription/iOSTranscriptionManager+SessionLifecycle.swift`
  - Idle shutdown, deferred disable-session handling, and watchdog cleanup.
- `KeyVox iOS/Core/Transcription/iOSTranscriptionManager+InterruptedCaptureRecovery.swift`
  - Interrupted-capture staging and recovery on app reactivation.
- `KeyVox iOS/Core/Transcription/iOSInterruptedCaptureRecoveryStore.swift`
  - Durable storage for interrupted captures that need to be resumed later.
- `KeyVox iOS/Core/Transcription/iOSSessionPolicy.swift`
  - Session safety thresholds and timeout policy.

### App UI

- `KeyVox iOS/Views/MainTabView.swift`
  - Four-tab container: Home, Dictionary, Style, Settings.
- `KeyVox iOS/Views/HomeTabView.swift`
  - Weekly stats, last transcription card, and debug-only diagnostics.
- `KeyVox iOS/Views/DictionaryTabView.swift`
  - Dictionary UI plus editor flow built around `AutoFocusTextField` and `KeyboardObserver`.
- `KeyVox iOS/Views/StyleTabView.swift`
  - User-facing dictation style toggles.
- `KeyVox iOS/Views/SettingsTabView.swift`
  - Session timeout, Live Activities toggle, keyboard haptics, audio preference, and model actions.
- `KeyVox iOS/Views/ReturnToHostView.swift`
  - One-time post-cold-launch host-return guidance screen during a live session handoff.

### Keyboard Extension

- `KeyVox Keyboard/App/KeyboardViewController.swift`
  - Extension controller and top-level keyboard surface owner.
  - Owns toolbar mode switching, full-access instructions presentation, warm/cold app launch behavior, Caps Lock, symbol page, trackpad mode, and insertion.
- `KeyVox Keyboard/Core/KeyboardDictationController.swift`
  - Keyboard-local state machine for shared recording state and app launch handoff.
- `KeyVox Keyboard/Core/KeyboardIPCManager.swift`
  - Extension-side App Group/Darwin client.
- `KeyVox Keyboard/Core/KeyboardTextInputController.swift`
  - Host-app text insertion and key-action dispatch.
- `KeyVox Keyboard/Core/KeyboardInsertionSpacingHeuristics.swift`
  - Conservative smart-spacing before inserted dictation text.
- `KeyVox Keyboard/Core/KeyboardInsertionCapitalizationHeuristics.swift`
  - Host-text capitalization preservation for direct typing paths.
- `KeyVox Keyboard/Core/KeyboardModelAvailability.swift`
  - Lightweight installed-model gate used by the extension toolbar.
- `KeyVox Keyboard/Views/KeyboardRootView.swift`
  - Stable keyboard chrome and key grid.
  - Hosts the branded toolbar row and the full-access warning overlay.
- `KeyVox Keyboard/Views/FullAccessView.swift`
  - Full-screen keyboard-only instructional view shown when the user needs to enable Full Access.

### Tests

- `KeyVoxiOSTests/App/`
  - Onboarding state, settings persistence, shared paths, iCloud sync, weekly stats, Live Activity coordination, and model manager behavior.
- `KeyVoxiOSTests/Core/Audio/`
  - Audio input preference resolution and stop-time capture processing.
- `KeyVoxiOSTests/Core/Keyboard/`
  - Keyboard dictation control, text insertion behavior, and cursor-trackpad helpers.
- `KeyVoxiOSTests/Core/Transcription/`
  - Transcription/session lifecycle and recovery behavior.

## Change Tracking

- Update this file when iOS file ownership, target boundaries, or top-level runtime flow changes.
- Use [`ENGINEERING.md`](ENGINEERING.md) for lifecycle rules, onboarding contracts, IPC details, session behavior, and operational/testing policy.
- Keep `Docs/KEYVOX_IOS.md` as historical design context rather than the current iOS source of truth.
