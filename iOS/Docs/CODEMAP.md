# KeyVox iOS Code Map
**Last Updated: 2026-10-18**

## Project Overview

KeyVox iOS ships as four cooperating targets:

- The containing app owns onboarding, settings, dictation model lifecycle, local Vibes model lifecycle, bundled Vibes adapter lookup, local style rewrite inference, PocketTTS voice installs, copied-text playback, microphone capture, interrupted-capture recovery, session policy, weekly stats, iCloud sync, and the SwiftUI shell.
- The keyboard extension owns the visible custom keyboard, the letter, number, and symbol pages, full/compact key modes, letter-page typing with suggestions and autocorrection, the typing memory it learns from the user's typing, the emoji page and emoji search, warm/cold app handoff, copied-text speak transport, text insertion, warning-toolbar presentation, Vibes selection/status UI, latest-insertion editability tracking, and keyboard-only interaction behavior. For model-backed Vibes rewrites, it requests work from the containing app instead of loading the local rewrite model itself.
- The share extension owns shared text/URL/PDF extraction, OCR for shared images and rendered PDF pages, TTS request handoff to the main app, and visual feedback during share processing.
- The widget extension owns the Live Activity and Dynamic Island presentation plus the stop-session App Intent.

Shared speech and text behavior lives in `../Packages/KeyVoxCore`, including `DictationPipeline`, provider seams, dictation-language metadata and Whisper configuration, provider-specific voice-activity use, deterministic paragraph/list state resolution and text shaping, dictionary persistence primitives, model-artifact cleanup, guarded compact-time/date/math normalization, and post-processing order. The lower-level provider wrappers live in `../Packages/KeyVoxWhisper` and `../Packages/KeyVoxParakeet`; the shared Silero model and detector live in `../Packages/KeyVoxVoiceActivity` and are used by both providers.
Shared linguistic contracts, native analysis, portable analysis, health evaluation, and fallback routing live in `../Packages/KeyVoxLinguistics`. The containing app owns the portable linguistic resources and injects one analyzer into every app-side consumer; the keyboard transports language context but does not load the analyzer resources.
The local PocketTTS runtime now lives in `../Packages/KeyVoxTTS`.
Keyboard typing prediction, autocorrection, held-key characters, smart quotes, and typing memory live in `../Packages/KeyVoxPredictiveKeyboard`; the emoji catalog, search, Frequently Used ranking, suggestion-bar emoji, and two-person skin tones live in `../Packages/KeyVoxEmoji`. Among the shipping targets only the keyboard extension links these two packages; the containing app owns only the keyboard settings that steer them and the typing-memory reset.

The current default runtime flow is:

1. On first launch, the app routes through onboarding instead of dropping directly into tabs.
2. The setup screen lets the user work through model download and microphone access in parallel, but keeps keyboard setup gated until both prerequisites are complete.
3. When the user leaves setup for Settings, the app records a pending keyboard-tour handoff and later resumes into the keyboard tour after reactivation.
4. The keyboard tour autofocuses a text field, waits for the KeyVox keyboard to be shown, and only enables completion after the first non-empty tour transcription completes.
5. Finishing the keyboard tour completes onboarding directly; there is no separate customize-app screen on the current branch.
6. After onboarding, the main app shell owns ongoing model management, style/settings changes, weekly usage, and session controls.
7. When the user taps the mic in the keyboard extension, the extension decides between warm Darwin signaling and cold URL launch. The user may instead invoke the Toggle Dictation App Shortcut to start or stop the same shared recording without foregrounding KeyVox.
8. The containing app records and processes audio, runs the shared dictation pipeline with the provider-reported language code, and publishes `recordingStartFailed`, `transcribing`, `transcriptionReady`, or `noSpeech` back through the App Group bridge. `recordingStartFailed` reports an actual recorder startup error. Published results carry the utterance ID and selected style identifier so later keyboard changes bind only to the matching latest-utterance artifact. A visible KeyVox keyboard inserts successful results, while the bundled shortcut workflow copies returned text and posts the completion notification.
9. The app optionally rewrites the post-processed base text through the local Vibes model and LoRA adapter selected by the current Vibe, preserving the dictation language for linguistic output repair and later artifact-scoped rewrites.
10. The extension resolves preceding and following host-text context, delegates leading spacing, capitalization, adjacent terminal-punctuation, and trailing-separator policy to `KeyVoxTextComposition`, and performs the resulting insertion or punctuation replacement through the iOS document proxy.
11. Later keyboard long presses may restyle or revert only the latest untouched KeyVox insertion: Vibes changes use an app-IPC rewrite request, paragraph/list changes use persisted deterministic artifact variants, and Caps Lock swaps between the inserted text and the preserved pre-Caps selected output. If the local Vibes model is missing, keyboard Vibes taps do not cycle styles and instead route the user into the app-owned Vibes install/trial flow.
12. When the user triggers copied-text playback, the containing app owns PocketTTS synthesis, explicit model load/unload lifetime, deterministic playback preparation, replay caching, pause/resume/stop transport state, and return-to-host readiness.
13. If the user keeps the session active, the Live Activity coordinator mirrors session state and weekly-word updates into the widget extension.
14. When Compact Keys is available, a long press on `#+=` replaces the first two symbol rows with a shorter two-row keyboard; the keyboard-symbol key restores the full layout.
15. The keyboard waits for the host to hand over the focused field's document state, reads the field's text traits narrowed by the user's keyboard settings, and opens on the letter page or, when the field or the Open on 123 setting prefers numbers, on the number page.
16. On the full keyboard's letter page, taps, text changes, word boundaries, and suggestion taps run through the shared `PredictiveTypingSession`; the suggestion bar takes the toolbar accessories' place while the field allows predictions and holds letters, and the dictation accessories return while dictating, in Compact Keys, on the symbol pages, and until the user changes the latest untouched dictation.
17. The emoji key opens the emoji page in the key grid's place; its search field starts an emoji search over the letter keys that makes the keyboard taller until done is tapped or the keyboard goes away.

## Architecture

- **`KeyVox iOS/`**: app lifecycle, grouped app composition/routing/integration surfaces, onboarding state, app haptics, App Store review requests, keyboard typing settings and the typing-memory reset, App Group storage, iCloud sync, reusable resumable download transport, dictation model background downloads, local Vibes model download/validation, bundled Vibes adapter lookup, app-owned local style rewrite inference, PocketTTS install ownership and playback-scoped runtime ownership, audio capture, transcription/session management, KeyVox Vibes app wiring, Live Activity coordination, and the SwiftUI shell.
- **`KeyVox Keyboard/`**: custom keyboard controller, presentation-scoped keyboard view lifecycle, toolbar modes, copied-text speak transport, keyboard playback pause/resume/stop controls, call-aware warning detection, key grid UI with letter, number, and symbol pages, multi-finger key handling, held-key character popups, delete repeat, letter-case shift state, field typing traits, prediction coordination and the suggestion bar, persisted typing memory, the emoji page and emoji search, full-access instructional surface, live indicator rendering, host-app launch handoff, haptics, cursor trackpad behavior, and platform-owned insertion coordination.
- **`KeyVox Widget/`**: ActivityKit/WidgetKit surface for the lock screen and Dynamic Island, plus the stop-session App Intent.
- **`../Packages/KeyVoxCore/`**: shared dictation pipeline, provider seams, dictation-language values/display names, the Whisper Base language catalog and service configuration, provider-specific VAD coordination, deterministic paragraph/list state and variant handling, dictionary store, post-processing order, model-artifact cleanup, audio-file loading, packaged pronunciation/file-type resources, guarded compact-time/date/math normalization, silence heuristics, and list formatting behavior.
- **`../Packages/KeyVoxLinguistics/`**: linguistic provider contracts, native and portable analyzers, UTF-16 token/range models, feature availability, language normalization, analysis-health evaluation, and lazy health-based fallback routing.
- **`../Packages/KeyVoxModels/`**: shared Whisper Base artifact identity and streaming model-file checksum verification used by the app-owned installer.
- **`../Packages/KeyVoxState/`**: shared observable-state boundary that preserves Combine behavior on Apple platforms.
- **`../Packages/KeyVoxPromotions/`**: campaign manifest loading, eligibility, selection, persistence, and published campaign state.
- **`../Packages/KeyVoxVoiceActivity/`**: shared Silero model, VAD protocol/configuration, actor-isolated detector, and speech-runtime bridge.
- **`../Packages/KeyVoxPredictiveKeyboard/`**: UI-independent English typing prediction and correction built on a bundled AOSP LatinIME native target with KeyVox ranking: the shared `PredictiveTypingSession`, `PredictionComputer`, noisy-channel and missing-space correction, completions, next-word and sentence-opener suggestions, personal vocabulary, typing memory and its file, held-key characters and popup layout, smart quotes, bundled language data, and package tests.
- **`../Packages/KeyVoxEmoji/`**: UI-independent emoji catalog in the system emoji keyboard's categories and order, emoji search, Frequently Used ranking, suggestion-bar emoji by word, two-person skin tones, bundled emoji data, and package tests.
- **`../Packages/KeyVoxTextComposition/`**: platform-neutral leading-capitalization, leading-spacing, quotation-mark context, sentence-boundary, adjacent terminal-punctuation, and trailing-separator policy used immediately before insertion.
- **`../Packages/KeyVoxWhisper/`**: local `whisper.cpp` wrapper package consumed through the shared `WhisperService`, including request parameters and snapshots, compute policy, encoder configuration, segments, and iterable language identifiers.
- **`../Packages/KeyVoxParakeet/`**: local Parakeet runtime package with a public backend seam and the Core ML backend used by the iOS app.
- **`../Packages/KeyVoxTTS/`**: PocketTTS runtime actor, Core ML inference helpers, tokenizer support, text normalization, chunk planning, audio-frame streaming contract, and package tests for deterministic text preparation behavior.
- **`../Packages/KeyVoxLocalInference/`**: llama.cpp-backed local GGUF inference package with chat-template formatting, optional LoRA adapter attachment, quiet llama logging, cancellation, greedy decoding, token accounting, and opt-in live model tests.
- **`../Packages/KeyVoxVibesAdapters/`**: bundled KeyVox-trained LoRA adapter resources and typed adapter catalog used by the app's local Vibes model manager.
- **`../Packages/KeyVoxStyleRewrite/`**: reusable dictation style transform package, style request construction, token-aware chunk planning, model-response orchestration, output repair, Chill heuristic formatting, latest-utterance artifact models, and package tests for transform behavior.
- **`KeyVoxiOSTests/`**: deterministic tests for onboarding state, keyboard-tour routing, settings persistence, KeyVox Vibes artifact persistence, iCloud sync, weekly stats, model lifecycle, copied-text playback policy and lifecycle, model download recovery, microphone permission handling, text input helpers, letter-case shift state, word deletion, typing-memory reset, emoji page and search geometry, cursor-trackpad behavior, and transcription/session orchestration.
- **`iOS/Docs/`**: iOS-local source of truth. `CODEMAP.md` tracks file ownership; `ENGINEERING.md` tracks invariants, contracts, and operational policy.

## Contributor Notes

- Keep iOS-only platform behavior inside the iOS targets. Shared dictation processing and dictionary logic belong in `KeyVoxCore`; shared editor-adjacent composition policy belongs in `KeyVoxTextComposition`.
- Keep the keyboard extension thin. It should transport commands, render keyboard UI, insert final text, and perform artifact-scoped Vibes changes only for untouched KeyVox insertions by asking the containing app to rewrite; it must not become an alternate owner of dictation recording, app onboarding, local rewrite model loading, or broad arbitrary host-text transformation.
- Keep typing prediction, correction, and typing-memory rules in `KeyVoxPredictiveKeyboard`, and emoji data, search, and ranking rules in `KeyVoxEmoji`. The keyboard's `Core/Prediction/` and `Core/Emoji/` files adapt those packages to the document proxy, threads, App Group storage, and keyboard geometry rather than re-implementing their rules.
- Keep app-extension and app-widget contracts centralized in `KeyVoxIPCBridge`; do not duplicate App Group keys, timestamps, or Darwin notification names.
- Keep onboarding state separate from settings state. `OnboardingStore` is the routing owner for onboarding progress and launch flags.
- Keep the keyboard root layout stable. The warning toolbar is intentionally layered as an overlay instead of participating in the main keyboard stack layout.
- Update [`ENGINEERING.md`](ENGINEERING.md) whenever lifecycle rules, IPC contracts, onboarding routing, Live Activity behavior, or model recovery behavior change.

## Directory Index

This is the curated iOS structure map, including the direct shared package dependency.

