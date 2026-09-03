# Changelog

All notable changes to this project will be documented in this file.

The format loosely follows Keep a Changelog and the project uses semantic versioning.

---

## [1.3.7] - 2026-09-02

Adds dynamic campaign cards to Mac settings while fixing capitalization, numbered-list formatting, and custom-dictionary matches.

### Added

- Added dynamic campaign cards to the Home settings screen with relevant actions, sharing, stable selection, and cached fallback content.
- Added KeyVox as a visible initial custom-dictionary entry on fresh installations so it can be edited or deleted like any other saved term.

### Changed

- Updated custom-dictionary hints and matching to use only user-visible saved entries instead of hidden built-in KeyVox product terms.

### Fixed

- Fixed dictated text losing sentence-leading capitalization in empty editors containing only whitespace and after indented line breaks.
- Fixed numbered-list detection so strong sequential marker patterns remain intact when list items contain unrelated numbers, while preserving safeguards for ambiguous sequences.
- Fixed multiword custom-dictionary matching so every changed word requires its own phonetic support, preventing a shared exact word from masking an unrelated replacement.
- Fixed initial KeyVox dictionary seeding so a failed first write is retried without restoring entries that an existing user deleted.

---

## [1.3.6] - 2026-08-23

Improves Mac dictation in empty web editors and around existing text while strengthening silence detection, number formatting, custom-dictionary matching, and factual money preservation in Vibes rewrites.

### Changed

- Updated Parakeet to use the same shared voice-activity detection as Whisper so captures without detected speech are rejected before decoding.
- Updated dictated number formatting to preserve and group complete spoken quantities through hundreds, thousands, and their remaining tens and units.
- Updated text composition to preserve contextual capitalization after colons, use locale-aware capitalization for calendar dates and standalone month names, and add missing spacing after hyphens or before following letters, numbers, and emoji.
- Updated custom-dictionary matching to require phonetic support for non-exact replacements while still correcting supported stylized near-misses before title-cased words.
- Updated Vibes rewrites to preserve complete mixed and grouped money amounts and remove unsupported currencies introduced by the local model.

### Fixed

- Fixed empty web editors with nested placeholder content being treated as non-empty, preserving correct first-dictation capitalization and spacing.
- Fixed model-added periods appearing before existing punctuation or lowercase continuation text, while preserving punctuation before quotation marks and correctly reusing or replacing adjacent question and exclamation marks.
- Fixed terminal periods being removed before content on a new line or an adjacent URL while retaining the expected behavior for ordinary lowercase continuations.
- Fixed dictated text running into following content when a required trailing space was missing, including menu-fallback pastes that must deliver the separator after the pasted text is verified.
- Fixed distinct mixed-case product names being replaced by unrelated custom-dictionary entries with similar coarse pronunciations.
- Fixed Vibes rewrites truncating, changing, splitting, or misformatting source-backed money facts.

---

## [1.3.5] - 2026-08-20

Restores reliable window dragging throughout KeyVox and prevents upstream changes from breaking model downloads.

### Changed

- Updated overlays, settings, onboarding, warnings, and update windows to support consistent dragging from their visible surfaces.
- Pinned Parakeet and Whisper downloads to verified artifact revisions so released app versions continue receiving the model files they expect.

### Fixed

- Fixed KeyVox windows and overlays not moving when dragged while preserving Vibe pill interactions.
- Fixed Parakeet installation failing after reaching 100% when upstream model metadata changes independently of the app.

---

## [1.3.4] - 2026-08-18

Adds a guided welcome and language-selection flow to Mac onboarding while improving selection replacement spacing, Electron clipboard restoration, and custom-dictionary matching.

### Added

- Added an animated welcome screen before Mac setup.
- Added a searchable Whisper language picker with Auto Detect and the complete supported-language catalog before model and permission setup.
- Added back navigation from setup to language selection while preserving the current choice.

### Changed

- Updated onboarding to use shared action-button styling with clearer typography for welcome, language, and setup completion actions.
- Organized Mac onboarding screens and microphone setup components under one dedicated view structure and updated the architecture documentation for the expanded flow.
- Updated shared custom-dictionary matching through `KeyVoxCore` `1.2.5` to evaluate candidate-relative word endings more reliably while keeping scoring, thresholds, and single-token safety in separate responsibilities.

