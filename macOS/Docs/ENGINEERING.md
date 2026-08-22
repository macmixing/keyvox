# Engineering Notes

This document contains implementation and maintainer-focused details that are intentionally kept out of the top-level README.

**Last Updated: 2026-08-21**

## Design Philosophy

KeyVox follows a strict engineering contract:

- No silent data loss.
- No hidden telemetry.
- No background collection of user speech.
- No surprise behavior.

User data is treated as sacred.  
If the clipboard is modified, it must be restored.  
If behavior changes based on a setting, it must be explicit and predictable.  
If something could fail, it must fail safely.

Paste failures can cause user-visible data loss. When paste completion cannot be verified, KeyVox must warn the user instead of silently assuming success. Prefer generic, observable verification fixes over hard-coded bundle ID policy. Bundle-specific paste trust rules are reserved for cases where the target app architecture guarantees menu paste into an available text target and must be approved intentionally.

KeyVox is designed to be local-first, transparent, and deterministic.  
Convenience must never come at the cost of trust.

## Architecture Overview

KeyVox is organized by responsibility:

- `App/`: App lifecycle plus persisted app-owned state, runtime flags, window managers, and registries (`KeyVoxApp`, `AppSettingsStore`, `MacRuntimeFlags`, `AppServiceRegistry`, `DockIconVisibilityController`, `WeeklyWordStatsStore`).
- `App/iCloud/`: Dedicated iCloud KVS sync helpers and payloads. `KeyVoxiCloudSyncCoordinator` owns dictionary plus trigger/paragraph/list-formatting convergence, `WeeklyWordStatsCloudSync` owns weekly usage convergence separately, `KeyVoxiCloudKeys` owns every KVS key, and `KeyVoxiCloudPayloads` owns the dictionary and weekly-stats payload shapes.
- `Core/Transcription/`: Runtime state machine and macOS host-side transcription orchestration split across `TranscriptionManager.swift` plus focused extensions for bindings, recording sessions, and overlay/debug work. The reusable transcribe -> post-process -> paste boundary remains extracted into `Packages/KeyVoxCore/Sources/KeyVoxCore/Transcription/` (`DictationPipeline`, `TranscriptionPostProcessor`, `DictationPromptEchoGuard`). The macOS host owns capture/audio eligibility for dictionary hinting, while `KeyVoxCore` owns effective dictionary availability, built-in entries, prompt content, post-processing, and prompt-echo suppression. The macOS host also persists the most recent successful transcription for Home-tab display after relaunch and publishes a per-successful-dictation revision for UI flows that must observe repeated identical dictations.
- `Core/DictationTriggerController.swift`: Trigger-key orchestration that converts keyboard press/release/escape state into recording-session commands and hands consumed trigger+L/P chords to the formatting action controller without owning transcription or replacement behavior.
- `Core/Vibes/`: Mac-owned KeyVox Vibes and latest-insertion change runtime. The Mac Vibes path uses a local GGUF rewrite model plus bundled LoRA adapters, not Foundation Models. `MacLocalRewriteModelManager` owns local model installation, `MacLocalRewriteInferenceService` owns cached local inference composition, `MacLocalStyleRewriteTextTransformer` bridges shared style rewrite requests to local inference, `MacVibesCoordinator` owns readiness-gated style resolution/prewarm/transform, `MacVibesIntroController` owns one-time intro eligibility, `MacVibesAccessMatrix` owns settings-state decisions, `MacDictationChangeController` owns latest untouched dictation Vibe and deterministic paragraph/list changes, `MacFormattingShortcutMonitor` owns safe chord interception, `MacFormattingTriggerActionController` owns formatting feedback/action orchestration, `MacVibesTriggerActionController` owns quick-tap orchestration and the Vibes trigger-key interaction toggle gate, and `MacTriggerTapClassifier` keeps single/double tap timing separate from recording orchestration.
- `Core/Audio/`: Recording, stream processing, silence classification, and threshold policy.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/` and `Packages/KeyVoxCore/Sources/KeyVoxCore/Lists/`: Deterministic dictionary correction and list parsing/rendering, with matcher evaluation strategies organized under `Packages/KeyVoxCore/Sources/KeyVoxCore/Language/Dictionary/Evaluation/` (`Helpers/`, `SplitJoin/`, and strategy files). `DictionaryMatcher+SpelledUppercaseGuard.swift` owns shared phonetic validation for uppercase dictionary sequences, while `DictionaryMatcher+ExactMultiTokenJoin.swift` owns exact three- and four-token joins into canonical single-entry replacements. Package-owned hidden dictionary entries live beside user dictionary primitives so app/product naming is corrected through the same matcher pipeline without persisting or displaying those entries as user vocabulary.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Normalization/`: Ordered pure normalization stages used by post-processing: early literal cleanup, pre-list normalization, late model-output cleanup, and final finishers. The individual passes remain small and composable, while the documented contract stays centered on stable ordering boundaries rather than every micro-pass. Shared normalization utilities (for example URL/domain/email-safe capitalization guards) also live here.
- `Packages/KeyVoxTextComposition/`: Platform-neutral policy for composing finalized dictation with adjacent editor text. It owns leading capitalization, leading spacing, quote classification, sentence-boundary rules, and adjacent terminal-punctuation decisions, but never reads Accessibility state or performs insertion.
- `Packages/KeyVoxStyleRewrite/Sources/KeyVoxStyleRewrite/OutputRepair/`: Deterministic post-model Vibes repair. `PunctuationRepair` preserves punctuation facts first, `TerminalPunctuationBoundaryRepair` preserves source-backed terminal `!` and `?!` boundaries, `AddressFactRepair` preserves source-backed address facts, `NumberEvidence` is the shared factual number evidence source used by general number repair and money repair, `NumberSeparatorEvidenceRepair` owns decimal-vs-time separator preservation, `NumberEvidenceRepair` coordinates factual number preservation, `MoneyFactRepair` owns currency-specific repair, and `APStyleNumberRepair` owns AP-style number presentation only after factual number evidence has been repaired. `StyleRewritePromptLeakGuard` falls back to the base text when generated output leaks significant prompt text.
- `Core/Services/`: Paste/injection, update/checking, and process-termination services. Paste behavior is intentionally split into `Accessibility/`, `MenuFallback/`, `Clipboard/`, `Composition/`, `Heuristics/`, and `Pipeline/` subdomains. `PasteUntouchedInsertionAuthorizer` decides whether the latest insertion may change, while `PasteUntouchedInsertionReplacer` owns exact AX target resolution, safe write strategy, verification, and caret placement. The composition coordinators resolve Mac-specific preceding/following context and delegate deterministic capitalization, spacing, and adjacent terminal-punctuation policy to `KeyVoxTextComposition`; they do not duplicate package rules. In-place updater pieces live under `AppUpdate/`, immediate process termination is centralized in `AppProcessTerminator.swift`, update feed source selection lives in `UpdateFeedConfig.swift`, and provider inference lives under `Packages/KeyVoxCore/Sources/KeyVoxCore/Services/Whisper/` and `Packages/KeyVoxCore/Sources/KeyVoxCore/Services/Parakeet/`.
- `Core/Overlay/`: Floating overlay lifecycle, persistence, motion, generic standalone-pill presentation, generic audio-indicator timing/state driving, and reusable fling-impact types.
- `Views/`: Setup onboarding, first-dictation practice, settings, warnings, and presentation-only UI composition, including the proprietary logo system renderer plus separate reusable overlay-pill components.
- `Tools/`: Maintainer scripts for pronunciation resources, diagnostics, update feed helpers, and quality gates.
- `Packages/KeyVoxCore/Sources/KeyVoxCore/Resources/Pronunciation/common-words-v1.txt`: Curated safety/policy list for common-word replacement guards; maintained with pronunciation resources as tuning data.