```text
iOS/
├── CHANGELOG.md
├── Docs/
│   ├── CODEMAP.md
│   └── ENGINEERING.md
├── KeyVox iOS.xcodeproj/
├── KeyVox iOS.xctestplan
├── app-update-policy.json
├── KeyVox iOS/
│   ├── App/
│   │   ├── AppReview/
│   │   │   ├── AppReviewRequestCoordinator.swift
│   │   │   ├── AppReviewRequestPolicy.swift
│   │   │   └── AppReviewRequestStore.swift
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
│   │   │   ├── KeyVoxKeyboardBridge.swift
│   │   │   ├── KeyboardTypingMemoryLocation.swift
│   │   │   └── KeyboardTypingMemoryReset.swift
│   │   ├── KeyVoxSpeak/
│   │   │   ├── KeyVoxSpeakIntroController.swift
│   │   │   └── TTSPurchaseController.swift
│   │   ├── KeyVoxVibes/
│   │   │   ├── KeyVoxVibesAccessMatrix.swift
│   │   │   ├── KeyVoxVibesIntroController.swift
│   │   │   ├── KeyVoxVibesPurchaseController.swift
│   │   │   ├── KeyVoxVibesTrialPolicy.swift
│   │   │   └── KeyVoxVibesTrialRemainingTimeFormatter.swift
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
│   │   │   ├── OnboardingKeyboardTourState.swift
│   │   │   ├── OnboardingMicrophonePermissionController.swift
│   │   │   ├── OnboardingSetupState.swift
│   │   │   ├── OnboardingStore.swift
│   │   │   └── RuntimeFlags.swift
│   │   ├── Presentation/
│   │   │   ├── AppReviewRequestBlockingPreference.swift
│   │   │   ├── AppTypography.swift
│   │   │   ├── InlineWarningRules.swift
│   │   │   ├── KeyboardObserver.swift
│   │   │   └── KeyVoxSpeakFlowRules.swift
│   │   ├── Purchases/
│   │   │   └── StoreUnlockStore.swift
│   │   ├── Routing/
│   │   │   ├── AppLaunchRouteStore.swift
│   │   │   ├── KeyVoxURLRoute.swift
│   │   │   └── KeyVoxURLRouter.swift
│   │   ├── Shortcuts/
│   │   │   ├── DictationShortcutInstaller.swift
│   │   │   ├── DictationShortcutSettingsOpener.swift
│   │   │   ├── DictationShortcutSetupIntroController.swift
│   │   │   ├── KeyVoxSpeakShortcutIntent.swift
│   │   │   ├── KeyVoxSpeakShortcutsProvider.swift
│   │   │   ├── ShortcutDictationCoordinator.swift
│   │   │   └── ToggleKeyVoxDictationIntent.swift
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
│   │   │   ├── AudioRecorder+AudioSessionActivation.swift
│   │   │   ├── AudioRecorder+Session.swift
│   │   │   ├── AudioRecorder+StopPipeline.swift
│   │   │   └── AudioRecorder+Streaming.swift
│   │   ├── Downloads/
│   │   │   ├── ResumableDownloadTaskDescriptor.swift
│   │   │   ├── ResumableDownloadTransport.swift
│   │   │   ├── ResumableDownloadTransport+Lifecycle.swift
│   │   │   └── ResumableDownloadTransport+SessionDelegate.swift
│   │   ├── Extensions/
│   │   │   └── String+NilIfEmpty.swift
│   │   ├── ModelDownloader/
│   │   │   ├── DictationModelCatalog.swift
│   │   │   ├── InstalledDictationModelLocator.swift
│   │   │   ├── ModelBackgroundDownloadCoordinator.swift
│   │   │   ├── ModelBackgroundDownloadCoordinator+State.swift
│   │   │   ├── ModelBackgroundDownloadCoordinator+Transport.swift
│   │   │   ├── ModelBackgroundDownloadCoordinator+TransportDelegate.swift
│   │   │   ├── ModelBackgroundDownloadJob.swift
│   │   │   ├── ModelBackgroundDownloadJobStore.swift
│   │   │   ├── ModelDownloadBackgroundTasks.swift
│   │   │   ├── ModelInstallManifest.swift
│   │   │   ├── ModelInstallState.swift
│   │   │   ├── ModelManager.swift
│   │   │   ├── ModelManager+InstallLifecycle.swift
│   │   │   ├── ModelManager+Support.swift
│   │   │   └── ModelManager+Validation.swift
│   │   ├── LocalRewriteModel/
│   │   │   ├── LocalRewriteBackgroundDownloadCoordinator.swift
│   │   │   ├── LocalRewriteBackgroundDownloadCoordinator+DownloadState.swift
│   │   │   ├── LocalRewriteBackgroundDownloadCoordinator+Transport.swift
│   │   │   ├── LocalRewriteBackgroundDownloadCoordinator+TransportDelegate.swift
│   │   │   ├── LocalRewriteBackgroundDownloadJob.swift
│   │   │   ├── LocalRewriteBackgroundDownloadJobStore.swift
│   │   │   ├── LocalRewriteModelCatalog.swift
│   │   │   ├── LocalRewriteModelInstallManifest.swift
│   │   │   ├── LocalRewriteModelInstallState.swift
│   │   │   ├── LocalRewriteModelManager+BackgroundLifecycle.swift
│   │   │   └── LocalRewriteModelManager.swift
│   │   ├── TTS/
│   │   │   ├── AudioModeCoordinator.swift
│   │   │   ├── PocketTTSAssetLocator.swift
│   │   │   ├── PocketTTSBackgroundDownloadCoordinator.swift
│   │   │   ├── PocketTTSBackgroundDownloadCoordinator+DownloadState.swift
│   │   │   ├── PocketTTSBackgroundDownloadCoordinator+RateLimit.swift
│   │   │   ├── PocketTTSBackgroundDownloadCoordinator+Scheduling.swift
│   │   │   ├── PocketTTSBackgroundDownloadCoordinator+Transport.swift
│   │   │   ├── PocketTTSBackgroundDownloadCoordinator+TransportDelegate.swift
│   │   │   ├── PocketTTSBackgroundDownloadJob.swift
│   │   │   ├── PocketTTSBackgroundDownloadJobStore.swift
│   │   │   ├── PocketTTSEngine.swift
│   │   │   ├── PocketTTSInstallManifest.swift
│   │   │   ├── PocketTTSModelCatalog.swift
│   │   │   ├── PocketTTSModelManager+BackgroundLifecycle.swift
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
│   │   │       ├── TTSPlaybackCoordinator+AudioSessionActivation.swift
│   │   │       ├── TTSPlaybackCoordinator+Lifecycle.swift
│   │   │       ├── TTSPlaybackCoordinator+Progress.swift
│   │   │       ├── TTSPlaybackCoordinator+Scheduling.swift
│   │   │       └── TTSPlaybackCoordinatorBufferingPolicy.swift
│   │   ├── StyleRewrite/
│   │   │   ├── LocalRewriteInferenceService.swift
│   │   │   ├── LocalStyleRewriteTextTransformer.swift
│   │   │   ├── StyleRewriteLatestArtifactStore.swift
│   │   │   └── StyleRewritePipelineCoordinator.swift
│   │   └── Transcription/
│   │       ├── DictationService.swift
│   │       ├── InterruptedCaptureRecovery.swift
│   │       ├── InterruptedCaptureRecoveryStore.swift
│   │       ├── SessionPolicy.swift
│   │       ├── TranscriptionCommandResult.swift
│   │       ├── TranscriptionManager.swift
│   │       ├── TranscriptionManager+InterruptedCaptureRecovery.swift
│   │       └── TranscriptionManager+SessionLifecycle.swift
│   ├── Info.plist
│   ├── KeyVoxiOS.entitlements
│   ├── PrivacyInfo.xcprivacy
│   ├── Resources/
│   │   ├── Assets.xcassets/
│   │   ├── DictationShortcutSetup/
│   │   │   ├── ActionButtonDemoHandoff.mov
│   │   │   ├── ActionButtonDemoPaste.mov
│   │   │   ├── ActionButtonIntro.mov
│   │   │   ├── ActionButtonSettings.mov
│   │   │   ├── ActionButtonShortcutOption.mov
│   │   │   ├── ActionButtonShortcutSelection.mov
│   │   │   ├── AddShortcutPage.mov
│   │   │   └── ShortcutHero.mov
│   │   ├── Kanit-Light.ttf
│   │   ├── Kanit-Medium.ttf
│   │   ├── KeyVoxProducts.storekit
│   │   ├── Onboarding/
│   │   │   ├── EnableKeyboard.mov
│   │   │   └── KeyVoxKeyboardSelection.mov
│   │   ├── ReturnToHost.mov
│   │   ├── Shortcuts/
│   │   │   └── Toggle KeyVox Dictation.shortcut
│   │   ├── TTSVoicePreviews/
│   │   └── keyvox.icon/
│   ├── Views/
│   │   ├── AppRootView.swift
│   │   ├── ContainingAppTab.swift
│   │   ├── MainTabView.swift
│   │   ├── PlaybackPreparationView.swift
│   │   ├── ReturnToHostView.swift
│   │   ├── SettingsTabView/
│   │   │   ├── KeyboardSettingsCopy.swift
│   │   │   ├── KeyboardSettingsView.swift
│   │   │   ├── SettingsRow.swift
│   │   │   ├── SettingsTabView+About.swift
│   │   │   ├── SettingsTabView+General.swift
│   │   │   ├── SettingsTabView+Models.swift
│   │   │   ├── SettingsTabView+TTS.swift
│   │   │   ├── SettingsTabView+VibesAI.swift
│   │   │   └── SettingsTabView.swift
│   │   ├── StyleTabView+KeyVoxVibes.swift
│   │   ├── StyleTabView.swift
│   │   ├── ThirdPartyNoticesView.swift
│   │   ├── Components/
│   │   │   ├── App/
│   │   │   │   ├── AppActionButton.swift
│   │   │   │   ├── AppCard.swift
│   │   │   │   ├── AppIconTile.swift
│   │   │   │   ├── AppPageIndicator.swift
│   │   │   │   ├── AppScrollMetrics.swift
│   │   │   │   ├── AppScrollScreen.swift
│   │   │   │   ├── AppTheme.swift
│   │   │   │   ├── AppTintedScrollIndicator.swift
│   │   │   │   ├── AppTintedScrollView.swift
│   │   │   │   └── AppToolbarContent.swift
│   │   │   ├── AppUpdatePrompt.swift
│   │   │   ├── AutoFocusTextField.swift
│   │   │   ├── DeletionConfirmation.swift
│   │   │   ├── DownloadConfirmation.swift
│   │   │   ├── InlineWarningRow.swift
│   │   │   ├── LogoBarView.swift
│   │   │   ├── LoopingVideoPlayer.swift
│   │   │   ├── ModelDownloaderCardView.swift
│   │   │   ├── ModelDownloadProgress.swift
│   │   │   ├── ModelUpdatePrompt.swift
│   │   │   ├── NativeActivityIndicator.swift
│   │   │   └── PlaybackVoicePickerMenu.swift
│   │   ├── DictionaryTabView/
│   │   │   ├── DictionaryEntryRowView.swift
│   │   │   ├── DictionaryFloatingAddButton.swift
│   │   │   ├── DictionarySortMode.swift
│   │   │   ├── DictionaryTabView.swift
│   │   │   ├── DictionaryWordEditorMode.swift
│   │   │   └── DictionaryWordEditorView.swift
│   │   ├── DictationShortcutSetup/
│   │   │   ├── DictationShortcutSetupBrowsingView.swift
│   │   │   ├── DictationShortcutSetupOnboardingView.swift
│   │   │   ├── DictationShortcutSetupPage.swift
│   │   │   ├── DictationShortcutSetupPageView.swift
│   │   │   ├── DictationShortcutSetupVideoAsset.swift
│   │   │   ├── DictationShortcutSetupVideoView.swift
│   │   │   └── ShortcutIntroView.swift
│   │   ├── HomeTabView/
│   │   │   ├── HomeTabView.swift
│   │   │   ├── IOSPromotionCard.swift
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
│   │   ├── KeyVoxVibes/
│   │   │   ├── KeyVoxVibesIntroSheetView.swift
│   │   │   ├── KeyVoxVibesSceneAView.swift
│   │   │   ├── KeyVoxVibesSceneBView.swift
│   │   │   ├── KeyVoxVibesSceneCView.swift
│   │   │   ├── KeyVoxVibesSheetView.swift
│   │   │   ├── KeyVoxVibesUnlockScene.swift
│   │   │   └── KeyVoxVibesUnlockSheetView.swift
│   │   ├── Onboarding/
│   │   │   ├── OnboardingEnableKeyboardScreen.swift
│   │   │   ├── OnboardingFlowView.swift
│   │   │   ├── OnboardingLanguageScreen.swift
│   │   │   ├── OnboardingLogoPopInSequence.swift
│   │   │   ├── OnboardingSetupScreen.swift
│   │   │   ├── OnboardingStepRow.swift
│   │   │   ├── OnboardingWelcomeScreen.swift
│   │   │   └── Tour/
│   │   │       ├── OnboardingKeyboardTourSceneAView.swift
│   │   │       ├── OnboardingKeyboardTourSceneBView.swift
│   │   │       ├── OnboardingKeyboardTourSceneCView.swift
│   │   │       └── OnboardingKeyboardTourScreen.swift
├── KeyVox Keyboard/
│   ├── App/
│   │   ├── KeyboardContainingAppLauncher.swift
│   │   ├── KeyboardViewController+Debug.swift
│   │   ├── KeyboardViewController+Emoji.swift
│   │   ├── KeyboardViewController+EmojiSearch.swift
│   │   ├── KeyboardViewController+PresentationLifecycle.swift
│   │   ├── KeyboardViewController+Typing.swift
│   │   └── KeyboardViewController.swift
│   ├── Core/
│   │   ├── Dictation/
│   │   │   ├── AudioIndicatorDriver.swift
│   │   │   ├── DictationChange/
│   │   │   │   ├── KeyboardDictationChangeArtifactStore.swift
│   │   │   │   ├── KeyboardDictationChangeController+Actions.swift
│   │   │   │   ├── KeyboardDictationChangeController+Session.swift
│   │   │   │   ├── KeyboardDictationChangeController+Variants.swift
│   │   │   │   ├── KeyboardDictationChangeController.swift
│   │   │   │   └── KeyboardDictationChangeSession.swift
│   │   │   ├── KeyboardLocalStyleRewriteTextTransformer.swift
│   │   │   └── KeyboardDictationController.swift
│   │   ├── Emoji/
│   │   │   ├── KeyboardEmojiCategoryMemory.swift
│   │   │   ├── KeyboardEmojiFrequentlyUsedStore.swift
│   │   │   ├── KeyboardEmojiGridGeometry.swift
│   │   │   ├── KeyboardEmojiPanel.swift
│   │   │   ├── KeyboardEmojiPredictionsIndex.swift
│   │   │   ├── KeyboardEmojiSearchGeometry.swift
│   │   │   ├── KeyboardEmojiSearchIndex.swift
│   │   │   ├── KeyboardEmojiSearchSkinTonePickerLayout.swift
│   │   │   ├── KeyboardEmojiSections.swift
│   │   │   ├── KeyboardEmojiSilhouetteRenderer.swift
│   │   │   ├── KeyboardEmojiSkinTonePickerLayout.swift
│   │   │   ├── KeyboardEmojiSkinToneStore.swift
│   │   │   ├── KeyboardEmojiSupport.swift
│   │   │   └── KeyboardEmojiTwoPersonPickerLayout.swift
│   │   ├── Feedback/
│   │   │   ├── KeyboardHapticsSettingsStore.swift
│   │   │   ├── KeyboardInteractionHaptics.swift
│   │   │   ├── KeyboardKeypressHaptics.swift
│   │   │   ├── KeyboardTextInputHapticPattern.swift
│   │   │   └── KeyboardTextInputHapticPlayer.swift
│   │   ├── Input/
│   │   │   ├── KeyboardCompactKeysHoldController.swift
│   │   │   ├── KeyboardCursorTrackpadSupport.swift
│   │   │   ├── KeyboardDeleteRepeatSchedule.swift
│   │   │   ├── KeyboardHeldKeyController.swift
│   │   │   ├── KeyboardKeyActivation.swift
│   │   │   ├── KeyboardLetterCaseController.swift
│   │   │   ├── KeyboardSpecialKeyInteractionSupport.swift
│   │   │   ├── KeyboardSymbolPageReturnTracker.swift
│   │   │   ├── KeyboardTextInputController.swift
│   │   │   ├── KeyboardTouchRouterGestureRecognizer.swift
│   │   │   └── KeyboardWordDeletion.swift
│   │   ├── Prediction/
│   │   │   ├── KeyboardPersonalVocabularyBuilder.swift
│   │   │   ├── KeyboardPredictionCoordinator.swift
│   │   │   ├── KeyboardPredictionEngine.swift
│   │   │   ├── KeyboardTypingMemory.swift
│   │   │   └── KeyboardTypingTraits.swift
│   │   ├── Settings/
│   │   │   └── KeyboardAppSettingsStore.swift
│   │   ├── Text/
│   │   │   ├── KeyboardCapsLockStateStore.swift
│   │   │   ├── KeyboardDictionaryCasingStore.swift
│   │   │   ├── KeyboardInsertionCapitalizationCoordinator.swift
│   │   │   └── KeyboardInsertionSpacingCoordinator.swift
│   │   ├── Transport/
│   │   │   ├── KeyboardIPCManager.swift
│   │   │   ├── KeyboardTransportDisplayState.swift
│   │   │   └── KeyboardTTSController.swift
│   │   ├── KeyboardLayoutGeometry.swift
│   │   ├── KeyboardKeysMode.swift
│   │   ├── KeyboardDictationModelStatus.swift
│   │   ├── KeyboardInstalledModels.swift
│   │   ├── KeyboardModelAvailability.swift
│   │   ├── KeyboardOpeningLayout.swift
│   │   ├── KeyboardState.swift
│   │   ├── KeyboardStyle.swift
│   │   ├── KeyboardSymbolLayout.swift
│   │   ├── KeyboardTopRowAccessoryLayout.swift
│   │   ├── KeyboardToolbarMode.swift
│   │   └── KeyboardTypography.swift
│   ├── Info.plist
│   ├── KeyVoxKeyboard.entitlements
│   ├── PrivacyInfo.xcprivacy
│   └── Views/
│       ├── FullAccessView.swift
│       ├── KeyboardInputHostView.swift
│       ├── KeyboardRootView.swift
│       ├── Components/
│       │   ├── KeyboardCancelButton.swift
│       │   ├── KeyboardCapsLockButton.swift
│       │   ├── KeyboardHeldKeyPopupView.swift
│       │   ├── KeyboardHitTargetButton.swift
│       │   ├── KeyboardKeyGridPage.swift
│       │   ├── KeyboardKeyGridView+Touches.swift
│       │   ├── KeyboardKeyGridView.swift
│       │   ├── KeyboardKeyPopupView.swift
│       │   ├── KeyboardKeyTouchSession.swift
│       │   ├── KeyboardKeyView.swift
│       │   ├── KeyboardLogoBarView.swift
│       │   ├── KeyboardRoundedBorderRenderer.swift
│       │   ├── KeyboardSettingsToggleButton.swift
│       │   ├── KeyboardSpeakButton.swift
│       │   ├── KeyboardSuggestionBarView.swift
│       │   └── KeyboardVibesButton.swift
│       └── Emoji/
│           ├── KeyboardEmojiCategoryBar+Scrub.swift
│           ├── KeyboardEmojiCategoryBar.swift
│           ├── KeyboardEmojiCategoryStyle.swift
│           ├── KeyboardEmojiCell.swift
│           ├── KeyboardEmojiChoiceHighlightView.swift
│           ├── KeyboardEmojiGridLayout.swift
│           ├── KeyboardEmojiPageView+SkinTones.swift
│           ├── KeyboardEmojiPageView.swift
│           ├── KeyboardEmojiPickerPanelShape.swift
│           ├── KeyboardEmojiSearchFieldView.swift
│           ├── KeyboardEmojiSearchResultsView+SkinTones.swift
│           ├── KeyboardEmojiSearchResultsView.swift
│           ├── KeyboardEmojiSkinTonePickerView.swift
│           └── KeyboardEmojiTwoPersonPickerView.swift
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
│   ├── PrivacyInfo.xcprivacy
│   └── ShareViewController.swift
├── KeyVox Widget/
│   ├── AppIntent.swift
│   ├── Assets.xcassets/
│   ├── Info.plist
│   ├── KeyVox Widget.entitlements
│   ├── KeyVox_WidgetBundle.swift
│   ├── KeyVox_WidgetLiveActivity.swift
│   └── PrivacyInfo.xcprivacy
├── KeyVoxiOSTests/
│   ├── App/
│   │   ├── AppUpdatePolicyEvaluatorTests.swift
│   │   ├── AppHapticsDecisionTests.swift
│   │   ├── AppSettingsStoreTests.swift
│   │   ├── CloudSyncCoordinatorTests.swift
│   │   ├── DictationShortcutSetupIntroControllerTests.swift
│   │   ├── KeyVoxSessionLiveActivityCoordinatorTests.swift
│   │   ├── KeyVoxURLRouterTests.swift
│   │   ├── KeyVoxURLRouteTests.swift
│   │   ├── KeyVoxVibesAccessMatrixTests.swift
│   │   ├── KeyVoxVibesIntroControllerTests.swift
│   │   ├── KeyVoxVibesPurchaseControllerTests.swift
│   │   ├── ModelManagerTests.swift
│   │   ├── OnboardingKeyboardAccessProbeTests.swift
│   │   ├── OnboardingKeyboardTourStateTests.swift
│   │   ├── OnboardingMicrophonePermissionControllerTests.swift
│   │   ├── OnboardingDownloadNetworkMonitorTests.swift
│   │   ├── OnboardingSetupStateTests.swift
│   │   ├── OnboardingStoreTests.swift
│   │   ├── SharedPathsTests.swift
│   │   ├── ShortcutDictationCoordinatorTests.swift
│   │   ├── StyleRewriteLatestArtifactStoreTests.swift
│   │   ├── TTSPurchaseControllerTests.swift
│   │   ├── WeeklyWordStatsCloudSyncTests.swift
│   │   └── WeeklyWordStatsStoreTests.swift
│   ├── Core/
│   │   ├── Audio/
│   │   │   ├── AudioBluetoothRoutePolicyTests.swift
│   │   │   ├── AudioInputPreferenceResolverTests.swift
│   │   │   └── StoppedCaptureProcessorTests.swift
│   │   ├── Keyboard/
│   │   │   ├── KeyboardCompactKeysTests.swift
│   │   │   ├── KeyboardCursorTrackpadSupportTests.swift
│   │   │   ├── KeyboardDeterministicDictationFormatterTests.swift
│   │   │   ├── KeyboardDictationChangeControllerTests.swift
│   │   │   ├── KeyboardDictationControllerTests.swift
│   │   │   ├── KeyboardEmojiCategoryMemoryTests.swift
│   │   │   ├── KeyboardEmojiCategoryStyleTests.swift
│   │   │   ├── KeyboardEmojiGridGeometryTests.swift
│   │   │   ├── KeyboardEmojiSearchKeysTests.swift
│   │   │   ├── KeyboardEmojiSearchSkinTonePickerLayoutTests.swift
│   │   │   ├── KeyboardEmojiSkinTonePickerLayoutTests.swift
│   │   │   ├── KeyboardEmojiSupportTests.swift
│   │   │   ├── KeyboardInteractionHapticsTests.swift
│   │   │   ├── KeyboardLetterCaseControllerTests.swift
│   │   │   ├── KeyboardToolbarModeTests.swift
│   │   │   ├── KeyboardTextInputControllerTests.swift
│   │   │   ├── KeyboardTypingMemoryResetTests.swift
│   │   │   ├── KeyboardViewControllerTests.swift
│   │   │   └── KeyboardWordDeletionTests.swift
│   │   ├── LocalRewriteModel/
│   │   │   └── LocalRewriteBackgroundDownloadJobTests.swift
│   │   ├── ModelDownloader/
│   │   │   ├── ModelBackgroundDownloadCoordinatorTests.swift
│   │   │   └── ModelBackgroundDownloadJobTests.swift
│   │   ├── TTS/
│   │   │   ├── TTSManager/
│   │   │   │   ├── TTSManagerLifecycleTests.swift
│   │   │   │   └── TTSManagerPolicyTests.swift
│   │   │   ├── PocketTTSEngineTests.swift
│   │   │   ├── TTSPlaybackCoordinatorBufferingPolicyTests.swift
│   │   │   └── TTSSystemPlaybackTests.swift
│   │   └── Transcription/
│   │       └── TranscriptionManagerTests.swift
│   ├── Views/
│   │   ├── InlineWarningRulesTests.swift
│   │   ├── KeyVoxSpeakFlowRulesTests.swift
│   │   └── TTSPreparationPresentationPolicyTests.swift
│   └── KeyVoxiOSTests.swift
├── Shortcuts/
│   └── Toggle KeyVox Dictation.wflow
├── Launch Screen.storyboard
└── LaunchLogo.png

Packages/
├── KeyVoxCore/
│   ├── Sources/KeyVoxCore/
│   └── Tests/KeyVoxCoreTests/
├── KeyVoxTextComposition/
│   ├── Package.swift
│   ├── Sources/KeyVoxTextComposition/
│   └── Tests/KeyVoxTextCompositionTests/
├── KeyVoxPredictiveKeyboard/
│   ├── Package.swift
│   ├── Sources/
│   │   ├── KeyVoxPredictiveKeyboard/
│   │   │   ├── AccentSuggestionOverlay.swift
│   │   │   ├── CapitalizedSpellings.swift
│   │   │   ├── CharacterList.swift
│   │   │   ├── ContestedTap.swift
│   │   │   ├── ContestedTapPolicy.swift
│   │   │   ├── ContextLanguageScorer.swift
│   │   │   ├── CorrectionRejections.swift
│   │   │   ├── EnglishKeyboardLayout.swift
│   │   │   ├── EnglishPredictiveEngine.swift
│   │   │   ├── FollowerTable.swift
│   │   │   ├── GrammarWords.swift
│   │   │   ├── HeldKeyCharacters.swift
│   │   │   ├── HeldKeyPopupLayout.swift
│   │   │   ├── KeyCenterMap.swift
│   │   │   ├── LearnedCapitals.swift
│   │   │   ├── LearnedVocabulary.swift
│   │   │   ├── LearnedWords.swift
│   │   │   ├── MissingSpaceCorrector.swift
│   │   │   ├── NoisyChannelCorrector.swift
│   │   │   ├── PersonalVocabulary.swift
│   │   │   ├── PersonalWordForms.swift
│   │   │   ├── PickVariety.swift
│   │   │   ├── PredictionComputer.swift
│   │   │   ├── PredictionModels.swift
│   │   │   ├── PredictionRequest.swift
│   │   │   ├── PredictionResult.swift
│   │   │   ├── PredictiveArtifactLocator.swift
│   │   │   ├── PredictiveData/
│   │   │   ├── PredictiveTypingSession.swift
│   │   │   ├── RepeatedPicks.swift
│   │   │   ├── RevisionRequest.swift
│   │   │   ├── ScoredWordLines.swift
│   │   │   ├── SentenceEnding.swift
│   │   │   ├── SentenceOpeners.swift
│   │   │   ├── SmartQuotes.swift
│   │   │   ├── SuggestionBar.swift
│   │   │   ├── SuggestionBarComposer.swift
│   │   │   ├── SuggestionCandidateRanker.swift
│   │   │   ├── TextEdit.swift
│   │   │   ├── TouchAlignmentScorer.swift
│   │   │   ├── TypedWordTouches.swift
│   │   │   ├── TypingMemory.swift
│   │   │   ├── TypingMemoryFile.swift
│   │   │   ├── TypingSlip.swift
│   │   │   ├── TypingTextContext.swift
│   │   │   ├── UnknownWordFollowers.swift
│   │   │   ├── WordCasing.swift
│   │   │   └── WordFollowers.swift
│   │   └── KeyVoxPredictiveNative/
│   │       ├── KeyVoxPredictiveNative.cpp
│   │       ├── include/KeyVoxPredictiveNative.h
│   │       ├── jni.h
│   │       └── latinime/
│   └── Tests/KeyVoxPredictiveKeyboardTests/
├── KeyVoxEmoji/
│   ├── Package.swift
│   ├── Sources/KeyVoxEmoji/
│   │   ├── Emoji.swift
│   │   ├── EmojiCatalog.swift
│   │   ├── EmojiCatalog+KeyboardSections.swift
│   │   ├── EmojiData/
│   │   │   ├── emoji_catalog.txt
│   │   │   ├── emoji_predictions.txt
│   │   │   ├── emoji_search.txt
│   │   │   └── emoji_starters.txt
│   │   ├── EmojiDataError.swift
│   │   ├── EmojiDataLocator.swift
│   │   ├── EmojiFrequentlyUsed.swift
│   │   ├── EmojiKeyboardCategory.swift
│   │   ├── EmojiKeyboardSection.swift
│   │   ├── EmojiPredictions.swift
│   │   ├── EmojiSearch.swift
│   │   └── EmojiTwoPersonTones.swift
│   └── Tests/KeyVoxEmojiTests/
├── KeyVoxLinguistics/
│   ├── Package.swift
│   ├── Sources/KeyVoxLinguistics/
│   │   ├── AppleLexicalRole.swift
│   │   ├── AppleLinguisticAnalyzer.swift
│   │   ├── AppleLinguisticCapabilities.swift
│   │   ├── HealthRoutingLinguisticAnalyzer.swift
│   │   ├── LexicalRole.swift
│   │   ├── LinguisticAnalysis.swift
│   │   ├── LinguisticAnalysisHealth.swift
│   │   ├── LinguisticAnalyzerFactory.swift
│   │   ├── LinguisticAnalyzing.swift
│   │   ├── LinguisticFeatures.swift
│   │   ├── LinguisticToken.swift
│   │   ├── ModelLanguageIdentifier.swift
│   │   ├── PennContextualRoleResolver.swift
│   │   ├── PennLexicalRole.swift
│   │   ├── PerceptronFeatures.swift
│   │   ├── PerceptronLinguisticAnalyzer.swift
│   │   ├── PerceptronModel.swift
│   │   ├── PerceptronModelLoader.swift
│   │   ├── PlatformLinguisticAnalyzer.swift
│   │   ├── Resources/
│   │   ├── UnicodeLinguisticAnalyzer.swift
│   │   ├── UnicodeWordTokenizer.swift
│   │   ├── WordNetLexicalDatabase.swift
│   │   └── WordNetLexicalRoleResolver.swift
│   └── Tests/KeyVoxLinguisticsTests/
├── KeyVoxModels/
│   ├── Package.swift
│   ├── Sources/KeyVoxModels/
│   │   ├── ModelFileIntegrity.swift
│   │   ├── WhisperBaseModelArtifact.swift
│   │   └── WhisperEncoderArtifact.swift
│   └── Tests/KeyVoxModelsTests/
├── KeyVoxState/
│   ├── Package.swift
│   ├── Sources/KeyVoxState/
│   │   ├── StateChannel.swift
│   │   ├── StateUpdates.swift
│   │   └── StateValue.swift
│   └── Tests/KeyVoxStateTests/
├── KeyVoxPromotions/
│   ├── Package.swift
│   ├── Sources/KeyVoxPromotions/
│   │   ├── PromotionCampaign.swift
│   │   ├── PromotionCenter*.swift
│   │   ├── PromotionContent.swift
│   │   ├── PromotionDefaults.swift
│   │   ├── PromotionEligibility.swift
│   │   ├── PromotionManifest*.swift
│   │   ├── PromotionPlatform.swift
│   │   ├── PromotionResources.swift
│   │   ├── PromotionSelection.swift
│   │   ├── PromotionStateStore.swift
│   │   ├── PromotionVersion.swift
│   │   └── Resources/campaigns.json
│   └── Tests/KeyVoxPromotionsTests/
├── KeyVoxVoiceActivity/
│   ├── Package.swift
│   ├── Sources/
│   │   ├── CWhisper/
│   │   ├── KeyVoxVoiceActivity/
│   │   │   ├── VoiceActivityAnalyzing.swift
│   │   │   ├── VoiceActivityConfiguration.swift
│   │   │   ├── VoiceActivityDetector.swift
│   │   │   └── Resources/ggml-silero-v5.1.2.bin
│   │   └── KeyVoxSpeechRuntime/SpeechRuntime.swift
│   └── Tests/KeyVoxVoiceActivityTests/
├── KeyVoxWhisper/
│   ├── Package.swift
│   ├── Sources/KeyVoxWhisper/
│   │   ├── Segment.swift
│   │   ├── Whisper.swift
│   │   ├── WhisperComputePolicy.swift
│   │   ├── WhisperEncoderConfiguration.swift
│   │   ├── WhisperError.swift
│   │   ├── WhisperLanguage.swift
│   │   ├── WhisperModelLanguage.swift
│   │   ├── WhisperParams.swift
│   │   └── WhisperParamsSnapshot.swift
│   └── Tests/KeyVoxWhisperTests/
├── KeyVoxParakeet/
│   ├── Package.swift
│   ├── Sources/KeyVoxParakeet/
│   └── Tests/KeyVoxParakeetTests/
├── KeyVoxVibesAdapters/
│   ├── Package.swift
│   ├── Sources/KeyVoxVibesAdapters/
│   │   ├── KeyVoxVibesAdapterCatalog.swift
│   │   └── Resources/Adapters/
│   │       ├── casual-alpha-9-lora.gguf
│   │       └── polished-alpha-027-lora.gguf
│   └── Tests/KeyVoxVibesAdaptersTests/
│       └── KeyVoxVibesAdapterCatalogTests.swift
├── KeyVoxStyleRewrite/
│   ├── Package.swift
│   ├── Sources/KeyVoxStyleRewrite/
│   │   ├── ChillHeuristicFormatter.swift
│   │   ├── DictationTextTransforming.swift
│   │   ├── OutputRepair/
│   │   │   ├── OutputRepair.swift
│   │   │   ├── Repairs/
│   │   │   └── Support/
│   │   ├── StyleRewriteDictationConfiguration.swift
│   │   ├── StyleRewriteInputVariantSelection.swift
│   │   ├── StyleRewritePromptLeakGuard.swift
│   │   ├── StyleRewriteTextTransformer.swift
│   │   └── TextTransformChunkPlanner.swift
│   └── Tests/KeyVoxStyleRewriteTests/
├── KeyVoxLocalInference/
│   ├── Package.swift
│   ├── Sources/KeyVoxLocalInference/
│   │   ├── LocalLanguageModel.swift
│   │   ├── LocalLanguageModelGPUOffloadMode+Logging.swift
│   │   ├── LocalInferenceCancellationToken.swift
│   │   ├── LlamaLoadedModel.swift
│   │   ├── LlamaLocalLanguageModel*.swift
│   │   └── ProcessInfo+XCTest.swift
│   └── Tests/KeyVoxLocalInferenceTests/
│       ├── LocalLanguageModelCasualPromptLiveTests.swift
│       ├── LocalLanguageModelLiveTestSupport.swift
│       ├── LocalLanguageModelPolishedGauntletLiveTests.swift
│       ├── LocalLanguageModelTests.swift
│       └── LocalLanguageModelVibePromptLiveTests.swift
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
    │   ├── PocketTTSModelMetadata.swift
    │   ├── PocketTTSMimiInference.swift
    │   ├── PocketTTSSpokenNumberNormalizer.swift
    │   ├── PocketTTSTextNormalizer.swift
    │   ├── SentencePieceModelParser.swift
    │   └── SentencePieceTokenizer.swift
    └── Tests/KeyVoxTTSTests/
        ├── LinguisticAnalyzerTestCase.swift
        ├── PocketTTSChunkPlannerTests.swift
        └── PocketTTSSpokenNumberNormalizerTests.swift
```