### Fixed

- Fixed dictation spacing when replacing a selection that begins with whitespace or punctuation so the replacement keeps the correct boundary from the preceding text.
- Fixed ordinary content selections so replacement text is not given an unnecessary leading space.
- Fixed confirmed Electron menu pastes so the user's original clipboard is restored immediately after both the expected payload and a live value change are observed, while weaker insertion evidence retains the existing safety delay.
- Fixed stylized custom-dictionary entries with plural and possessive endings so possessives require supporting context, plurals remain intact before verbs and conjunctions, and exact saved entries take precedence over shorter candidate-relative alternatives.

---

## [1.3.3] - 2026-08-15

Improves Mac dictation insertion in Electron editors, spoken punctuation, first-dictation onboarding, Vibes guidance, and audio indicator responsiveness.

### Added

- Added a timed exit from first-dictation practice so onboarding can be skipped if a successful practice dictation cannot be completed.
- Added contextual Vibes guidance that explains when Vibes AI must be downloaded before a writing style can be selected.
- Added an iPhone app download reference to the More settings help card so companion-app access is easier to discover.

### Changed

- Updated the listening indicator to filter low-frequency background noise, respond quickly to speech, and fall away more smoothly while retaining its quiet-input animation.
- Updated first-dictation practice to keep its completion state synchronized with the inserted transcription and to display configured trigger-key names more clearly.
- Updated Vibes settings so trigger-key interactions remain unavailable until Vibes AI is ready, download and installation progress retain the main action-button layout, and wrapped tip icons align with their first line of text.
- Updated shared spoken punctuation handling through `KeyVoxCore` `1.2.4` so question-mark and exclamation-point commands work after more natural direct, adverbial, particle-led, and adjective-preposition clauses, including later sentences in a transcription.

### Fixed

- Fixed Electron editors misreporting whether a newline belongs before or after the caret, preventing incorrect capitalization and spacing at line boundaries while preserving the confirmed surrounding text context.
- Fixed empty Electron fields containing invisible formatting characters so the first inserted dictation keeps document-start capitalization.
- Fixed rapid or repeated fallback pastes so clipboard capture, insertion, verification, and restoration complete as ordered transactions without one dictation overwriting another's clipboard payload.
- Fixed fallback paste in Electron apps so the insertion payload remains available long enough for Command-V to consume it before the user's original clipboard contents are restored.
- Fixed first-dictation onboarding so a successful practice transcription reliably reveals the Finish action even when the text field updates before the completion revision arrives.
- Fixed spoken question-mark and exclamation-point commands so continuation text begins with the correct sentence capitalization.
- Fixed explicit questions that refer to punctuation noun phrases so wording such as `What's wrong with the question mark?` remains text instead of being converted into a punctuation command.
- Fixed stylized split-and-join custom-dictionary matching so an unrelated short tail cannot collapse an ordinary phrase such as `link the` into a saved entry such as `LinkTrak`.
- Fixed debug transcription traces so they remain available during normal app sessions while staying suppressed during automated checks.
- Fixed the Vibes download action disappearing during download or installation progress.

---

## [1.3.2] - 2026-08-09

Improves custom-dictionary corrections, text insertion around punctuation and symbols, and dictated time formatting.

### Changed

- Updated shared text composition through `KeyVoxTextComposition` `1.0.2` so sentence capitalization works consistently after punctuation and symbol delimiters, including when trailing whitespace is present.
- Updated custom-dictionary matching through `KeyVoxCore` `1.2.3` so joined stylized number words can resolve from both digit and fully spoken forms.

### Fixed

- Fixed joined custom-dictionary entries such as `EightyEight Pilots` and `OneHundredOne Dalmatians` so equivalent numeric and spoken dictation resolves to the saved styling.
- Fixed custom-dictionary possessives before adjective-and-noun phrases so dictation such as `cue boards latest update` becomes `Cueboard's latest update`.
- Fixed unrelated multiword pronunciation matches so ordinary phrases such as `Levin means` are not rewritten as possessive dictionary entries.
- Fixed capitalization at document and sentence boundaries when punctuation or symbol delimiters appear before the inserted dictation, while preserving lowercase continuation text after non-terminal delimiters.
- Fixed missing spacing after an existing ampersand during text insertion.
- Fixed dictated times with dotted meridiems before capitalized continuation text so `11 a.m. Eastern` becomes `11:00 AM Eastern` without an extra period.