### macOS Theme Ownership

- `Views/Components/MacAppTheme.swift` is the shared macOS theme surface for reusable app-window styling tokens.
- `Views/Components/UIComponents.swift` is the shared macOS typography/progress/effect surface for reusable non-branded UI primitives.
- `MacAppTheme.screenBackground` is the source of truth for the standard macOS app window background (`#1A1740` equivalent).
- Reusable settings/onboarding/update/modal styling should prefer `MacAppTheme` tokens instead of reintroducing local hard-coded indigo/background stacks.
- `Views/StatusMenuView.swift` and `Views/Warnings/*` intentionally keep separate styling and should not be folded into `MacAppTheme` unless product direction changes.

File-level ownership and locations are intentionally maintained in one place: [`CODEMAP.md`](CODEMAP.md).

### Transcription Manager Ownership

- `TranscriptionManager.swift` owns shared runtime state, dependencies, pipeline composition, initialization, and teardown.
- `TranscriptionManager+Bindings.swift` owns Combine bindings from keyboard/caps-lock/model readiness into manager state, routes trigger-key events and cancellation into `DictationTriggerController`, and coordinates formatting-monitor runtime eligibility and overlay readiness.
- `TranscriptionManager+RecordingSession.swift` owns recording start/stop, formatting-chord recorder discard, transcription pipeline execution, paste insertion handoff, weekly word totals, and last-transcription persistence.
- `TranscriptionManager+OverlayAndDebug.swift` owns overlay hands-free visual updates, playback sound effects, and debug-only transformation-speed logging.
- `Core/DictationTriggerController.swift` owns trigger-key press/release handling, pending-stop behavior, deferred starts, hands-free toggles, and cancellation, and calls back into `TranscriptionManager` only for recording-session commands.

## Platform Compatibility

- Supported macOS range: macOS 13.5 and newer.
- KeyVox uses accessory activation policy on Ventura/Sonoma and early Sequoia builds (`< 15.6`) to avoid menu bar collision/regression behavior.
- On macOS versions where KeyVox normally has a Dock icon, `DockIconVisibilityController` may switch to accessory policy after all managed KeyVox windows are closed when `KeyVox.HideDockIconWhenAllWindowsClosed` is enabled. The Settings UI hides this option on legacy accessory-only systems.
- Parakeet provider availability is additionally runtime-gated by OS support (`macOS 14+`), and unsupported persisted selections normalize back to Whisper.
- Mac Vibes local rewrite inference requests GPU offload through `KeyVoxLocalInference`, but the package runtime only allows GPU offload on macOS Sequoia (15) and newer. macOS Ventura/Sonoma (13.5-14.x) always runs Vibes local rewrite on CPU.
- iOS also consumes `KeyVoxLocalInference`, but GPU offload remains unavailable there; the package reports CPU-only support outside macOS.

