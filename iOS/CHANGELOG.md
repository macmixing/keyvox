# Changelog

All notable changes to this project will be documented in this file.

The format loosely follows Keep a Changelog and the project uses semantic versioning.

---

## [1.2.5] Build 3 - 2026-05-29

Adds reversible long-press formatting for the latest untouched dictation, including audio-derived paragraphs, deterministic lists, and Caps Lock reversal.

### Added

- Added audio-derived paragraph and inline variants from Whisper and Parakeet so Paragraphs can be applied later from captured audio boundary evidence instead of guessed from visible text.
- Added deterministic paragraph/list variants for every base dictation state so the keyboard can swap Paragraphs and Lists on the latest untouched insertion without rerunning transcription.
- Added selected pre-Caps text to latest dictation artifacts so Caps Lock can be reversed after Vibes or base dictation output has already been inserted.
- Added Caps Lock long-press support for applying or removing uppercase formatting on the latest untouched dictation.

### Changed

- Updated keyboard long-press formatting so Paragraphs, Lists, Vibes, and Caps Lock behave as reversible state controls for the latest untouched KeyVox insertion.
- Updated Vibes replacement caching to reuse rendered style output for the current paragraph/list state instead of reprocessing already-rendered combinations.
- Updated deterministic list variants to honor the configured list render mode, including preserving multiline list separation when converting from no-list to list.
- Updated Paragraphs and Lists tap handling so accidental taps during an active untouched insertion do not silently change the stored default setting.
- Updated Caps Lock visual state so active dictation casing uses the same light and dark active color pattern as the other formatting controls.
- Split the keyboard latest-insertion dictation-change controller into focused files grouped under `DictationChange`.
- Updated iOS engineering and codemap documentation for latest-artifact state, pre-Caps selected text, deterministic long-press controls, and Caps Lock reversal.

### Fixed

- Fixed Paragraphs and Lists indicators so they reflect the formatting actually applied to the current untouched insertion instead of lighting from unrelated deterministic variants.
- Fixed paragraph/list no-op handling so long press does not show processing feedback when the stored variant would not change the text.
- Fixed Vibes reapply after list/paragraph changes so cached rendered variants are preserved across deterministic state changes.
- Fixed list reapply after Vibes changes so multiline list structure keeps the proper separation before the first list marker.
- Fixed Caps Lock reversal for dictated text inserted while Caps Lock and a Vibe are active.
- Fixed Caps Lock display state so changing Paragraphs, Lists, or Vibes while Caps is active preserves the reversible uppercase layer.
- Fixed Caps Lock long-press visuals so yellow means an active reversible transform while the filled icon and pressed state follow the transformed casing.

### Package versions

KeyVox iOS 1.2.5
  KeyVoxCore           1.0.13
  KeyVoxLocalInference 1.0.3
  KeyVoxParakeet       1.0.3
  KeyVoxStyleRewrite   1.0.5
  KeyVoxTTS            1.0.1
  KeyVoxVibesAdapters  1.0.3
  KeyVoxWhisper        1.0.0

---

## [1.2.4] - 2026-05-24

Extends the Vibes trial, refreshes Vibes trial copy, and strengthens deterministic numeric repair for local rewrite output.

### Added

- Added a shared Vibes trial duration policy so the containing app, keyboard extension, UI copy, and tests read the same local trial length.
- Added a 3-day Vibes trial with a versioned trial-start defaults key so users get the refreshed trial window without resetting intro, unlock, model, or selected-Vibe state.
- Added shared Vibes trial remaining-time formatting with adaptive day, hour, and minute output.
- Added dictation-provider-aware Vibes example text so the Style tab and Vibes intro can show examples that match the active Whisper or Parakeet dictation model.
- Added an English-only language support disclosure to the Vibes usage intro scene.
- Added a Settings help card that opens the KeyVox FAQ and contact page with campaign tracking.
- Added shared factual number evidence repair through `KeyVoxStyleRewrite` `1.0.2` for changed, deleted, and separator-drifted numeric values in rewritten text.
- Added Vibes output repair support for preserving spoken-number list cues when local rewrites flatten raw dictated list markers.
- Added deterministic time-versus-decimal separator repair so source evidence can preserve values such as `5:30` and `5.30` correctly after local model rewriting.