### Package versions

KeyVox macOS 1.3.2:
- KeyVoxCore            1.2.3
- KeyVoxWhisper         1.1.0
- KeyVoxParakeet        1.0.4
- KeyVoxStyleRewrite    1.0.11
- KeyVoxLocalInference  1.0.4
- KeyVoxVibesAdapters   1.0.4
- KeyVoxTextComposition 1.0.2

---

## [1.3.1] - 2026-08-05

Adds numeric dictionary matching and emoji-aware text composition while improving speech-range handling, dictation responsiveness, and Mac text insertion and overlay feedback.

### Added

- Added numeric custom-dictionary matching for equivalent digit, cardinal, ordinal, and phonetic number forms, including joined and hyphenated entries.
- Added VAD-assisted speech-range trimming that removes trailing and inter-speech silence before Whisper decoding while preserving logical paragraph chunk boundaries.
- Added stylized mixed-case preservation and emoji-aware capitalization and spacing at document, sentence, line, and list boundaries through `KeyVoxCore` `1.2.2` and `KeyVoxTextComposition` `1.0.1`.

### Changed

- Updated shared transcription post-processing and deterministic variant generation to run on a serialized background queue, keeping no-speech completions isolated to `MainActor`.
- Updated Mac Accessibility context collection to inspect preceding grapheme-safe text, the character before the previous non-whitespace character, and line-start context for more reliable composition decisions.
- Updated leading-space fallback paste so spaces and Command-V are delivered through one ordered keyboard sequence and verified as one insertion.
- Updated Mac architecture documentation and the code map for the expanded dictionary matcher ownership and shared normalization and composition behavior.

### Fixed

- Fixed numeric dictionary candidate evaluation so numeric source mappings remain aligned across variants, while singular/plural companion mismatches and unrelated plural or possessive tails are rejected.
- Fixed pronunciation-aware dictionary corrections for acronym-bearing entries such as `chat GBT` to `ChatGPT`, while unrelated phrases such as `chat got` remain unchanged.
- Fixed exact three- and four-token dictionary phrase recovery so input such as `data api client` becomes `DataAPIClient` without leaving a duplicated prefix.
- Fixed dictionary split and join matching so dotted domains are protected across two-, three-, and four-token windows, and uppercase pronunciation guards apply consistently across matching strategies.
- Fixed four-digit year preservation for qualified, coordinated, prepositional, clause-based, and extended-range years while continuing to group clear quantities; nominal identifiers such as PIN numbers remain ungrouped.
- Fixed fallback insertion in applications that normalize leading spaces during paste by keeping the spaces and pasted text in a deterministic delivery order.
- Fixed longer dictation results so cleanup and formatting no longer block the rest of the app while preserving the existing synchronous processing API where needed.
- Fixed logo-bar animation timing by rendering quiet-input and processing states through shared timeline-driven Canvas animations with elapsed-time phase projection for smooth, continuous motion between indicator updates.
- Fixed silent dictation input so dead live audio maps to the quiet animation state instead of appearing inactive, while capture classification remains separate.
- Fixed delayed overlay settle animation so the motion controller remains available while the settle work executes.

### Package versions

KeyVox macOS 1.3.1:
- KeyVoxCore            1.2.2
- KeyVoxWhisper         1.1.0
- KeyVoxParakeet        1.0.4
- KeyVoxStyleRewrite    1.0.11
- KeyVoxLocalInference  1.0.4
- KeyVoxVibesAdapters   1.0.4
- KeyVoxTextComposition 1.0.1

## [1.3.0] - 2026-08-01

Adds selectable Whisper dictation languages, rejects noise-only captures before decoding, and improves shared transcript cleanup.

### Added

- Added a Language row to Active Model settings with Auto Detect and the complete set of languages supported by Whisper Base.
- Added device-local Whisper language persistence so each Mac keeps its own selection, while missing or unsupported saved values safely return to Auto Detect.
- Added shared whole-capture voice-activity gating through `KeyVoxCore` `1.2.0` and `KeyVoxWhisper` `1.1.0`, using a bundled Silero `v5.1.2` model to identify recordings without speech before Whisper decoding.