For the full file-level map, see [`CODEMAP.md`](CODEMAP.md).

## Inference Models

- KeyVox supports two on-device dictation providers on macOS:
  - `Whisper Base` (`ggml-base` + Core ML encoder bundle)
  - `Parakeet TDT v3` (manifest-backed Core ML model directory)
- KeyVox Vibes is a separate on-device rewrite runtime on macOS:
  - Base model: `Qwen2.5-0.5B-Instruct` GGUF artifact
  - Adapter package: `KeyVoxVibesAdapters`
  - Polished style maps to the polished LoRA.
  - Casual and Chill styles map to the casual LoRA.
  - Mac Vibes are free and have no trial, unlock, purchase, restore, or paywall path.
- `AppServiceRegistry` owns the host-side provider composition:
  - `WhisperService`
  - `ParakeetService`
  - `SwitchableDictationProvider`
  - Mac Vibes local rewrite manager/inference/coordinator
- `AppSettingsStore.activeDictationProvider` is the local source of truth for the selected provider.
- `AppSettingsStore.whisperDictationLanguage` is the device-local source of truth for Whisper's configured language.
- `AppSettingsStore.ActiveDictationProvider.supportedCases()` is the UI/runtime gate for which providers can be selected on the current OS.
- Unsupported provider selections fail closed back to Whisper instead of leaving the runtime in an unavailable state.

### Dictation Language Contract

- `DictationLanguage`, `DictationLanguageDisplayNameFormatter`, and `WhisperBaseLanguageCatalog` in `KeyVoxCore` are shared across iOS and macOS. The Mac app must not maintain a separate language list.
- `KeyVoxWhisper.WhisperLanguage` owns the iterable identifiers recognized by the pinned Whisper runtime; the shared catalog derives the Whisper Base options from those identifiers.
- `AppSettingsStore.whisperDictationLanguage` persists in local UserDefaults under `KeyVox.App.WhisperDictationLanguage`, defaults to Auto Detect, and is intentionally excluded from iCloud sync so different Macs and iOS devices may keep different choices.
- Missing or unsupported stored identifiers resolve to Auto Detect. Settings writes must be validated against `WhisperBaseLanguageCatalog`.
- `AppServiceRegistry` applies the stored language when composing `WhisperService` and observes later changes. `WhisperService` also reapplies the configured identifier before each transcription request.
- `Views/Settings/DictationLanguageSection.swift` uses the standard Mac `SettingsRow` plus right-side menu picker. The control displays the current selection directly; it does not use the iOS Change-button presentation.
- Parakeet TDT v3 has no native forced-language selection. Its row remains visible with a disabled Auto Detect picker and directs users to the Need Help FAQ for its supported languages.
- Switching to Parakeet does not erase the stored Whisper choice; switching back restores it.

## Mac Vibes Local Rewrite Contract

- Mac Vibes are controlled only by local Vibes AI install state and the selected Vibe style. There is no Mac paywall or entitlement branch.
- `MacVibesAccessMatrix` is the pure decision point for Settings UI:
  - not installed: show Vibes AI download content and a download action
  - downloading/installing: show progress/status and hide the style picker
  - failed: show failure content and a repair action
  - ready: show the selected Vibe and style picker
- `MacVibesAccessMatrix` must stay copy-free. It emits structural decisions only; visible strings live in the owning settings views.
- Mac settings deliberately split Vibes surfaces by concern:
  - `SettingsVibesCard` in the Style tab owns style selection, status/readiness presentation, expandable examples, and the trigger-key usage tip.
  - `SettingsVibesExamplesSection` owns the expandable example list, animated height measurement, and example-row selection behavior.
  - `SettingsVibesAIInstallCard` in the Settings/System section owns install management, delete/repair/progress/error display, and the Vibes trigger-key interactions toggle.
- The Mac Vibes intro flow is separate from Settings:
  - `MacVibesIntroController` owns one-time cold-launch eligibility after main onboarding and a completed-or-skipped first-dictation outcome, then persists the seen flag.
  - The intro must wait for the initial automatic update check; if an update is available, the intro remains suppressed until the app has updated and the post-update notice is dismissed.
  - `KEYVOX_FORCE_KEYVOX_VIBES_INTRO=1` forces repeated local presentation without clearing defaults, but it does not bypass the update-availability gate.
  - `WindowManager+VibesIntro` owns AppKit window creation, sizing, dismissal, and Style-tab handoff.
  - `MacVibesIntroWindowView` owns shared intro chrome: top close control, centered footer action, scene switching, dynamic size measurement, and the disabled `Try it` state while Vibes AI is not ready.
  - Intro scenes own only scene content; they should not reserve header/footer space or resize the NSWindow directly.
