# Changelog

All notable changes to this project will be documented in this file.

The format loosely follows Keep a Changelog and the project uses semantic versioning.

---

## [1.1.6] - 2026-05-28

Adds guided first-dictation onboarding, a Settings help entry point, centralized Mac runtime flags, and stronger Vibes money repair.

### Added

- Added a first-dictation onboarding flow with intro, Option-key prompt, practice, and success screens after initial setup and Vibes intro gates complete.
- Added first-dictation onboarding presentation coordination, completion persistence, DEBUG forcing, and paste accessibility priming for the practice flow.
- Added a Settings help card in More settings for quick access to KeyVox help.
- Added centralized Mac runtime flag handling for onboarding, mic picker, model-download preview, raw-text logging, and Vibes intro DEBUG controls.

### Changed

- Updated Mac onboarding, model download preview, Vibes intro, and dictation-change paths to read runtime flags through the shared `MacRuntimeFlags` source of truth.
- Updated macOS engineering and codemap documentation for first-dictation onboarding and centralized runtime flag ownership.
- Updated `KeyVoxStyleRewrite` to `1.0.4` with shared currency unit matching for redundant minor currency repair.

### Fixed

- Fixed Vibes money output repair so redundant minor currency words are removed when a rewritten decimal amount already preserves the matching source dictation evidence.
- Fixed status menu Quit so KeyVox can terminate while Settings is open.

### Package versions

KeyVox macOS 1.1.6:
- KeyVoxCore           1.0.12
- KeyVoxWhisper        1.0.0
- KeyVoxParakeet       1.0.3
- KeyVoxStyleRewrite   1.0.4
- KeyVoxLocalInference 1.0.3
- KeyVoxVibesAdapters  1.0.3

---

## [1.1.5] - 2026-05-25

Strengthens Mac Vibes rewrite repair for list cues and unsupported inserted number evidence.

### Added

- Added Vibes output repair support for preserving spoken-number list cues when local rewrites flatten raw dictated list markers.
- Added deterministic repair for unsupported inserted number evidence so ambiguous non-numeric source phrases stay ambiguous instead of being replaced with invented factual values.

### Fixed

- Fixed Vibes rewrites so ordered list numbering is preserved while ordinary spoken low-number wording can still be restored where appropriate.
- Fixed Vibes rewrites so spoken list cues can be restored while preserving cue punctuation and avoiding ordered-list marker AP-style regressions.
- Fixed Vibes rewrites so ambiguous source phrases such as approximate durations are restored when the local model inserts unsupported factual number evidence.

### Package versions

KeyVox macOS 1.1.5:
- KeyVoxCore           1.0.12
- KeyVoxWhisper        1.0.0
- KeyVoxParakeet       1.0.3
- KeyVoxStyleRewrite   1.0.3
- KeyVoxLocalInference 1.0.3
- KeyVoxVibesAdapters  1.0.3

---

## [1.1.4] - 2026-05-23

Refines Mac Vibes examples and strengthens deterministic numeric repair for local rewrite output.

### Added

- Added dictation-provider-aware Vibes example text so Mac settings and the Vibes intro can show examples that match the active Whisper or Parakeet dictation model.
- Added shared factual number evidence repair through `KeyVoxStyleRewrite` `1.0.2` for changed, deleted, and separator-drifted numeric values in rewritten text.
- Added deterministic time-versus-decimal separator repair so source evidence can preserve values such as `5:30` and `5.30` correctly after local model rewriting.

### Changed

- Updated the Mac Vibes settings card and Vibes intro window to pass the active dictation model into the shared style example formatter.
- Updated money fact repair to parse multi-token spoken number phrases through the shared number evidence path before applying currency-specific repair.
- Updated Chill formatting so colon-separated numeric runs collapse consistently with its relaxed punctuation policy.
- Updated macOS engineering and codemap documentation for the expanded style rewrite output repair ownership.

### Fixed

- Fixed Mac Vibes examples so Parakeet users see spoken-number-oriented examples instead of Whisper-style numeric punctuation examples.
- Fixed Vibes rewrites so decimal and time separators are less likely to drift when rewritten output changes punctuation around numeric evidence.
- Fixed Vibes rewrites so factual numeric values are restored more consistently when the local model changes or deletes number evidence between otherwise aligned source words.

### Package versions