### Changed

- Updated the Mac runtime to apply the selected Whisper language during model preparation and at the start of each transcription request so every capture uses one consistent language.
- Updated the Parakeet language row to remain on Auto Detect with guidance to its supported-language FAQ, without overwriting the saved Whisper selection.
- Updated Mac architecture documentation and the code map for language ownership, device-local persistence, and the Whisper voice-activity gate.

### Fixed

- Fixed steady background noise and other noise-only captures so they no longer reach Whisper decoding and produce hallucinated text, while recordings containing speech keep their complete original audio.
- Fixed compact dictated times such as `810 PM` so they normalize once to `8:10 PM` instead of becoming `8:10:00 PM`.
- Fixed strong spaced single-letter pronunciations so supported dictation such as individually spoken letters can match the intended custom dictionary term without weakening existing safeguards.
- Fixed unanchored plural split/join matches so unrelated phrases such as `main goes` do not collapse into stylized custom dictionary entries, while valid anchored replacements remain supported.
- Fixed stylized custom dictionary matching in guarded titlecase, list, noun, and particle contexts while preserving common-word protection and requiring eligible short-token evidence.
- Fixed normalized spoken email addresses so a sentence-ending period remains intact when the following sentence is initially captured as part of the domain.
- Fixed qualified year references such as `in 2012 maybe`, `in maybe 2015`, and `since at least 2012` so they remain years while similarly phrased quantities still receive thousands separators.
- Fixed incidental title casing at Whisper continuation-segment boundaries while preserving proper names and dictionary-defined casing.

### Package versions

KeyVox macOS 1.3.0:
- KeyVoxCore            1.2.0
- KeyVoxWhisper         1.1.0
- KeyVoxParakeet        1.0.4
- KeyVoxStyleRewrite    1.0.11
- KeyVoxLocalInference  1.0.4
- KeyVoxVibesAdapters   1.0.4
- KeyVoxTextComposition 1.0.0

### Package changes

- `KeyVoxCore` `1.2.0` adds shared Whisper Base language selection and whole-capture voice-activity gating, and improves compact-time normalization, guarded stylized custom dictionary matching, spoken email punctuation, qualified-year preservation, and continuation-segment casing.
- `KeyVoxWhisper` `1.1.0` exposes the complete supported language set and bundles the Silero `v5.1.2` voice-activity model with a reusable detector for shared Whisper clients.

---

## [1.2.1] - 2026-07-27

Improves Mac dictation insertion around sentence, quote, and editor boundaries while expanding spoken terminal punctuation completion.

### Added

- Added shared capitalization and leading-spacing behavior through `KeyVoxTextComposition` `1.0.0`, including sentence-boundary, delimiter, and opening and closing quote awareness.

### Changed

- Updated Mac paste composition to use the shared text-composition policy while keeping Accessibility context collection, dictionary casing, and text insertion owned by the Mac app.
- Updated Accessibility inspection to capture the two preceding characters so quote boundaries and new lines can be classified from the local editor context.
- Updated Mac architecture documentation and the code map for shared text-composition ownership and the new paste coordinators.
- Updated `KeyVoxCore` to `1.1.1` with expanded spoken terminal punctuation completion for determiner-ending clauses.

### Fixed

- Fixed capitalization and spacing immediately after opening quotes, after closing quotes in sentence continuations, and after terminal punctuation followed by a closing quote.
- Fixed capitalization after an indented new line and during selection replacement so the local sentence boundary determines the inserted text casing.
- Fixed missing or partial Accessibility context so stale information from an earlier insertion does not add an unwanted leading space or incorrectly lowercase new dictation.
- Fixed spoken terminal punctuation after determiner-ending phrases so clauses such as `I'm happy to hear that exclamation point` can end with the intended punctuation while ordinary punctuation-word references remain unchanged.

### Package versions

KeyVox macOS 1.2.1:
- KeyVoxCore            1.1.1
- KeyVoxWhisper         1.0.1
- KeyVoxParakeet        1.0.4
- KeyVoxStyleRewrite    1.0.11
- KeyVoxLocalInference  1.0.4
- KeyVoxVibesAdapters   1.0.4
- KeyVoxTextComposition 1.0.0