- The Mac first-dictation practice flow is separate from setup onboarding:
  - `OnboardingView` owns the welcome, language selection, and setup routes in the main onboarding window; `OnboardingSetupScreen` owns model, microphone, and Accessibility requirements.
  - The selected onboarding language is persisted to `AppSettingsStore.whisperDictationLanguage` before setup begins, and returning from setup preserves the in-progress selection.
  - `WindowManager+FirstDictationOnboarding` owns the optional post-setup first-dictation window and opens Settings after either completion or skip.
  - `AppSettingsStore.hasCompletedFirstDictation` means a real successful dictation happened; `hasSkippedFirstDictation` means the user intentionally skipped the first-dictation step.
  - `FirstDictationOnboardingFlowView` observes `TranscriptionManager.successfulDictationRevision` so repeated identical dictations still count as new events, then verifies the focused practice field contains the latest transcription.
  - `FirstDictationOptionKeyPromptView` renders from the configured trigger binding and uses `KeyboardMonitor.isTriggerKeyPressed` for the held/down visual state.
  - `KEYVOX_FORCE_ONBOARDING=1` and `KEYVOX_FORCE_FIRST_DICTATION_ONBOARDING=1` force the respective Mac onboarding windows without clearing or faking persisted completion state.
  - Scene C owns the install/download card and uses the shared labeled progress component for status and percent display.
  - Opening help from the Vibes card question-mark path starts at Scene B as standalone help: no close-header space, no X, and a `Done` footer action.

- `MacVibesCoordinator.canUseVibes` means the local Vibes AI model is installed and ready.
- `MacVibesCoordinator.selectedVibe` resolves to `.none` while the model is missing, but the persisted selected style is not erased just because the model is unavailable.
- `MacVibesCoordinator.releasePrewarmSession(reason:)` forwards to the local transformer so prewarm work is cancelled and the local rewrite model is unloaded after dictation and Vibe-change transforms.
- The app does not prewarm Vibes AI at launch or immediately after install readiness; model loading must stay tied to user-initiated dictation or Vibe-change work.
- The local inference service keeps only one model identity cached during active prewarm or generation work and unloads when that lifecycle is released or the installed model is invalidated/deleted/replaced.
- `MacLocalStyleRewriteTextTransformer` owns debug instrumentation for prewarm, missing LoRA adapters, generation metrics, and local rewrite failures.
- `KeyVoxLocalInference` owns GPU diagnostics and fallback logs. Expected behavior:
  - macOS Sequoia (15)+: automatic mode may report Metal/GPU backend when available, with CPU fallback on load/context failure
  - macOS Ventura/Sonoma (13.5-14.x): automatic mode resolves to CPU-only because platform GPU support is disabled before device enumeration
  - non-macOS platforms: CPU-only

## Mac Runtime Flags

`MacRuntimeFlags` is the single macOS environment flag parser.

Supported flags:

- `KEYVOX_FORCE_ONBOARDING`: forces the setup onboarding window without clearing persisted completion state
- `KEYVOX_FORCE_FIRST_DICTATION_ONBOARDING`: forces the first-dictation practice window without clearing or faking first-dictation completion/skipped state
- `KEYVOX_FORCE_MIC_PICKER`: debug-only force path for the onboarding microphone picker
- `KEYVOX_FORCE_KEYVOX_VIBES_INTRO`: forces repeated local Vibes intro presentation without clearing defaults, while still respecting the update-availability gate
- `KVX_MODEL_DOWNLOAD_PREVIEW_ERROR`: debug-only model-download preview error value
- `KVX_DEBUG_LOG_RAW_TEXT`: enables raw final text in debug transformation logs when set to `1`

## Mac Vibes Trigger-Key Contract

- Hold-to-dictate remains the primary trigger-key behavior.
- Vibes trigger-key interactions are an optional layer controlled by `AppSettingsStore.vibesTriggerKeyInteractionsEnabled`, persisted with `KeyVox.VibesTriggerKeyInteractionsEnabled`, and enabled by default.
- When the Vibes trigger-key interaction setting is off:
  - single-tap Vibe apply/undo is disabled
  - double-tap Vibe cycling is disabled
  - recording-start suppression/defer paths used for visible Vibe pills are disabled
  - the selected Vibe can still be applied to ordinary dictation output when set permanently in the app
- When the setting is on and Vibes are ready, quick taps are owned by `MacVibesTriggerActionController`; `MacTriggerTapClassifier` decides whether a quick tap should wait for a possible second tap or complete as a single-tap action.
- `TranscriptionManager` may defer recording start only for Vibes quick-tap handoff windows. Real dictation must not wait for a Vibe pill to clear.
- A standalone single-tap pill with no transformable text can be adopted by `OverlayManager.prepareVibePillCycleHandoff()` so the exact visible pill becomes the first cycle pill on double tap.
- `OverlayManager.showVibeCyclePill` reuses the visible primary/auxiliary cycle panel when possible, schedules animated dismissal separately from panel removal, and keeps cycle-pill positioning centered on the normal recording overlay.
- `VibeCyclePillVisibilityController` owns the atomic cycle-pill presentation state; `VibeCyclePillOverlay` owns only rendering, entry/exit animation, and the forward flip between cycle states.

## Mac Paragraph/List Trigger-Key Contract