KeyVox macOS 1.1.4:
- KeyVoxCore           1.0.12
- KeyVoxWhisper        1.0.0
- KeyVoxParakeet       1.0.3
- KeyVoxStyleRewrite   1.0.2
- KeyVoxLocalInference 1.0.3
- KeyVoxVibesAdapters  1.0.3

## [1.1.3] - 2026-05-22

Refines Mac Vibes with stronger factual-number repair, refreshed bundled style adapters, and shared address-number protection in dictation cleanup.

### Added

- Added deterministic Vibes output repair for address numbers, ordinal street contexts, deleted low-number evidence, money amounts, currency operands, and AP-style low-number cleanup through `KeyVoxStyleRewrite` `1.0.1`.
- Added focused Vibes output repair modules for punctuation, AP-style numbers, address facts, deleted number evidence, money facts, and shared repair support.
- Added live local-model validation coverage for address-shaped inputs, money and time boundaries, ordinal streets, math operands, AP-style repair behavior, and deleted-number repair behavior through `KeyVoxLocalInference` `1.0.3`.
- Added model-training continuation materials for Casual alpha-6, alpha-7, alpha-8, and alpha-9 plus Polished alpha-026 to strengthen money, address, time, spoken-year, and rating-formatting boundaries.

### Changed

- Updated the bundled Polished Vibes adapter to `polished-alpha-026-lora.gguf` through `KeyVoxVibesAdapters` `1.0.3`.
- Updated the bundled Casual Vibes adapter to `casual-alpha-9-lora.gguf` through `KeyVoxVibesAdapters` `1.0.3`.
- Updated the Vibes adapter catalog so Polished and Casual resolve to the refreshed bundled adapter resources.
- Moved rating-formatting behavior away from adapter-specific expectations and into deterministic AP-style number repair.
- Removed the second dictionary normalization pass after Vibes style output transformation so dictionary correction remains owned by base dictation post-processing.
- Updated Vibes training documentation and shared engineering notes for the refreshed adapter and output repair behavior.

### Fixed

- Fixed Vibes rewrites so source address numbers stay factual when local rewrite output collapses digits, turns addresses into time-shaped text, or drifts around ordinal street wording.
- Fixed Vibes rewrites so money amounts, split dollar-and-cent phrases, and numeric currency operands are restored when source dictation contains clear currency evidence.
- Fixed Vibes rewrites so removed low-number words can be restored when the surrounding rewritten text still aligns with the source evidence.
- Fixed shared dictation cleanup through `KeyVoxCore` `1.0.12` so address numbers such as `1152 North Washington Street` are protected from thousands grouping while nearby ordinary quantities can still receive separators.

### Package versions

KeyVox macOS 1.1.3:
- KeyVoxCore           1.0.12
- KeyVoxWhisper        1.0.0
- KeyVoxParakeet       1.0.3
- KeyVoxStyleRewrite   1.0.1
- KeyVoxLocalInference 1.0.3
- KeyVoxVibesAdapters  1.0.3

## [1.1.2] - 2026-05-20

Refines Mac Vibes with promoted money-boundary adapters, shared dictionary correction improvements, and tighter local rewrite model lifecycle management.

### Added

- Added model-training datasets, lineage, manifests, validation scripts, and run materials for the promoted Polished `alpha-025` and Casual `alpha-5` Vibes adapters.
- Added live validation coverage for Polished and Casual money-boundary behavior, including dollar amounts followed by day counts, price ratios, star rating counts, and math expressions with money operands.
- Added shared dictation pipeline coverage to ensure dictionary correction still applies after Vibes-style output transformation.

### Changed

- Updated the bundled Polished Vibes adapter to `polished-alpha-025`, improving separation between money and adjacent quantity phrases while preserving spoken-year and age-compound fixes.
- Updated the bundled Casual Vibes adapter to `casual-alpha-5`, improving separation between money and adjacent quantity phrases while preserving Casual voice and spoken-year handling.
- Updated the Vibes adapter catalog and third-party notices to point at the promoted bundled adapter resources.
- Updated shared dictation cleanup through `KeyVoxCore` `1.0.11` so stylized two-token dictionary phrases such as KeyVox product names can recover from near-miss leading tokens when the trailing token matches exactly.
- Updated Mac Vibes runtime behavior so local rewrite model loading is tied to dictation or Vibe-change work instead of app launch or install-readiness prewarming.
- Updated macOS engineering documentation and codemap notes for the promoted adapters and utterance-scoped Vibes runtime lifecycle.