### Package changes

- `KeyVoxCore` `1.1.1` expands spoken terminal punctuation completion to eligible determiner-ending clauses while preserving punctuation-word references and protected short phrases.
- `KeyVoxTextComposition` `1.0.0` establishes the shared source of truth for leading capitalization and spacing across sentence starts, continuations, punctuation, delimiters, and quotation marks.

---

## [1.2.0] - 2026-07-18

Adds reversible List and Paragraph formatting for the latest untouched Mac dictation, strengthens replacement safety and feedback, and preserves trailing Whisper audio.

### Added

- Added trigger-key formatting shortcuts so holding the configured trigger key and pressing `L` toggles List formatting while `P` toggles Paragraph formatting for the latest untouched dictation; repeating either shortcut reverses the change without changing saved formatting preferences.
- Added reusable formatting feedback pills with enabled, disabled, processing, and completion states, including animated List and Paragraph icons during Vibes-backed rendering.
- Added a Settings tip that explains the reversible List and Paragraph shortcuts.
- Added shared deterministic paragraph/list state, variant resolution, and text formatting through `KeyVoxCore` `1.1.0` so Mac formatting changes preserve the correct saved or rendered source across all four formatting combinations.

### Changed

- Updated latest-insertion formatting so active Vibes, all-caps presentation, cached rendered variants, and prior Vibe state remain intact while List or Paragraph formatting is applied or reversed.
- Updated formatting-chord handling so recording still starts immediately on trigger-down, then a recognized `L` or `P` chord safely discards that captured shortcut recording before applying the requested change.
- Updated latest-insertion replacement to run away from the main thread and bind each change to the original app process, Accessibility element, text range, and selection context.
- Updated Vibes and formatting feedback to share the same overlay-pill layout, processing pulse, and completion presentation.
- Updated Mac architecture documentation, the code map, and the project README for reversible formatting, shortcut ownership, overlay feedback, and latest-insertion replacement safety.
- Updated the bundled Whisper runtime through `KeyVoxWhisper` `1.0.1` from `whisper.cpp` `v1.7.5` to `v1.7.6`.

### Fixed

- Fixed Whisper dictation so the trailing audio is still decoded when less than one second remains after the final completed segment.
- Fixed latest-insertion replacement so focus, process, target-range, selection, or caret changes invalidate stale authorization instead of risking a change in the wrong field or app.
- Fixed delayed Accessibility updates, multiline replacements, repeated formatting changes, and menu fallback handling so authorized replacements retain the intended target and final caret position.
- Fixed formatting state and feedback so edited, removed, unavailable, or unchanged dictations do not report a successful toggle, while valid no-text-change transitions still preserve the correct session state.
- Fixed formatting shortcuts so consumed key events and trigger release cannot leak letters, start a Vibe action, stop another recording flow, or create duplicate actions from key repeat.
- Fixed completion feedback so the ring begins when replacement starts while paste verification continues safely in the background.
- Fixed Vibes replacement feedback so the completion ring starts with the replacement instead of waiting for post-insertion verification.
- Fixed processing-pill accessibility so the decorative pulsing icon layer is hidden while the meaningful foreground icon remains exposed.
- Fixed plural custom-dictionary homophone matching through `KeyVoxCore` `1.1.0` so unrelated pronunciation collisions such as `checks` and `cues` are rejected while valid differently spelled homophones remain supported.
- Fixed strong custom-dictionary brand corrections beside capitalized product wording so transcription variants such as `Keybox Core` resolve to `KeyVox Core` without weakening unrelated titlecase phrase protection.

### Package versions

KeyVox macOS 1.1.16:
- KeyVoxCore           1.1.0
- KeyVoxWhisper        1.0.1
- KeyVoxParakeet       1.0.4
- KeyVoxStyleRewrite   1.0.11
- KeyVoxLocalInference 1.0.4
- KeyVoxVibesAdapters  1.0.4

### Package changes

- `KeyVoxCore` `1.1.0` adds shared deterministic paragraph/list controls, saved and rendered variant resolution, paragraph collapse with ordered-list preservation, post-rewrite layout adjustment, and stronger custom-dictionary matching protections.
- `KeyVoxWhisper` `1.0.1` updates the bundled `whisper.cpp` runtime to `v1.7.6` and adopts its 100-millisecond end-of-audio threshold so short trailing dictation audio is not skipped.

