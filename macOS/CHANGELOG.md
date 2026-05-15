# Changelog

All notable changes to this project will be documented in this file.

The format loosely follows Keep a Changelog and the project uses semantic versioning.

---

## [1.1.0] - 2026-05-14

Introduces KeyVox Vibes on Mac with local writing styles, downloadable Vibes AI model support, trigger-key Vibe controls, a Vibes intro flow, and new shared local rewrite/runtime packages.

### Added

- KeyVox Vibes on Mac, including Casual, Polished, and Chill rewrite modes for dictated text.
- New shared `KeyVoxStyleRewrite`, `KeyVoxLocalInference`, and `KeyVoxVibesAdapters` packages for local style rewriting, GGUF inference, GPU-aware llama runtime loading, and bundled Vibes LoRA adapters.
- Downloadable Vibes AI model management on Mac, including install, readiness, repair, delete, SHA-256 validation, staged installation, and local model invalidation handling.
- Vibes settings cards with style selection, examples, model-install status, progress, repair actions, and trigger-key usage guidance.
- Trigger-key Vibe interactions so users can tap to apply or undo the selected Vibe on the latest untouched dictation, and double-tap to cycle Vibes.
- Vibe pill overlays and selected-Vibe labels for recording, cycling, processing, and completion feedback.
- A dedicated Mac Vibes intro window with animated scenes, Vibes AI download handling, and post-update presentation coordination.
- Local rewrite prewarming when Vibes AI becomes ready and before upcoming dictation sessions.
- Vibes branding assets and bundled adapter resources for the Mac target.
- Model-training datasets, prompts, specs, lineage, and run artifacts for the shipped Casual and Polished Vibes adapters.

### Changed

- Integrated Vibes into the Mac dictation pipeline so selected styles can transform final dictated text before paste insertion.
- Integrated post-dictation replacement support so Mac can verify the latest untouched insertion and replace it through Accessibility or menu fallback paths.
- Updated the recording overlay and trigger-key monitor to carry timestamped trigger events, defer recording starts during Vibe tap decisions, and show the selected Vibe during recording and transcription.
- Updated overlay placement persistence to resolve origins by panel size, support centered Vibe pill placement, and clamp overlay windows more consistently across displays.
- Updated shared dictation cleanup through `KeyVoxCore` `1.0.9` so observed leading asterisk censorship artifacts are repaired before downstream formatting.
- Updated the in-app updater flow to track whether an update is available, resume Vibes intro presentation after update gates, and handle move-to-Applications relaunch failures with clearer recovery.
- Updated updater window and prompt styling around progress, badges, current/update version labels, and post-update notice presentation.
- Updated macOS docs, project membership, third-party notices, and shared package version tracking for the Vibes runtime and adapter architecture.

### Fixed

- Fixed shared transcription cleanup for observed leading asterisk censorship artifacts before time, email, website, capitalization, and punctuation finishers run.
- Fixed move-to-Applications updater handoff so KeyVox only terminates after macOS successfully opens the moved app, and clears the staged resume flag if reopening fails.
- Fixed updater install termination to flush process state before exiting for installer handoff.
- Fixed replacement of the latest dictated insertion so successful Vibe changes can preserve caret position and restore the clipboard immediately after menu fallback replacement.
- Fixed overlay positioning support for Vibe pill windows without disturbing the saved recording overlay location.

### Package versions

KeyVox macOS 1.1.0:
- KeyVoxCore           1.0.9
- KeyVoxWhisper        1.0.0
- KeyVoxParakeet       1.0.3
- KeyVoxStyleRewrite   1.0.0
- KeyVoxLocalInference 1.0.0
- KeyVoxVibesAdapters  1.0.0

## [1.0.10] - 2026-05-04

Ships shared dictation engine updates from the iOS release line to macOS, focused on built-in KeyVox dictionary handling, safer post-processing, and the Parakeet prompt-priming fix.

### Changed

