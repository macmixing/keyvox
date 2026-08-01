# KeyVox Code Map
**Last Updated: 2026-07-31**

## Project Overview

KeyVox is a macOS menu bar dictation app that records speech while a trigger key is held, transcribes locally with Whisper or Parakeet, and inserts text into the focused app. The default trigger is **Right Option (⌥)**.

## Architecture

- **App**: app entry point, window lifecycle, shared settings/defaults ownership, and macOS-side iCloud sync wiring
- **Core**: state machine, audio pipeline, keyboard monitoring, overlay orchestration, model management, provider-aware host integration, paste/update host integration
- **Packages/KeyVoxCore**: shared dictation engine (transcription pipeline, whole-capture Whisper voice-activity gating, deterministic paragraph/list state and variant handling, dictionary matching, normalization, lists, shared audio helpers, packaged resources)
- **Packages/KeyVoxTextComposition**: platform-neutral policy for joining finalized dictation to existing editor text, including leading capitalization, spacing, quotation-mark context, and sentence boundaries
- **Core/Services**: reusable host integration services (paste/injection, update checking)
- **Views**: SwiftUI UI layer (menu, onboarding, settings, overlays, warnings, branded visuals)
- **Resources**: assets, entitlements, bundled fonts/icons, pronunciation resources
- **Tools**: maintainer-only scripts (resource generation, dev helpers)
- **KeyVoxTests**: app unit tests for deterministic/runtime-safe logic
- **Packages**: local Swift packages for the shared engine, the `whisper.cpp` wrapper, Parakeet Core ML runtime, local rewrite inference, shared style rewrite contracts, and bundled Vibes LoRA adapters

## Contributor Notes

- Behavior and motion constants are kept file-local near their owning runtime logic to reduce maintenance confusion.
- Proprietary visual tuning remains in the excluded branded file `Views/Components/LogoBarView.swift`.
- Shared macOS app-window theme tokens now live in `Views/Components/MacAppTheme.swift`; use that file for reusable settings/onboarding/update/modal colors instead of repeating local window background stacks.
- Shared macOS typography, blur wrappers, and generic progress visuals now live in `Views/Components/UIComponents.swift`.
- `Views/StatusMenuView.swift` and `Views/Warnings/*` intentionally keep separate styling ownership and are not part of `MacAppTheme`.
- `Core/Overlay/OverlayTypes.swift` owns reusable fling-impact models; keep those neutral and non-branded rather than embedding them into physics or panel files.
- `Core/Services/UpdateFeedConfig.swift` owns the tracked GitHub feed plus the optional local override resolver; update-feed source selection should stay separate from prompt and install behavior.
- No shared constants module is required unless a value is truly reused across multiple domains.
- Unit tests intentionally focus on deterministic/runtime-safe behavior; hardware/global-input/UI-rendering remain integration scope.
- `CODEMAP.md` is the source of truth for high-level file ownership and where major systems live; `ENGINEERING.md` owns behavior contracts, pipeline order, and maintainer policy.

## Directory Index

This is a curated map of the repo layout (intentionally not an exhaustive inventory).

```text
KeyVox/
├── macOS/
│   ├── App/
│   │   ├── KeyVoxApp.swift
│   │   ├── MacRuntimeFlags.swift
│   │   ├── WindowManager+Updates.swift
│   │   ├── WindowManager+VibesIntro.swift
│   │   ├── WindowManager+FirstDictationOnboarding.swift
│   │   ├── AppSettingsStore.swift
│   │   ├── AppServiceRegistry.swift
│   │   ├── LoginItemController.swift
│   │   ├── DockIconVisibilityController.swift
│   │   ├── WeeklyWordStatsStore.swift
│   │   ├── UserDefaultsKeys.swift
│   │   └── iCloud/
│   ├── Core/
│   │   ├── KeyboardMonitor.swift
│   │   ├── AudioDeviceManager.swift
│   │   ├── Audio/
│   │   │   └── AudioRecorder*.swift
│   │   ├── ModelDownloader/
│   │   ├── Transcription/
│   │   │   └── TranscriptionManager*.swift
│   │   ├── DictationTriggerController.swift
│   │   ├── Vibes/
│   │   │   ├── MacLocalRewriteModelCatalog.swift
│   │   │   ├── MacLocalRewriteModelInstallManifest.swift
│   │   │   ├── MacLocalRewriteModelInstallState.swift
│   │   │   ├── MacLocalRewriteModelManager.swift
│   │   │   ├── MacLocalRewriteInferenceService.swift
│   │   │   ├── MacLocalStyleRewriteTextTransformer.swift
│   │   │   ├── MacVibesIntroController.swift
│   │   │   ├── MacVibesAccessMatrix.swift
│   │   │   ├── MacVibesCoordinator.swift
│   │   │   ├── MacVibesReadinessPrewarmer.swift
│   │   │   ├── MacDictationChangeController.swift
│   │   │   ├── MacDictationChangeController+Formatting.swift
│   │   │   ├── MacDictationChangeSession.swift
│   │   │   ├── MacDictationInsertionReplacing.swift
│   │   │   ├── MacDictationRenderedVariantKey.swift
│   │   │   ├── MacFormattingChangeOutcome.swift
│   │   │   ├── MacFormattingShortcutMonitor.swift
│   │   │   ├── MacFormattingShortcutStateMachine.swift
│   │   │   ├── MacFormattingTriggerActionController.swift
│   │   │   ├── MacTriggerTapClassifier.swift
│   │   │   └── MacVibesTriggerActionController.swift
│   │   ├── Services/
│   │   │   ├── AppProcessTerminator.swift
│   │   │   ├── Paste/
│   │   │   │   ├── Accessibility/
│   │   │   │   ├── Clipboard/
│   │   │   │   ├── Composition/
│   │   │   │   ├── Heuristics/
│   │   │   │   ├── MenuFallback/
│   │   │   │   ├── Pipeline/
│   │   │   │   └── PasteService.swift
│   │   │   ├── AppUpdateService.swift
│   │   │   ├── AppUpdateLogic.swift
│   │   │   ├── UpdateFeedConfig.swift
│   │   │   ├── UpdatePromptPresenting.swift
│   │   │   └── AppUpdate/
│   │   └── Overlay/
│   │       ├── OverlayManager.swift
│   │       ├── OverlayTypes.swift
│   │       └── AudioIndicatorDriver.swift
│   ├── Views/
│   │   ├── Components/
│   │   │   ├── AppActionButton.swift
│   │   │   ├── AppUpdateProgressBar.swift
│   │   │   ├── ConfirmDeletePromptView.swift
│   │   │   ├── DictionaryFloatingAddButton.swift
│   │   │   ├── LogoBarView.swift
│   │   │   ├── MacAppTheme.swift
│   │   │   ├── MacFormattingPillView.swift
│   │   │   ├── OnboardingMicrophonePickerView.swift
│   │   │   ├── OverlayPillCompletionStroke.swift
│   │   │   ├── OverlayPillMetrics.swift
│   │   │   ├── OverlayPillOverlay.swift
│   │   │   ├── OverlayPillProcessingIcon.swift
│   │   │   ├── OverlayPillState.swift
│   │   │   ├── OverlayPillView.swift
│   │   │   ├── OverlayPresentationMetrics.swift
│   │   │   ├── SelectedVibeLabel.swift
│   │   │   ├── UIComponents.swift
│   │   │   ├── VibePillView.swift
│   │   │   └── SettingsLastTranscriptionCard.swift
│   │   ├── StatusMenuView.swift
│   │   ├── OnboardingView.swift
│   │   ├── FirstDictation/
│   │   ├── RecordingOverlay.swift
│   │   ├── VibePillOverlay.swift
│   │   ├── UpdatePromptOverlay.swift
│   │   ├── VibesIntro/
│   │   ├── Updates/
│   │   ├── Settings/
│   │   │   ├── DictationLanguageSection.swift
│   │   │   ├── SettingsView+DictationModels.swift
│   │   │   ├── SettingsVibesCard.swift
│   │   │   ├── SettingsVibesAIInstallCard.swift
│   │   │   └── SettingsVibesExamplesSection.swift
│   │   └── Warnings/
│   ├── Resources/
│   ├── KeyVoxTests/
│   └── Docs/
│       ├── CODEMAP.md
│       └── ENGINEERING.md
├── Packages/
│   ├── KeyVoxCore/
│   │   └── Sources/KeyVoxCore/
│   │       ├── Transcription/
│   │       ├── Services/Parakeet/
│   │       ├── Services/Whisper/
│   │       ├── Language/
│   │       ├── Lists/
│   │       ├── Normalization/
│   │       ├── Support/
│   │       ├── Audio/
│   │       └── Resources/Pronunciation/
│   ├── KeyVoxTextComposition/
│   │   ├── Sources/KeyVoxTextComposition/
│   │   └── Tests/KeyVoxTextCompositionTests/
│   ├── KeyVoxWhisper/
│   │   └── Sources/KeyVoxWhisper/
│   │       ├── Resources/ggml-silero-v5.1.2.bin
│   │       └── WhisperVoiceActivityDetector.swift
│   ├── KeyVoxParakeet/
│   ├── KeyVoxLocalInference/
│   │   └── Sources/KeyVoxLocalInference/
│   │       ├── LocalLanguageModel.swift
│   │       ├── LocalLanguageModelGPUOffloadMode+Logging.swift
│   │       ├── ProcessInfo+XCTest.swift
│   │       ├── LlamaLocalLanguageModel*.swift
│   │       ├── LlamaLoadedModel.swift
│   │       └── LocalInferenceCancellationToken.swift
│   ├── KeyVoxStyleRewrite/
│   │   └── Sources/KeyVoxStyleRewrite/
│   │       ├── OutputRepair/
│   │       │   ├── OutputRepair.swift
│   │       │   ├── Repairs/
│   │       │   │   ├── APStyleNumberRepair.swift
│   │       │   │   ├── AddressFactRepair.swift
│   │       │   │   ├── MoneyFactRepair.swift
│   │       │   │   ├── NumberEvidenceRepair.swift
│   │       │   │   ├── NumberSeparatorEvidenceRepair.swift
│   │       │   │   ├── PunctuationRepair.swift
│   │       │   │   └── TerminalPunctuationBoundaryRepair.swift
│   │       │   └── Support/
│   │       │       ├── CurrencyUnits.swift
│   │       │       ├── NumberEvidence.swift
│   │       │       ├── RepairMatching.swift
│   │       │       ├── RepairNumberParsing.swift
│   │       │       └── RepairTokenization.swift
│   │       ├── StyleRewriteDictationConfiguration.swift
│   │       ├── StyleRewritePromptLeakGuard.swift
│   │       └── StyleRewriteTextTransformer.swift
│   └── KeyVoxVibesAdapters/
├── Tools/
├── build/
└── README.md
```