---

## [1.1.15] - 2026-07-15

Improves Mac dictation punctuation, long Vibes rewrite responsiveness, and status-menu styling.

### Added

- Added shared terminal-period completion through `KeyVoxCore` `1.0.20` so eligible multi-word dictation prose ends with a period when no sentence-ending punctuation is present.

### Changed

- Updated long Casual and Polished Vibes output repair through `KeyVoxStyleRewrite` `1.0.11` so deterministic cleanup runs away from the main actor and uses bounded number-phrase analysis.
- Updated the Mac status menu to use the system-provided menu surface, native accent selection colors, and consistent action and warning-row alignment.

### Fixed

- Fixed ordinary dictation prose so missing terminal punctuation is completed consistently while existing punctuation, lists, headings, math, times, URLs, email addresses, and other non-prose output remain unchanged.
- Fixed model-supplied terminal commas so eligible completed prose ends with a period instead of `,.`.
- Fixed long Vibes rewrites so output repair no longer blocks overlay animation while preserving supported AP-style number formatting and factual number repair.

### Package versions

KeyVox macOS 1.1.15:
- KeyVoxCore           1.0.20
- KeyVoxWhisper        1.0.0
- KeyVoxParakeet       1.0.4
- KeyVoxStyleRewrite   1.0.11
- KeyVoxLocalInference 1.0.4
- KeyVoxVibesAdapters  1.0.4

### Package changes

- `KeyVoxCore` `1.0.20` adds shared terminal-period completion for eligible prose, replaces terminal commas with periods, and preserves protected punctuation and non-prose output.
- `KeyVoxParakeet` `1.0.4` adds backward-compatible runtime support for the current Parakeet Core ML artifact layouts. macOS continues to use the legacy `Encoder` and `JointDecision` artifacts, so this package change does not alter Mac Parakeet behavior.
- `KeyVoxStyleRewrite` `1.0.11` moves deterministic Vibes output repair away from the main actor and bounds long-form number analysis so long rewrites remain responsive.

---

## [1.1.14] - 2026-07-11

Improves Mac dictation dictionary matching so random recognizer titlecase is less likely to trigger accidental custom dictionary replacements.

### Changed

- Updated `KeyVoxCore` to `1.0.19` with dictionary matcher hardening for random Whisper titlecase output and shared post-transcription ownership of dictionary matching.

### Fixed

- Fixed custom dictionary matching so accidental titlecase output from Whisper does not replace ordinary words with weakly similar dictionary entries.
- Fixed common words so plain titlecase alone no longer counts as stylized dictionary evidence.
- Preserved supported structural-context dictionary corrections while requiring peer support for weak titlecase matches.
- Disabled Whisper dictionary prompt hinting so custom dictionary corrections are handled deterministically after transcription instead of being nudged upstream by prompt bias.

### Package versions

KeyVox macOS 1.1.14:
- KeyVoxCore           1.0.19
- KeyVoxWhisper        1.0.0
- KeyVoxParakeet       1.0.3
- KeyVoxStyleRewrite   1.0.10
- KeyVoxLocalInference 1.0.4
- KeyVoxVibesAdapters  1.0.4

### Package changes

- `KeyVoxCore` `1.0.19` hardens dictionary matching against random Whisper titlecase, requires corroboration before weak titlecase replacements, preserves structural-context corrections, and disables Whisper dictionary prompt hinting so dictionary corrections stay in shared post-transcription matching.

---

## [1.1.13] - 2026-07-05

Improves Mac Vibes factual repair and shared dictation cleanup so source-backed numbers, version strings, money amounts, punctuation, and known names survive local rewrite cleanup more reliably.

### Changed

- Updated `KeyVoxCore` to `1.0.18` with deterministic variant context support, refined spoken terminal punctuation guarding, and safer dictionary matching for known names.
- Updated `KeyVoxStyleRewrite` to `1.0.10` with stronger source-backed number, version, money, and deterministic variant repair for Vibes output.
- Updated Mac Vibes processing so the rewrite pipeline receives Core-owned deterministic dictation variants and can choose a no-list variant when it better preserves version-number evidence.
- Centralized the legacy Mac Vibes string processing path through the deterministic-context overload so result mapping stays consistent.