### Changed

- Updated Vibes intro, unlock, and Style tab copy around trials, unlock prompts, active-trial status, and missing-model download guidance.
- Updated the Vibes info sheet to keep a bottom `Vibe Now` CTA for already-unlocked users.
- Updated the Speak intro sheet so its primary action advances through intro scenes and only offers `Speak Now` or `Try Now` on the final relevant scene.
- Moved the Vibes English-only disclosure from the examples intro scene to the usage intro scene, matching the Speak disclosure placement and styling.
- Updated the GitHub support card in Settings so only the `Open` action button launches GitHub Sponsors.
- Updated the keyboard Vibes trial gate to use the shared trial duration policy instead of a separate extension-side duration constant.
- Extracted keyboard paragraph/list deterministic formatting into a focused formatter so latest-insertion session handling stays separate from text-shaping rules.
- Shared keyboard long-press processing indicator and haptic handling across Vibes, Paragraphs, and Lists changes.
- Updated money fact repair to parse multi-token spoken number phrases through the shared number evidence path before applying currency-specific repair.
- Updated Chill formatting so colon-separated numeric runs collapse consistently with its relaxed punctuation policy.
- Updated iOS engineering and codemap documentation for the Vibes trial policy, trial time formatter, expanded style rewrite output repair ownership, and keyboard deterministic formatting split.

### Fixed

- Fixed Vibes trial state so the refreshed 3-day trial uses a new versioned trial-start key without clearing unrelated Vibes state.
- Fixed Vibes trial remaining-time copy so active trials can display days and hours instead of only hour/minute text.
- Fixed the Style tab `Try Now` action so explicitly requested Vibes sheets can present immediately after onboarding while automatic intro deferral still waits for the next eligible launch.
- Fixed the Speak intro so first-time users are guided through the scenes before the final setup or start action instead of seeing the same primary action on every scene.
- Fixed Vibes examples so Parakeet users see spoken-number-oriented examples instead of Whisper-style numeric punctuation examples.
- Fixed Vibes rewrites so decimal and time separators are less likely to drift when rewritten output changes punctuation around numeric evidence.
- Fixed Vibes rewrites so factual numeric values are restored more consistently when the local model changes or deletes number evidence between otherwise aligned source words.
- Fixed Vibes rewrites so ambiguous non-numeric source phrases are restored when the local model inserts unsupported factual number evidence.
- Fixed Vibes rewrites so decimal money amounts do not keep duplicate minor currency words when the local model formats dollars and cents.
- Fixed Vibes rewrites so spoken list cues can be restored while preserving cue punctuation and avoiding ordered-list marker AP-style regressions.
- Fixed keyboard Paragraphs and Lists toggle display so it reflects the active untouched insertion state and returns to the stored settings state when the insertion is edited or selection changes.
- Fixed keyboard paragraph/list long-press changes so processing haptics fire consistently and numbered list structure is preserved when paragraph formatting is reverted.

### Package versions

KeyVox iOS 1.2.4
  KeyVoxCore           1.0.12
  KeyVoxLocalInference 1.0.3
  KeyVoxParakeet       1.0.3
  KeyVoxStyleRewrite   1.0.2
  KeyVoxTTS            1.0.1
  KeyVoxVibesAdapters  1.0.3
  KeyVoxWhisper        1.0.0

## [1.2.3] - 2026-05-22

Improves Vibes factual-number preservation, refreshes bundled Polished and Casual adapters, and fixes the keyboard Vibes key after an edited dictation.

### Added

- Added deterministic Vibes output repair for address numbers, ordinal street contexts, deleted low-number evidence, money amounts, currency operands, and AP-style low-number cleanup.
- Added focused Vibes output repair modules for punctuation, AP-style numbers, address facts, deleted number evidence, money facts, and shared repair support.
- Added live local-model coverage for address-shaped inputs, money and time boundaries, ordinal streets, math operands, AP-style repair behavior, and deleted-number repair behavior.
- Added continuation training materials for Casual alpha-6, alpha-7, alpha-8, and alpha-9 plus Polished alpha-026 to strengthen money, address, time, spoken-year, and rating-formatting boundaries.