## Core Runtime Flow

1. `Core/KeyboardMonitor.swift` publishes trigger/shift/escape/caps-lock state.
2. `Core/Transcription/TranscriptionManager*.swift` drives app state: `idle -> recording -> transcribing -> idle`.
3. `Core/Audio/AudioRecorder.swift` captures live audio as mono float frames at 16kHz.
4. `App/AppServiceRegistry.swift` routes dictation through `SwitchableDictationProvider`, normalizes active-provider selection, synchronizes the device-local Whisper language, and binds install-time Parakeet preloading to the downloader.
5. For Whisper, `Packages/KeyVoxCore/Sources/KeyVoxCore/Services/Whisper/WhisperService+TranscriptionCore.swift` runs whole-capture voice-activity analysis through the package-owned Silero detector before decoding; Parakeet does not use this Whisper-specific gate.
6. `Packages/KeyVoxCore/Sources/KeyVoxCore/Transcription/AudioParagraphChunker.swift` detects long internal silence and computes conservative chunk boundaries shared by both providers.
7. `Packages/KeyVoxCore/Sources/KeyVoxCore/Services/Whisper/WhisperService.swift` or `Packages/KeyVoxCore/Sources/KeyVoxCore/Services/Parakeet/ParakeetService.swift` transcribes the chunk stream through the active provider and stitches chunk text with paragraph or space separators.
8. `Packages/KeyVoxCore/Sources/KeyVoxCore/Transcription/TranscriptionPostProcessor.swift` orchestrates email pre-normalization, dictionary correction, spoken colon/quantity/math normalization, list formatting, late cleanup, date/time/email/website repair, numeric grouping, whitespace/capitalization, terminal punctuation, and all-caps finishing through focused helpers under `Packages/KeyVoxCore/Sources/KeyVoxCore/Normalization/`.
9. `Core/Vibes/MacVibesCoordinator.swift` optionally runs local KeyVox Vibes rewrites through `MacLocalStyleRewriteTextTransformer`, `MacLocalRewriteInferenceService`, `Packages/KeyVoxLocalInference`, and bundled LoRA adapters from `Packages/KeyVoxVibesAdapters` when Vibes AI is installed.
10. `Core/Services/Paste/PasteService.swift` resolves macOS editor context through its composition coordinators, delegates leading capitalization and spacing policy to `Packages/KeyVoxTextComposition`, then inserts text via Accessibility first and menu-bar Paste fallback second.
11. `Core/Overlay/OverlayManager.swift` owns overlay lifecycle orchestration and delegates motion/persistence helpers.
12. `Core/Overlay/AudioIndicatorDriver.swift` owns generic indicator timing, smoothing, stale-sample handling, and published timeline state.
13. `Views/RecordingOverlay.swift` hosts overlay visibility behavior and feeds generic indicator state into the branded renderer.
14. `Views/Components/LogoBarView.swift` renders standalone and recording-reactive KeyVox logo presentations; reusable temporary pill rendering lives in the dedicated overlay pill components.

## Key Components

### App Layer

- `App/KeyVoxApp.swift`
  - App entry point and menu bar scene.
  - Owns onboarding/settings windows via `WindowManager`.
  - Reopen behavior prefers visible non-settings windows (updater, post-update notice, onboarding) before falling back to Settings.
  - Cancels app termination once to close Settings first when the Settings window is visible.
- `App/DockIconVisibilityController.swift`
  - Owns runtime Dock icon visibility by switching between regular and accessory activation policy.
  - Keeps legacy accessory-only macOS builds (`< 15.6`) on accessory policy and only honors the user hide-Dock preference when no managed KeyVox windows are visible.
- `App/WindowManager+Updates.swift`
  - Dedicated updater and post-update notice window lifecycle.
  - Applies updater-specific floating-window centering and stoplight hiding.
  - Keeps update-related window policy out of the primary settings/onboarding window code.
- `App/WindowManager+VibesIntro.swift`
  - Dedicated Vibes intro/help window lifecycle.
  - Hosts the shared Vibes intro window, resolves the SwiftUI fitting size before presentation, and keeps scene-size changes routed through one AppKit resize path.
  - Opens Settings directly to the Style tab when the intro `Try it` action completes.
- `App/WindowManager+FirstDictationOnboarding.swift`
  - Dedicated post-setup first-dictation window lifecycle.
  - Hosts the separate first-dictation flow after setup onboarding completes, animates intro-to-practice resizing from a centered frame, and opens Settings when the user completes or skips the flow.
- `App/MacRuntimeFlags.swift`
  - Centralized macOS environment flag parser for forcing setup onboarding, first-dictation onboarding, the debug microphone picker, debug model-download preview errors, raw-text debug logs, and the KeyVox Vibes intro without clearing persisted defaults.
- `App/AppSettingsStore.swift`
  - Centralized persisted user-preference owner (`triggerBinding`, `autoParagraphsEnabled`, `listFormattingEnabled`, sound settings, onboarding, first-dictation outcome flags, selected microphone, selected Vibe, Vibes trigger-key interactions, hide Dock icon preference, update prompt timestamps, active dictation provider, Whisper dictation language).
  - Single in-memory observable source consumed by settings UI and runtime managers.
  - Validates restored Whisper language identifiers against the shared catalog and defaults missing or unsupported values to Auto Detect.
- `App/AppServiceRegistry.swift`
  - Retains shared runtime services and app-owned sync helpers.
  - Instantiates `WhisperService`, `ParakeetService`, and `SwitchableDictationProvider`.
  - Normalizes active-provider selection changes back into the runtime only when transcription is idle.
  - Applies the persisted Whisper language during composition and keeps later local selection changes synchronized with `WhisperService`.
  - Hooks downloader post-install preparation so Parakeet preload happens after install finalization instead of on the first trigger path.
  - Owns the Mac Vibes local rewrite model manager, inference service, and coordinator without startup Vibes model prewarming.
  - Owns the dedicated weekly stats store/sync subsystem separately from the general iCloud settings coordinator.
- `App/WeeklyWordStatsStore.swift`
  - Dedicated local weekly-usage store for combined weekly word count plus hidden per-installation contribution totals.
  - Persists a stable installation identifier, current-week snapshot, and rollover behavior outside `AppSettingsStore`.
- `App/iCloud/WeeklyWordStatsCloudSync.swift`
  - Dedicated iCloud KVS sync helper for weekly word stats only.
  - Merges same-week per-device totals deterministically and keeps `KeyVoxiCloudSyncCoordinator` focused on dictionary/settings sync.
- `App/iCloud/KeyVoxiCloudSyncCoordinator.swift`
  - Owns macOS iCloud KVS convergence for dictionary entries plus `triggerBinding`, `autoParagraphsEnabled`, and `listFormattingEnabled`.
  - Uses per-setting modified-at timestamps so newer local/remote values win deterministically during bootstrap and live sync.
- `App/iCloud/KeyVoxiCloudKeys.swift`
  - Single source of truth for macOS iCloud KVS value keys and per-setting modified-at keys.
- `App/iCloud/KeyVoxiCloudPayloads.swift`
  - Codable payload ownership for dictionary snapshots and per-device weekly word totals exchanged through iCloud KVS.