## Current Runtime Map

### Shared Linguistic Analysis

- `Packages/KeyVoxLinguistics/Sources/KeyVoxLinguistics/LinguisticAnalyzing.swift`
  - Defines the text, optional UTF-16 range, optional language, requested features, grouping, and result boundary used by all linguistic consumers.
- `Packages/KeyVoxLinguistics/Sources/KeyVoxLinguistics/LinguisticAnalysisHealth.swift`
  - Validates token ranges and requested evidence against the effective caller range, while treating punctuation-only requested ranges as valid inconclusive results.
- `Packages/KeyVoxLinguistics/Sources/KeyVoxLinguistics/HealthRoutingLinguisticAnalyzer.swift`
  - Keeps healthy native analysis primary, resolves the portable analyzer lazily after an unhealthy result, latches that route by normalized language, and reports the selected provider and reason.
- `Packages/KeyVoxLinguistics/Sources/KeyVoxLinguistics/LinguisticAnalyzerFactory.swift`
  - Builds the shared health-routed analyzer and loads the perceptron and WordNet resources only when the normalized request language matches the configured portable language.
- `Packages/KeyVoxLinguistics/Sources/KeyVoxLinguistics/PerceptronLinguisticAnalyzer.swift`
  - Supplies portable token boundaries and grammatical roles, with WordNet-backed lexical resolution where requested.
- `KeyVox iOS.xcodeproj/project.pbxproj`
  - The containing-app target copies `averaged-perceptron-tagger-eng` and `wordnet-3.0` into its bundle. The keyboard target has no ownership of these resources.

### Shared Runtime Infrastructure

- `Packages/KeyVoxModels/Sources/KeyVoxModels/WhisperBaseModelArtifact.swift`
  - Owns the shared Whisper Base revision, filename, download URL, and checksum. The iOS catalog adds its host-owned install layout and Core ML acceleration artifact.
- `Packages/KeyVoxModels/Sources/KeyVoxModels/ModelFileIntegrity.swift`
  - Streams model files through SHA-256 with byte progress while leaving download and install state with `ModelManager`.
- `Packages/KeyVoxState/Sources/KeyVoxState/StateValue.swift`
  - Keeps shared service state portable while mapping directly to `Published` and `ObservableObject` on Apple platforms; `WhisperService`, `ParakeetService`, `DictionaryStore`, and `PromotionCenter` use this boundary.
- `Packages/KeyVoxPromotions/Sources/KeyVoxPromotions/`
  - Owns campaign manifest decoding and retrieval, cached/bundled fallback, version and date eligibility, deterministic startup selection/rotation, persisted selection state, repository-cache refresh, and the published `PromotionCenter.currentCampaign` value.
- `Packages/KeyVoxVoiceActivity/Sources/KeyVoxVoiceActivity/`
  - Owns the shared VAD protocol, standard configuration, Silero resource, actor-isolated detector, and speech-segment results used by Whisper and Parakeet.
- `Packages/KeyVoxVoiceActivity/Sources/KeyVoxSpeechRuntime/SpeechRuntime.swift`
  - Exposes the shared `whisper.cpp` runtime bridge consumed by both the VAD detector and `KeyVoxWhisper`.

### App Lifecycle and Composition

- `KeyVox iOS/App/Lifecycle/KeyVoxiOSApp.swift`
  - SwiftUI app entry point.
  - Injects all app-wide environment objects.
  - Registers model-download background tasks.
  - Handles scene activation/background callbacks for transcription recovery, model recovery, onboarding keyboard-tour arming, Dictation Shortcut intro scheduling, shortcut-route consumption, and Dictation/Speak/Vibes download transport handoffs.
  - Starts Dictation, Speak, and Vibes foreground-to-background handoffs during `.inactive`, while the app still has foreground execution time, and hands unfinished transfers back during `.active`.
  - Consumes any cold-launch URL route that was captured before SwiftUI rendered and pre-presents `ReturnToHostView` without animation before routing `keyvoxios://record/start`.
  - Asks `OnboardingStore` to resolve its persisted state on every scene-phase change and again when protected data becomes available.