### Fixed

- Fixed Vibes rewrites so version-number dictation such as spoken dot or point-separated versions can recover the intended numeric form instead of staying as a list or mixed spoken/numeric output.
- Fixed Vibes money repair so decimal amounts such as five point three dollars remain `$5.3` instead of being repaired down to the minor digit.
- Fixed Vibes number repair so trailing spoken values, spoken `oh` digit sequences, connector-based hundreds, and nearby separate numeric facts are preserved from source evidence.
- Fixed dictionary matching so longer known names are not replaced by shorter stylized dictionary entries on weak evidence.
- Fixed spoken terminal punctuation cleanup so punctuation-word references stay protected while eligible short terminal commands can still convert to punctuation symbols.

### Package versions

KeyVox macOS 1.1.13:
- KeyVoxCore           1.0.18
- KeyVoxWhisper        1.0.0
- KeyVoxParakeet       1.0.3
- KeyVoxStyleRewrite   1.0.10
- KeyVoxLocalInference 1.0.4
- KeyVoxVibesAdapters  1.0.4

### Package changes

- `KeyVoxCore` `1.0.18` adds deterministic variant context APIs for Vibes, refines spoken terminal punctuation reference guards, and protects known titlecase names from weak stylized dictionary matches.
- `KeyVoxStyleRewrite` `1.0.10` adds deterministic repair for trailing number evidence, spoken zero digit evidence, version separators, decimal money amounts, nearby numeric facts, and connector-based hundreds, while splitting number evidence repair into focused files.

---

## [1.1.12] - 2026-06-28

Fixes Vibes decimal rewrites so source-backed values such as `5.5`, `GPT-5.6`, and `5.05` survive Casual and Polished model cleanup.

### Changed

- Updated `KeyVoxStyleRewrite` to `1.0.9` with deterministic decimal evidence preservation for Vibes output repair.

### Fixed

- Fixed Vibes decimal rewrites so source-backed spoken decimals such as five point five are preserved when Casual or Polished outputs drift to `10`, `5`, `5 point 5`, or `5 points 5`.
- Fixed fused Vibes decimal outputs such as `GPT56` so Mac rewrite repair restores deterministic output like `GPT-5.6`.
- Preserved source fractional width for decimal evidence such as `5.05` so rewritten output does not collapse it to `5.5`.

### Package versions

KeyVox macOS 1.1.12:
- KeyVoxCore           1.0.17
- KeyVoxWhisper        1.0.0
- KeyVoxParakeet       1.0.3
- KeyVoxStyleRewrite   1.0.9
- KeyVoxLocalInference 1.0.4
- KeyVoxVibesAdapters  1.0.4

### Package changes

- `KeyVoxStyleRewrite` `1.0.9` is the cherry-picked package diff from `mac-1.1.11`, adding deterministic decimal evidence repair for changed, truncated, pluralized, fused, boundary, and fractional-width Vibes decimal cases.

---

## [1.1.11] - 2026-06-13

Improves Vibes repair for connector-based spoken hundreds.

### Changed

- Updated `KeyVoxStyleRewrite` to `1.0.8` with more deterministic connector-number repair for Vibes output formatting.

### Fixed

- Fixed Vibes rewrites so spoken hundreds with connectors, such as seven hundred and fifty, are repaired as one AP-style numeric value.
- Fixed Vibes rewrites so changed connector-based hundreds can be restored from the original dictation evidence when model output drifts to a different number.

### Package versions

KeyVox macOS 1.1.11:
- KeyVoxCore           1.0.17
- KeyVoxWhisper        1.0.0
- KeyVoxParakeet       1.0.3
- KeyVoxStyleRewrite   1.0.8
- KeyVoxLocalInference 1.0.4
- KeyVoxVibesAdapters  1.0.4

---

## [1.1.10] - 2026-06-06

Improves Vibes number preservation and adds a small multi-display updater reliability improvement.

### Changed