- Trigger+L toggles list formatting and trigger+P toggles paragraph formatting for only the latest untouched KeyVox insertion. These actions never change the persisted paragraph/list preferences.
- Recording starts immediately on trigger-down. There is no formatting-chord delay or deferred recording start.
- `MacFormattingShortcutMonitor` recognizes physical L/P key codes for the configured left/right trigger binding and consumes both key-down and matching key-up so letters, Option characters, and Command/Control actions do not reach the focused app.
- Auto-repeat remains consumed but emits only one formatting action per physical key press. A tap disabled by timeout or user input is re-enabled.
- The event tap may start only when `AXIsProcessTrusted()` is already true. The formatting feature must not request Accessibility permission at launch or move the existing permission prompt out of the recording/onboarding permission flow.
- The formatting monitor is action-enabled only while idle or during an ordinary unlocked recording. Stopping, transcribing, and hands-free-stop flows retain their existing ownership.
- When L/P arrives during an eligible recording, the trigger interaction becomes consumed, pending Vibe tap classification is cleared, the recording is stopped and discarded without transcription or paste, and formatting runs after recorder shutdown.
- Trigger release after a consumed formatting chord cannot become a Vibe tap, recording stop, or hands-free action.
- `MacDictationChangeController` validates the latest insertion before mutation, resolves a saved deterministic source through `KeyVoxCore`, reapplies the active Vibe when available, adjusts rewritten layout for the target state, preserves all-caps display, and commits session state only after paste replacement succeeds.
- Rendered variants are cached by deterministic state plus Vibe. If Vibes becomes unavailable, cached styled targets remain usable; an uncached styled target no-ops without clearing the active or previous Vibe.
- If no untouched insertion exists, the chord is still consumed and the pill reports the requested formatting control as off and unavailable for replacement.
- Formatting feedback uses the shared overlay pill: yellow SF Symbol means enabled, white means disabled, model-backed rendering uses the shared icon pulse, and the completed stroke starts when replacement begins rather than after post-insertion verification.

## Whisper Voice-Activity Gate

Whisper uses a shared whole-capture VAD gate after macOS stop-time audio acceptance and before paragraph chunking:

- `KeyVoxWhisper.WhisperVoiceActivityDetector` owns the actor-isolated whisper.cpp VAD context and loads the package-bundled `ggml-silero-v5.1.2.bin` model.
- `WhisperService+ModelLifecycle` creates the detector during Whisper warmup and releases it when Whisper unloads.
- `WhisperService+TranscriptionCore` treats no detected speech as likely no-speech and skips decoder work.
- when speech is detected, the complete accepted recording proceeds unchanged; VAD segments must not trim transcription input
- if detector creation or analysis is unavailable, the existing Whisper decoder no-speech safeguards remain the fallback
- the gate is Whisper-specific; Parakeet keeps its existing provider flow, and macOS must not add a second host-local VAD asset or policy

## Post-Processing Order

1. For Whisper, whole-capture VAD rejects no-speech input before chunking; Parakeet begins with the next step.
2. `Packages/KeyVoxCore/Sources/KeyVoxCore/Transcription/AudioParagraphChunker.swift` computes conservative chunk boundaries from silence windows.
3. The active provider (`WhisperService` or `ParakeetService`) transcribes each chunk and stitches chunk text with `\n\n` when `autoParagraphsEnabled` is on (space-separated when off).
4. Early literal cleanup runs first: `EmailAddressNormalizer` repairs email literal casing/punctuation boundaries before downstream matching, then dictionary correction applies effective dictionary adherence via `DictionaryMatcher`, including dictionary-backed spoken/literal email recovery and package-owned hidden app/product naming entries.
5. Pre-list normalization prepares deterministic structure: lightweight idiom normalization (`hole in one` -> `hole-in-one`), `ColonNormalizer`, spoken quantity grouping, and `MathExpressionNormalizer` run before list parsing so structural markers stabilize early.
6. List formatting applies numeric list rendering when confidence gates pass.
7. Late cleanup normalizes residual model output after list rendering: `LaughterNormalizer`, `CharacterSpamNormalizer`, `AsteriskCensorshipArtifactNormalizer`, `TimeExpressionNormalizer`, `DateNormalizer`, final email boundary repair, `WebsiteNormalizer`, and `ThousandsGroupingNormalizer`.
8. Final finishers apply render-mode whitespace cleanup, capitalization guards (including URL/domain/email and technical-token safety checks), spoken terminal punctuation, terminal-time punctuation completion, and the optional `AllCapsOverrideNormalizer`.
9. Final text is inserted via the paste service. macOS resolves focused-target, recent-insertion, and following-character context; supplies dictionary casing preservation; delegates shared capitalization, spacing, and adjacent terminal-punctuation policy to `KeyVoxTextComposition`; and retains ownership of Accessibility selection expansion and paste fallback transport. An incoming model period is stripped when punctuation already follows, while a differing incoming question or exclamation mark replaces that following punctuation.

`TimeExpressionNormalizer` owns compact numeric time shaping. A meridiem match that continues an already colon-separated number must be ignored so input such as `810 PM` becomes `8:10 PM` exactly once, never `8:10:00 PM`.

## Dictionary Hinting and Built-Ins