### Changed

- Updated the bundled Polished Vibes adapter to `polished-alpha-026-lora.gguf`.
- Updated the bundled Casual Vibes adapter to `casual-alpha-9-lora.gguf`.
- Updated the adapter catalog so Polished and Casual resolve to the refreshed bundled Vibes adapter resources.
- Moved rating-formatting behavior away from adapter-specific expectations and into deterministic AP-style number repair.
- Removed the second dictionary normalization pass after Vibes style output transformation so dictionary correction remains owned by base dictation post-processing.
- Updated Vibes training documentation and iOS engineering documentation for the refreshed adapter and output repair behavior.

### Fixed

- Fixed Vibes rewrites so source address numbers stay factual when local rewrite output collapses digits, turns addresses into time-shaped text, or drifts around ordinal street wording.
- Fixed Vibes rewrites so money amounts, split dollar-and-cent phrases, and numeric currency operands are restored when source dictation contains clear currency evidence.
- Fixed Vibes rewrites so removed low-number words can be restored when the surrounding rewritten text still aligns with the source evidence.
- Fixed shared dictation cleanup so address numbers such as `1152 North Washington Street` are protected from thousands grouping while nearby ordinary quantities can still receive separators.
- Fixed the iOS keyboard Vibes key so, after the latest dictation has been edited or otherwise no longer matches the untouched insertion, the key shows the selected next Vibe instead of the stale Vibe from the previous transform.

### Package versions

KeyVox iOS 1.2.3
  KeyVoxCore           1.0.12
  KeyVoxLocalInference 1.0.3
  KeyVoxParakeet       1.0.3
  KeyVoxStyleRewrite   1.0.1
  KeyVoxTTS            1.0.1
  KeyVoxVibesAdapters  1.0.3
  KeyVoxWhisper        1.0.0

## [1.2.2] - 2026-05-20

Fixes Vibes rewrite memory cleanup after dictation, refreshes bundled Vibes adapters for money-boundary recognition, and improves shared dictionary matching for stylized product phrases.

### Fixed

- Released warmed Vibes rewrite resources after dictation finishes, is cancelled, becomes stale, has no captured audio, or cannot continue because the dictation model is unavailable.
- Cancelled pending Vibes rewrite prewarm work before unloading local rewrite resources so the app does not keep the local model resident after a dictation session no longer needs it.
- Updated the bundled Casual Vibes adapter to alpha-5 so adjacent money and quantity phrases stay separated in dollar amounts followed by day counts, price ratios, star rating counts, and math expressions with money operands.
- Updated the bundled Polished Vibes adapter to alpha-025 so adjacent money and quantity phrases stay separated while preserving the teen-number age-compound fix from the 1.2.1 line.
- Added live local-model guard coverage for Polished and Casual money-boundary behavior.
- Fixed shared dictionary matching so two-token stylized entries such as `KeyVox Speak` can recover leading-token near misses like `Kivok Speak` through the normal dictionary matcher path.
- Removed built-in KeyVox alias variants so the package-owned entries use the same canonical dictionary matching path as user dictionary entries.
- Reapplied shared dictionary normalization after Vibes output transformation so transformed text can still be corrected before casing and paste.

### Package versions

KeyVox iOS 1.2.2 (build 1)
  KeyVoxCore           1.0.11
  KeyVoxLocalInference 1.0.2
  KeyVoxParakeet       1.0.3
  KeyVoxStyleRewrite   1.0.0
  KeyVoxTTS            1.0.1
  KeyVoxVibesAdapters  1.0.2
  KeyVoxWhisper        1.0.0

## [1.2.1] - 2026-05-18

Fixes a keyboard extension crash path by rasterizing the Vibes key logo before display, improves Vibes spoken year and age-compound recognition, and preserves spoken year formatting during shared dictation cleanup.

### Fixed