- `App/UserDefaultsKeys.swift`
  - Single source of truth for app preference keys.
- `Views/OnboardingView.swift`
  - Onboarding step orchestration UI.
  - Delegates microphone Step 1 flow logic to `OnboardingMicrophoneStepController`.
  - Uses `LogoBarView(size:)` for the standalone branded logo presentation.
- `Views/FirstDictation/*`
  - Separate optional first-dictation flow shown after setup onboarding, not inside `OnboardingView`.
  - `FirstDictationIntroView` owns the try/skip choice, `FirstDictationPracticeView` owns the focused practice field and instruction copy, `FirstDictationOptionKeyPromptView` renders the configured trigger key, and `FirstDictationSuccessCelebrationView` owns the success animation.
  - `FirstDictationOnboardingFlowView` keys completion off successful dictation revisions and verifies the focused field contains the latest dictated text.
- `Views/OnboardingMicrophoneStepController.swift`
  - Owns onboarding microphone authorization and no-built-in gating behavior.
  - Drives microphone-step completion state and prompt visibility.
- `Views/Components/OnboardingMicrophonePickerView.swift`
  - Presentation-only onboarding modal for required microphone selection confirmation.
  - Uses the shared app action button treatment for the microphone confirmation action.
- `Views/Components/MacAppTheme.swift`
  - Shared macOS app-window theme tokens for settings, onboarding, updater, and related modal surfaces.
  - Owns the standard main-window background color (`#1A1740` equivalent) plus reusable card/icon/sidebar/stroke accents.
  - Explicitly excludes `StatusMenuView` and warning overlays from the shared theme boundary.
- `Views/Components/DictionaryFloatingAddButton.swift`
  - Shared floating circular add action used by the dictionary settings surface.
- `Views/Components/LogoBarView.swift`
  - Single branded Mac logo file.
  - Provides standalone logo presentation (`LogoBarView(size:)`) and recording-indicator presentation (`LogoBarView(phase:timelineState:ringColor:)`).
  - Contains the proprietary ring/glow/bar/ripple visual language and visual tuning.
- `Views/Components/OverlayPillView.swift`
  - Neutral shared temporary-pill renderer for normal, processing, and completed presentation with injected icon content.
  - Owns the capsule, title, completion stroke, common sizing, and shared animation surface without owning Vibe or formatting copy.
- `Views/Components/OverlayPillProcessingIcon.swift`
  - Shared two-layer processing pulse used by both the Vibes logo and formatting SF Symbols.
  - Keeps the decorative glow layer hidden from accessibility while leaving the foreground icon's semantics to its owning presentation.
- `Views/Components/VibePillView.swift`
  - Vibe-specific pill content layered onto `OverlayPillView` and the shared processing-icon renderer.
- `Views/Components/MacFormattingPillView.swift`
  - Formatting-specific List/Paragraph titles, SF Symbols, enabled-state color, and the Paragraph-specific content spacing used by the shared pill renderer.
- `Views/Components/SelectedVibeLabel.swift`
  - Small recording-time Vibe label shown below the floating logo when a non-None Vibe is selected.
  - Lives outside `RecordingOverlay` layout so it does not affect the logo panel's position or animation.
- `Views/RecordingOverlay.swift`
  - Thin overlay shell for visibility animation, panel sizing, and ring-color selection.
  - Feeds recorder-derived indicator samples into `AudioIndicatorDriver` and renders `LogoBarView`.
- `Views/VibePillOverlay.swift`
  - Owns the cycle-pill presentation controller and forward flip animation used for double-tap Vibe cycling.
- `Views/Components/OverlayPillOverlay.swift`
  - Generic standalone-pill visibility shell shared by Vibe and formatting feedback.
- `Views/Settings/SettingsView+DictationModels.swift`
  - User-facing `Active Model` settings card for provider selection plus install/remove/progress/error state per model.
  - Attaches the language row beneath the model controls and delegates its presentation to `DictationLanguageSection`.
  - Falls back to the first ready provider when the persisted active selection is no longer installable/selectable.
  - Only surfaces Parakeet on supported systems; unsupported selections normalize back to Whisper in `AppSettingsStore`.
- `Views/Settings/DictationLanguageSection.swift`
  - Uses the standard Mac `SettingsRow` and menu-picker pattern to display and select the current Whisper language from `WhisperBaseLanguageCatalog`.
  - Keeps the dropdown visible but disabled on Auto Detect for Parakeet and owns the nearby FAQ guidance copy.
- `Views/Settings/SettingsView+Legal.swift`
  - Bundled project/license/OFL/pronunciation/third-party notices viewer presented from Settings.
- `Views/Components/ConfirmDeletePromptView.swift`
  - Reusable destructive confirmation sheet used for dictionary-entry deletion and Vibes AI model deletion.
- `Views/VibesIntro/MacVibesIntroWindowView.swift`
  - Shared Mac Vibes intro window shell.
  - Owns the top-right close control, centered footer action, dynamic content-size measurement, Scene B standalone help behavior, and the `Try it` readiness gate.
- `Views/VibesIntro/MacVibesIntroSceneAView.swift`
  - Scene A presentation for introducing KeyVox Vibes and style examples.
- `Views/VibesIntro/MacVibesIntroSceneBView.swift`
  - Scene B presentation for trigger-key Vibes behavior, tap-to-Vibe, undo, and local-first messaging.
- `Views/VibesIntro/MacVibesIntroSceneCView.swift`
  - Scene C presentation for Vibes AI readiness.
  - Owns the intro install/download card, ready-row copy/icon swap, and shared progress presentation.

### Core Managers

- `Core/Transcription/TranscriptionManager.swift`
  - Owns runtime state, dependencies, active-provider pipeline composition, initialization, and teardown for the macOS dictation manager.
  - Publishes `successfulDictationRevision` as a monotonic in-memory signal for UI that needs to react to every successful dictation, including repeated identical text.
- `Core/Transcription/TranscriptionManager+Bindings.swift`
  - Binds keyboard/caps-lock/model readiness publishers into runtime availability, trigger orchestration, formatting-shortcut monitor eligibility, and overlay hands-free state.
- `Core/Transcription/TranscriptionManager+RecordingSession.swift`
  - Starts/stops recordings, routes transcribe -> post-process -> paste through internal `DictationPipeline`, and records spoken-word totals through `WeeklyWordStatsStore`.
  - Chooses list render mode (`multiline` vs `singleLineInline`) from focused target context before post-processing.
  - Persists the most recent successful final transcription for the Settings Home tab card.
  - Marks `hasCompletedFirstDictation` on successful normal dictation and triggers popup eligibility when the first successful dictation happens outside the first-dictation window.
  - Stops and discards an in-progress ordinary recording when a consumed formatting chord takes ownership, then runs the latest-insertion change after recorder shutdown.
- `Core/Transcription/TranscriptionManager+OverlayAndDebug.swift`
  - Keeps overlay hands-free visual updates, playback sound effects, and debug-only transformation-speed logging out of recording-session flow.
- `Core/DictationTriggerController.swift`
  - Owns trigger press/release orchestration, pending-stop handling, deferred recording start, hands-free lock mode, and escape cancellation.
  - Delegates recording/transcription actions back to `TranscriptionManager` through a narrow runtime protocol and delegates Vibes quick-tap apply/undo/cycling behavior to `MacVibesTriggerActionController`.
  - Hands consumed trigger+L/P interactions to `MacFormattingTriggerActionController`, cancels the current Vibe interaction, and prevents trigger release from becoming a recording or Vibe action.
- `Core/Vibes/MacVibesCoordinator.swift`
  - Mac-owned local style rewrite coordinator for KeyVox Vibes.
  - Resolves the selected Vibe through local model readiness, prewarms requested styles, transforms pipeline output, and releases the local rewrite runtime after dictation and Vibe-change transforms complete.
- `Core/Vibes/MacVibesReadinessPrewarmer.swift`
  - Defines the old install-readiness prewarm helper, but the app runtime does not retain it because Vibes AI should not load at app launch or immediately after reinstall.
- `Core/Vibes/MacVibesIntroController.swift`
  - Owns one-time cold-launch Vibes intro eligibility after main onboarding and a completed-or-skipped first-dictation outcome.
  - Persists the seen flag and supports the local force-show environment flag used by the Mac debug scheme.
- `Core/Vibes/MacLocalRewriteModelCatalog.swift`
  - Mac-local source of truth for the Vibes GGUF model descriptor, artifact metadata, install manifest filename, and LoRA adapter filenames.
- `Core/Vibes/MacLocalRewriteModelManager.swift`
  - Downloads, stages, validates, promotes, deletes, and publishes install state for the Mac Vibes AI model under Application Support.
  - Resolves bundled LoRA adapters through `KeyVoxVibesAdapters` before falling back to installed adapter paths.
- `Core/Vibes/MacLocalRewriteInferenceService.swift`
  - Caches the loaded local rewrite model per model URL and adapter URL.
  - Unloads the cached model when the installed model is invalidated or the Mac Vibes coordinator releases the transform lifecycle.
  - Requests automatic GPU offload from `KeyVoxLocalInference`; the package runtime gates that to macOS Sequoia (15) and newer, with macOS Ventura/Sonoma (13.5-14.x) remaining CPU-only.