- `KeyVox iOS/App/Composition/SharedPaths.swift`
  - Centralizes rooted app-group, cache, and install filesystem locations used by app-owned services.
- `KeyVox iOS/App/Shortcuts/KeyVoxSpeakShortcutIntent.swift`
  - App-owned `Speak Copied Text` App Intent for the official KeyVox Speak shortcut.
  - Stages the existing `keyvoxios://tts/start` route into shared app-group state and relies on the containing app to consume and route it on activation.
- `KeyVox iOS/App/Shortcuts/ToggleKeyVoxDictationIntent.swift`
  - Background-capable audio-recording App Intent that starts or stops the shared KeyVox dictation session without foregrounding the containing app.
  - Returns no value when recording begins or no speech is detected, and returns only completed transcript text when stopping succeeds.
  - Exposes the optional `Release Mic Immediately` parameter, which defaults off.
- `KeyVox iOS/App/Shortcuts/ShortcutDictationCoordinator.swift`
  - Maps the shared transcription state into idle, recording, and busy shortcut outcomes without becoming a second recording owner.
  - Prepares Live Activity support before shortcut recording begins, routes start/stop commands into `TranscriptionManager`, and maps typed command results into App Intent outcomes.
  - Reports whether recording actually started when completing Live Activity preparation, and releases the microphone on stop whenever no Live Activity is showing, even when `Release Mic Immediately` is off.
- `KeyVox iOS/App/Shortcuts/DictationShortcutInstaller.swift`
  - App-owned installer handoff used by the onboarding and Settings guide for the signed bundled workflow.
  - Opens the shortcut file directly on supported system releases and presents the standard share sheet on earlier releases, including popover anchoring for regular-width layouts.
- `KeyVox iOS/App/Shortcuts/DictationShortcutSettingsOpener.swift`
  - Main-actor system Settings handoff used by the guided Action Button setup pages.
- `KeyVox iOS/App/Shortcuts/DictationShortcutSetupIntroController.swift`
  - App-owned one-time presentation state for showing the full Dictation Shortcut guide to existing users on an eligible launch.
  - Defers presentation until onboarding is already complete, records handled state, and takes priority over automatic KeyVox Vibes and KeyVox Speak introductions.
- `KeyVox iOS/App/Shortcuts/KeyVoxSpeakShortcutsProvider.swift`
  - Registers the Toggle Dictation and KeyVox Speak App Shortcut phrases surfaced in the Shortcuts system.
- `KeyVox iOS/App/Lifecycle/AppDelegate.swift`
  - Receives background `URLSession` callbacks and routes each configured session identifier to its owning Dictation, Speak, or Vibes model manager.
- `KeyVox iOS/App/Lifecycle/AppSceneDelegate.swift`
  - Captures cold-launch scene connection URLs before the first root render and forwards them into the launch-route store.
- `KeyVox iOS/App/Routing/AppLaunchRouteStore.swift`
  - Small launch-scoped routing owner for early cold-start URL presentation and later route consumption.
- `KeyVox iOS/App/Routing/KeyVoxURLRoute.swift`
  - Typed app route surface for cold-start recording, copied-text playback, locked KeyVox Vibes launches, Vibes trial-start launches, and keyboard-originated missing-model recovery.
- `KeyVox iOS/App/Routing/KeyVoxURLRouter.swift`
  - App-owned URL parsing and route dispatch owner for record, TTS, locked Vibes, Vibes trial-start, model recovery, and return-to-host flows.
- `KeyVox iOS/App/Composition/AppServiceRegistry.swift`
  - Main composition root.
  - Builds dictionary, onboarding, settings, App Store review-request state, weekly stats, app haptics, the shared app-tab router, Whisper, Parakeet, the active-provider router, post-processing, dictation model management, local Vibes model management, local Vibes inference, keyboard bridge, transcription, Shortcut dictation coordination, Dictation Shortcut intro state, KeyVox Vibes style rewrite coordination, PocketTTS runtime services, the TTS unlock gate, KeyVox Vibes purchase/trial state, the KeyVox Speak and Vibes intro controllers, the App Store update coordinator, iCloud sync, Live Activity, and URL-routing services.
  - Applies the persisted Whisper language when the service is created and keeps later device-local language changes synchronized with `WhisperService`.
  - Creates one health-routed linguistic analyzer from containing-app resources and injects it into Whisper continuation analysis, `TranscriptionPostProcessor`, the local Vibes transformer, and `PocketTTSEngine`.
  - Creates the iOS `PromotionCenter` with the current app version, iOS audience, App Group defaults, and runtime-selected bundled or remote manifest source.
  - Creates `OnboardingStore` with the current protected-data availability, and tells `CloudSyncCoordinator` to treat the install as existing while onboarding state is still unresolved so an unreadable launch is never seeded as a fresh dictionary install.
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
- `KeyVox iOS/App/KeyVoxVibes/KeyVoxVibesIntroController.swift`
  - App-owned cold-launch intro owner for the KeyVox Vibes presentation flow.
  - Mirrors the KeyVox Speak deferred-launch pattern, refuses to present over onboarding, return-to-host, or recording launches, and can reserve a usage-only scene path for future help entry points.
- `KeyVox iOS/App/KeyVoxVibes/KeyVoxVibesAccessMatrix.swift`
  - Semantic access/model-state matrix for the Style tab Vibes card.
  - Resolves access state plus local Vibes AI availability into card content, visible control, card action, destination start scene, dynamic text class, and destination CTA without coupling tests to display copy.
- `KeyVox iOS/App/KeyVoxVibes/KeyVoxVibesPurchaseController.swift`
  - App-owned unlock and local trial state owner for KeyVox Vibes.
  - Loads the Vibes StoreKit non-consumable product, owns purchase and restore flows, caches unlock state, records the versioned local trial start date, reads the shared trial duration policy, exposes `canUseVibes`, and forces selected Vibe back to `None` when access expires.
- `KeyVox iOS/App/KeyVoxVibes/KeyVoxVibesTrialPolicy.swift`
  - Shared source of truth for the KeyVox Vibes local trial duration used by the app, keyboard extension, trial copy, and tests.
- `KeyVox iOS/App/KeyVoxVibes/KeyVoxVibesTrialRemainingTimeFormatter.swift`
  - Formats Vibes trial durations for UI copy with adaptive days/hours/minutes output while leaving each view responsible for its own surrounding sentence.
- `KeyVox iOS/App/Purchases/StoreUnlockStore.swift`
  - Shared StoreKit non-consumable loading, purchase, restore, and entitlement abstraction used by both KeyVox Speak and KeyVox Vibes purchase controllers.
- `KeyVox iOS/App/Presentation/KeyVoxSpeakFlowRules.swift`
  - Pure scene-selection and scene-fallback rules shared by the intro sheet, unlock sheet, and the Home help presentation path so branch coverage stays deterministic in tests.
- `KeyVox iOS/App/Presentation/InlineWarningRules.swift`
  - Pure warning-visibility rules shared by onboarding, KeyVox Speak setup, Home copied-text playback, and Settings install surfaces so Wi-Fi warning coverage stays deterministic in iOS tests.
- `KeyVox iOS/App/Presentation/AppTypography.swift`
  - App-wide typography helpers for SwiftUI surfaces that should share the same app font treatment.
- `KeyVox iOS/App/Presentation/KeyboardObserver.swift`
  - App-side keyboard-presentation observer used by text-entry flows such as onboarding and dictionary editing.
- `KeyVox iOS/App/Stats/WeeklyWordStatsStore.swift`
  - App-owned local weekly usage aggregator consumed by Home, settings-adjacent surfaces, and Live Activity mirroring.
- `KeyVox iOS/App/Feedback/AppHaptics.swift`
  - App-owned UIKit haptic emitter injected through the SwiftUI environment.
- `KeyVox iOS/App/Feedback/AppHapticsDecisions.swift`
  - Pure decision helpers for onboarding step completion, tab selection, edge-swipe, session-toggle, and dictionary-save haptics.
- `KeyVox iOS/App/AppReview/AppReviewRequestPolicy.swift`
  - Pure StoreKit review eligibility rule: onboarding completed before the current launch, an installation older than the eligibility window, a successful dictation inside that window, and no earlier request for the current version.
- `KeyVox iOS/App/AppReview/AppReviewRequestStore.swift`
  - App-owned defaults persistence for the first-launch date, last successful dictation date, and last requested version, recorded through the registry's successful-dictation callback.
- `KeyVox iOS/App/AppReview/AppReviewRequestCoordinator.swift`
  - Schedules a delayed review request only while the main interface is presented without a competing presentation or update-prompt refresh, suppresses requests for the rest of an activation once something competes, and cancels pending work when the app leaves active.
- `KeyVox iOS/App/Presentation/AppReviewRequestBlockingPreference.swift`
  - SwiftUI preference that lets descendant presentations block the review request.

### Onboarding and Root Routing

- `KeyVox iOS/Views/AppRootView.swift`
  - Root router for launch hold vs return-to-host vs onboarding overlay vs main app.
  - Holds on the launch route until both the initial launch context and the onboarding store's persisted state are resolved.
  - Keeps `MainTabView` mounted under the onboarding overlay so onboarding can fade into the live shell without re-rooting the scene tree.
  - Suppresses `ReturnToHostView` whenever onboarding is active or was just completed during the same launch.
  - Owns the automatic existing-user Dictation Shortcut guide plus post-onboarding KeyVox Speak and KeyVox Vibes intro sheets, all gated to the true `.main` route.
  - Gives the unhandled Dictation Shortcut guide first priority, then KeyVox Vibes, then KeyVox Speak, deferring lower-priority introductions to later eligible launches.
  - Also owns the system update alert presentation and keeps update prompts scoped to the `.main` route so launch-hold, onboarding, return-to-host, and playback-preparation flows remain uninterrupted.
- `KeyVox iOS/App/Onboarding/OnboardingStore.swift`
  - Persisted onboarding state for welcome, language selection, the Dictation Shortcut setup handoff, keyboard setup/tour continuation, and full completion.
  - Owns the selected onboarding language separately from completion so returning to the picker restores the exact checkmark.
  - Also owns launch-scoped route flags, forced onboarding/Shortcut setup entry, pending keyboard and Shortcut setup state, and post-completion suppression.
  - Records the keyboard-tour handoff after the guided Shortcut pages and arms it when the KeyVox keyboard becomes enabled in system settings.
  - Publishes `hasResolvedPersistentState`: when protected data is unavailable at launch and no completion value can be read, it defers to a later resolution that rereads the persisted onboarding values without writing them back.
- `KeyVox iOS/Views/Onboarding/OnboardingFlowView.swift`
  - Stack-based onboarding router: welcome -> language -> setup -> Dictation Shortcut setup -> keyboard enablement -> keyboard tour.
  - Keeps earlier screens mounted so forward routes slide over them and back navigation restores their existing state.
- `KeyVox iOS/Views/Onboarding/OnboardingLanguageScreen.swift`
  - Searchable Whisper-language picker, including Auto Detect, before model setup.
  - Persists the selected language through `OnboardingStore` and `AppSettingsStore`, dismisses search focus before advancing, and restores interaction when the setup route returns to it.
- `KeyVox iOS/Views/Onboarding/OnboardingSetupScreen.swift`
  - Whisper Base download and microphone-permission prerequisite screen.
  - Gates the combined keyboard-and-Shortcut setup handoff until both prerequisites are complete, while allowing them to proceed in parallel.
  - Starts the guided Dictation Shortcut route; keyboard system settings are handled later by `OnboardingEnableKeyboardScreen`.
  - Uses app-owned haptics for warning/success step feedback.
- `KeyVox iOS/Views/DictationShortcutSetup/DictationShortcutSetupOnboardingView.swift`
  - Controlled eight-step onboarding flow with back, Skip, bottom CTA, and non-interactive shared page indicator behavior.
  - Installs the bundled Shortcut from Add Shortcut, opens system Settings from Action Button Shortcut Selection, and hands off to keyboard enablement from Action Button Demo Handoff.
- `KeyVox iOS/Views/DictationShortcutSetup/DictationShortcutSetupBrowsingView.swift`
  - Swipeable reuse of the same eight steps for the one-time existing-user introduction and the Settings reference guide.
  - Existing-user mode retains guided CTAs and Finish; Settings mode limits actions to Add Shortcut and Open Settings while allowing free step browsing and close.
  - Sizes each page to the full screen width with the safe-area padding inside the page so neighboring pages never show beside the current one, uses an inline navigation title, and keeps the navigation bar from minimizing on scroll where the system supports that behavior.
- `KeyVox iOS/Views/DictationShortcutSetup/DictationShortcutSetupPage.swift`
  - Ordered setup-step model, semantic step identifiers, accessibility descriptions, and single source of truth for the eight bundled video asset names and viewport dimensions.
- `KeyVox iOS/Views/DictationShortcutSetup/DictationShortcutSetupPageView.swift`
  - Shared per-step presentation that composes `ShortcutIntroView` with the reusable video viewport.
- `KeyVox iOS/Views/DictationShortcutSetup/DictationShortcutSetupVideoView.swift`
  - Active-page looping playback wrapper for the transparent Shortcut/Action Button instructional media.
- `KeyVox iOS/Views/Components/App/AppPageIndicator.swift`
  - Shared page-count/selection presentation with optional one-page previous/next navigation and VoiceOver adjustable actions.
- `KeyVox iOS/Views/Components/LoopingVideoPlayer.swift`
  - Reusable bundled-video player with readiness binding and explicit play/pause control.
  - Pauses and seeks inactive pages to the start, restarts when they become active, and resumes active playback after app activation.
- `KeyVox iOS/Views/Onboarding/OnboardingEnableKeyboardScreen.swift`
  - Dedicated post-Shortcut screen that demonstrates enabling the KeyVox keyboard and Full Access, opens app keyboard settings, and resumes into the keyboard tour when enablement is detected.
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
- `KeyVox iOS/App/Onboarding/OnboardingKeyboardAccessProbe.swift`
  - App-side probe for keyboard enablement, keyboard presentation, and keyboard-reported Full Access confirmation.
- `KeyVox iOS/App/Onboarding/OnboardingMicrophonePermissionController.swift`
  - App-side microphone permission surface for onboarding.
- `KeyVox iOS/App/Onboarding/OnboardingDownloadNetworkMonitor.swift`
  - Cellular vs non-cellular detection for onboarding download copy.
- `KeyVox iOS/App/Onboarding/RuntimeFlags.swift`
  - Reads `KEYVOX_FORCE_ONBOARDING`, `KEYVOX_FORCE_DICTATION_SHORTCUT_SETUP`, copied-text playback/Vibes development flags, promotion-preview flags, and the debug-only `KEYVOX_FORCE_FRESH_DICTIONARY_INSTALL` flag from the process environment.

### Shared State, IPC, and Session Surfaces

- `KeyVox iOS/App/Integration/KeyVoxIPCBridge.swift`
  - Source of truth for App Group defaults keys, the latest published transcription with its utterance ID and selected style identifier, TTS playback state and request state, language-preserving style rewrite IPC request/response storage, replay-related shared request storage, shortcut-staged pending route storage, keyboard onboarding presentation/access timestamps, shared live-meter file transport, keyboard settings-change signaling, and Darwin notification names.
  - Does not carry app-update state; required updates stay inside the containing app and do not change keyboard dictation availability.
- `KeyVox iOS/App/Integration/KeyVoxTTSRequest.swift`
  - Dependency-free shared copied-text playback request model and enums used by both the containing app and share extension to keep the JSON handoff contract compile-time safe.
- `KeyVox iOS/App/iCloud/UserDefaultsKeys.swift`
  - Includes onboarding language completion/selection, pending Dictation Shortcut setup, and one-time Shortcut guide handled-state keys.
  - Includes the app-owned cached TTS unlock state plus the local day token and free-speak usage count used by the phase-one copied-text playback gate.
  - Also includes the post-onboarding KeyVox Speak intro keys for seen-state, feature-used state, the delayed eligible-open counter, and the app-owned cached update decision keys used for cold-launch reminders.
  - Also includes the KeyVox Vibes style-selection keys used by both `AppSettingsStore` and the keyboard extension's Vibes selector.
  - Also includes the shared Compact Keys availability and active-mode keys used by the containing app and keyboard extension.
  - Also includes the shared keyboard typing settings (auto-capitalization, auto-correction, shift caps lock, predictive text, emoji keyboard, period shortcut, and Open on 123), the typing-memory reset generation, the keyboard's emoji Frequently Used and per-emoji skin-tone keys, and the app-owned review-request dates and last requested version.
- `KeyVox iOS/App/iCloud/AppSettingsStore.swift`
  - Owns the device-local active dictation provider and Whisper language selection alongside the app's other persisted settings.
  - Validates restored Whisper language identifiers against `WhisperBaseLanguageCatalog` and defaults missing or unsupported values to Auto Detect; this preference is intentionally not part of iCloud settings sync.
  - Owns the user-facing Compact Keys availability toggle, which defaults on and clears any active compact mode when disabled.
  - Owns the published keyboard typing settings shown on the Keyboard settings screen; every toggle defaults on except Open on 123, which defaults off, and each writes its shared App Group key for the keyboard extension to read.
- `KeyVox iOS/App/iCloud/KeyVoxPlaybackVoice.swift`
  - Dependency-free shared playback-voice catalog used by both `AppSettingsStore` and the share extension when resolving canonical TTS voice IDs and display names.
- `KeyVox iOS/App/Integration/KeyVoxKeyboardBridge.swift`
  - App-side IPC endpoint for start/stop/cancel/disable-session/style-rewrite commands and extension-facing state publishing.
  - Publishes each ready transcription with its utterance ID and selected style identifier.