- User dictionary entries remain the only visible and persisted dictionary data. Built-in app/product entries are package-owned, hidden, and merged only at effective-use boundaries.
- Built-in canonical entries currently cover `KeyVox` and `KeyVox Speak`. Alias spellings such as `Kivok`, `Kivox`, and `Keyvox` compile into the matcher as observed forms but replace to the canonical brand text.
- If a user already has a matching canonical phrase in their dictionary, `KeyVoxCore` de-dupes the effective entry set so the phrase is not fed through the matcher or provider prompt twice.
- `DictionaryHintPromptBuilder` builds prompt text from user phrases plus canonical built-ins only. Alias spellings are intentionally not exposed in the prompt.
- macOS `TranscriptionManager` still decides whether a capture is audio-safe for dictionary hinting by using `DictionaryHintPromptGate`; `DictationPipeline` then combines that host signal with package-owned effective dictionary availability.
- `TranscriptionPostProcessor` always applies effective dictionary entries, so the built-in corrections remain available even when a provider prompt is disabled for short, silent, or otherwise unsafe captures.
- Adjacent-titlecase safety checks still guard against broad prose/name rewrites, but sentence punctuation is treated as a real boundary so a built-in brand alias at the end of one sentence is not blocked by titlecase text starting the next sentence.

## Model Management

- macOS model installation is model-aware rather than provider-hard-coded.
- `Core/ModelDownloader/DictationModelCatalog.swift` is the source of truth for:
  - model IDs
  - install layouts
  - remote artifact metadata
  - required byte estimates
- Current install layouts:
  - `Whisper Base` uses the legacy/rooted Whisper layout under `Models/whisper`
  - `Parakeet TDT v3` uses a manifest-backed subdirectory layout under `Models/parakeet`
  - `KeyVox Vibes AI` uses a manifest-backed rewrite layout under `Models/rewrite/qwen2-5-0-5b-instruct`, with staging under `Models/rewrite/.staging/qwen2-5-0-5b-instruct`
- `Core/ModelDownloader/InstalledDictationModelLocator.swift` owns:
  - rooted install resolution
  - one-time legacy Whisper migration into `Models/whisper`
  - fast readiness checks for hot paths
  - strict manifest-backed validation for staged/promoted installs
- `Core/ModelDownloader/ModelDownloader.swift` publishes per-model install state and enforces a single active download at a time.
- Download completion is intentionally split:
  - transport/delegate completion stays immediate so temporary download files can be moved before they expire
  - heavy validation and post-install work run off the hot path
- `App/AppServiceRegistry.swift` supplies downloader `postInstallPreparation` so Parakeet preload happens after a successful install instead of on the first trigger press.
- `App/AppServiceRegistry.swift` does not retain a Vibes readiness prewarmer; an already-installed or newly reinstalled Vibes model must not load until dictation or a Vibe-change transform requests it.
- `Views/Settings/SettingsView+DictationModels.swift` is the release-facing `Active Model` settings surface for install, removal, progress, and provider switching.
- `Views/Settings/DictationLanguageSection.swift` is the attached model-language surface and owns the Mac picker presentation plus provider-specific explanatory copy.
- `Views/Settings/SettingsVibesCard.swift` is the Style-tab Vibes surface for style selection, readiness/status, examples, and style-card download/repair/progress affordances.
- `Views/Settings/SettingsVibesAIInstallCard.swift` is the Settings/System Vibes AI management surface for install, removal, progress, repair, and the trigger-key interactions toggle.
- `Core/Transcription/TranscriptionManager+RecordingSession.swift` persists the last successful final transcription to `UserDefaultsKeys.App.lastTranscription` for the Settings Home tab.
- `Core/Transcription/TranscriptionManager+RecordingSession.swift` also marks the first-dictation completion flag after successful normal dictation and asks popup eligibility to re-run when that first completion happens outside the first-dictation window.

## Update Feed and Release Checks

`Core/Services/AppUpdateService.swift` is the prompt/check orchestration source-of-truth, with `Core/Services/UpdateFeedConfig.swift` owning which GitHub repository feed is used.

- Reads latest release metadata from GitHub Releases.
- Resolves the tracked feed through `UpdateFeedResolver`, allowing an optional local owner/repo override without changing tracked defaults.
- Normalizes release tags such as `v1.2.3` to `1.2.3`.
- Uses a summarized release-notes preview (summary section when present, else truncated body text).
- Parses release metadata into an installable zip path vs manual-only fallback.
- Enforces host allowlist checks before opening release links or downloading install assets.
- Treats manual checks differently from automatic prompts: status-menu checks reopen the prompt flow even if the user previously pressed `Later` in the same session.
- Publishes whether the first automatic update check completed and whether the current version has an available update so cold-launch one-time UI can avoid appearing in front of update flows.

## In-Place Updater

KeyVox now supports an in-place GitHub Releases updater on macOS.

- Automatic checks still surface a lightweight update prompt first.
- Installable releases require both a `KeyVox-<version>.zip` asset and `keyvox-update-manifest.json`.
- The prompt CTA opens a dedicated updater window instead of sending users to the browser.
- The updater downloads the zip, verifies SHA-256, extracts the staged app, validates bundle identity, and verifies Apple trust before launch handoff.
- Final app replacement is performed by `Resources/updater.sh` after the main app exits.
- The updater only performs in-place installation from `/Applications`; if needed, KeyVox first copies itself into `/Applications`, relaunches, and resumes the updater flow automatically.
- On the first successful launch after update, KeyVox can present a dedicated post-update notice window.