- Fixed a keyboard extension crash that could prevent affected users from opening the KeyVox keyboard from the globe key when the Vibes logo rendered through live template-vector tinting.
- Updated the Vibes key none-state logo to render as a cached tinted bitmap before assignment while preserving the existing Vibes key layout, state colors, and behavior.
- Updated bundled Casual and Polished Vibes adapters so spoken year references are preserved more reliably during local rewrite.
- Updated the bundled Polished Vibes adapter to alpha-024 so teen-number age compounds such as `eighteen year old` become `18-year-old` instead of `8-year-old`.
- Added Polished Vibes guard coverage for `8-year-old` versus `18-year-old`, `$180` versus `$1,800`, adjacent teen age compounds, and the full 2010s spoken-year sweep.
- Fixed shared dictation cleanup so spoken year references stay ungrouped while nearby spoken quantities can still receive thousands separators.

### Package versions

KeyVox iOS 1.2.1 (build 5)
  KeyVoxCore           1.0.10
  KeyVoxLocalInference 1.0.1
  KeyVoxParakeet       1.0.3
  KeyVoxStyleRewrite   1.0.0
  KeyVoxTTS            1.0.1
  KeyVoxVibesAdapters  1.0.1
  KeyVoxWhisper        1.0.0

## [1.2.0] - 2026-05-14

Introduces KeyVox Vibes on iPhone with downloadable local rewrite models, keyboard-side rewrite and format controls, a Vibes trial and unlock flow, and new shared rewrite/runtime packages.

### Added

- KeyVox Vibes on iPhone, including Casual, Polished, and Chill rewrite modes for dictated text.
- New shared `KeyVoxStyleRewrite`, `KeyVoxLocalInference`, and `KeyVoxVibesAdapters` packages for local style rewriting, local GGUF inference, and bundled Vibes LoRA adapters.
- Downloadable local Vibes AI model management in the app, including install, readiness, repair, and delete handling for the rewrite model.
- Style tab and keyboard Vibes controls so users can choose a Vibe, apply it after dictation, compare in-app examples, switch between generated variants from the original dictated text, and restore the latest untouched insertion.
- Keyboard post-dictation format changes for the latest untouched insertion, including reversible Paragraphs and Lists changes from the keyboard.
- Vibes intro, trial, help, and unlock flows with shared StoreKit purchase and restore handling.
- A left-handed keyboard control-strip layout option and expanded keyboard accessory controls for Vibes, Dictionary, and Settings.
- Vibes branding assets, the shared `KeyVoxProducts.storekit` configuration, and local rewrite downloader surfaces in the Style and Settings flows.
- A delayed transcription landing haptic for the iOS keyboard after dictated text lands.
- Vibes onboarding and intro-sheet presentation coordination so the first Vibes introduction waits until onboarding and other feature sheets are eligible.
- Bundled `llama.xcframework` runtime and debug-symbol packaging for the new local inference package.

### Changed

- Integrated local rewrite handling with shared chunk planning, explicit context budgeting, typed local-model errors, output repair, prompt-leak fallback handling, and Chill formatting that preserves meaningful numeric symbols and structure more reliably.
- Integrated shared local inference runtime support with explicit caller-owned context limits, split llama loading and prompting components, packaged adapter support, and versioned package tracking for the shipped runtime and adapters.
- Wired Vibes routing, access checks, restore handling, onboarding presentation, intro and unlock sheet defaults, settings, and keyboard state synchronization across the keyboard and containing app.
- Wired Chill and post-dictation formatting support that preserves meaningful structure and symbols, including paragraphs, lists, email-style tokens, emoji, math-style text, phone numbers, dates, percentages, and numeric separators.
- Updated shared dictation cleanup so built-in `KeyVox Vibes` name handling, spoken decimal and version phrases, and list-marker parsing stay more stable.
- Updated KeyVox Speak text cleanup so numbered list markers written like `1)` read more naturally during copied-text playback.
- Updated Speak settings and sheet flows so setup, unlock, and ready states stay separated, unlocked Speak upsell copy stays hidden, and the keyboard can warn when no dictation model is installed.
- Updated iOS docs, package changelogs, version tracking, and third-party notices to cover the shipped Vibes runtime, adapters, and architecture.

### Fixed

- Fixed shared transcription cleanup for observed leading asterisk censorship artifacts before downstream formatting runs.

### Package versions

