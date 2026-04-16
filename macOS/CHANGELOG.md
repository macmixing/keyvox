# Changelog

All notable changes to this project will be documented in this file.

The format loosely follows Keep a Changelog and the project uses semantic versioning.

---

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