### Updater Runtime Split

The updater is intentionally separated by concern:

- `Core/Services/AppUpdateService.swift`
  release discovery from the resolved feed, session snooze behavior, and prompt construction
- `Core/Services/AppUpdateLogic.swift`
  pure release parsing, version comparison, and host allowlist helpers
- `Core/Services/UpdateFeedConfig.swift`
  tracked feed defaults plus local override resolution
- `Core/Services/UpdatePromptPresenting.swift`
  prompt UI abstraction boundary used by the service
- `Core/Services/AppUpdate/`
  install pipeline pieces (`AppReleaseInfo`, manifest loading, download transport, checksum verification, extraction, bundle verification, install launch, cleanup, launch notice handling)
- `Views/UpdatePromptOverlay.swift`
  lightweight update-available prompt window
- `Views/Updates/`
  dedicated updater window, release-notes card, and post-update notice UI
- `App/WindowManager+Updates.swift`
  updater/post-update window lifecycle, centering, and floating-window presentation

### Release Packaging Contract

The updater expects a release zip and manifest that match the shipped app metadata.

- Zip asset name:
  `KeyVox-<version>.zip`
- Manifest asset name:
  `keyvox-update-manifest.json`
- Manifest fields:
  `version`, `assetName`, `sha256`, `byteSize`, `bundleIdentifier`, `minimumSupportedMacOS`
- Packaging helper:
  `build/build_release.sh`

`build/build_release.sh` assumes maintainers already exported a signed/notarized `.app` from Xcode. The script verifies the exported app, creates the release zip, and writes the updater manifest into `build/Release/`.

### Local Override Workflow

Maintainers can override the update feed locally without changing tracked defaults.

- Override file path:
  `~/Library/Application Support/KeyVox/update-feed.override.json`
- Helper script:
  `Tools/UpdateFeed/configure_local_feed.sh`
- Example template:
  `Tools/UpdateFeed/update-feed.override.example.json`

## Testing and Quality Gates

- App tests:
  `xcodebuild -project macOS/KeyVox.xcodeproj -scheme "KeyVox DEBUG" -configuration Debug -destination 'platform=macOS' -enableCodeCoverage YES CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO -resultBundlePath /tmp/keyvox-tests.xcresult test`
- Package tests:
  `cd Packages/KeyVoxCore && swift test --scratch-path /tmp/KeyVoxCore-test-clean`
- Text composition package tests:
  `cd Packages/KeyVoxTextComposition && swift test --scratch-path /tmp/KeyVoxTextComposition-test-clean`
- Whisper package tests:
  `cd Packages/KeyVoxWhisper && swift test --scratch-path /tmp/KeyVoxWhisper-test-clean`
- Parakeet package tests:
  `cd Packages/KeyVoxParakeet && swift test --scratch-path /tmp/KeyVoxParakeet-test-clean`
- Local inference package tests:
  `cd Packages/KeyVoxLocalInference && swift test --scratch-path /tmp/KeyVoxLocalInference-test-clean`
- Style rewrite package tests:
  `cd Packages/KeyVoxStyleRewrite && swift test --scratch-path /tmp/KeyVoxStyleRewrite-test-clean`
- Vibes adapter package tests:
  `cd Packages/KeyVoxVibesAdapters && swift test --scratch-path /tmp/KeyVoxVibesAdapters-test-clean`
- Core coverage gate:
  `Tools/Quality/check_core_coverage.sh /tmp/keyvox-tests.xcresult`
- Coverage markdown summary:
  `Tools/Quality/coverage_summary.sh /tmp/keyvox-tests.xcresult`
- KeyVoxCore JSON coverage gate:
  `Tools/Quality/check_keyvoxcore_coverage.sh <coverage-json-path>`
- KeyVoxCore JSON coverage summary:
  `Tools/Quality/keyvoxcore_coverage_summary.sh <coverage-json-path>`

## Tooling

- Tooling guide:
  `Tools/README.md`
- Frontmost-app AX diagnostics:
  `Tools/ExploreAX.swift`
- Multi-app AX diagnostics:
  `Tools/ExploreAXApps.swift`
- Paste signal probe harness:
  `Tools/ExplorePasteSignal.sh`
- AX notification observer for paste debugging:
  `Tools/ObservePasteAXNotifications.swift`
- Pronunciation pipeline/regeneration scripts:
  `Tools/Pronunciation/*`
- Update-feed local override helper:
  `Tools/UpdateFeed/configure_local_feed.sh`
- Release zip + manifest packaging helper:
  `build/build_release.sh`

### Integration-Only Exclusions

- Audio capture hardware/runtime integration paths
- Global keyboard hook behavior
- Overlay window rendering/interaction details; pure overlay state machines such as Vibe pill presentation remain unit-testable

These remain integration/manual-test territory by design.

## Pronunciation Pipeline

- Runtime pronunciation resources:
  `Packages/KeyVoxCore/Sources/KeyVoxCore/Resources/Pronunciation/`
- Lexicon build script:
  `Tools/Pronunciation/build_lexicon.sh`
- Source/checksum lock:
  `Packages/KeyVoxCore/Sources/KeyVoxCore/Resources/Pronunciation/sources.lock.json`
- Source/license verification:
  `Tools/Pronunciation/verify_licenses.sh`