KeyVox iOS 1.2.0
  KeyVoxCore           1.0.9
  KeyVoxLocalInference 1.0.0
  KeyVoxParakeet       1.0.3
  KeyVoxStyleRewrite   1.0.0
  KeyVoxTTS            1.0.1
  KeyVoxVibesAdapters  1.0.0
  KeyVoxWhisper        1.0.0

## [1.1.2] - 2026-05-06

Fixes warm keyboard dictation handoff in Messages edit mode so recording starts immediately, missed IPC state updates are reconciled, and completed transcription text is inserted into the edited message field.

### Fixed

- Fixed a Messages edit-mode keyboard dictation handoff where warm recordings could appear flatlined, remain stuck transcribing, or fail to insert text when recording state or transcription-ready notifications were missed.

### Package versions

KeyVox iOS 1.1.2
  KeyVoxCore       1.0.8
  KeyVoxWhisper    1.0.0
  KeyVoxParakeet   1.0.3
  KeyVoxTTS        1.0.0

## [1.1.1] - 2026-05-05

Ships a focused Parakeet dictation fix that removes unsupported prompt priming from the iOS Parakeet path while preserving dictionary correction through post-transcription matching.

### Fixed

- Fixed a Parakeet dictation failure where dictionary prompt text could corrupt the decoder state before audio decoding and cause the beginning of words to be dropped or mangled.
- Removed Parakeet dictionary hint forwarding from the shared iOS dictation service path so Parakeet starts decoding from its normal blank-token state.
- Preserved dictionary correction behavior through the existing shared dictionary matcher instead of relying on unsupported Parakeet prompt hinting.

### Package versions

KeyVox iOS 1.1.1
  KeyVoxCore       1.0.8
  KeyVoxWhisper    1.0.0
  KeyVoxParakeet   1.0.3
  KeyVoxTTS        1.0.0

## [1.1.0] - 2026-04-24

Ships KeyVox Speak as a major iPhone release with local copied-text playback, a new Share extension, keyboard playback controls, native Shortcuts integration, PocketTTS model management, StoreKit unlock support, and shared dictation/runtime refinements.

### Added

- KeyVox Speak copied-text playback on iPhone, powered by the new local `KeyVoxTTS` PocketTTS runtime package for on-device synthesis.
- A Speak Copied Text Home card with local playback, install shortcuts, preparation progress, pause/resume/stop controls, transcript display, replay, replay scrubbing, background-readiness status, and voice switching when multiple voices are installed.
- PocketTTS shared-engine and per-voice installation flows, including install, repair, delete, progress, manifest validation, bundled voice previews, and playback voices for Theo, Anne, Jordan, Sharon, Victoria, Dean, Jon, and Parker.
- Speak Timeout controls so generated audio can stay replayable while KeyVox manages how long the local speech engine stays warm after playback.
- A KeyVox Share extension that can extract shared text, URLs, web/HTML payloads, PDFs, and images, including selectable PDF text, rendered-PDF OCR fallback, image OCR, web article cleanup, and app handoff for immediate playback.
- Keyboard-side KeyVox Speak support with a Speak copied text button, App Group request handoff, playback state reconciliation, pause/resume/stop transport controls, and playback progress display.
- Official KeyVox Speak App Shortcuts routing for copied-text playback through the system Shortcuts surface.
- KeyVox Speak intro, help, install, and unlock sheets with ready-state-aware scene selection and post-onboarding presentation control.
- KeyVox Speak Unlimited StoreKit support, including daily free-speak gating, product loading, purchase, restore, current-entitlement refresh, transaction update handling, and local StoreKit configuration.
- A never-disable option for dictation sessions.
- Third-party notices inside the iOS app and licensing attribution for downloaded PocketTTS model artifacts.
- Built-in dictionary handling for KeyVox and KeyVox Speak names so product terms are corrected and included in dictation hint prompts even before users add custom dictionary entries.

### Changed