- Updated the bundled `KeyVoxCore` package to `1.0.8` with shared built-in dictionary entries for `KeyVox` and `KeyVox Speak`, centralized dictionary hint prompt construction, refined list parsing, and deterministic post-processing variants.
- Updated the bundled `KeyVoxParakeet` package to `1.0.3` with unsupported decoder prompt priming removed from the Parakeet runtime.
- Moved effective dictionary ownership into the shared dictation pipeline so macOS still decides audio eligibility for dictionary hinting while `KeyVoxCore` owns built-in entries, prompt content, dictionary matching, and prompt-echo suppression.
- Updated macOS engineering documentation and codemap notes for the shared dictionary ownership model.

### Fixed

- Fixed Parakeet dictation corruption where dictionary prompt text could advance decoder state before audio decoding and cause the beginning of words to be dropped or mangled.
- Fixed app and product name correction so `KeyVox` and `KeyVox Speak` can be corrected through hidden built-in dictionary entries without requiring visible user dictionary entries.
- Refined shared list-marker parsing and post-processing so dictated text is less likely to be misread as structured list content.
- Preserved dictionary correction through the post-transcription matcher path when provider prompt hinting is unavailable or disabled.

### Package versions

KeyVox macOS 1.0.10:
- KeyVoxCore       1.0.8
- KeyVoxWhisper    1.0.0
- KeyVoxParakeet   1.0.3

## [1.0.9] - 2026-04-22

### Changed

- Reworked Parakeet Core ML chunk assembly around emitted-token timing, decode windows, and overlap-aware merge logic, including a tail-context rescue pass for final remainder chunks.
- Removed macOS recorder stop-delay handling and synthetic transcription silence padding so stopped captures return normalized captured frames only after queued capture work drains.
- Updated macOS paste menu fallback test assertions to avoid isolated enum equality checks under the XCTest host.

### Fixed

- Rescued short final Parakeet utterance tails that could be lost when the last partial chunk did not have enough decoding context.
- Prevented recorder padding from inflating captured audio duration and working against short-utterance/no-speech decisions.

### Package versions

KeyVox macOS 1.0.9 (build 1):
- KeyVoxCore       1.0.5
- KeyVoxWhisper    1.0.0
- KeyVoxParakeet   1.0.2

## [1.0.8] - 2026-04-16

### Changed

- Updated the bundled `KeyVoxCore` package to `1.0.5` with shared numeric grouping refinements that preserve month-led year references such as `November 2025`.
- Refined macOS menu fallback paste verification so clipboard restoration now distinguishes exact dictated-payload evidence from structural insertion signals.

### Fixed

- Prevented delayed menu paste consumers, including browser-based editors, from receiving the previously restored clipboard content after KeyVox had already triggered insertion.
- Kept immediate clipboard restoration for menu fallback only when the expected dictated text is observed in the target field, while preserving the existing grace delay for structural-only or trusted fallback evidence.
- Preserved thousands grouping for quantity-like four-digit numbers while leaving adjacent calendar year references ungrouped.

### Package versions

KeyVox macOS 1.0.8 (build 1):
- KeyVoxCore       1.0.5
- KeyVoxWhisper    1.0.0
- KeyVoxParakeet   1.0.2

## [1.0.7] - 2026-04-15

### Changed

- Updated the bundled `KeyVoxCore` package to `1.0.4` with shared Parakeet no-speech handling refinements, model lifecycle observability, and spoken-version list-detection fixes.
- Updated the bundled `KeyVoxParakeet` package to `1.0.2` with decoder timing, lexical segment timing, and no-speech gating refinements for short cue-like hallucinations.
- Made macOS clipboard restoration after paste insertion evidence-driven so verified Accessibility and menu fallback insertions restore the previous clipboard immediately.

### Fixed

- Preserved trailing dictation audio during the macOS stop-recording handoff so final speech is less likely to be clipped before transcription.
- Kept macOS update prompt and installer windows anchored to the active display across update checks, relaunch prereflight, and installation flow transitions.
- Kept a grace delay only for trusted menu fallback paste paths that do not expose concrete insertion evidence.
- Prevented spoken semantic-version prose such as `version one point zero point seven` from being mistaken for list structure during shared text formatting.
- Tightened Parakeet short-output filtering so brief low-confidence cue-like hallucinations are rejected without suppressing valid short speech.