- Quality gates:
  `Tools/Pronunciation/benchmarks/run_quality_gates.sh`

## Contributor Notes

- Keep behavior/motion constants close to owning logic.
- Keep branded visual tuning inside branded view files.
- `Views/Components/LogoBarView.swift` is the only branded Mac logo file and owns only standalone/recording logo presentation; it does not own temporary pill copy or rendering.
- `Views/Components/OverlayPillView.swift` owns neutral pill layout, common metrics, state, and completion animation; injected feature views own their icons and copy.
- `Views/Components/OverlayPillProcessingIcon.swift` owns the shared two-layer processing pulse and keeps its duplicated decorative glow inaccessible; `VibePillView` and `MacFormattingPillView` provide feature-specific icon content and idle presentation.
- `Views/Components/MacFormattingPillView.swift` owns formatting titles, SF Symbols, enabled colors, and feature-specific spacing.
- `Views/Components/SelectedVibeLabel.swift` owns the small recording-time selected Vibe label. It stays separate from `RecordingOverlay` so the label cannot push or resize the logo panel.
- `Views/Components/MacAppTheme.swift` is the shared non-branded macOS theme file for app-window surfaces; keep generic window/theme tokens there rather than scattering repeated values across settings/onboarding/update views.
- `Views/Components/UIComponents.swift` is the shared non-branded home for typography/effect/progress primitives; keep those generic building blocks there rather than re-declaring them in feature views.
- Do not route `Views/StatusMenuView.swift` or `Views/Warnings/*` through `MacAppTheme` unless the product explicitly wants those surfaces visually unified with the main app windows.
- `Views/RecordingOverlay.swift` is a thin overlay shell. Generic timing/metering state belongs in `Core/Overlay/AudioIndicatorDriver.swift`, not in the branded renderer.
- `Views/Components/OverlayPillOverlay.swift` is the generic standalone-pill visibility shell; `Views/VibePillOverlay.swift` retains only Vibe cycle presentation and flip behavior.
- `Core/Services/Paste/PasteService.swift` owns latest untouched insertion verification/replacement for Mac Vibes and deterministic formatting changes. Change controllers should ask PasteService whether a replacement is safe instead of reconstructing host text themselves.
- `Core/Services/Paste/Composition/PasteTerminalPunctuationCoordinator.swift` owns Mac-specific following-character lookup and requests guarded AX selection expansion when the shared terminal-punctuation result requires replacement; punctuation classification and the preserve/replace decision remain package-owned.
- `Core/Services/Paste/Accessibility/PasteUntouchedInsertionAuthorizer.swift` is the state owner for latest-insertion authorization. It captures and invalidates the token, verifies live app and AX context, and advances successful replacements only within the same target lineage.
- `Core/Services/Paste/Accessibility/PasteUntouchedInsertionToken.swift` is the immutable authorization record. It binds the latest insertion to its original PID, AX element, target range, and selection snapshot; focus, caret/selection, target-range, or process changes invalidate eligibility.
- `Core/Services/Paste/Accessibility/PasteAccessibilityInjector.swift` must keep self-targeted AX writes on the main thread, but must not use an unbounded cross-thread `DispatchQueue.main.sync`; the current contract returns fallback on timeout so paste recovery can proceed.
- `Core/Services/AppProcessTerminator.swift` is the only helper for intentional immediate app termination after updater handoff or resume-after-move relaunch; keep termination policy out of updater views and app entry-point branching.
- `Core/Vibes/MacVibesAccessMatrix.swift` stays the pure Mac Vibes settings decision surface. Do not add entitlement, trial, purchase, restore, or paywall branches to Mac Vibes.
- Mac Vibes settings copy belongs beside the view that renders it: `SettingsVibesCardCopy`, `SettingsVibesExamplesCopy`, and `SettingsVibesAIInstallCardCopy`. Do not move user-facing copy into `MacVibesAccessMatrix`.
- `Core/Vibes/MacLocalRewriteInferenceService.swift` stays the Mac-local composition point for model URL, adapter URL, and GPU offload mode. Platform GPU eligibility belongs in `KeyVoxLocalInference`, where it is already logged and tested.
- Generic reusable indicator models (`AudioIndicatorPhase`, `AudioIndicatorSignalState`, `AudioIndicatorSample`, `AudioIndicatorTimelineState`) should stay neutral and non-branded.
- `Core/Overlay/OverlayTypes.swift` should remain the neutral home for reusable fling-impact models instead of folding those shapes into panel or physics files.
- Keep the macOS iCloud settings sync split intact: `KeyVoxiCloudSyncCoordinator` owns dictionary/settings convergence, while `WeeklyWordStatsCloudSync` owns weekly usage only.
- Keep the dictation-language preference device-local; do not add it to `KeyVoxiCloudSyncCoordinator` or another cross-device payload.
- Prefer deterministic pure helpers for unit-test coverage.
- Preserve behavior when doing structural refactors unless explicitly changing product behavior.

## Change Tracking

- `ENGINEERING.md` captures stable contracts and system behavior, not per-commit file churn.
- Use Git history (commits/PRs/tags) and release notes for detailed change logs.
- Keep this doc updated only when architecture, invariants, or operational/testing policy changes.