- `Core/Vibes/MacLocalStyleRewriteTextTransformer.swift`
  - Bridges shared style rewrite requests into Mac local inference.
  - Maps `polished` to the polished LoRA and `casual`/`chill` to the casual LoRA.
  - Cancels pending prewarm work and unloads the local rewrite inference cache when resources are released.
  - Logs prewarm, LoRA-missing, metrics, and failure diagnostics in debug builds.
- `Core/Vibes/MacVibesAccessMatrix.swift`
  - Pure settings-state resolver for Mac Vibes install/download/repair/ready UI.
  - Emits structural state only; user-facing copy stays in the owning settings views.
  - Mac Vibes have no trial, unlock, purchase, restore, or paywall branches.
- `Core/Vibes/MacDictationChangeController.swift`
  - Captures the latest inserted dictation session and safely applies Vibe or deterministic paragraph/list changes only when the focused field still contains the untouched insertion before the caret.
  - Preserves all four deterministic variants, all-caps presentation, active/previous Vibe state, and rendered results cached by deterministic state plus Vibe.
- `Core/Vibes/MacFormattingShortcutMonitor.swift`
  - Accessibility-gated `CGEventTap` monitor that tracks the configured left/right trigger binding, consumes physical L/P key-down and matching key-up events, suppresses repeats, and restores a disabled tap.
  - Starts only after Accessibility is already trusted; app launch must not request or move the existing permission prompt.
- `Core/Vibes/MacFormattingShortcutStateMachine.swift`
  - Pure modifier/chord decision state for trigger binding specificity, L/P mapping, repeat suppression, key-up consumption, onboarding, and runtime eligibility.
- `Core/Vibes/MacFormattingTriggerActionController.swift`
  - Owns formatting-pill feedback and delegates latest-insertion changes to `MacDictationChangeController` without changing saved paragraph/list preferences.
- `Core/Vibes/MacTriggerTapClassifier.swift`
  - Small deterministic helper for single-tap vs double-tap classification.
- `Core/Vibes/MacVibesTriggerActionController.swift`
  - Owns quick-tap press timing, pending single-tap work, Vibe apply/undo dispatch, and double-tap Vibe cycling outside `TranscriptionManager`.
  - Respects `AppSettingsStore.vibesTriggerKeyInteractionsEnabled`; when disabled, trigger-key taps fall through to normal dictation behavior without Vibes single-tap, double-tap, or pill-handoff behavior.
- `Core/Services/Paste/PasteService.swift`
  - Owns paste insertion plus latest untouched insertion verification/replacement used by Mac Vibes apply/undo.
  - Requires the exact original process, AX element, target range, and selection snapshot before replacement and falls back conservatively when Accessibility cannot prove the insertion is still safe to mutate.
- `Core/Services/Paste/Accessibility/PasteUntouchedInsertionAuthorizer.swift`
  - State owner for latest-insertion token capture, validation, invalidation, and successful-replacement advancement.
  - Resolves current AX context through the existing replacer and rejects process, element, target-range, or selection mismatches before PasteService mutates text.
- `Core/Services/Paste/Accessibility/PasteUntouchedInsertionReplacer.swift`
  - Resolves the exact current Accessibility target for an authorized latest insertion and performs replacement through confirmed selected-text or whole-value writes, with menu fallback only when direct mutation cannot be proven safe.
  - Owns newline-normalized target recovery, post-write verification, tracked value-target continuity, and final caret placement; it does not authorize whether an insertion may be changed.
- `Core/Services/Paste/Accessibility/PasteUntouchedInsertionToken.swift`
  - Immutable authorization record for the latest successful insertion, binding replacement to its original PID and AX target context.
  - Allows a successful replacement to advance only within the same process, AX element, and target start location.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Transcription/DictationPipeline.swift`
  - Boundary helper for transcribe -> post-process -> paste orchestration with injected dependencies for smoke/integration tests.
  - Treats the host-provided dictionary-hint flag as an audio/silence eligibility signal, then applies package-owned dictionary availability so built-in entries can participate consistently across macOS and iOS.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Transcription/DictationPromptEchoGuard.swift`
  - Post-transcription guard that suppresses likely dictionary-prompt echo output by treating repetitive prompt-like text as no-speech.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Transcription/TranscriptionPostProcessor.swift`
  - Post-transcription orchestration (email pre-normalization, dictionary correction, idiom/colon/spoken-quantity/math/list passes, laughter/spam/model-artifact/time/date/email/website/numeric grouping cleanup, then whitespace/capitalization/terminal-punctuation/all-caps finishing).
  - Merges hidden package-owned dictionary entries before matching so app-brand corrections work even when the user has not created visible dictionary entries.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Transcription/AudioParagraphChunker.swift`
  - Shared conservative silence/fallback chunking used by both Whisper and Parakeet services.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Transcription/DictationDeterministicState.swift`
  - Shared paragraph/list state value used by both iOS and macOS latest-insertion changes.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Transcription/DictationDeterministicVariantResolver.swift`
  - Selects the target state and saved or rendered source variant for paragraph/list changes.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Transcription/DictationDeterministicTextFormatter.swift`
  - Owns paragraph collapse, ordered-list line preservation, and post-rewrite layout adjustment.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Transcription/SwitchableDictationProvider.swift`
  - Small provider router that swaps the active dictation backend without changing host-side transcription call sites.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Normalization/TimeExpressionNormalizer.swift`
  - Isolated time-shape and meridiem normalization helper used by post-processing.
  - Rejects meridiem matches that continue an already colon-separated number so compact times such as `810 PM` normalize exactly once to `8:10 PM`.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Normalization/Math/MathExpressionNormalizer.swift`
  - Deterministic math phrase/operator normalization (`plus/minus/times/divided by`, exponents, percent, chained expressions) with protected URL/email/code/time/date/version spans.
  - Strips terminal punctuation only for standalone math utterances while preserving sentence punctuation.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Normalization/LaughterNormalizer.swift`
  - Dedicated laughter normalization pass (`ha ha` -> `haha`) separated from time normalization.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Normalization/CharacterSpamNormalizer.swift`
  - Collapses model character-spam runs (same non-whitespace character repeated 16+ times) to a single character.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Normalization/AsteriskCensorshipArtifactNormalizer.swift`
  - Repairs narrow provider asterisk-censorship artifacts before downstream time/email/website/capitalization finishers.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Normalization/WhitespaceNormalizer.swift`
  - Render-mode-aware whitespace normalization (`.multiline` paragraph preservation vs `.singleLineInline` flattening).
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Normalization/SentenceCapitalizationNormalizer.swift`
  - Sentence-start/text-start/line-break capitalization with email/domain safety guards.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Normalization/ColonNormalizer.swift`
  - Converts spoken/delimiter forms of `colon` into punctuation (`:`) with lightweight homophone tolerance and punctuation cleanup guards.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Normalization/TerminalPunctuationNormalizer.swift`
  - Converts eligible spoken terminal punctuation commands into `?`/`!` during post-processing and appends terminal periods for sentence-like outputs ending in formatted times when punctuation is absent.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Normalization/AllCapsOverrideNormalizer.swift`
  - Final independent override that uppercases post-processed output when Caps Lock mode is enabled.
- `Core/KeyboardMonitor.swift`
  - Global/local key monitors with left/right modifier specificity.
  - Default trigger binding is `rightOption`.
  - Publishes live Caps Lock state used to enable forced all-caps output mode.
  - Mirrors persisted trigger binding from `AppSettingsStore`; owns runtime key state only.
- `Core/Overlay/OverlayManager.swift`
  - Floating overlay lifecycle orchestration and visibility.
  - Owns recording overlay windows, generic standalone Vibe/formatting pills, recording-time selected-Vibe labels, and cycle-pill window reuse/handoff.
- `Core/Overlay/AudioIndicatorDriver.swift`
  - Generic audio-indicator driver for overlay/logo timing.
  - Owns smoothing, stale-sample handling, phase progression, and published timeline state.
  - Keeps reusable indicator types neutral (`AudioIndicatorPhase`, `AudioIndicatorSignalState`, `AudioIndicatorSample`, `AudioIndicatorTimelineState`) and non-branded.
- `Core/Overlay/OverlayMotionController.swift`
  - Fling/reset motion sequencing, timers/work items, and programmatic motion guards.
- `Core/Overlay/OverlayScreenPersistence.swift`
  - Per-display persistence using preferred-display key + origins-by-display map plus legacy migration.
- `Core/Overlay/OverlayPanel.swift`
  - NSPanel event capture for drag velocity sampling and double-click reset trigger.
- `Core/Overlay/OverlayFlingPhysics.swift`
  - Pure fling impact/reflection/duration helpers used by motion control.
- `Core/Overlay/OverlayTypes.swift`
  - Shared neutral fling-impact models used across overlay physics and motion orchestration.