### Package versions

KeyVox macOS 1.0.7 (build 1):
- KeyVoxCore       1.0.4
- KeyVoxWhisper    1.0.0
- KeyVoxParakeet   1.0.2

## [1.0.6] - 2026-04-07

### Added

- Added a promoted KeyVox Keyboard for iPhone card to the macOS Home settings view with direct App Store access.
- Added a copy-link action for the iPhone promo card so the App Store listing can be shared from macOS settings.

### Changed

- Updated the bundled `KeyVoxCore` package to `1.0.1` with shared Parakeet no-speech confirmation behavior for short low-confidence one-shot output.
- Updated the bundled `KeyVoxParakeet` package to `1.0.1` with confidence-gated short-utterance suppression for low-confidence Parakeet output.
- Refined macOS developer and promo card presentation with promoted card styling, stronger primary CTA treatment, and animated app icon glow.

### Fixed

- Reset the promo card copied state after temporary feedback so repeated copy actions behave consistently in macOS settings.
- Hardened macOS settings card theming so shared card colors stay explicit and stable across promo and non-promo surfaces.

## [1.0.5] - 2026-03-30

### Added

- Added model-managed Parakeet support on macOS as a new on-device dictation option alongside Whisper.
- Added an `Active Model` settings experience for macOS so installed dictation models can be managed in one place.
- Added per-model install handling for macOS dictation models, including staged validation before a model is made available to the app.

### Changed

- Updated the macOS status menu and readiness flow to follow the currently active dictation model.
- Preserved capitalization at new line starts on macOS so pasted transcriptions better match the surrounding text context.

### Fixed

- Improved macOS model download and install reliability for local dictation assets, including activation and cleanup edge cases.

## [1.0.4] - 2026-03-19

### Added

- Added leading-capitalization normalization before macOS paste so fresh transcriptions better match text expectations at insertion time.

### Changed

- Reworked the macOS settings window to align with the iOS tab structure, including Home, Dictionary, Style, and Settings tabs.
- Added a Home dashboard for weekly word totals and the most recent transcription, and moved trigger key, audio, system, and developer controls into the new Settings layout.

### Fixed

- Reset dismissed macOS settings windows to Home when reopened from the Dock instead of returning to the previously viewed tab.

## [1.0.3] - 2026-03-14

### Added

- Added a full in-app GitHub release updater for macOS, including release parsing, manifest loading, zip download, checksum verification, staged install, relaunch handling, and post-update confirmation.
- Added updater-specific macOS windows and cards for release notes, progress, install requirements, failure states, and post-update messaging.
- Added automatic move-to-Applications prereflight so update installs can continue after relaunch from the correct location.
- Added updater safety checks for SHA validation, bundle and Team ID verification, Gatekeeper checks, staged cleanup, and rollback-aware install handoff.
- Added shared updater UI components and app-wide styling primitives, including `AppActionButton`, `AppUpdateProgressBar`, `MacAppTheme`, and centralized `appFont` selection.
- Added a floating dictionary add button in macOS settings and automatically switch dictionary sorting to Recently Added after a successful add.
- Added Kanit Light to the macOS app for lighter settings, warning, onboarding, updater, and status-menu supporting copy.
- Added refreshed bundled app artwork and logo assets.

### Changed

- Replaced browser-led update actions with an in-app updater flow that keeps release notes, progress, install guidance, and completion messaging inside KeyVox.
- Refreshed the macOS app theme by centralizing shared colors, window chrome, card styling, and common typography hooks across onboarding, settings, prompts, and updater surfaces.
- Moved AI model download to the first onboarding step so new users can start setup in a more natural order.
- Unified prompt and modal actions around shared button styling, including centered actions for onboarding, dictionary editing, and destructive confirmation flows.
- Refined macOS dictionary management by moving Add Word to a floating corner action and enlarging the word editor presentation.
- Polished audio settings layout so microphone selection and card icon alignment render more cleanly.
- Updated status-menu typography to use the shared app font system.
- Tuned the recording overlay meter boost for a steadier visual response.