- Updated the bundled Polished Vibes adapter through `KeyVoxVibesAdapters` `1.0.4` so Polished resolves to `polished-alpha-027-lora.gguf`, refreshed for bad-rating meaning preservation.
- Updated Polished adapter validation through `KeyVoxLocalInference` `1.0.4` with AP-style small-number expectations and clearer live prompt progress logging.
- Updated Mac local Vibes logging so adapter labels come from the shared adapter catalog.

### Fixed

- Fixed Vibes money output repair through `KeyVoxStyleRewrite` `1.0.7` so rewritten currency values can be restored from source evidence when multi-money amounts drift.
- Fixed Vibes money preservation for comma-grouped source amounts and chunked spoken money phrases such as five thousand twenty two dollars.
- Fixed the completed-update prompt so future updater flows preserve the preferred display across relaunch before showing the notice.

### Package versions

KeyVox macOS 1.1.10:
- KeyVoxCore           1.0.17
- KeyVoxWhisper        1.0.0
- KeyVoxParakeet       1.0.3
- KeyVoxStyleRewrite   1.0.7
- KeyVoxLocalInference 1.0.4
- KeyVoxVibesAdapters  1.0.4

---

## [1.1.9] - 2026-06-02

Adds spoken question mark and exclamation point support for Mac dictation.

### Added

- Added shared dictation cleanup through `KeyVoxCore` `1.0.17` so eligible spoken terminal punctuation commands such as `question mark`, `exclamation point`, and `exclamation mark` can become `?` and `!` when they end a dictated sentence.
- Added support for repeated, mixed, or punctuation-wrapped spoken terminal punctuation commands so dictation can produce symbols such as `?!` and `!?` while ordinary references to punctuation wording stay unchanged.
- Added shared Vibes output repair through `KeyVoxStyleRewrite` `1.0.6` so rewritten text can preserve terminal `!`, `?!`, and `!?` punctuation boundaries that came from spoken punctuation evidence.

### Changed

- Updated Mac engineering and codemap documentation for shared terminal punctuation normalization and Vibes terminal punctuation repair ownership.

### Fixed

- Fixed Vibes rewrites so Casual, Polished, and Chill preserve proven spoken terminal punctuation after local model rewriting or Chill heuristic formatting.

### Package versions

KeyVox macOS 1.1.9:
- KeyVoxCore           1.0.17
- KeyVoxWhisper        1.0.0
- KeyVoxParakeet       1.0.3
- KeyVoxStyleRewrite   1.0.6
- KeyVoxLocalInference 1.0.3
- KeyVoxVibesAdapters  1.0.3

---

## [1.1.8] - 2026-06-01

Improves Mac dictation cleanup for common uppercase reaction tokens and simplifies the More settings heading.

### Changed

- Changed the More settings section heading so the developer links area uses the shorter `MORE` label.

### Fixed

- Fixed shared dictation cleanup through `KeyVoxCore` `1.0.15` so uppercase reaction tokens such as `LOL`, `LMAO`, `LMFAO`, `OMG`, and `WTF` normalize to lowercase forms before final sentence casing.

### Package versions

KeyVox macOS 1.1.8:
- KeyVoxCore           1.0.15
- KeyVoxWhisper        1.0.0
- KeyVoxParakeet       1.0.3
- KeyVoxStyleRewrite   1.0.5
- KeyVoxLocalInference 1.0.3
- KeyVoxVibesAdapters  1.0.3

---

## [1.1.7] - 2026-05-30

Improves Whisper recovery for long Mac dictations that previously could drop trailing words.

### Added

- Added trailing-audio detection so Whisper can retry long captures when speech-like audio remains after the final decoded segment.

### Changed

- Updated Whisper retry selection so trailing cutoff retries can keep a recovered final word while preserving stricter selection for other retry paths.
- Split Whisper retry heuristics out of the chunk transcription flow so retry rules stay separate from transcription assembly.

### Fixed

- Fixed long Whisper dictations where the final word or words could be omitted even though speech-like audio remained in the capture.

### Package versions

KeyVox macOS 1.1.7:
- KeyVoxCore           1.0.14
- KeyVoxWhisper        1.0.0
- KeyVoxParakeet       1.0.3
- KeyVoxStyleRewrite   1.0.5
- KeyVoxLocalInference 1.0.3
- KeyVoxVibesAdapters  1.0.3

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