- Updated dictation audio coordination so recording and Speak playback hand off cleanly when moving between dictation, voice previews, copied-text playback, and warm monitoring.
- Updated the existing keyboard toolbar to integrate Speak alongside dictation controls only when the shared PocketTTS engine and at least one voice are ready.
- Updated shared TTS text preparation for arrow, slash, dash, line, and punctuation handling so copied text produces more natural speech pauses.
- Updated onboarding, Home, Settings, and Speak copy to match the final KeyVox Speak setup, help, playback, and unlock flow.
- Added debug-only App Store update lookup diagnostics and audio route-transition instrumentation for release validation without adding release logging noise.
- Reorganized iOS app, keyboard, and view source folders by responsibility, including separate composition, feedback, integration, routing, presentation, TTS, Home, Settings, Dictionary, and keyboard transport areas.
- Updated iOS documentation, project membership, package resolution, App Store README copy, app symbols, KeyVox Speak artwork, and app-update policy resources for the release.

### Fixed

- Fixed dictionary tab row state so swipe-exposed rows reset when leaving the Dictionary tab.
- Fixed shared dictation month-led year handling so phrases such as `November 2025` remain calendar references instead of being grouped as large numbers.
- Fixed shared Parakeet handling for short hallucinated or trailing no-speech output by using lexical timing, decoder no-speech probability, trailing-segment filtering, and duration-sensitive single-word confidence thresholds.
- Fixed shared Parakeet decoding for long audio with a final partial chunk so short final utterance tails are rescued and merged instead of being dropped or duplicated across overlapping decode windows.

### Package versions

KeyVox iOS 1.1.0 (build 2)
  KeyVoxCore       1.0.6
  KeyVoxWhisper    1.0.0
  KeyVoxParakeet   1.0.2
  KeyVoxTTS        1.0.0

## [1.0.3] - 2026-04-17

Fixes onboarding progression when users complete keyboard setup out of the expected step order while working through app settings.

### Fixed

- Fixed an onboarding state where users could complete microphone access, enable the KeyVox keyboard, and allow Full Access during the same Settings trip, then return to a fully checked setup screen with no way to continue.
- Fixed onboarding so users who enable the KeyVox keyboard before the dictation model finishes downloading are automatically advanced into the keyboard tour once the model is ready.

## [1.0.2] - 2026-04-09

Adds release-branch update enforcement so unsupported installs can be blocked behind a required App Store upgrade, while preserving spoken version phrases during dictation cleanup.

### Added

- Added App Store update enforcement backed by a minimum-supported-version policy manifest, including shared forced-update state that can gate keyboard usage when an upgrade is required.

### Fixed

- Fixed dictation list detection so spoken semantic-version phrases such as `one point zero point two` stay as prose instead of being reformatted as numbered-list content.

## [1.0.1] Build 3 - App Store - 2026-04-09

Polishes the iOS release branch with a more stable first-open keyboard layout, fully visible symbol popups on compact devices, and more responsive live input meter updates during recording startup.

### Changed

- Updated keyboard symbol popup sizing to account for rendered label content and shared popup padding instead of relying on key width alone.
- Moved shared live meter publication to the audio tap path before the recorder's `MainActor` UI update hop.

### Fixed

- Fixed symbol popup placement so edge keys such as `@` stay fully visible instead of clipping against the keyboard bounds on compact devices.
- Fixed the initial iOS keyboard presentation so first-open layout state applies cleanly and the cancel control visibility no longer destabilizes the release keyboard layout.
- Fixed stale live meter samples during cold-start recording handoff so the keyboard indicator receives live input updates sooner.

## [1.0.0] Build 11 - App Store - 2026-04-01

Improves iOS keyboard launch stability by removing a crash-prone microphone logo rendering path that could prevent the keyboard from appearing for some users.

### Changed

- Updated the branded keyboard logo bar to rasterize its microphone asset before display instead of relying on live vector template styling during keyboard layout.
- Switched the keyboard logo bar appearance refresh path to the iOS 17 trait change registration API.

### Fixed

- Fixed a keyboard extension crash in `KeyboardLogoBarView` triggered while rendering the toolbar microphone image during layout.
- Fixed a failure mode where affected users could not bring up the KeyVox keyboard because the extension crashed before presentation completed.

## [1.0.0] Build 10 - TestFlight - 2026-04-01

Refines the iOS onboarding and settings experience by keeping the keyboard tour input anchored to the screen width, surfacing clearer model download sizes, and splitting model-management UI into a dedicated settings extension.