- `KeyVox iOS/App/Integration/KeyboardTypingMemoryLocation.swift`
  - Single source of truth for the App Group `Keyboard/typing-memory.json` location, compiled into the containing app, keyboard extension, and tests.
- `KeyVox iOS/App/Integration/KeyboardTypingMemoryReset.swift`
  - App-side reset of what the keyboard learned from typing: increments the shared reset generation before removing the memory file so a keyboard still holding the old memory never saves it again.
- `KeyVox iOS/App/LiveActivity/KeyVoxSessionLiveActivityCoordinator.swift`
  - App-side owner that mirrors session state and weekly-word count into the widget extension through ActivityKit.
  - Prepares the required Live Activity before background audio-recording intents start and reconciles the pending activity against the actual session outcome.
  - Keeps an activity started for a successful audio-recording intent showing until the session ends, even if the Live Activities setting is turned off mid-session.
  - Exposes whether a Live Activity is actually showing; dismissed or ended activities do not count, and a removed cached activity is replaced by another showing one or a new request.
- `KeyVox iOS/App/LiveActivity/KeyVoxSessionLiveActivityAttributes.swift`
  - Shared ActivityKit attributes and content state.
- `KeyVox Widget/AppIntent.swift`
  - `EndSessionIntent` that posts the shared disable-session Darwin notification.
- `KeyVox Widget/KeyVox_WidgetLiveActivity.swift`
  - Lock screen and Dynamic Island UI for the live activity.

### Model Installation and Recovery

- `KeyVox iOS/Core/Downloads/ResumableDownloadTransport.swift`
  - Reusable transport owner for paired foreground and background `URLSession` instances, synchronized per-family session creation, task discovery and deduplication, pending resume data, cancellation, and background-session completion handlers.
  - Contains no model catalog, installation path, retry policy, persisted job, or finalization logic. Each model family supplies those policies through `ResumableDownloadTransportDelegate`.
- `KeyVox iOS/Core/Downloads/ResumableDownloadTransport+Lifecycle.swift`
  - Owns the reusable foreground/background handoff state machine.
  - Cancels tasks with resume data, transfers the resume tokens to the destination session through the family delegate, and follows a newer lifecycle state if the app changes phase while a handoff is running.
- `KeyVox iOS/Core/Downloads/ResumableDownloadTransport+SessionDelegate.swift`
  - Converts raw `URLSessionDownloadDelegate` callbacks into family-neutral progress, temporary-file completion, task completion, and background-event notifications.
- `KeyVox iOS/Core/Downloads/ResumableDownloadTaskDescriptor.swift`
  - Encodes and decodes the universal `jobID` plus `artifactID` identity stored in `URLSessionTask.taskDescription`.
  - Family separation comes from distinct transport instances and background-session identifiers, allowing independent download families to run simultaneously without sharing or cancelling each other's tasks.
  - The transport is reusable because model-specific persistence, installation, scheduling, and retry behavior stay behind its delegate boundary.

- `KeyVox iOS/Core/ModelDownloader/ModelManager.swift`
  - Observable owner of per-model install state, active-install gating, user-facing download/delete/repair actions, relaunch recovery, and Dictation transport lifecycle handoffs.
  - Enforces one active download/install at a time and keeps provider selection persistence outside the model manager.
- `KeyVox iOS/Core/ModelDownloader/DictationModelCatalog.swift`
  - iOS-local model descriptor catalog for `Whisper Base` and `Parakeet TDT v3`, including artifact metadata and rooted install layout rules.
- `KeyVox iOS/Core/ModelDownloader/InstalledDictationModelLocator.swift`
  - Rooted install/staging locator plus legacy Whisper migration and lightweight installed-model resolution helpers for Whisper and Parakeet.
- `KeyVox iOS/Core/ModelDownloader/ModelBackgroundDownloadCoordinator.swift`
  - Dictation-specific owner of the reusable foreground/background transport and the existing `com.cueit.keyvox.model-download.background-session` namespace.
  - Reconciles the persisted Dictation job with both sessions, prepares staged artifact downloads, and limits cancellation and recovery to the active Dictation job.
- `KeyVox iOS/Core/ModelDownloader/ModelBackgroundDownloadCoordinator+Transport.swift`
  - Recreates every unfinished Dictation artifact in the destination session during foreground/background handoff.
- `KeyVox iOS/Core/ModelDownloader/ModelBackgroundDownloadCoordinator+TransportDelegate.swift`
  - Maps transport callbacks into Dictation artifact state, rejects non-2xx responses, and moves successful temporary downloads into the existing model staging location.
- `KeyVox iOS/Core/ModelDownloader/ModelBackgroundDownloadCoordinator+State.swift`
  - Serializes persisted Dictation job mutations, preserves monotonic per-artifact progress, and publishes state changes.
- `KeyVox iOS/Core/ModelDownloader/ModelBackgroundDownloadJob.swift`
  - Durable representation of the Dictation job UUID, per-model and per-artifact transfer state, monotonic aggregate progress floor, and finalization state.
- `KeyVox iOS/Core/ModelDownloader/ModelBackgroundDownloadJobStore.swift`
  - Persistence seam for the active Dictation job at `Models/model-download-job.json`.
- `KeyVox iOS/Core/ModelDownloader/ModelManager+InstallLifecycle.swift`
  - Finalization, extraction, manifest writes, staged-file cleanup, model-specific preload sequencing (both Whisper and Parakeet installs finish with the model loaded), and safe delete/repair coordination after downloads complete.
- `KeyVox iOS/Core/ModelDownloader/ModelManager+Validation.swift`
  - Strict readiness validation for rooted installed artifacts and install manifests.
- `KeyVox iOS/Core/ModelDownloader/ModelDownloadBackgroundTasks.swift`
  - App-side background repair task registration and scheduling.
- `KeyVox iOS/Views/Components/ModelUpdatePrompt.swift`
  - Presentation owner for the Parakeet artifact-update prompt, including Download/Later actions and modal accessibility focus.
  - The prompt does not decide model currency or perform downloads; its caller supplies the pending update state and actions.
- `KeyVox iOS/Core/LocalRewriteModel/LocalRewriteModelCatalog.swift`
  - App-local catalog for the Vibes rewrite base model and package-provided bundled adapter filenames.
  - Current base model is `Qwen2.5-0.5B-Instruct` from `Qwen/Qwen2.5-0.5B-Instruct-GGUF`, artifact `qwen2.5-0.5b-instruct-q4_k_m.gguf`, with strict SHA-256 validation and a 491,400,032-byte expected size.
  - Current bundled adapters are provided by `KeyVoxVibesAdapters`: `polished-alpha-027-lora.gguf` and `casual-alpha-9-lora.gguf`.
- `KeyVox iOS/Core/LocalRewriteModel/LocalRewriteModelManager.swift`
  - Containing-app owner for local Vibes model install state, lifecycle recovery, foreground-owned finalization, manifest validation, SHA-256 integrity checks, delete/repair-style cleanup, and adapter URL resolution.
  - Resolves LoRA adapters from the bundled `KeyVoxVibesAdapters` package first and falls back to the installed model directory only when needed.
  - Invalidates the local inference service when the installed base model is deleted or replaced.
- `KeyVox iOS/Core/LocalRewriteModel/LocalRewriteModelManager+BackgroundLifecycle.swift`
  - Starts or resumes the persisted Vibes job, serializes activation recovery, maps job progress into public install state, and finalizes completed downloads only while the app is active.
  - Builds the artifact and manifest completely in the existing staging directory before replacing the installed model directory.
- `KeyVox iOS/Core/LocalRewriteModel/LocalRewriteBackgroundDownloadJob.swift`
  - Persisted single-artifact Vibes job containing download identity, byte progress, task identity, errors, and finalization state.
- `KeyVox iOS/Core/LocalRewriteModel/LocalRewriteBackgroundDownloadJobStore.swift`
  - Atomic JSON persistence seam for the active Vibes job at `Models/rewrite/background-download-job.json`.
- `KeyVox iOS/Core/LocalRewriteModel/LocalRewriteBackgroundDownloadCoordinator.swift`
  - Vibes-specific owner of the reusable foreground/background transport and the unique `com.cueit.keyvox.vibes-download.background-session` namespace.
  - Reconciles persisted state with both sessions, prevents progress regression across handoffs, and limits cancellation and recovery to the active Vibes job.
- `KeyVox iOS/Core/LocalRewriteModel/LocalRewriteBackgroundDownloadCoordinator+Transport.swift`
  - Recreates the active Vibes transfer in the destination session during a foreground/background handoff.
- `KeyVox iOS/Core/LocalRewriteModel/LocalRewriteBackgroundDownloadCoordinator+TransportDelegate.swift`
  - Maps transport callbacks into Vibes state, rejects non-2xx responses, and moves successful temporary downloads into the existing Vibes staging location.
- `KeyVox iOS/Core/LocalRewriteModel/LocalRewriteBackgroundDownloadCoordinator+DownloadState.swift`
  - Owns persisted Vibes progress and failure mutations plus state-change publication.
- `KeyVox iOS/Core/LocalRewriteModel/LocalRewriteModelInstallManifest.swift`
  - Durable manifest for the installed local rewrite model identity, source repository, artifact filename, expected hash, installed hash, file size, and install date.
- `KeyVox iOS/Core/LocalRewriteModel/LocalRewriteModelInstallState.swift`
  - User-facing install state for not-installed, downloading, installing, ready, and failed local Vibes model states.

### Copied Text Playback and PocketTTS

- `KeyVox iOS/Core/TTS/PocketTTSModelCatalog.swift`
  - PocketTTS shared-runtime and per-voice artifact metadata plus approximate voice download sizes used by settings.
- `KeyVox iOS/Core/TTS/PocketTTSModelManager.swift`
  - Observable owner of shared PocketTTS Core ML install state and independent per-voice install state.
  - Keeps the public install-state surface, readiness queries, lifecycle bridge to the reusable transport, and queue state for the follow-up voice install flow.
- `KeyVox iOS/Core/TTS/PocketTTSModelManager+BackgroundLifecycle.swift`
  - Creates or resumes persisted Speak download jobs, maps their progress into public install state, performs foreground-owned finalization, and starts the queued voice only after a combined Home engine-plus-voice request finishes installing the shared engine.
- `KeyVox iOS/Core/TTS/PocketTTSModelManager+InstallLifecycle.swift`
  - Public install, repair, and delete entry points for PocketTTS runtime and voice assets.
- `KeyVox iOS/Core/TTS/PocketTTSModelManager+Support.swift`
  - Shared staging, manifest, filesystem replacement, and install-helper utilities used by the PocketTTS manager lifecycle split.
- `KeyVox iOS/Core/TTS/PocketTTSBackgroundDownloadJob.swift`
  - Persisted Speak job model containing the install target, dynamic artifact identity, per-artifact byte progress, retry timing, finalization state, and optional voice queued after a shared-engine install.
- `KeyVox iOS/Core/TTS/PocketTTSBackgroundDownloadJobStore.swift`
  - Atomic JSON persistence seam for the active Speak job at the existing rooted PocketTTS install location.
- `KeyVox iOS/Core/TTS/PocketTTSBackgroundDownloadCoordinator.swift`
  - Speak-specific download owner built on `ResumableDownloadTransport`.
  - Reconciles persisted artifact state with both sessions, prepares zero-byte and remote artifacts, preserves monotonic byte progress across handoffs, and keeps foreground downloads sequential while allowing the background session to own the full remaining job.
- `KeyVox iOS/Core/TTS/PocketTTSBackgroundDownloadCoordinator+Transport.swift`
  - Adapts a transport handoff back into the active Speak job, selecting the existing Speak scheduling policy for the destination session.
- `KeyVox iOS/Core/TTS/PocketTTSBackgroundDownloadCoordinator+TransportDelegate.swift`
  - Handles family-neutral transport callbacks at the Speak boundary, moves completed temporary files into Speak staging, validates HTTP responses, and dispatches completion into Speak scheduling or retry behavior.
- `KeyVox iOS/Core/TTS/PocketTTSBackgroundDownloadCoordinator+DownloadState.swift`
  - Owns persisted Speak artifact progress, completion, and failure mutations plus state-change publication.
- `KeyVox iOS/Core/TTS/PocketTTSBackgroundDownloadCoordinator+Scheduling.swift`
  - Advances the next sequential foreground Speak artifact after a successful foreground task completes.
- `KeyVox iOS/Core/TTS/PocketTTSBackgroundDownloadCoordinator+RateLimit.swift`
  - Owns Speak HTTP 429 parsing, persisted retry timing, and background retry task creation.
- `KeyVox iOS/Core/TTS/PocketTTSEngine.swift`
  - App-owned streaming TTS engine wrapper around the local PocketTTS runtime.
  - Owns the app-side runtime and shared linguistic-analyzer injection seams, explicit prepare/unload lifecycle, prepared-runtime compute-mode guards, and debug load/unload visibility.
- `Packages/KeyVoxTTS/Sources/KeyVoxTTS/PocketTTSModelMetadata.swift`
  - Declares the installed synthesis model's linguistic language capability. The current model is English-only and does not consume the dictation-language preference.
- `KeyVox iOS/Core/TTS/TTSPlaybackCoordinator/`
  - Split playback transport owner for deterministic startup runway, background-safe continuation, replay capture, pause and resume, metering, progress publishing, playback scheduling, and preserved-TTS route-family selection.
  - `TTSPlaybackCoordinator+AudioSessionActivation.swift` owns playback session activation and deactivation, using the asynchronous system playback activation calls where the running iOS release provides them and synchronous activation otherwise.
- `KeyVox iOS/Core/TTS/TTSManager/`
  - Split high-level copied-text playback owner for request lifecycle, preparation progress, replay state, paused replay restoration, lifecycle observation, system playback command routing, App Group TTS state publishing, and the consume-on-success free-speak hook used by phase-one monetization.
  - Owns user-configured Speak Timeout behavior by unloading the PocketTTS runtime immediately, after the selected warm-retention window, or never after generated playback has demand-warmed the runtime.
  - Honors the development-only force-regeneration flag so matching copied text can regenerate instead of reusing the replay cache during debugging.
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
- `KeyVox iOS/Views/HomeTabView/TTS/HomeTabView+TTSPresentation.swift`
  - Defines `TTSPreparationPresentationPolicy`, the pure spinner/progress visibility policy tested separately from Home view copy and layout.

### KeyVox Vibes and Style Rewrite

- `Packages/KeyVoxStyleRewrite/`
  - Shared style-transform package used by the iOS app.
  - Owns language-aware `TextTransformRequest`, `TextTransformResult`, chunk timings, typed error summaries, language-preserving latest-utterance artifact models, style configuration, token-aware chunk planning, model-response orchestration, fallback/error policy, prompt-leak fallback, output repair, and deterministic Chill formatting.
  - Keeps the package name generic (`KeyVoxStyleRewrite`) while the iOS app presents the feature as `KeyVox Vibes`.
- `Packages/KeyVoxStyleRewrite/Sources/KeyVoxStyleRewrite/StyleRewriteDictationConfiguration.swift`
  - Defines the persisted style enum and request construction.
  - Current style order is `None`, `Casual`, `Polished`, `Chill`.
  - `None` produces no transform request.
  - `Casual` uses the casual LoRA prompt for light cleanup, preserving slang, profanity, grammar, meaning, lists, paragraph breaks, and the word `like`, while formatting clear numbers, dates, money, and percentages.
  - `Polished` uses the polished LoRA prompt for a medium readability pass that removes spoken filler and false starts, standardizes `ain't`, preserves meaning/structure/paragraph breaks, and uses numerals where appropriate.
  - `Chill` uses the casual LoRA prompt for cleanup, then applies deterministic lowercase/limited-punctuation formatting through `ChillHeuristicFormatter`.
- `Packages/KeyVoxStyleRewrite/Sources/KeyVoxStyleRewrite/TextTransformChunkPlanner.swift`
  - Plans chunks before model calls using a budget of instructions, prompt wrapper, input chunk, expected output expansion, and safety margin within the configured context window.
  - Prefers semantic boundaries, then falls back to word-level splits when one segment is too large.
  - Uses a conservative approximate counter through `StyleRewriteTextTransformTokenCounter`.
- `Packages/KeyVoxStyleRewrite/Sources/KeyVoxStyleRewrite/StyleRewriteTextTransformer.swift`
  - Generic chunk-runner-backed transformer used by the app and keyboard IPC client.
  - Applies the model response, style-specific processing modes, Casual cleanup metadata, deterministic output repair, prompt-leak fallback, and Chill cleanup-plus-heuristic path.
  - Falls back to the post-processed base text when the local model is unavailable, prompt input is too long, generation fails, prompt output leaks instructions, or otherwise requires full fallback.
  - For chunk-level errors that do not require full fallback, keeps the failed chunk as base text and records chunk errors.
  - Passes the request language into shared linguistic output repair so native or portable evidence is selected by the composed analyzer rather than inferred from the text.
- `Packages/KeyVoxStyleRewrite/Sources/KeyVoxStyleRewrite/StyleRewritePromptLeakGuard.swift`
  - Detects significant instruction/prompt leakage in generated output and converts it into a base-text fallback with a typed prompt-leak error summary.