### Fixed

- Fixed Vibes local rewrite resource cleanup so pending prewarm work is cancelled and the cached local rewrite model unloads after dictation transforms, Vibe-change transforms, and quick-tap cancellation paths.
- Fixed post-transformation dictionary normalization so style rewrites that introduce dictionary near misses can still be corrected before casing and paste.
- Fixed built-in KeyVox product-name correction to use the same canonical matcher path as user dictionary entries instead of package-owned alias shortcuts.

### Package versions

KeyVox macOS 1.1.2:
- KeyVoxCore           1.0.11
- KeyVoxWhisper        1.0.0
- KeyVoxParakeet       1.0.3
- KeyVoxStyleRewrite   1.0.0
- KeyVoxLocalInference 1.0.2
- KeyVoxVibesAdapters  1.0.2

## [1.1.1] - 2026-05-18

Refines the Mac Vibes release with updated bundled style adapters, safer spoken-number cleanup, a new Dock icon preference, and more reliable paste behavior in blank web editors and Chromium-style browser surfaces.

### Added

- Added a More settings toggle to hide the Dock icon when all KeyVox windows are closed, while keeping the Dock icon visible whenever managed windows such as Settings, onboarding, updater, post-update notices, or the Vibes intro are open.
- Added Dock activation-policy management so KeyVox can switch between regular and accessory app modes based on the new Dock icon preference, visible app windows, and the existing older-macOS menu-bar compatibility rule.
- Added generic Chromium-style paste verification across related renderer and helper processes inside the front app bundle, so successful menu paste can be verified even when the editable field is owned by a nested browser process.
- Added updated Vibes model-training datasets, lineage, manifests, and run materials for the refreshed Casual and Polished adapters.

### Changed

- Updated the bundled Casual Vibes adapter to `casual-alpha-4`, improving spoken-year handling while preserving the existing time, money, and quantity guards.
- Updated the bundled Polished Vibes adapter to `polished-alpha-024`, improving spoken-year handling and teen age-compound precision, including cases such as `18-year-old` versus `8-year-old`.
- Updated shared dictation cleanup through `KeyVoxCore` `1.0.10` so spoken year references remain ungrouped when context indicates a year, while nearby quantities still receive thousands separators when context indicates an amount.
- Updated shared numeric normalization to handle adjacent spoken-number phrases more precisely so ignored trailing words are not accidentally consumed into a prior number span.
- Updated Vibes adapter catalog and third-party notices to point at the refreshed bundled Casual and Polished adapter resources.
- Updated local inference package tracking through `KeyVoxLocalInference` `1.0.1` with live validation coverage for the refreshed Vibes adapters.
- Updated macOS codemap and engineering notes around paste verification, warning behavior, and bundle-specific paste trust policy.
- Split Mac transcription manager responsibilities across focused binding, overlay/debug, and recording-session extensions without changing the dictation workflow.

### Fixed

- Fixed blank Quill-style and placeholder-backed web editors so empty editor state is treated as caret position zero with no active selection, preventing hidden placeholder text or stale editor state from affecting capitalization and spacing decisions.
- Fixed paste spacing and capitalization fallbacks so missing AX context no longer reuses the last successful insertion signal to add a leading space or lowercase the next paste in unrelated opaque web surfaces.
- Fixed Atlas-style browser paste verification after browser relaunch by finding the related renderer/helper accessibility process that owns the edited text field, without hard-coding the browser bundle ID.
- Fixed paste warning behavior so menu fallback success still requires observable insertion evidence, preserving recovery warnings when KeyVox cannot verify that paste completed.
- Fixed paste verifier latency by ignoring degenerate AX snapshots, filtering related helper processes to those with an accessibility surface, and stopping candidate scans as soon as usable verification context is found.
- Fixed Dock icon visibility updates after app windows are opened, hidden, closed, dismissed, or shown from updater and Vibes intro flows.

### Package versions

KeyVox macOS 1.1.1:
- KeyVoxCore           1.0.10
- KeyVoxWhisper        1.0.0
- KeyVoxParakeet       1.0.3
- KeyVoxStyleRewrite   1.0.0
- KeyVoxLocalInference 1.0.1
- KeyVoxVibesAdapters  1.0.1

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