### Changed

- Extracted the release-facing `Active Model` settings section into `SettingsTabView+Models.swift` to keep `SettingsTabView` lighter and easier to maintain.
- Added approximate uninstalled model size labels in Settings for Whisper Base and Parakeet TDT v3.
- Updated the iOS code map and engineering notes to reflect the extracted settings model-management surface.

### Fixed

- Fixed the onboarding keyboard tour input bar so long dictated text no longer expands the field beyond the screen width.
- Fixed `AutoFocusTextField` sizing behavior in SwiftUI layouts by removing unwanted horizontal intrinsic-width pressure.

## [1.0.0] Build 9 - TestFlight - 2026-03-31

Stabilizes the iOS keyboard presentation lifecycle so repeated globe-key swaps no longer accumulate retained keyboard trees, while preserving the active keyboard when the host app backgrounds and returns.

### Changed

- Refactored the iOS keyboard controller so presentation-tree creation, teardown, and host lifecycle handling are owned by dedicated presentation lifecycle helpers instead of being spread across the main controller file.
- Updated the keyboard lifecycle to create its presentation tree only on the real appearance path instead of during controller preload.
- Added controller-scoped debug lifecycle counters and regression seams for validating keyboard presentation creation and teardown behavior.
- Updated the iOS engineering notes and codemap to document the keyboard’s presentation-scoped lifecycle rules and host background/foreground behavior.

### Fixed

- Fixed a keyboard extension memory leak where repeated globe-key hide/show cycles could retain full keyboard presentation trees and steadily increase extension memory usage.
- Fixed retained keyboard key-grid, blur-view, and controller accumulation during repeated presentation swaps in the iOS keyboard extension.
- Fixed a regression where backgrounding the host app with the keyboard visible could leave the keyboard blank when returning to the foreground until the user cycled input modes again.

## [1.0.0] Build 8 - TestFlight - 2026-03-30

Improves iPhone dictation accuracy and reliability with better spoken-number, date, list, colon, math, and Parakeet runtime handling across the shared package layer used by the beta.

### Changed

- Improved spoken large-number normalization so thousand-scale quantities are cleaned up earlier in post-processing and read more naturally in sentence context.
- Improved month-led date normalization and protected spoken years from being regrouped into large-number output.
- Refined colon association handling for title-and-subtitle style dictation phrases such as labels, announcements, and headings.
- Tightened list detection so ordinary prose is less likely to be reformatted as a numbered list, while genuine dictated lists continue to format more reliably.
- Improved list trailing-text splitting so reminder-style sentences after a list item break out more naturally instead of being folded into the last item.
- Improved Parakeet runtime tensor handling and decoder projection normalization for steadier Core ML transcription behavior in the shared runtime layer.
- Hardened half-precision Parakeet tensor storage handling in the shared runtime package.

### Fixed

- Fixed false list formatting for spoken prose patterns that contained incidental number words but were not intended to be lists.
- Fixed cases where spoken time phrases such as `five PM` could interfere with list detection.
- Fixed cases where short final list items could fail to split cleanly before trailing commentary or reminder text.
- Fixed a regression where conjunctions such as `and` could be dropped before normalized thousand-scale quantities.
- Fixed several spoken math-equation normalization regressions involving compound numbers and exponent phrasing.

## [1.0.0] Build 7 - TestFlight - 2026-03-30

Adds model-managed Parakeet support to the iOS beta, including active model selection, per-model downloads, and a refreshed settings flow for managing on-device dictation models.

### Added

- On-device Parakeet TDT v3 as an installable dictation model alongside Whisper Base.
- A new `Active Model` settings section for choosing the installed dictation model and managing model downloads directly in the app.
- Model-aware iOS download, repair, and removal flows for Whisper Base and Parakeet TDT v3.
- Local active-model persistence so iPhone dictation can reopen with the user’s selected installed model.
- iOS migration support for moving existing Whisper installs into the new rooted `Models/whisper` layout.

### Changed