- `Packages/KeyVoxStyleRewrite/Sources/KeyVoxStyleRewrite/OutputRepair/`
  - Runs deterministic post-model repair after local rewrite output and before app injection.
  - `RepairTokenization.swift` maps word tokens to roles and lemmas through the injected shared linguistic analyzer rather than constructing a separate system tagger.
  - `PunctuationRepair.swift` preserves punctuation facts before more specific fact repairs.
  - `TerminalPunctuationBoundaryRepair.swift` preserves source-backed terminal `!` and `?!` boundaries across model rewrites and Chill heuristic formatting.
  - `AddressFactRepair.swift` preserves source-backed address facts before money and number repair.
  - `NumberEvidence.swift` is the shared source of truth for factual number evidence used by general number repair and money repair.
  - `NumberEvidenceRepair.swift` coordinates factual number preservation, including separator evidence repair, changed number repair, and deleted number repair.
  - `NumberSeparatorEvidenceRepair.swift` preserves factual numeric separators, including decimal-vs-time evidence such as `5.30` versus `5:30`, while rejecting ambiguous date-detector output split into whitespace-separated adjacent detections.
  - `MoneyFactRepair.swift` owns currency-specific repair while using shared number evidence for amount values and resolving currency units from lemma evidence or the token surface.
  - `APStyleNumberRepair.swift` owns AP-style number presentation only, after factual number evidence has been repaired.
- `Packages/KeyVoxStyleRewrite/Sources/KeyVoxStyleRewrite/ChillHeuristicFormatter.swift`
  - Deterministic Chill formatter after optional local-model cleanup.
  - Lowercases, removes unsupported punctuation, preserves emoji, symbol characters, and email-shaped inline tokens, keeps question marks where sentence boundaries require them, separates interior sentence boundaries with periods, and leaves the final cluster without a trailing period unless it is a question.
- `Packages/KeyVoxLocalInference/Sources/KeyVoxLocalInference/LocalLanguageModel.swift`
  - Public local language model request, result, configuration, error, and generation protocol types.
  - Implementation lives in the `LlamaLocalLanguageModel*.swift` files.
  - Owns model/context creation, adapter attachment, quiet llama logging, prompt formatting through the model chat template, tokenization, prompt-too-long checks, greedy decoding, cancellation, cache clearing, unload, and generation metrics.
- `Packages/KeyVoxVibesAdapters/Sources/KeyVoxVibesAdapters/KeyVoxVibesAdapterCatalog.swift`
  - Typed catalog for bundled KeyVox Vibes LoRA adapters.
  - Exposes adapter IDs, filenames, compatible base-model ID, and `Bundle.module` resource URL lookup for Polished and Casual.
- `KeyVox iOS/Core/StyleRewrite/LocalRewriteInferenceService.swift`
  - App-owned local inference cache for the installed Vibes base model plus the currently requested LoRA adapter.
  - Provides the cached `LlamaLocalLanguageModel` for polished, casual, chill, or no adapter and unloads when the local rewrite model is invalidated or the utterance-scoped rewrite lifecycle is released.
- `KeyVox iOS/Core/StyleRewrite/LocalStyleRewriteTextTransformer.swift`
  - iOS adapter from `KeyVoxStyleRewrite` chunk requests into `KeyVoxLocalInference`.
  - Receives the app's shared linguistic analyzer, maps Polished to `polished-alpha-027`, maps Casual and Chill to `casual-alpha-9`, prewarms the selected model/adapter without generating text, cancels pending prewarm work when resources are released, sends short LoRA prompts, unloads the local rewrite inference cache on release, and logs local inference load/prefill/decode/total timing in debug builds.
- `KeyVox iOS/Core/StyleRewrite/StyleRewritePipelineCoordinator.swift`
  - iOS app-side adapter between `TranscriptionManager` / `DictationPipeline` and `KeyVoxStyleRewrite`.
  - Resolves the current `AppSettingsStore` style, carries the pipeline or IPC language into transform requests, forwards utterance-scoped prewarm/release calls to the app-owned local transformer, converts package results into `DictationPipelineTextProcessingResult`, records latest-utterance artifacts, and handles keyboard style rewrite IPC requests.
- `KeyVox iOS/Core/StyleRewrite/StyleRewriteLatestArtifactStore.swift`
  - App Group latest-artifact persistence for the most recent dictation.
  - Stores the utterance ID and provider-reported language with raw provider text, post-processed base text, selected inserted text, selected pre-Caps text, selected style identifier, deterministic paragraph/list variants, variant timing/error metadata, inference duration, transform duration, and creation date.
  - Exposes raw `Data` and decoded artifact access for keyboard Vibes revert/restyle flows.
- `KeyVox iOS/Views/StyleTabView+KeyVoxVibes.swift`
  - Branded KeyVox Vibes section inside the existing Style tab.
  - Uses the same app-card treatment as nearby settings surfaces while keeping the broader tab named `Style`.

### Audio and Transcription Runtime

- `Packages/KeyVoxCore/Sources/KeyVoxCore/Transcription/DictationPipeline.swift`
  - Owns the transcribe, post-process, optional transform, and insertion boundary and carries the provider-reported language into text-processing context and the final result.
  - Accepts a caller-supplied utterance ID and, when an output delivery handler is configured, delivers `DictationPipelineOutputDelivery` values carrying that ID, the output text, and the selected style identifier instead of calling the paste closure.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Transcription/TranscriptionPostProcessor.swift`
  - Owns ordered transcription normalization and uses the analyzer injected by the containing app for dictionary and numeric linguistic evidence.
  - Removes model-generated literal ellipsis artifacts as its last step before the all-caps override, keeping spoken ellipses and repairing word spacing.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Transcription/AudioParagraphChunker.swift`
  - Splits long captures into decode chunks and, when providers pass shared VAD speech segments, prefers fallback boundaries in VAD-confirmed gaps so active speech is not split.
- `KeyVox iOS/Core/Audio/AudioRecorder.swift`
  - Public recorder and monitoring surface.
  - Tracks session warmth, meter state, and last capture facts.
- `KeyVox iOS/Core/Audio/AudioRecorder+Session.swift`
  - Owns `AVAudioSession` configuration, warm-engine setup, route-recovery retries, interruption observation, and monitoring lifecycle.
- `KeyVox iOS/Core/Audio/AudioRecorder+AudioSessionActivation.swift`
  - Owns the recorder's session category configuration plus activation and deactivation, using the asynchronous system activation calls where the running iOS release provides them and synchronous activation otherwise.
- `KeyVox iOS/Core/Audio/AudioRecorder+Streaming.swift`
  - Owns input-buffer conversion, capture accumulation, and live meter/signal-state updates.
- `KeyVox iOS/Core/Audio/AudioBluetoothRoutePolicy.swift`
  - Shared preserved-TTS Bluetooth route-family policy.
  - Maps the built-in microphone setting to the playback route family without changing the recorder baseline warm-session contract.
- `KeyVox iOS/Core/Audio/AudioRecorder+StopPipeline.swift`
  - Owns stop-time and interruption-time capture finalization, produces cleaned `StoppedCapture` values, and rejects silence before inference.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Services/Whisper/WhisperService+TranscriptionCore.swift`
  - Runs shared voice-activity analysis before Whisper decoding, rejects captures with no detected speech, skips chunks without speech overlap, and compacts selected speech ranges with bounded internal silence.
  - Falls back to full source chunks and the existing decoder no-speech safeguards when VAD analysis is unavailable.
  - Starts or reuses the in-flight background warmup, waits for it inside the transcription task, and applies the configured language and dictionary hint prompt only after loading finishes.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Services/Whisper/WhisperService+ModelLifecycle.swift`
  - Loads the VAD detector and then the Whisper model off the main actor in one background warmup, installs the result only when it is still the current warmup, exposes `preloadIfNeeded()` for callers that must finish with the model loaded, and cancels pending warmup on unload.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Services/SpeechModelLoadQueue.swift`
  - Shared serial queue that runs blocking VAD detector and Whisper model loads one at a time off the main actor.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Services/Whisper/WhisperSpeechRangePlanner.swift`
  - Converts shared VAD timestamps into padded, bounded frame ranges and compacts those ranges for Whisper decoding.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Services/Whisper/WhisperSegmentTextAssembler.swift`
  - Assembles each Whisper chunk off the main actor, passing the detected language into conservative continuation-name analysis and casing repair backed by an immutable pronunciation lookup snapshot.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Services/Parakeet/ParakeetService+TranscriptionCore.swift`
  - Loads the shared VAD analyzer in a background warmup through `SpeechModelLoadQueue`, ends a cancelled request once that load finishes, rejects a whole capture when no speech is detected, and otherwise preserves the original chunk audio for Parakeet decoding.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Services/Parakeet/ParakeetService+Backend.swift`
  - Adapts the service to the package's backend contract while retaining Core ML as the iOS runtime.
- `Packages/KeyVoxWhisper/Sources/KeyVoxWhisper/`
  - Owns the low-level Whisper context, request parameters and snapshots, segments, language metadata, compute policy, and encoder configuration while consuming the shared speech runtime from `KeyVoxVoiceActivity`.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Audio/SpeechAudioFileLoading.swift`
  - Routes iOS audio-file loading through AVFoundation and returns mono 16 kHz inference samples.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/PlatformNumericTextProtection.swift`
  - Uses Apple's date and address detectors behind the shared numeric-protection boundary so normalization preserves recognized spans.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/SpelledOutNumberParser.swift`
  - Centralizes spelled-number parsing shared by date and math normalization.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/FileTypes/`
  - Loads the packaged `mime-db.json` registry and protects recognized file extensions during sentence capitalization.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Support/KeyVoxCoreResources.swift`
  - Centralizes access to packaged pronunciation and file-type data through the default SwiftPM bundle, with a one-time host configuration seam.
- `KeyVox iOS/Core/Transcription/DictationService.swift`
  - iOS-local transcription-service abstraction used by the runtime manager.
- `KeyVox iOS/Core/Transcription/TranscriptionManager.swift`
  - Primary iOS runtime state machine and dictation owner.
  - Exposes typed start/stop command results used by keyboard, URL, and App Shortcut entry points; a new recording clears the previously published IPC transcript before capture begins.
  - Passes each utterance ID into `DictationPipeline`, receives output through the pipeline's delivery handler, publishes it only when the delivery matches the active utterance, and publishes the utterance ID and selected style identifier with the transcript; interrupted-capture recovery reuses the recovery ID as its utterance ID.
  - When immediate microphone release is requested, preserves transcription after an initial shutdown failure, retries shutdown after output completes, and restores the configured idle timeout if that retry also fails.
  - Starts KeyVox Vibes prewarm after audio recording successfully begins, never before recorder startup finishes.
  - Releases the utterance-scoped KeyVox Vibes local rewrite cache after dictation output is published, and on stale, empty, cancelled, or unavailable-model stop paths.
  - Prints speed-profile transformation duration, style, processing mode, chunk count, errors, and raw final text when raw debug logging is enabled.
- `KeyVox iOS/Core/Transcription/TranscriptionManager+SessionLifecycle.swift`
  - Idle shutdown, user-configured session timeout scheduling including Never, deferred disable-session handling, and watchdog cleanup.
  - Releases any retained style rewrite prewarm session when an active utterance is cancelled.
- `KeyVox iOS/Core/Transcription/TranscriptionCommandResult.swift`
  - Typed start and stop outcomes shared by non-UI transcription command callers.
- `KeyVox iOS/Core/Transcription/TranscriptionManager+InterruptedCaptureRecovery.swift`
  - Interrupted-capture staging and recovery on app reactivation.
- `KeyVox iOS/Core/Transcription/InterruptedCaptureRecoveryStore.swift`
  - Durable storage for interrupted captures that need to be resumed later.
- `KeyVox iOS/Core/Transcription/SessionPolicy.swift`
  - Session safety thresholds and timeout policy.

### App UI

- `KeyVox iOS/Views/MainTabView.swift`
  - Four-tab container: Home, Dictionary, Style, Settings.
  - Adds edge-swipe tab navigation on top of `TabView` and owns unlock-sheet presentation surfaces for KeyVox Speak and KeyVox Vibes monetization flows.
  - Owns the app-shell download confirmation overlay for Home and Settings model downloads so tab bar and toolbar controls are covered while confirmation is active.
  - Performs confirmed Settings deletions, including the learned-words reset through `KeyboardTypingMemoryReset`.
- `KeyVox iOS/Views/ContainingAppTab.swift`
  - Source of truth for app-tab ordering, titles, and previous/next navigation.
- `KeyVox iOS/Views/HomeTabView/`
  - Filesystem-grouped Home feature surface.
  - `HomeTabView.swift` owns the weekly stats card, current promotion placement, last transcription card, Home-level state, and debug-only diagnostics.
  - `IOSPromotionCard.swift` renders the selected campaign supplied by `PromotionCenter`; it does not perform manifest selection or eligibility checks.
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
  - `KeyVoxSpeakSheetView.swift` owns the shared shell, pager state, pinned bottom CTA area, unlock action, restore action, mode-specific chrome, and sheet-level download confirmation overlay so pinned controls are covered while confirmation is active.
  - `KeyVoxSpeakSceneAView.swift`, `KeyVoxSpeakSceneBView.swift`, and `KeyVoxSpeakSceneCView.swift` own the three swipeable pages, matching the onboarding-scene split pattern. Scene C requests setup downloads through the sheet-owned confirmation path instead of starting downloads directly.
  - `KeyVoxSpeakUnlockScene.swift` owns the shared unlock-mode scene model so unlock copy and CTA rules stay centralized across wrappers.
  - `KeyVoxSpeakInstallCardView.swift` owns the shared PocketTTS setup card used by scene C, including shared-model install, featured-voice install, progress, and repair actions. It requests a combined engine-plus-voice confirmation only when the shared Speak engine is missing, otherwise it requests the voice-only confirmation.
  - `KeyVoxSpeakIntroSheetView.swift` is the thin post-onboarding intro wrapper around the shared sheet.
  - `TTSUnlockSheetView.swift` is the thin unlock-mode wrapper around the same shared sheet for Home and Settings purchase entry points.
- `KeyVox iOS/Views/KeyVoxVibes/`
  - Dedicated feature folder for the shared KeyVox Vibes presentation surface.
  - `KeyVoxVibesSheetView.swift` owns the shared pager shell, intro/unlock/info mode selection, bottom CTA area, model-availability CTA rules, sheet-level Vibes AI download confirmation, unlock action, restore action, and close behavior.
  - In info mode, the sheet keeps a bottom `Vibe Now` CTA that dismisses the usage refresher for already-unlocked users.
  - `KeyVoxVibesSceneAView.swift`, `KeyVoxVibesSceneBView.swift`, and `KeyVoxVibesSceneCView.swift` own the swipeable intro pages for what Vibes is, what it does, and how the local trial starts.
  - `KeyVoxVibesSceneCView.swift` also owns the compact Vibes AI install card shown when the local model is missing, including progress/error presentation, confirmed download requests, repair action, graceful collapse when install readiness arrives, and the active-trial recovery subtitle variant.
  - `KeyVoxVibesUnlockScene.swift` owns the unlock scene, including active-trial remaining-time copy.
  - `KeyVoxVibesIntroSheetView.swift` is the thin post-onboarding intro wrapper around the shared sheet.
  - `KeyVoxVibesUnlockSheetView.swift` is the thin unlock-mode wrapper around the same shared sheet for Style tab and keyboard locked-tap entry points, including direct unlock-scene recovery and model-gated continue behavior when an unlocked user is missing Vibes AI.
- `KeyVox iOS/Views/DictionaryTabView/DictionaryTabView.swift`
  - Dictionary UI plus editor flow built around the shared `AutoFocusTextField`, feature-local sort state, and the app-owned `KeyboardObserver`.
- `KeyVox iOS/Views/StyleTabView.swift`
  - Style tab composition for Lists, Paragraphs, and the KeyVox Vibes section.
- `KeyVox iOS/Views/StyleTabView+KeyVoxVibes.swift`
  - KeyVox Vibes card, style picker, selected style summary, style description, examples, and purchase row.
  - Consumes `KeyVoxVibesAccessMatrix` so main-card content, CTA visibility, card actions, recovery destinations, and dynamic trial/unlock text stay centralized and testable without string assertions.
  - Uses the shared Vibes trial remaining-time formatter for active-trial status while keeping the card sentence local to the Style tab.
  - Keeps selected Vibe displayed as `None` until both Vibes access and local Vibes AI readiness are active, and exposes an install entry point when the model is missing.
- `KeyVox iOS/Views/SettingsTabView/SettingsTabView.swift`
  - Top-level settings composition, shared disclosure state, download-confirmation request binding, full-screen Dictation Shortcut reference-guide presentation, third-party notices sheet presentation, and cross-section coordination for the extracted settings surface.
- `KeyVox Keyboard/Core/KeyboardToolbarMode.swift`
  - Central warning-priority resolver for the keyboard toolbar: dictation model missing, dictation model action required, Full Access missing, microphone permission missing, then branded.
  - Required app updates are not a keyboard toolbar mode, so dictation stays available from the keyboard while the containing app shows its forced-update prompt.
- `KeyVox iOS/Views/SettingsTabView/SettingsTabView+General.swift`
  - Session timeout, Live Activities, the Dictation Shortcut setup-guide entry point, Speak Timeout, the Keyboard row that opens `KeyboardSettingsView`, and audio preference sections extracted from the settings root view.
- `KeyVox iOS/Views/SettingsTabView/KeyboardSettingsView.swift`
  - Keyboard settings screen: single-line typing toggles for keyboard haptics, auto-capitalization, auto-correction, caps lock, predictive text, the emoji keyboard, and the period shortcut, then Compact Keys, Open on 123, and Left-Handed Layout with descriptions, then Reset Learned Words through the shared deletion confirmation.