- `Core/AudioDeviceManager.swift`
  - Microphone discovery and selection policy.
  - Uses `AppSettingsStore.selectedMicrophoneUID` for persisted selection.
- `Core/ModelDownloader/ModelDownloader.swift`
  - Model-aware macOS downloader and install-state owner for `Whisper Base` and `Parakeet TDT v3`.
  - Owns one active download at a time, per-model state publication, and post-install preparation hooks.
- `Core/ModelDownloader/DictationModelCatalog.swift`
  - Source of truth for model IDs, install layouts, remote artifact metadata, and progress byte accounting.
- `Core/ModelDownloader/DictationModelInstallManifest.swift`
  - Decodable manifest model used by strict staged-install validation for manifest-backed providers.
- `Core/ModelDownloader/ModelDownloadTransport.swift`
  - Small transport/progress abstractions used to keep downloader execution and tests isolated from direct `URLSession` coupling.
- `Core/ModelDownloader/InstalledDictationModelLocator.swift`
  - Resolves rooted install locations, performs legacy Whisper migration, and separates fast readiness checks from strict manifest-backed validation.
- `Core/ModelDownloader/ModelDownloader+DownloadLifecycle.swift`
  - Owns URLSession delegate callbacks, staged promotion, strict post-install validation, and per-download completion sequencing.
- `Core/ModelDownloader/ModelDownloader+Validation.swift`
  - Validates legacy Whisper installs and strict manifest-backed subdirectory installs before marking models available.
- `Core/Audio/AudioRecorder.swift`
  - Audio-recorder state holder and public orchestration entrypoints (`startRecording`, `stopRecording`).
- `Core/Audio/AudioRecorder+Session.swift`
  - Capture session/device lifecycle setup and teardown.
- `Core/Audio/AudioRecorder+Streaming.swift`
  - Live sample conversion/downsampling, frame buffering, and quiet/dead/active waveform state updates.
- `Core/Audio/AudioRecorder+PostProcessing.swift`
  - Stop-time gap removal, normalization, capture classification, and final output frame selection.