- Refactored iOS model management around model IDs instead of a single Whisper-only install path.
- Updated iOS transcription routing to follow the selected active dictation model while keeping onboarding Whisper-first.
- Replaced the previous debug-only model controls in Settings with the new release-facing model management UI.
- Updated keyboard model availability checks to follow the rooted model layout and active installed model state.

### Fixed

- Restored compatibility for older iOS model install manifests during app upgrades.
- Tightened installed-model validation so incomplete Whisper installs are no longer treated as ready.
- Prevented model delete, repair, and download flows from racing active background download jobs or starting a second model install mid-download.
- Improved first-use Parakeet loading behavior so model selection stays responsive and heavy preload work no longer blocks the settings interaction.

## [1.0.0] Build 6 - TestFlight - 2026-03-26

Polishes the iOS keyboard release with newline-aware capitalization, a unified keyboard geometry system, steadier delete behavior in single-line fields, and more natural dictionary entry capitalization.

### Added

- Newline-aware capitalization handling for iOS keyboard insertions so sentence starts stay capitalized after pressing return, including when indentation follows.
- A dedicated `KeyboardLayoutGeometry` owner for live keyboard sizing rules across the key grid and bottom toolbar rows.
- Regression coverage for newline-start capitalization behavior and repeat-delete handling in single-line host fields.
- A custom microphone toolbar icon asset for the iOS keyboard.

### Changed

- Unified keyboard layout geometry so measured key widths drive third-row, bottom-row, and landscape special-key sizing consistently.
- Refined special-key presentation by hiding the visible space-bar label, replacing the return text label with the return symbol, and tuning special-key typography.
- Refreshed the keyboard toolbar microphone presentation with updated icon treatment, glow styling, and speaking-meter gain.
- Changed dictionary entry autocapitalization from word-based behavior to sentence-based behavior for more natural phrase entry.

### Fixed

- Stabilized repeat delete in single-line host fields by tolerating transient empty-context states and avoiding repeated fallback haptics during phantom-empty proxy reads.
- Preserved leading capitalization at new line starts in the iOS keyboard capitalization heuristics.

## [1.0.0] Build 5 - TestFlight - 2026-03-21

Refines the iOS keyboard release with active-call safety messaging, consistent symbol popup alignment, and a lower-memory full access instructions flow.

### Added

- Active phone call detection in the iOS keyboard using a CallKit-backed observer.
- A toolbar warning state that blocks dictation while a phone call is active and preserves warning precedence alongside full access and microphone permission states.
- Keyboard toolbar test coverage for active-call warning behavior and precedence.
- An app version and build footer in the iOS Settings tab.

### Changed

- Shared symbol baseline-offset styling between keyboard keys and popup labels so symbol pages render consistently.
- Updated iOS code map and engineering notes to document the keyboard warning toolbar behavior.

### Fixed

- Full access instructions are now created only when the instructions screen is presented instead of being built hidden during keyboard launch.
- Removed hidden launch-time full-screen instructions view work from the keyboard path to reduce extension memory pressure on affected devices.


## [1.0.0] Build 4 - TestFlight - 2026-03-19

Initial TestFlight release of KeyVox for iPhone.

### Added

- Native iOS custom keyboard extension for system-wide access to KeyVox dictation from any text field.
- Local-first dictation system powered by on-device Whisper (`ggml-base`) for absolute privacy and zero cloud dependency.
- iCloud sync ecosystem for custom dictionaries, weekly word stats, and core style preferences across Mac and iPhone.
- Live Activities and Dynamic Island support to track active dictation sessions with quick-stop system controls.
- Deterministic post-processing pipeline for automatic paragraph detection, list formatting, and cursor-aware smart capitalization.
- Native keyboard interactions including spacebar-trackpad cursor scrubbing, customizable key haptics, caps-lock persistence, and repeating delete.
- Custom phonetic dictionary system to teach KeyVox specific industry jargon, names, and email addresses.
- Smooth, interactive onboarding tour to guide keyboard installation and test your first dictation.
- Syncable weekly word stats tracking across all KeyVox devices.

### Security

- No telemetry.
- No background speech collection.
- No network usage during transcription.

### Notes

KeyVox is designed as a deterministic, local-first dictation tool.  
All speech processing occurs on-device and no user speech data is transmitted or stored remotely.