- `KeyVox iOS/Views/SettingsTabView/KeyboardSettingsCopy.swift`
  - Copy owner for the Keyboard settings screen and the Settings row that opens it.
- `KeyVox iOS/Views/SettingsTabView/SettingsRow.swift`
  - Shared settings-row layout with mutually exclusive SF Symbol and template-rendered asset icon support and an optional description for single-line rows.
- `KeyVox iOS/Views/SettingsTabView/SettingsTabView+Models.swift`
  - Release-facing `Dictation Model` section, provider selection, per-model install actions, and not-installed size labels.
  - Attaches the Language section beneath the model card: Whisper uses the shared model catalog for its picker, while Parakeet remains visible as Auto Detect with FAQ guidance because it has no native forced-language selection.
- `KeyVox iOS/Views/SettingsTabView/SettingsTabView+TTS.swift`
  - Release-facing `KeyVox Speak` section for PocketTTS runtime install state, per-voice install actions, voice previews, playback voice selection, and the `KeyVox Speak Unlimited` unlock row placed beneath the model section, including the shared installed-voice picker menu.
- `KeyVox iOS/Views/SettingsTabView/SettingsTabView+VibesAI.swift`
  - Release-facing `KeyVox Vibes AI` model card placed below the dictation model card, with download/delete/repair actions, confirmation handoff, install progress, percentage text, failure copy, and animated progress collapse.
- `KeyVox iOS/Views/SettingsTabView/SettingsTabView+About.swift`
  - Rate-and-review, GitHub support, shared Speak/Vibes restore-purchases, version footer, and third-party notices launcher extracted from the settings root view.
- `KeyVox iOS/Views/Components/DeletionConfirmation.swift`
  - Shared destructive confirmation component used by the settings model sections and the Keyboard screen's learned-words reset, with per-case title, message, and confirm-button wording.
- `KeyVox iOS/Views/Components/DownloadConfirmation.swift`
  - Shared non-destructive download confirmation component used before model and voice downloads. It carries separate copy for Whisper Base, Parakeet TDT v3, KeyVox Vibes AI, the Speak engine, individual Speak voices, and combined first-use Speak engine-plus-voice setup.
- `KeyVox iOS/Views/Components/ModelDownloaderCardView.swift`
  - Compact reusable app-styled model downloader card with title/action row, subtitle/status text, right-aligned progress percentage, progress bar, and error text. Scene C uses it for the inline Vibes AI install surface.
- `KeyVox iOS/Views/Components/AppUpdatePrompt.swift`
  - Shared custom update prompt component used by the root app shell instead of the native system alert so optional and forced update prompts match the app's modal overlay styling.
- `KeyVox iOS/Views/ReturnToHostView.swift`
  - One-time post-cold-launch host-return guidance screen during a live session handoff.
  - Includes a top-right dismiss control for returning to the Home surface without waiting for an external host-app switch.

### Keyboard Extension

- `KeyVox Keyboard/App/KeyboardViewController.swift`
  - Extension controller and top-level keyboard surface owner.
  - Owns toolbar mode switching, full-access instructions presentation, warm/cold app launch behavior, onboarding presentation reporting, Caps Lock, Vibes key cycling, missing-model Vibes recovery launch, dictionary/settings tab launch, the letter/number/symbol page, keys mode and controller-view height, emoji panel state, trackpad mode, and insertion.
  - Waits for the host's first `textDidChange(_:)` after appearing before reading the focused field, then prepares typing for that field; a later change of the field's typing traits starts the new field fresh.
  - Tracks whether the latest dictation is still untouched and whether the field holds letters, which together decide whether the toolbar offers suggestions or the dictation accessories.
  - Missing-model taps open `keyvoxios://vibes/model-recovery`; access-aware recovery scene selection remains app-owned by `KeyVoxVibesPurchaseController`.
- `KeyVox Keyboard/App/KeyboardViewController+Typing.swift`
  - Letter-page typing: field preparation, opening layout, shift and caps-lock handling, word-boundary autocorrection, picked-word spacing, suggestion taps and long-press forgetting, contested taps near letter keys, held-delete word deletion, return to letters after symbols, and personal, learned, and emoji vocabulary hand-off to the prediction coordinator.
- `KeyVox Keyboard/App/KeyboardViewController+Emoji.swift`
  - Emoji page binding, opening and closing, typing an emoji with the character-key haptic, recording Frequently Used and skin-tone choices, the page's delete repeat, and the suggestion-bar emoji for a word.
- `KeyVox Keyboard/App/KeyboardViewController+EmojiSearch.swift`
  - Emoji search binding, start and end, routing typed characters, space, delete, and done into the search text, held-delete word deletion inside the search, and results that fall back to the Frequently Used emoji before anything is typed.
- `KeyVox Keyboard/Core/KeyboardDictationModelStatus.swift`
  - Resolves the active provider's App Group artifacts into ready, not-installed, or repair-required state for keyboard warning presentation.
  - Keeps lightweight extension-side artifact inspection separate from containing-app install, validation, and repair ownership.
- `KeyVox Keyboard/Core/KeyboardInstalledModels.swift`
  - Caches the dictation availability and Speak voice readiness the toolbar depends on; the controller rechecks it when the keyboard appears and when the extension host becomes active instead of inspecting disk on every UI update.
- `KeyVox Keyboard/Core/KeyboardOpeningLayout.swift`
  - Resolves the page and keys mode a field opens on: full letter keys, or the number page in the user's Compact Keys mode when the field or Open on 123 prefers numbers.
- `KeyVox Keyboard/App/KeyboardContainingAppLauncher.swift`
  - Responder-chain URL launcher used by the extension whenever it needs to wake the containing app for cold dictation or copied-text playback handoff.
- `KeyVox Keyboard/App/KeyboardViewController+PresentationLifecycle.swift`
  - Presentation-tree creation, per-presentation binding, teardown, and extension-host lifecycle observation.
  - Pauses the active presentation during host backgrounding, refreshes it on host foregrounding, and tears the tree down only for real dismissal and globe-key presentation swaps.
  - Keeps the keyboard view hierarchy disposable across globe-key presentation swaps.
  - Binds and unbinds key-grid callbacks, letter-key geometry for predictions, suggestion-bar taps and long presses, the emoji page, and the emoji search with the presentation tree; on host foregrounding it also adopts any typing-memory reset and rechecks installed models.
- `KeyVox Keyboard/App/KeyboardViewController+Debug.swift`
  - Debug-only presentation lifecycle counters and controller test hooks.
- `KeyVox Keyboard/Core/Dictation/DictationChange/KeyboardDictationChangeController.swift`
  - Keyboard-local artifact-scoped changer facade for the latest untouched KeyVox dictation insertion.
  - Owns the display-facing state surface, injected collaborators, and current session reference used by the split dictation-change files.
- `KeyVox Keyboard/Core/Dictation/DictationChange/KeyboardDictationChangeController+Actions.swift`
  - Owns long-press action entry points for Vibes, Paragraphs, Lists, and Caps Lock on the latest untouched insertion.
- `KeyVox Keyboard/Core/Dictation/DictationChange/KeyboardDictationChangeController+Session.swift`
  - Builds the latest untouched insertion session from `KeyboardTextInsertionResult` plus the app-published latest dictation artifact, retaining the artifact's provider-reported language when available.
  - Binds the session to the published utterance ID; until the matching artifact is readable it records the inserted text under the delivered style, and later actions refresh the session from the artifact once it arrives.
- `KeyVox Keyboard/Core/Dictation/DictationChange/KeyboardDictationChangeController+Variants.swift`
  - Resolves artifact/session state, cached rendered variants, Vibes replacement text, Caps display text, and shared debug/preparation helpers for dictation-change actions.
- `KeyVox Keyboard/Core/Dictation/DictationChange/KeyboardDictationChangeSession.swift`
  - Session, language context, artifact identity and load state, rendered-variant key, and display-source value types for the latest untouched dictation insertion.
- `KeyVox Keyboard/Core/Dictation/DictationChange/KeyboardDictationChangeArtifactStore.swift`
  - Lightweight keyboard-side reader for the app-published latest dictation artifact in App Group defaults; returns the artifact only when its ID matches the requested utterance.
- `KeyVox Keyboard/Core/Dictation/AudioIndicatorDriver.swift`
  - Drives the logo indicator from the shared live meter; pauses its display link whenever neither a listening, processing, or speaking phase nor speech-playback progress needs new frames.
- `KeyVox Keyboard/Core/Dictation/KeyboardLocalStyleRewriteTextTransformer.swift`
  - Keyboard-side style rewrite transport that writes the base text, style, and saved dictation language into a `KeyVoxStyleRewriteIPCRequest`, polls for the matching response, and returns package-shaped transform results with processing mode `app-ipc`.
  - Keeps local rewrite model execution out of the extension.
- `KeyVox Keyboard/Core/Dictation/KeyboardDictationController.swift`
  - Owns the keyboard-side recording request lifecycle, including a synchronous keyboard-process audio-session gate, a generic two-second start-failure state, and the no-response fallback.
  - The gate reads the extension's live `AVAudioSession` values directly; it does not consume a persisted containing-app availability flag.
  - Consumes containing-app startup results from shared state so a failure remains observable across the temporary app handoff.
  - Keyboard-local state machine for shared recording state and app launch handoff.
- `../Packages/KeyVoxCore/Sources/KeyVoxCore/Transcription/DictationDeterministicState.swift`
  - Shared paragraph/list state value used by both keyboard long-press changes and Mac trigger-key changes.
- `../Packages/KeyVoxCore/Sources/KeyVoxCore/Transcription/DictationDeterministicVariantResolver.swift`
  - Selects the target paragraph/list state and the saved or cached source variant without owning presentation or replacement.
- `../Packages/KeyVoxCore/Sources/KeyVoxCore/Transcription/DictationDeterministicTextFormatter.swift`
  - Owns paragraph collapse, ordered-list line preservation, and post-rewrite layout adjustment shared across clients.
- `KeyVox Keyboard/Core/Transport/KeyboardTTSController.swift`
  - Keyboard-local copied-text playback transport owner that stages TTS requests and reacts to shared TTS state.
- `KeyVox Keyboard/Core/Feedback/KeyboardInteractionHaptics.swift`
  - Keyboard-owned interaction haptic coordinator that respects the extension’s local haptics preference.
- `KeyVox Keyboard/Core/Transport/KeyboardIPCManager.swift`
  - Extension-side App Group/Darwin client plus stale shared-state reconciliation.
  - Preserves fresh recording/transcribing state across short heartbeat gaps, but treats a cold state with an expired or missing recording timestamp as stale.
- `KeyVox Keyboard/Core/Settings/KeyboardAppSettingsStore.swift`
  - Keyboard-local App Group settings bridge for controls that mirror containing-app settings.
  - Reads and writes the shared selected Vibe, paragraph, and list-formatting defaults, derives Vibe display text from `StyleRewriteStyle`, evaluates trial access using the shared Vibes trial duration policy, forces the resolved Vibe to `None` when access or Vibes AI install readiness is missing, and posts shared Darwin notifications so the containing app can refresh visible settings.
  - Reads Compact Keys availability and persists the active full/compact mode independently; availability defaults on while active mode defaults full.
  - Reads the shared keyboard typing settings and Left-Handed Layout with the same defaults the containing app uses; the keyboard never writes them.
- `KeyVox Keyboard/Core/Input/KeyboardCompactKeysHoldController.swift`
  - Owns the cancellable half-second `#+=` hold gesture that requests compact-mode activation without turning the eventual touch-up into a normal symbol-page keypress.
- `KeyVox Keyboard/Core/Input/KeyboardTextInputController.swift`
  - Host-app text insertion, key dispatch, double-space period behavior, cursor movement, and document-proxy execution of adjacent punctuation replacement after selected-text insertion.
  - Captures the first character after the insertion or selected span once, then applies shared terminal-punctuation and trailing-separator composition before inserting the finalized text.
  - Applies typing-session `TextEdit` values by deleting and retyping only the changed end of the replaced text, deletes whole words for a held delete key, types smart quotes unless a character was picked from a held key's popup, gates the double-space period on the period-shortcut setting and an empty selection, and switches between the letter, number, and alternate symbol pages.
- `KeyVox Keyboard/Core/Input/KeyboardLetterCaseController.swift`
  - Owns the letter page's shift state: a tap shifts the next letter, a quick second tap locks caps when allowed, and the field's auto-capitalization type decides when the keyboard shifts by itself.
- `KeyVox Keyboard/Core/Input/KeyboardSymbolPageReturnTracker.swift`
  - Returns to the letter page right after a character that belongs inside words (as `TypingTextContext.isWordCharacter` defines it) is typed on a symbol page, or on the space that follows any other symbol-page character.
- `KeyVox Keyboard/Core/Input/KeyboardHeldKeyController.swift`
  - Times a finger on a key that offers held-key characters, opens the popup through the bundled `HeldKeyCharacters`, follows the finger across its cells, and reports whether the touch chose a character, closed the popup, or never opened it.
- `KeyVox Keyboard/Core/Input/KeyboardDeleteRepeatSchedule.swift`
  - Single source of truth for the held delete key's repeat timing and its switch from single characters to whole words; `KeyboardDeleteRepeatController` in `KeyboardSpecialKeyInteractionSupport.swift` runs it.
- `KeyVox Keyboard/Core/Input/KeyboardWordDeletion.swift`
  - Measures how many characters a number of whole words takes at the end of the text, each word with its trailing whitespace and attached punctuation.
- `KeyVox Keyboard/Core/Input/KeyboardKeyActivation.swift`
  - Value types for a typed key with its location, key frame, timestamp, repeat flag, and held-key-choice flag, plus the letter-key geometry reported for predictions.
- `KeyVox Keyboard/Core/Input/KeyboardTouchRouterGestureRecognizer.swift`
  - Forwards every raw key-grid touch for any number of fingers without delaying or cancelling it, so the grid can follow overlapping taps itself.
- `KeyVox Keyboard/Core/Feedback/KeyboardTextInputHapticPlayer.swift` and `KeyboardTextInputHapticPattern.swift`
  - Core Haptics player and pattern for the tap felt on letter and character keys, held-key popups, and emoji; the engine runs on its own queue and stops after an idle delay.
- `KeyVox Keyboard/Core/Input/KeyboardCursorTrackpadSupport.swift`
  - Velocity-sensitive cursor-trackpad delta handling used by the space-bar trackpad interaction.
- `KeyVox Keyboard/Core/Text/KeyboardInsertionSpacingCoordinator.swift`
  - Converts the iOS preceding-text snapshot into shared composition context and delegates leading-spacing policy to `KeyVoxTextComposition`.
- `KeyVox Keyboard/Core/Text/KeyboardInsertionCapitalizationCoordinator.swift`
  - Converts the iOS preceding-text snapshot into shared composition context, supplies keyboard casing-preservation decisions, and delegates leading-capitalization policy to `KeyVoxTextComposition`.
- `Packages/KeyVoxTextComposition/Sources/KeyVoxTextComposition/`
  - Owns deterministic capitalization, leading spacing, quote classification, sentence-boundary, adjacent terminal-punctuation, and trailing-separator rules without depending on `UITextDocumentProxy` or insertion transport.
  - `TextCompositionPolicy.composeForInsertion` returns one `TextCompositionResult` containing finalized text plus any required following-code-point deletion, keeping the mutation decision separate from document-proxy execution.
  - `LeadingDateCapitalizationPolicy` uses `CalendarDatePrefixDetector` to preserve calendar-date capitalization, while `URLShapeDetector` uses syntax-based link-prefix recognition without a language-specific domain list.
  - `TerminalPunctuationCompositionPolicy` preserves supported non-quote following punctuation by stripping an incoming model period, deduplicates a matching incoming question or exclamation mark, and signals when a differing incoming question or exclamation mark must replace the following punctuation.
  - `TrailingSeparatorCompositionPolicy` appends one space when finalized dictation would otherwise run directly into a following letter, number, or emoji; it leaves existing trailing whitespace and punctuation/symbol boundaries unchanged.
  - `TextCompositionCharacterClassifier` keeps the shared emoji classification used by both leading- and trailing-separator decisions in one package-owned implementation.
- `KeyVox Keyboard/Core/KeyboardModelAvailability.swift`
  - Lightweight rooted-install gate used by the extension toolbar for Whisper, Parakeet, PocketTTS, and local Vibes AI availability.
- `KeyVox Keyboard/Core/KeyboardLayoutGeometry.swift`
  - Row-geometry helper for keyboard-specific sizing rules that should not live in `KeyboardRootView` or `KeyboardKeyGridView`.
  - Owns the letter page's inset middle row and shift row, the symbol pages' third row, and the bottom row's live widths, including the landscape side-key span, the paired page and emoji keys, the emoji search's three-key row, and the globe row, all driven from the measured key grid.
- `KeyVox Keyboard/Core/KeyboardKeysMode.swift`
  - Resolves full versus compact presentation from availability and persisted active state.
  - Takes the 286-point full or 174-point compact portrait height from `KeyboardStyle`, shortens it by the shorter landscape keys, and owns visible row count, per-orientation key height, and derived key-grid height.
- `KeyVox Keyboard/Core/KeyboardSymbolLayout.swift`
  - Defines the letter, number, and alternate symbol pages, the key kinds and their titles, symbols, and accessibility labels, the Compact Keys rows, the emoji search's bottom row, and the bottom-row variants without the emoji key or with the globe key.