- `Core/Audio/AudioRecorder+Thresholds.swift`
  - Input-volume-based threshold profile calibration and CoreAudio scalar lookup helpers.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Audio/AudioCaptureClassification.swift`
  - Centralized per-capture classification (absolute silence, long true silence, likely-silence rejection).
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Audio/AudioSilencePolicy.swift`
  - Shared thresholds/rules for low-confidence capture rejection and long true-silence detection.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Audio/AudioSignalMetrics.swift`
  - Pure signal metrics (RMS, peak, true-silence window ratio) used by capture classification.

### Service Layer (`Core/Services` + `Packages/KeyVoxCore/Sources/KeyVoxCore/Services`)

- `Core/Services/AppUpdateService.swift`
  - Fetches the latest GitHub release from the resolved feed, applies session snooze rules, and builds the initial update prompt.
  - Keeps automatic prompt policy separate from the install pipeline.
  - Publishes initial automatic-check completion and current-version update availability so cold-launch UI can wait behind available updates.
- `Core/Services/AppUpdateLogic.swift`
  - Pure update release parsing, host allowlist checks, version normalization/comparison, and asset classification.
- `Core/Services/UpdateFeedConfig.swift`
  - Defines the tracked GitHub release feed plus the optional local override resolver used by update checks.
- `Core/Services/UpdatePromptPresenting.swift`
  - Small UI presentation seam used so update-check behavior stays testable and decoupled from prompt-window ownership.
- `Core/Services/AppProcessTerminator.swift`
  - Centralized immediate-termination helper used only after updater install handoff or self-move relaunch handoff has been confirmed.
- `Core/Services/Paste/PasteService.swift`
  - Host paste orchestrator that snapshots the clipboard, attempts Accessibility insertion first, coordinates menu fallback second, and restores or recovers clipboard state afterward.
- `Core/Services/Paste/Accessibility/*`
  - Focused AX inspection/live-session/injection helpers plus exact-target authorization for direct insertion and latest-insertion replacement.
- `Core/Services/Paste/MenuFallback/*`
  - Menu-driven paste execution, scanning, verification, and warmup/fallback coordination.
- `Core/Services/Paste/Clipboard/*`
  - Clipboard snapshot and failure-recovery helpers that preserve clipboard fidelity during paste attempts.
- `Core/Services/Paste/Heuristics/*`
  - Leading-capitalization, spacing, and dictionary-casing helpers that keep insertion behavior deterministic across targets.
- `Core/Services/Paste/Pipeline/*`
  - Shared paste execution models and policy helpers used to keep decision logic pure and testable.
- `Core/Services/AppUpdate/AppReleaseInfo.swift`
  - Canonical updater release and manifest metadata models.
- `Core/Services/AppUpdate/AppUpdateCoordinator.swift`
  - UI-facing updater state machine for release refresh, download, verification, install handoff, and post-update notice state.
- `Core/Services/AppUpdate/AppUpdateState.swift`
  - Canonical updater state/error modeling shared by the coordinator and updater views.
- `Core/Services/AppUpdate/AppUpdateManifestLoader.swift`
  - Downloads and decodes the manifest asset referenced by the selected release.
- `Core/Services/AppUpdate/AppUpdateDownloadService.swift`
  - URLSession-based zip download orchestration and staged file delivery.
- `Core/Services/AppUpdate/AppUpdateDownloadDelegate.swift`
  - Download delegate bridge for progress callbacks and completion handling.
- `Core/Services/AppUpdate/AppUpdateChecksumVerifier.swift`
  - SHA-256 verification for downloaded updater archives.
- `Core/Services/AppUpdate/AppUpdateArchiveExtractor.swift`
  - Zip extraction into updater-managed staging directories.
- `Core/Services/AppUpdate/AppUpdateBundleVerifier.swift`
  - Bundle structure, bundle identifier/version, codesign, Team ID, and Gatekeeper verification for staged update apps.
- `Core/Services/AppUpdate/AppUpdateInstallLauncher.swift`
  - Launches `Resources/updater.sh`, stages post-update notice state, and terminates the app only after install handoff is confirmed.
- `Core/Services/AppUpdate/AppUpdateApplicationsPrereflight.swift`
  - `/Applications` prerequisite handling, including self-copy-and-relaunch before resuming install.
- `Core/Services/AppUpdate/AppUpdateLaunchNoticeService.swift`
  - Launch-time resolution of the one-time “updated” notice after successful installs.
- `Core/Services/AppUpdate/AppUpdateCleanupService.swift`
  - Startup cleanup for updater staging artifacts and deferred backup removal.
- `Core/Services/AppUpdate/AppUpdatePaths.swift`
  - Centralized release staging, zip, extract, and cleanup path construction.

- `Packages/KeyVoxCore/Sources/KeyVoxCore/Services/Whisper/WhisperService.swift`
  - Loads the rooted Whisper model path from Application Support and runs inference.
  - Defaults to automatic language detection and uses the shared paragraph chunker/post-processing contracts.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Services/Whisper/WhisperService+Language.swift`
  - Validates app selections against `WhisperBaseLanguageCatalog` and applies the configured identifier to the loaded Whisper parameters.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Services/Whisper/WhisperService+ModelLifecycle.swift`
  - Isolates model lifecycle helpers (`warmup`, `unloadModel`, model-path resolution), initializes model parameters with the configured language, and creates/releases the package-owned VAD detector with the Whisper model lifecycle.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Services/Whisper/WhisperService+TranscriptionCore.swift`
  - Owns whole-capture VAD gating plus chunk transcription flow, applies the current language before a request begins, and handles retry selection, whitespace normalization, and debug segment logging.
  - Rejects captures with no detected speech before decoding, preserves the complete original capture when speech exists, and falls back to decoder safeguards when VAD analysis is unavailable.
- `Packages/KeyVoxWhisper/Sources/KeyVoxWhisper/WhisperVoiceActivityDetector.swift`
  - Actor-isolated wrapper around whisper.cpp's VAD context, probability analysis, and speech-segment extraction.
  - Loads the package-owned `Resources/ggml-silero-v5.1.2.bin` model so platform apps do not duplicate VAD assets or policy.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Transcription/DictationLanguage.swift`
  - Shared stable language-code value with an explicit Auto Detect identifier.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Transcription/DictationLanguageDisplayNameFormatter.swift`
  - Produces localized language display names for platform settings surfaces.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Transcription/WhisperBaseLanguageCatalog.swift`
  - Derives the Whisper Base picker options from `KeyVoxWhisper.WhisperLanguage` so platform apps do not duplicate language lists.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Services/Parakeet/ParakeetService.swift`
  - Parakeet provider service root that owns request state and delegates lifecycle/transcription behavior across split extension files.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Services/Parakeet/ParakeetService+ModelLifecycle.swift`
  - Owns model warmup/preload/unload behavior and Parakeet instance management.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Services/Parakeet/ParakeetService+TranscriptionCore.swift`
  - Owns chunk transcription flow, prompt assignment, whitespace shaping, and provider-specific result handling.
- `Packages/KeyVoxParakeet/Sources/KeyVoxParakeet/`
  - Low-level Parakeet Core ML runtime package: model loading, vocabulary/runtime/backend management, decode loop, and public result models.

### Post-Processing (`Packages/KeyVoxCore/Transcription` + `Packages/KeyVoxCore/Normalization` + `Packages/KeyVoxCore/Language` + `Packages/KeyVoxCore/Lists`)

- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/DictionaryMatcher.swift`
  - Orchestrates dictionary matching flow and delegates tokenizer/candidate/split-join/overlap helpers.
  - Compiles built-in aliases to the same canonical replacement entry, so observed variants of the app/product name normalize through the same deterministic matcher path as user dictionary entries.
  - Maintains a domain-indexed email dictionary for spoken/literal email recovery.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/DictionaryBuiltInEntries.swift`
  - Package-owned hidden dictionary entries for app/product naming, currently `KeyVox` and `KeyVox Speak`, plus supported observed aliases such as `Kivok`, `Kivox`, and `Keyvox`.
  - Merges built-ins with user entries while suppressing duplicate canonical phrases, keeping the visible/persisted user dictionary unchanged.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/DictionaryHintPromptBuilder.swift`
  - Builds provider prompt text from visible user entries plus package-owned canonical built-ins, excluding alias spellings from the prompt surface.
  - De-dupes canonical phrases so a user-owned `KeyVox` entry does not feed duplicate prompt or matcher input.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Normalization/EmailAddressNormalizer.swift`
  - Shared non-dictionary email literal cleanup (casing, punctuation spacing, sentence-boundary repair, ellipsis normalization).
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Normalization/WebsiteNormalizer.swift`
  - Shared website/domain helper for compact-domain detection, leading-domain normalization, and standalone website checks.
  - Used by list marker parsing/detection and dictionary email normalization to keep website rules centralized.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Normalization/Math/`
  - Shared deterministic math normalizer split across core, pattern, protected-range, exponent, and spelled-out-operand helpers.
  - Converts high-confidence spoken math into symbol form before list parsing while preserving non-math structures and protected spans.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Normalization/ColonNormalizer.swift`
  - Provides spoken-colon normalization before list detection to stabilize `label colon value` phrasing into deterministic punctuation.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Normalization/CharacterSpamNormalizer.swift`
  - A model-noise guard that trims extreme repeated-character runs before downstream punctuation/capitalization finishing passes.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Normalization/AsteriskCensorshipArtifactNormalizer.swift`
  - A targeted provider-artifact guard that restores observed leading-f asterisk censorship patterns before downstream cleanup.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Normalization/ThousandsGroupingNormalizer.swift`
  - Normalizes spoken quantity forms before math parsing and adds grouping separators to quantity-style four-digit numerals later while preserving year-like references and protected date/version/phone shapes.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Normalization/DateNormalizer.swift`
  - Late cleanup pass for spoken date forms after time normalization and before final email/website/numeric finishing.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Normalization/TerminalPunctuationNormalizer.swift`
  - Handles spoken terminal punctuation and terminal-time punctuation completion near the end of post-processing.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Normalization/AllCapsOverrideNormalizer.swift`
  - Final-stage output override that forces uppercase while preserving prior list/email/website/time formatting.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/Email/DictionaryEmailEntry.swift`
  - Canonical email entry model and sanitizer for dictionary phrases that are valid email addresses.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/Email/DictionaryMatcher+EmailDomainResolution.swift`
  - Domain candidate extraction and fuzzy-domain disambiguation helpers for dictionary email matching.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/Email/DictionaryMatcher+EmailNormalization.swift`
  - Detects spoken (`name at domain`), compact (`nameatdomain`), and literal email candidates and rewrites them using dictionary-backed resolution.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/Email/DictionaryMatcher+EmailParsing.swift`
  - Shared local/domain normalization and attached-list-marker parsing helpers used by email normalization/resolution.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/Email/DictionaryMatcher+EmailResolution.swift`
  - Resolves spoken/literal/standalone dictionary email candidates and local-part ambiguity via deterministic guards.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/DictionaryMatcher+Tokenizer.swift`
  - Token extraction and range construction helpers used by matcher runtime.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/Evaluation/DictionaryMatcher+StandardEvaluation.swift`
  - Standard 1-4 token candidate scoring with thresholds, ambiguity, common-word, and short-token guards.
  - Applies contextual gating for common-word-like replacements to avoid unsupported prose substitutions.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/Evaluation/DictionaryMatcher+MergedTokenEvaluation.swift`
  - Merged-token recovery path for compact spoken forms that collapse multi-token dictionary entries.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/Evaluation/DictionaryMatcher+ThreeTokenEvaluation.swift`
  - Three-token-specific recovery paths (middle-initial and compressed-tail patterns).
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/Evaluation/Helpers/DictionaryMatcher+EvaluationStylizedHelpers.swift`
  - Provides stylized-token evidence and fallback-phonetic helpers used by standard/split-join evaluators.
  - Treats sentence punctuation as a boundary for adjacent-titlecase safety checks, preserving protection for phrase-like names without blocking app-brand aliases followed by a new sentence.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/Evaluation/Helpers/DictionaryMatcher+EvaluationSuffixHelpers.swift`
  - Implements possessive/plural form generation and suffix inference helpers used by evaluators.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/Evaluation/Helpers/DictionaryMatcher+EvaluationEvidenceHelpers.swift`
  - Contains split-tail consumption and token-alignment evidence helpers for deterministic scoring boosts.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/Evaluation/SplitJoin/DictionaryMatcher+SplitJoinScoring.swift`
  - Split-token to single-entry scoring and acceptance path with plural/possessive handling.
  - Promotes plural-tail split joins to possessive output when guarded possessive context is present.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/Evaluation/SplitJoin/DictionaryMatcher+SplitJoinForms.swift`
  - Split-join observed-form generation and replacement-suffix normalization helpers.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/Evaluation/SplitJoin/DictionaryMatcher+SplitJoinGuards.swift`
  - Split-join guard heuristics (domain-shape suppression, anchoring checks, possessive-sound inference).
  - Requires noun-following context for possessive split-join inference to limit false positives.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/DictionaryMatcher+OverlapResolver.swift`
  - Deterministic overlap pruning with confidence-first ordering.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/DictionaryTextNormalization.swift`
  - Shared phrase/token normalization used by dictionary matching and pronunciation lexicon loading.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/DictionaryStore.swift`
  - Persistent custom dictionary storage, validation, and backup recovery.
  - Exposes the shared dictionary hint prompt builder while keeping built-in entries out of persisted user storage and settings UI.
  - Exposes warning-clear helper for settings lifecycle cleanup.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/DictionaryEntry.swift`
  - Canonical dictionary entry model.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/PronunciationLexicon.swift`
  - Loads bundled pronunciation signatures and curated common-word safety list from `Packages/KeyVoxCore/Sources/KeyVoxCore/Resources/Pronunciation/`.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/PhoneticEncoder.swift`
  - Uses lexicon lookups first, then deterministic fallback encoding for unknown words.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/ReplacementScorer.swift`
  - Centralizes score weights, thresholds, ambiguity margin, and similarity math.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Lists/ListFormattingEngine.swift`
  - Applies conservative numeric list formatting only when reliable list patterns are detected.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Lists/ListPatternDetector.swift`
  - Detects monotonic list markers (digits + locale-aware spoken number cues) with false-positive guards.
  - Splits leading/list/trailing segments to preserve non-list prose around list blocks.
  - Delegates leading domain-token lowercasing to `WebsiteNormalizer`.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Lists/ListPatternMarkerParser.swift`
  - Parses spoken/typed marker tokens into canonical marker metadata used by list detection.
  - Handles markers attached to domains, spoken `to` as list marker 2 in email-list shapes, and time-component false-positive suppression.
  - Uses `WebsiteNormalizer` for domain-token heuristics to avoid duplicated website regex logic.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Lists/ListPatternRunSelector.swift`
  - Selects best monotonic list run and enforces confidence guards before formatting.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Lists/ListPatternTrailingSplitter.swift`
  - Splits trailing prose off list items while preserving valid list item content.
  - Uses scored deterministic split candidates with email-boundary-aware preference.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Lists/ListPatternMarker.swift`
  - Shared marker model for parser/detector/run-selection helpers.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Lists/ListRenderer.swift`
  - Renders detected lists as multiline (`1. ...`) or single-line inline (`1. ...; 2. ...`) based on target context.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Lists/ListFormattingTypes.swift`
  - Shared types for list render mode and detected list segments/items.
- `Tools/Pronunciation/build_lexicon.sh`
  - Maintainer pipeline for pinned-source regeneration of lexicon/common-word resources.
  - Enforces row targets and writes package-owned outputs under `Packages/KeyVoxCore/Sources/KeyVoxCore/Resources/Pronunciation/`, including `sources.lock.json`.

### Update UI (`Views/UpdatePromptOverlay.swift` + `Views/Updates` + `Views/Components`)

- `Views/Components/AppActionButton.swift`
  - Shared capsule-styled primary/secondary/destructive button used across updater, settings prompt, and onboarding confirmation surfaces.
- `Views/Components/UIComponents.swift`
  - Shared app typography, blur wrapper, and generic progress presentation primitives used across macOS surfaces.
- `Views/UpdatePromptOverlay.swift`
  - Lightweight update prompt shown before entering the dedicated updater window.
  - Owns prompt-window centering through `UpdatePromptManager`.
- `Views/Updates/UpdateWindowView.swift`
  - Dedicated updater window shell with dynamic height reporting and explicit drag region.
- `Views/Updates/UpdateHeaderCard.swift`
  - Current version / target version / state summary card for the updater window.
- `Views/Updates/UpdateProgressCard.swift`
  - Download/install progress card and byte-count presentation.
- `Views/Updates/UpdateReleaseNotesCard.swift`
  - Scrollable release-notes card used when the fetched release exposes summary/body text.
- `Views/Updates/UpdateApplicationsRequirementCard.swift`
  - `/Applications` prerequisite card shown before self-move and relaunch.
- `Views/Updates/UpdateFailureCard.swift`
  - Failure presentation card for updater pipeline errors.
- `Views/Updates/PostUpdateNoticeView.swift`
  - Final post-update notice window shown after successful installs.
- `Views/Components/AppUpdateProgressBar.swift`
  - Updater-specific progress bar component used inside updater progress UI.
- `Views/Components/SettingsLastTranscriptionCard.swift`
  - Home-tab card that surfaces the most recent successful transcription persisted by the host app.

### Release Tooling (`build/`)

- `build/build_release.sh`
  - Maintainer packaging helper for exported release apps.
  - Verifies a signed/notarized exported `.app`, creates `Release/KeyVox-<version>.zip`, and writes `Release/keyvox-update-manifest.json`.
- `build/build_dmg.sh`
  - Maintainer DMG packaging script for manual-install distribution artifacts.
- `Tools/Pronunciation/train_g2p.sh`
  - Build-time Phonetisaurus/OpenFst G2P generation for OOV pronunciation candidates used when regenerating package-owned pronunciation resources.
- `Tools/Pronunciation/verify_licenses.sh`
  - Enforces allowed-source and attribution policy before distribution.
- `Tools/Pronunciation/benchmarks/run_quality_gates.sh`
  - Enforces coverage/hit-rate/false-positive/latency thresholds using benchmark fixtures.
- `Tools/Pronunciation/benchmarks/evaluate_matcher.swift`
  - Thin benchmark CLI entrypoint (`@main`) that delegates to modular evaluator helpers.
- `Tools/Pronunciation/benchmarks/evaluate/EvaluateMatcherCore.swift`
  - Offline matcher core used by pronunciation benchmark quality evaluation.
- `Tools/Pronunciation/benchmarks/evaluate/EvaluateBenchmarkIO.swift`
  - Benchmark fixture loading and shared parsing/stat helper functions.
- `Tools/Pronunciation/benchmarks/evaluate/EvaluateBenchmarkRunner.swift`
  - End-to-end metric computation and main execution wrapper.
- `Tools/ExploreAX.swift`
  - Single-app (frontmost) Accessibility tree and candidate diagnostics for paste verification troubleshooting.
- `Tools/ExploreAXApps.swift`
  - Multi-app Accessibility scanner for comparing AX candidate quality across running apps.
- `Tools/ObservePasteAXNotifications.swift`
  - Captures AX notifications for focused targets during paste debugging.
- `Tools/ExplorePasteSignal.sh`
  - Repeatable shell harness for probing paste signal behavior and AX fallback timing.
- `Tools/README.md`
  - Maintainer/contributor guide for all scripts in `Tools/`.
- `Core/Services/Paste/PasteService.swift`
  - Orchestrates paste pipeline (dictionary-aware leading-cap normalization, smart spacing, AX injection, menu fallback, recovery, clipboard restore).
  - Determines preferred list render mode from focused AX role for single-line graceful fallback.
- `Core/Services/Paste/Clipboard/PasteFailureRecoveryCoordinator.swift`
  - Manages active paste-failure recovery session lifecycle, timers, and Command-V detection.
- `Core/Services/Paste/Accessibility/PasteAXInspector.swift`
  - Shared AX inspection helpers used by spacing, injector, and fallback verification.
- `Core/Services/Paste/Accessibility/PasteAccessibilityInjector.swift`
  - Direct AX selected-text insertion path with outcome classification.
  - Routes self-targeted AX writes through a bounded main-thread hop so local AppKit text fields can be updated without an unbounded cross-thread `main.sync`.
- `Core/Services/Paste/Accessibility/PasteUntouchedInsertionAuthorizer.swift`
  - Owns the current latest-insertion authorization lifecycle and invalidates it whenever the live app or AX context no longer matches.
  - Advances authorization after successful replacement only when the replacement remains in the original PID, element, and start location.
- `Core/Services/Paste/Accessibility/PasteUntouchedInsertionToken.swift`
  - Persists the exact PID, AX element, target range, and selection snapshot authorized for latest-insertion replacement.
  - Invalidates replacement eligibility when the current app, focus target, replacement range, or selection no longer matches.
- `Core/Services/Paste/MenuFallback/PasteMenuFallbackExecutor.swift`
  - Orchestrates menu fallback execution and verification decisions.
  - Coordinates AX snapshot verification, undo-state fallback checks, and live AX session verification.
- `Core/Services/Paste/MenuFallback/PasteMenuFallbackCoordinator.swift`
  - Coordinates menu-fallback decision flow from `PasteService` and computes fallback result flags.
  - Owns first-success warmup suppression bookkeeping and menu fallback transport normalization.
  - Binds live AX value-change verification to runtime frontmost PID with captured target fallback.
- `Core/Services/Paste/MenuFallback/PasteMenuScanner.swift`
  - Encapsulates menu traversal/discovery for Paste and Undo menu items.
  - Keeps AX identifier/shortcut/title matching and menu-item attribute readers.
- `Core/Services/Paste/Accessibility/PasteAXLiveSession.swift`
  - Encapsulates AXObserver lifecycle used for live mutation verification during menu fallback.
- `Core/Services/Paste/Clipboard/PasteClipboardSnapshot.swift`
  - Full-fidelity clipboard snapshot capture/restore utilities.
- `Core/Services/Paste/Composition/PasteCapitalizationCoordinator.swift`
  - Resolves macOS Accessibility and recent-insertion fallback context before delegating leading-capitalization policy to `KeyVoxTextComposition`.
  - Supplies the Mac-specific dictionary casing preservation decision without owning shared capitalization rules.
- `Core/Services/Paste/Heuristics/PasteDictionaryCasingStore.swift`
  - Reads the persisted macOS dictionary snapshot to preserve exact leading phrase casing during paste-time normalization.
- `Core/Services/Paste/Composition/PasteSpacingCoordinator.swift`
  - Resolves selection, caret, Accessibility, and recent-insertion fallback context before delegating leading-separator policy to `KeyVoxTextComposition`.
- `Packages/KeyVoxTextComposition/Sources/KeyVoxTextComposition/`
  - Owns deterministic capitalization, spacing, quotation-mark classification, and sentence-boundary policy shared by macOS and iOS.
  - Accepts platform-neutral adjacent-text context and has no dependency on Accessibility, UIKit document proxies, clipboards, or insertion transports.
- `Core/Services/Paste/Pipeline/PastePolicies.swift`
  - Static policy helpers for list render mode and failure-recovery decisions.
- `Core/Services/Paste/Pipeline/PasteModels.swift`
  - Shared internal model/enums for paste pipeline collaborators.
- `Core/Services/UpdateFeedConfig.swift`
  - Centralized update feed owner/repo defaults.
  - Supports optional local override file at `~/Library/Application Support/KeyVox/update-feed.override.json`.
- `Core/Services/AppUpdateLogic.swift`
  - Pure helpers for release mapping, host allowlist checks, version normalization, and version comparison.
- `Core/Services/AppUpdateService.swift`
  - Fetches latest release metadata from GitHub Releases API.
  - Endpoint is composed from resolved update feed config.
  - Maps `tag_name` to app version comparison and builds a summarized release-notes preview from the release body.
  - Prefers `.dmg` `browser_download_url`, then falls back to release `html_url`.
  - Supports timer-based checks and manual checks.
  - Treats network/decoding failures as no-update for auto checks; manual checks surface an "Updates Temporarily Unavailable" prompt.
  - Triggers `UpdatePromptOverlay` through an injected prompt-presenting seam.
- `Core/Services/UpdatePromptPresenting.swift`
  - Main-actor protocol seam used to test update prompt flow without UI window dependencies.
- `Tools/UpdateFeed/configure_local_feed.sh`
  - Maintainer helper for setting, clearing, and showing the local update feed override file.
- `Tools/UpdateFeed/update-feed.override.example.json`
  - Template for local override JSON shape (the active override lives in Application Support, not in the repo).
- `Tools/Quality/check_core_coverage.sh`
  - Enforces allowlisted core-file coverage threshold from `.xcresult` using `xccov`.
- `Tools/Quality/coverage_summary.sh`
  - Emits markdown coverage summaries for CI job step output.

### UI Layer

- `Views/StatusMenuView.swift`
  - Menu bar UI, status rendering, warning actions.
  - Routes model-missing actions to the Settings tab and triggers model download.
- `Views/OnboardingView.swift`
  - First-run setup for permissions and model download.
  - Accessibility and microphone authorization hooks are delegated to `WindowManager` callbacks.
- `Views/FirstDictation/*`
  - Optional first-dictation practice surfaces shown only after setup onboarding, with skip and completion reported back to `WindowManager+FirstDictationOnboarding`.
- `Views/Settings/*`
  - Split settings tabs and reusable settings components for Home, Dictionary, Style, and Settings.
  - Shared app-window styling is sourced from `Views/Components/MacAppTheme.swift`.
- `Views/Components/SettingsLastTranscriptionCard.swift`
  - Home-tab last-transcription card with persisted text display, bordered inner container, and copy action.
- `Views/Settings/SettingsView+Home.swift`
  - Home tab container with Words per week and last transcription cards.
- `Views/Settings/SettingsView+Dictionary.swift`
  - Dictionary tab container and English-only support footer text.
- `Views/Settings/SettingsView+DictionarySection.swift`
  - Dictionary management UI plus A-Z/Recently Added list sort toggle (hidden when no entries exist).
  - Dictionary description includes custom words, email addresses, and short phrases.
  - Primary add action is surfaced as a floating corner button from `Views/Components/DictionaryFloatingAddButton.swift`.
- `Views/Settings/SettingsView+DictationModels.swift`
  - Dictation provider selection plus install/remove/progress/error UI for model-backed providers, with the attached language row composed below the model controls.
- `Views/Settings/DictationLanguageSection.swift`
  - Standard Mac language dropdown for Whisper and disabled Auto Detect presentation with FAQ guidance for Parakeet.
- `Views/Settings/SettingsView+Style.swift`
  - Style tab with standalone Lists and Paragraphs cards backed by persisted `listFormattingEnabled` and `autoParagraphsEnabled`.
  - Always composes the KeyVox Vibes style card and drives style-picker availability from the Mac Vibes local install/access matrix.
- `Views/Settings/SettingsVibesCard.swift`
  - Style-tab KeyVox Vibes card with install/readiness status, download/repair/progress controls, the ready-state picker, and a trigger-key usage tip.
  - Copy lives in `SettingsVibesCardCopy`.
- `Views/Settings/SettingsVibesExamplesSection.swift`
  - Expandable style examples section owned by the Style-tab Vibes card.
  - Uses animated height measurement, white example text, yellow headers/chevron, and full-row selection when enabled.
  - Copy lives in `SettingsVibesExamplesCopy`.
- `Views/Settings/SettingsView+More.swift`
  - Settings tab includes Trigger Key, audio controls, system controls, developer cards, and footer actions.
  - System controls include Launch at Login and the hide-Dock-icon toggle on macOS versions where KeyVox normally has a Dock icon.
  - System section composes the Vibes AI install-management card separately from the Style-tab Vibes card.
- `Views/Settings/SettingsVibesAIInstallCard.swift`
  - System-tab Vibes AI install-management card for download, repair, delete, progress/error display, and the Vibes trigger-key interactions toggle.
  - Copy lives in `SettingsVibesAIInstallCardCopy`.
- `Views/Warnings/*`
  - Warning UI and panel orchestration for both system warnings and paste-failure recovery.
- `Views/Warnings/WarningManager.swift`
  - Owns warning panel lifecycle and paste-failure recovery panel presentation/update/dismiss.
  - Adds hover-aware auto-dismiss scheduling and animated slide/fade exit transitions.
- `Views/Warnings/PasteFailureRecoveryOverlayView.swift`
  - Paste-failure recovery view with `⌘ Cmd + V` guidance and progress bar.
- `Views/UpdatePromptOverlay.swift`
  - In-app update prompt UI.
  - Shares the standard macOS app-window theme surface through `MacAppTheme`.

## Change Tracking

- `CODEMAP.md` documents the current structure/ownership map only.
- Detailed change history should live in Git commits/PRs and release notes, not as hand-maintained per-file delta blocks.

## Persistence & Defaults

- Centralized persisted preferences owner: `App/AppSettingsStore.swift`
  - trigger binding, auto paragraphs toggle, list formatting toggle, sound enable/volume, selected microphone UID, selected Vibe, Vibes trigger-key interactions, hide Dock icon preference, onboarding completion, first-dictation completed/skipped flags, update prompt timestamps, active dictation provider, device-local Whisper language
- Shared app-owned runtime registry: `App/AppServiceRegistry.swift`
  - retains the dedicated weekly stats store/sync subsystem separately from the general iCloud settings coordinator
- Preference key catalog: `App/UserDefaultsKeys.swift`
- Paragraph style preference key: `KeyVox.AutoParagraphsEnabled`
- List formatting preference key: `KeyVox.ListFormattingEnabled`
- Selected Vibe preference key: `KeyVox.SelectedVibe`
- Vibes trigger-key interactions preference key: `KeyVox.VibesTriggerKeyInteractionsEnabled` (defaults to enabled)
- Hide Dock icon preference key: `KeyVox.HideDockIconWhenAllWindowsClosed` (defaults to disabled)
- Audio-device initialization marker: `KeyVox.HasInitializedMicrophoneDefault` (owned in `Core/AudioDeviceManager.swift`)
- Onboarding completion key: `KeyVox.HasCompletedOnboarding`
- First-dictation outcome keys:
  - `KeyVox.App.HasCompletedFirstDictation`
  - `KeyVox.App.HasSkippedFirstDictation`
- Mac Vibes intro seen key: `KeyVox.App.HasSeenKeyVoxVibesIntro`
- Last transcription cache key: `KeyVox.App.LastTranscription`
- Active provider key: `KeyVox.App.ActiveDictationProvider`
- Whisper language key: `KeyVox.App.WhisperDictationLanguage`
- Update prompt and handoff keys:
  - `KeyVox.App.UpdateAlertLastShown`
  - `KeyVox.App.UpdateAlertSnoozedUntil`
  - `KeyVox.App.PendingUpdatedVersion`
  - `KeyVox.App.PendingUpdatedVersionPreferredDisplayKey`
  - `KeyVox.App.LastAcknowledgedUpdatedVersion`
  - `KeyVox.App.ResumeUpdaterAfterApplicationsMove`
  - `KeyVox.App.ResumeUpdaterPreferredDisplayKey`
- Weekly word stats owner: `App/WeeklyWordStatsStore.swift`
  - persists a stable installation identifier plus the current-week usage snapshot and local rollover behavior
- Weekly word stats iCloud sync: `App/iCloud/WeeklyWordStatsCloudSync.swift`
  - syncs the weekly stats payload through iCloud KVS and merges same-week per-device totals deterministically
- Weekly word stats local keys:
  - `KeyVox.App.WeeklyWordStatsPayload`
  - `KeyVox.App.WeeklyWordStatsInstallationID`
- Overlay placement:
  - preferred display key: `KeyVox.RecordingOverlayPreferredDisplayKey`
  - origins by display map: `KeyVox.RecordingOverlayOriginsByDisplay`
  - legacy read-only migration key: `KeyVox.RecordingOverlayOrigin`
- iCloud per-setting modified-at keys:
  - `KeyVox.iCloud.DictionaryLastModifiedAt`
  - `KeyVox.iCloud.TriggerBindingLastModifiedAt`
  - `KeyVox.iCloud.AutoParagraphsLastModifiedAt`
  - `KeyVox.iCloud.ListFormattingLastModifiedAt`

## System / Build Facts

- Compatibility target: **macOS Ventura (13.5) and newer**
- Parakeet provider availability: **runtime-gated to macOS 14 and newer**
- Mac Vibes local rewrite GPU policy: **macOS Sequoia (15) and newer may use Metal/GPU offload; macOS Ventura/Sonoma (13.5-14.x) is CPU-only**
- App type: menu bar app (`MenuBarExtra`)
- Local model artifact name: `ggml-base.bin`
- Local Vibes AI artifact name: `qwen2.5-0.5b-instruct-q4_k_m.gguf`
- Local packages:
  - `Packages/KeyVoxCore`: extracted shared engine, packaged resources, and reusable tests
  - `Packages/KeyVoxWhisper`: local `whisper.cpp` wrapper package
  - `Packages/KeyVoxParakeet`: local Parakeet Core ML runtime package
  - `Packages/KeyVoxLocalInference`: local llama.cpp-backed rewrite inference package
  - `Packages/KeyVoxStyleRewrite`: shared style rewrite request/transform contracts and deterministic output repair
  - `Packages/KeyVoxVibesAdapters`: bundled Vibes LoRA adapter resources