### Fixed

- Prevented users from closing the updater window while an update is actively downloading, extracting, or installing.
- Fixed Swift 6 actor-isolation issues in updater test coverage by removing invalid `Equatable` assertions.

## [1.0.2] - 2026-03-11

### Added

- Added macOS iCloud sync for dictionary entries plus synced settings for trigger binding, auto paragraphs, and list formatting.
- Added weekly word stats sync so current-week totals can converge across devices.
- Added the `KeyVoxCore` Swift package to own shared transcription, normalization, dictionary, list, audio, Whisper, and pronunciation resource logic.
- Added thousands-grouping normalization for quantity-like four-digit numbers while protecting dates, years, versions, and phone numbers.
- Added a dedicated bug report issue template for more consistent incoming issue reports.

### Changed

- Moved reusable engine code, package resources, and core-focused test coverage into `KeyVoxCore` while keeping app-specific wiring in the app target.
- Tightened paragraph and list boundary detection to reduce accidental list rendering and awkward post-processing splits.
- Refactored the macOS recording overlay around a shared audio indicator driver and unified branded logo presentation through `LogoBarView`.
- Updated onboarding window sizing so the macOS onboarding flow grows with expanded content such as model download progress and errors.
- Moved weekly word-count persistence responsibilities out of `AppSettingsStore` into a dedicated store.

### Fixed

- Reduced dictionary false positives for stylized split-join and single-token corrections on long shared-prefix matches.
- Prevented prose number ranges and trailing commentary from being reformatted as lists while preserving terminal punctuation on longer list items.
- Preserved persisted dictionary freshness and empty dictionary snapshots during macOS iCloud bootstrap and reconciliation.
- Prefixed newly generated mac weekly-stats installation identifiers with `mac:` for more reliable device grouping.
- Hardened dictionary durability, audio post-processing, Whisper request cleanup, and regression coverage across sync and formatting edge cases.

## [1.0.1] - 2026-03-05

### Changed

- Replaced static TLD checks with shared domain heuristics in `WebsiteNormalizer`.
- Delegated ambiguous domain/prose-dot disambiguation from `SentenceCapitalizationNormalizer` to `WebsiteNormalizer`.

### Fixed

- Preserved sentence-boundary capitalization when prose periods are not domain separators.
- Made `WebsiteNormalizer.nextWord` composed-character safe to avoid surrogate-pair splitting.
- Prevented compressed-tail 3-token dictionary fallback false positives that could rewrite unrelated prose spans (#24).
- Added regression tests for long-TLD domain handling, sentence-boundary behavior, and compressed-tail dictionary matching.

## [1.0.0] - 2026-03-04

Initial public release of KeyVox.

### Added

- Local-first dictation system powered by on-device Whisper (`ggml-base`).
- Push-to-talk recording overlay triggered by a held key.
- Deterministic post-processing pipeline for formatting and cleanup.
- Custom dictionary system with phonetic-aware correction.
- Pronunciation lexicon pipeline and tooling.
- Automatic paragraph detection from silence windows.
- List rendering and spoken-number list parsing.
- Spoken math normalization with symbol conversion.
- Email literal normalization and punctuation repair.
- Website/domain casing normalization.
- Time expression normalization.
- Character spam cleanup and laughter normalization.
- Caps Lock override mode for full uppercase output.
- Clipboard-safe paste injection with restoration guarantees.
- Floating recording overlay with persistence and motion handling.
- GitHub-based update check system with local override capability.
- Maintainer tooling for diagnostics, pronunciation resources, and quality gates.
- Unit testing and coverage gates for core subsystems.

### Security

- No telemetry.
- No background speech collection.
- No network usage during transcription.

### Notes

KeyVox is designed as a deterministic, local-first dictation tool.  
All speech processing occurs on-device and no user speech data is transmitted or stored remotely.