- `KeyVox Keyboard/Core/KeyboardTopRowAccessoryLayout.swift`
  - Owns top-row accessory alignment driven from the measured key grid.
  - Keeps the left accessory slot stable by showing Settings while idle and the existing Cancel control while recording, transcribing, or playing speech.
  - With Vibes available, aligns Speak over `2`, Dictionary over `3`, Paragraphs over `4`, Lists over `5`, Caps Lock over `6`, the two-key-wide Vibes key across `7` and `8`, and the logo bar over the far-right `9`/`0` area.
  - Without the Vibes feature available, removes the Vibes key and compacts the remaining top-row accessories against the logo area so hidden feature keys do not leave gaps. Missing local Vibes AI readiness gates cycling but does not hide the key.
  - Mirrors the control strip for the left-handed layout setting without changing typed symbol order.
  - Gives portrait single-key accessories a height that resolves in Auto Layout to the smaller of the reference key's width and the standard button size, so the height never depends on a width read before the key grid lays out.
- `KeyVox Keyboard/Views/KeyboardRootView.swift`
  - Stable keyboard chrome and key grid.
  - Hosts the branded toolbar row and the shared warning overlay for dictation model, Full Access, and microphone permission warnings.
  - Shows the suggestion bar in place of the toolbar accessories on the full keyboard's letter page while predictions are offered and no cancel control is showing, spanning from the keyboard edge to the logo control.
  - Hosts the emoji page over the key grid's place, the emoji search field in the toolbar's place, and the search results above the keys while searching.
  - Sends touches in the keyboard's outer padding to the key grid so they type the nearest key.
  - Invalidates layout whenever branded-toolbar Vibes visibility changes so returning from a warning mode restores measured top-row spacing.
- `KeyVox Keyboard/Views/Components/KeyboardSpeakButton.swift`
  - Keyboard speak control used for copied-text playback transport in the top-row accessory area.
- `KeyVox Keyboard/Views/Components/KeyboardVibesButton.swift`
  - Keyboard Vibes selector key used in the top-row accessory area.
  - Displays the selected/current Vibe label and the active/editable status tint for the latest insertion while following the normal key palette/pressed outline behavior.
- `KeyVox Keyboard/Views/Components/KeyboardSettingsToggleButton.swift`
  - Reusable top-row settings icon key for keyboard controls backed by containing-app settings or containing-app shortcuts.
  - Uses normal key styling and indicates enabled state through icon tint instead of a permanently pressed visual state.
- `KeyVox Keyboard/Views/Components/KeyboardLogoBarView.swift`
  - Proprietary keyboard logo-bar rendering and animation surface protected by the KeyVox branding license.
  - Intentionally limited to visual drawing, layout, and animation behavior only.
- `KeyVox Keyboard/Core/Transport/KeyboardTransportDisplayState.swift`
  - Non-visual keyboard logo transport state, accessibility labels, and playback/dictation presentation inputs kept separate from the proprietary logo-bar rendering file.
- `KeyVox Keyboard/Views/Components/KeyboardKeyGridView.swift`
  - Shows the page for the current layout through cached `KeyboardKeyGridPage` instances, applies the letter case, reports letter-key frames for predictions, resolves a touch to the containing key or the nearest key within its hit slop, and exposes the key, held-key, delete, globe, and touch-down callbacks.
- `KeyVox Keyboard/Views/Components/KeyboardKeyGridView+Touches.swift`
  - Multi-finger key handling: each finger is followed separately, characters type on lift or as soon as another finger lands, delete repeats while held, a held space bar becomes the cursor trackpad, holding `#+=` requests Compact Keys, holding a key with held-key characters opens its popup, and the globe's touches go to the system input-mode list.
- `KeyVox Keyboard/Views/Components/KeyboardKeyGridPage.swift`
  - One built-and-kept page of key rows per symbol page, keys mode, emoji-search row, emoji key, and globe combination, with its row-geometry helpers, so switching pages never rebuilds a page already shown.
- `KeyVox Keyboard/Views/Components/KeyboardKeyTouchSession.swift`
  - One finger's key, typed location, timestamp, and rollover state.
- `KeyVox Keyboard/Views/Components/KeyboardKeyView.swift`
  - Renders one key with two alternating labels so case switches only show and hide labels; draws no per-key blur and gives its shadow an explicit rounded path.
- `KeyVox Keyboard/Views/Components/KeyboardHeldKeyPopupView.swift`
  - Renders a held key's popup cells from the package's `HeldKeyPopupLayout`, highlighting the cell under the finger.
- `KeyVox Keyboard/Views/Components/KeyboardSuggestionBarView.swift`
  - Leading, primary, and trailing suggestion slots, the autocorrection in a heavier weight, up to three emoji splitting the trailing slot, taps that select an item, and long presses that report it instead.
- `KeyVox Keyboard/Views/FullAccessView.swift`
  - Full-screen keyboard-only instructional view shown when the user needs to enable Full Access.

### Keyboard Typing and Predictions

- `Packages/KeyVoxPredictiveKeyboard/Sources/KeyVoxPredictiveKeyboard/PredictiveTypingSession.swift`
  - UI-independent typing state of one text field: the host reports taps and text changes and asks for the `TextEdit` that space, return, word-ending characters, picked-word spacing, or a suggestion tap should apply. Owns autocorrection undo, previous-word revision requests, deleted-into correction holds, picked-word runs, and the suggestion bar's emoji word. Use from one thread only.
- `Packages/KeyVoxPredictiveKeyboard/Sources/KeyVoxPredictiveKeyboard/PredictionComputer.swift`
  - Computes the suggestion bar and space-bar autocorrection for a `PredictionRequest`, revisions for a `RevisionRequest`, and the intended letter for a contested tap; takes the keyboard geometry, personal vocabulary, and learned vocabulary from the host.
- `Packages/KeyVoxPredictiveKeyboard/Sources/KeyVoxPredictiveKeyboard/EnglishPredictiveEngine.swift`
  - Loads the bundled `PredictiveData` dictionary, context model, rankers, accent overlay, and word lists, and bridges to the `KeyVoxPredictiveNative` LatinIME target.
- `Packages/KeyVoxPredictiveKeyboard/Sources/KeyVoxPredictiveKeyboard/NoisyChannelCorrector.swift`, `SuggestionCandidateRanker.swift`, `MissingSpaceCorrector.swift`, `TouchAlignmentScorer.swift`, and `ContextLanguageScorer.swift`
  - Score candidates by context likelihood against where the touches landed, decide when space replaces the typed word, rank completions and corrections on one score, and read a typed word as two words whose space was missed.
- `Packages/KeyVoxPredictiveKeyboard/Sources/KeyVoxPredictiveKeyboard/SuggestionBar.swift` and `SuggestionBarComposer.swift`
  - Role-based suggestion-bar model (primary, leading, trailing, and emoji items) and its composition while a word is typed, between words, and for putting a correction back.
- `Packages/KeyVoxPredictiveKeyboard/Sources/KeyVoxPredictiveKeyboard/PersonalVocabulary.swift` and `PersonalWordForms.swift`
  - The user's KeyVox Dictionary entries, known names, and text replacements, and how their words take the entry's capitals.
- `Packages/KeyVoxPredictiveKeyboard/Sources/KeyVoxPredictiveKeyboard/TypingMemory.swift`, `TypingMemoryFile.swift`, `CorrectionRejections.swift`, `LearnedWords.swift`, `LearnedCapitals.swift`, and `LearnedVocabulary.swift`
  - What the keyboard learns from typing: turned-down corrections, learned words, and learned capitals, shared by every session while the keyboard runs, saved to a host-chosen JSON file under a reset generation, and forgettable per word.
- `Packages/KeyVoxPredictiveKeyboard/Sources/KeyVoxPredictiveKeyboard/HeldKeyCharacters.swift` and `HeldKeyPopupLayout.swift`
  - Bundled held-key characters per key with the side each popup opens toward, and the popup cell layout that reaches the keyboard's edge and spills to the other side, or takes a second row, when an offer does not fit.
- `Packages/KeyVoxPredictiveKeyboard/Sources/KeyVoxPredictiveKeyboard/SmartQuotes.swift`, `CharacterList.swift`, and `TypingTextContext.swift`
  - Opening and closing quote marks, the bundled character lists that end words, shape picked-word spacing, or suppress next-word suggestions, and the word and sentence context read around the cursor.
- `KeyVox Keyboard/Core/Prediction/KeyboardPredictionCoordinator.swift`
  - Runs the shared typing session on the main thread and suggestion work on a serial background engine, publishing a result only when no newer request was made; at a word boundary it uses the current result or computes it on the spot so a fast space never skips an autocorrection. Contested-tap checks run on a second engine so keys such as delete never wait for suggestions.
  - Never rereads the document proxy when background work finishes.
- `KeyVox Keyboard/Core/Prediction/KeyboardPredictionEngine.swift`
  - Serial-queue owner of one lazily created `PredictionComputer`, holding geometry, vocabulary, and learned words until the engine exists and remembering when the engine cannot load.
- `KeyVox Keyboard/Core/Prediction/KeyboardTypingTraits.swift`
  - Resolves what the letter keyboard may do in the focused field from its keyboard type, content type, secure entry, autocorrection, and autocapitalization traits, narrowed by the shared keyboard typing settings; a feature the field turns off stays off.
- `KeyVox Keyboard/Core/Prediction/KeyboardPersonalVocabularyBuilder.swift`
  - Builds `PersonalVocabulary` from KeyVox Dictionary phrases and the system supplementary lexicon, treating lexicon entries whose input matches their text, ignoring case, as known names and the rest as text replacements.
- `KeyVox Keyboard/Core/Prediction/KeyboardTypingMemory.swift`
  - Shared typing memory for every keyboard view while the extension runs, loaded from and saved to `KeyboardTypingMemoryLocation` off the main thread after a short delay, never saved over a newer reset generation, and cleared when the containing app's reset is adopted.

### Keyboard Emoji

- `Packages/KeyVoxEmoji/Sources/KeyVoxEmoji/EmojiCatalog.swift` and `EmojiCatalog+KeyboardSections.swift`
  - Bundled emoji catalog in the system emoji keyboard's categories and order, with names and skin-tone versions, filtered into keyboard sections by the host's drawability check.
- `Packages/KeyVoxEmoji/Sources/KeyVoxEmoji/EmojiSearch.swift` and `EmojiPredictions.swift`
  - Word-prefix emoji search with whole-word matches first, and the suggestion-bar emoji for a word, which the search returns first so the two agree.
- `Packages/KeyVoxEmoji/Sources/KeyVoxEmoji/EmojiFrequentlyUsed.swift`
  - Codable Frequently Used ranking with decaying scores, bundled starters that fill what used emoji leave, and ordering of other emoji lists by use.
- `Packages/KeyVoxEmoji/Sources/KeyVoxEmoji/EmojiTwoPersonTones.swift`
  - Maps two-person emoji versions to and from each person's tone.
- `KeyVox Keyboard/Core/Emoji/KeyboardEmojiSections.swift`, `KeyboardEmojiSearchIndex.swift`, and `KeyboardEmojiPredictionsIndex.swift`
  - Shared indexes that read the bundled catalog, search, and suggestion-bar emoji once off the main thread and keep them while the keyboard runs; the suggestion bar offers emoji only after the user has typed an emoji since the keyboard started.
- `KeyVox Keyboard/Core/Emoji/KeyboardEmojiSupport.swift`
  - Asks the system emoji font whether it draws an emoji as one picture so the keyboard offers only emoji this phone shows.
- `KeyVox Keyboard/Core/Emoji/KeyboardEmojiFrequentlyUsedStore.swift` and `KeyboardEmojiSkinToneStore.swift`
  - App Group persistence for the Frequently Used ranking and the skin tone last chosen per emoji.
- `KeyVox Keyboard/Core/Emoji/KeyboardEmojiPanel.swift` and `KeyboardEmojiCategoryMemory.swift`
  - Closed, browsing, and searching panel state, and where a category tap scrolls the grid.
- `KeyVox Keyboard/Core/Emoji/KeyboardEmojiGridGeometry.swift`, `KeyboardEmojiSearchGeometry.swift`, `KeyboardEmojiSkinTonePickerLayout.swift`, `KeyboardEmojiSearchSkinTonePickerLayout.swift`, and `KeyboardEmojiTwoPersonPickerLayout.swift`
  - Measured layout math for the emoji grid, the search field and results (including the extra keyboard height while searching), and the skin-tone and two-person pickers, which stay inside the space they show in.
- `KeyVox Keyboard/Core/Emoji/KeyboardEmojiSilhouetteRenderer.swift`
  - Draws a two-person emoji with each unchosen person as a solid gray silhouette, attributing outline and clothing pixels to the nearest person and keeping a joining heart in color.
- `KeyVox Keyboard/Views/Emoji/KeyboardEmojiPageView.swift` and `KeyboardEmojiPageView+SkinTones.swift`
  - Sideways-scrolling emoji grid over the category bar, showing and typing each emoji in its chosen tone, with held-emoji skin-tone and two-person pickers.
- `KeyVox Keyboard/Views/Emoji/KeyboardEmojiCategoryBar.swift` and `KeyboardEmojiCategoryBar+Scrub.swift`
  - The bar with the key back to the typing keys, a button per category, and delete, plus finger scrubbing along the categories.
- `KeyVox Keyboard/Views/Emoji/KeyboardEmojiSearchFieldView.swift`, `KeyboardEmojiSearchResultsView.swift`, and `KeyboardEmojiSearchResultsView+SkinTones.swift`
  - The search field in the toolbar's place, the single scrolling row of results, and the picker a held result opens.
- `KeyVox Keyboard/Views/Emoji/KeyboardEmojiSkinTonePickerView.swift`, `KeyboardEmojiTwoPersonPickerView.swift`, `KeyboardEmojiChoiceHighlightView.swift`, and `KeyboardEmojiPickerPanelShape.swift`
  - Picker rendering with one shared choice highlight for both pickers in light and dark appearance and one panel-and-stem outline.
- `KeyVox Keyboard/Views/Emoji/KeyboardEmojiCell.swift`, `KeyboardEmojiGridLayout.swift`, and `KeyboardEmojiCategoryStyle.swift`
  - Grid cells labeled by their emoji for VoiceOver, the collection layout that places each emoji from `KeyboardEmojiGridGeometry`, and each category's bar symbol and VoiceOver wording.

### Tests

- `KeyVoxiOSTests/App/`
  - Onboarding state, Dictation Shortcut intro scheduling, onboarding keyboard-tour state, keyboard access probing, app haptics decisions, settings persistence, KeyVox Vibes latest-artifact persistence, Vibes intro/access/purchase semantics, shared paths, iCloud sync, weekly stats, Live Activity coordination, shortcut dictation coordination, URL routing, and model manager behavior across rooted Whisper migration and Parakeet installs.
- `KeyVoxiOSTests/App/TTSPurchaseControllerTests.swift`
  - Deterministic copied-text playback monetization coverage for cached unlock state, two-free-speaks-per-day accounting, local day resets, and purchase or restore state transitions through the placeholder store abstraction.
- `KeyVoxiOSTests/Core/Audio/`
  - Audio input preference resolution and stop-time capture processing.
- `KeyVoxiOSTests/Core/Keyboard/`
  - Keyboard dictation control, latest-insertion change behavior, deterministic paragraph/list/Caps formatting, controller presentation lifecycle coverage, toolbar warning precedence, interaction haptics, text insertion behavior, letter-case shift state, held-delete word deletion, typing-memory reset, emoji category memory and styles, emoji grid, search, and picker geometry, emoji drawability, and cursor-trackpad helpers.
  - The test target compiles every keyboard source except the keyboard's `Info.plist` and privacy manifest.
- `KeyVoxiOSTests/Core/TTS/`
  - Deterministic copied-text playback coverage for PocketTTS engine runtime lifecycle, TTS manager lifecycle handoff rules, system playback integration, and buffering policy behavior.
- `KeyVoxiOSTests/Views/`
  - Pure presentation-rule coverage for inline warning visibility, KeyVox Speak scene selection, and Home copied-text playback preparation spinner/progress behavior.
- `KeyVoxiOSTests/Core/Transcription/`
  - Transcription/session lifecycle, typed command outcomes, immediate microphone-release retry and timeout fallback, and interrupted-capture recovery behavior.
- `Packages/KeyVoxStyleRewrite/Tests/KeyVoxStyleRewriteTests/`
  - Package-level coverage for style request construction, token-aware chunk planning, chunk fallback/stitching, latest-utterance artifact serialization, Chill heuristics, and output repair.
- `Packages/KeyVoxLocalInference/Tests/KeyVoxLocalInferenceTests/`
  - Package-level coverage for local prompt formatting, adapter-aware generation behavior, and opt-in live model prompt suites for Polished, Casual, and the Polished gauntlet.
- `Packages/KeyVoxPredictiveKeyboard/Tests/KeyVoxPredictiveKeyboardTests/`
  - Package-level coverage for autocorrection, missing-space correction, word revision, deleted-into and remembered corrections, contact names and dictionary phrases, learned words, capitals, and suggestions, sentence endings and openers, picked-word spacing and repeated picks, emoji suggestions, smart quotes, held-key characters and popup layout, character lists, and the typing-memory file.
- `Packages/KeyVoxEmoji/Tests/KeyVoxEmojiTests/`
  - Package-level coverage for the catalog, keyboard sections, Frequently Used ranking, search, suggestion-bar emoji, and two-person tones.

## Change Tracking

- Update this file when iOS file ownership, target boundaries, or top-level runtime flow changes.
- Use [`ENGINEERING.md`](ENGINEERING.md) for lifecycle rules, onboarding contracts, IPC details, session behavior, and operational/testing policy.
- These two docs are the maintained iOS source of truth in this repo today.
