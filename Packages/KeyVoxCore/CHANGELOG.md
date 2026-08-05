# Changelog

All notable changes to `KeyVoxCore` will be documented in this file.

The format loosely follows Keep a Changelog and the package uses semantic versioning for internal engine tracking within the KeyVox monorepo.

---

## [1.2.2] - 2026-08-05

Thousands-grouping, numeric dictionary matching, stylized-capitalization, and emoji-boundary normalization fixes with regression coverage.

### Includes

- Added VAD-aware Whisper speech-range selection that removes trailing and inter-speech silence before decoding while preserving logical paragraph chunk boundaries, reducing hallucinated text from accepted silence.
- Moved transcription post-processing and deterministic variant generation onto a serialized background queue so longer dictation results do not block UI work while preserving the synchronous API for callers that require it.
- Delivered no-speech dictation completions asynchronously on `MainActor`, matching the successful transcription callback isolation.
- Preserved four-digit year forms with stacked uncertainty qualifiers such as `like at least` across numeric and spoken-number normalization paths.
- Preserved coordinated year references in noun contexts while continuing to group nearby quantities.
- Reworked four-digit year-versus-quantity detection around contextual evidence instead of individual sentence-shape branches, preferring ungrouped years when the context is ambiguous while retaining grouping for clear quantities such as standalone values, plural noun complements, partitive phrases, and quantity modifiers.
- Preserved prepositional and clause-based year forms, including simple references such as `in 2015`, even when the lexical tagger labels a neighboring alphabetic token as an unclassified word.
- Preserved explicit temporal years beyond the common year range, including `year 3000`, while continuing to group unqualified quantities such as `3000`.
- Protected nominal identifiers such as PIN numbers from grouping while retaining grouping for noun-based count and total-number quantities.
- Added number-aware dictionary variants so digit, cardinal, ordinal, and phonetic number forms can resolve to the same custom entry across hyphenated and joined phrase shapes.
- Updated dictionary phonetic encoding to use canonical cardinal pronunciations for numeric and ordinal tokens.
- Required number-shaped dictionary candidates to preserve numeric alignment and strong evidence for nonnumeric companion words, preventing unrelated plural or possessive tails from triggering replacements.
- Preserved model-emitted stylized mixed-case tokens such as `eBay` at sentence and list boundaries while continuing to capitalize ordinary list items.
- Added emoji-aware sentence and line-boundary capitalization while leaving emoji-following continuation text lowercase when it follows ordinary prose.
- Added regression coverage for mixed-format inputs with preformatted and unformatted quantities, affected year forms, and nominal identifiers.
- Added regression coverage for numeric dictionary substitutions, joined and hyphenated entries, cardinal and ordinal forms, and unrelated-tail false positives.
- Added regression coverage for stylized casing, ordinary list-item capitalization, and emoji sentence boundaries.

### Notes

- `1.2.2` tracks the thousands-grouping, quantity-protection, numeric dictionary matching, stylized-capitalization, and emoji-boundary behavior used by shared dictation clients.

---

## [1.2.1] - 2026-08-02

Safer pronunciation-aware dictionary correction with complete multi-token phrase recovery.

### Includes

- Corrected acronym-bearing dictionary entries using pronunciation evidence, allowing spoken equivalents such as `chat GBT` to resolve to `ChatGPT` while leaving unrelated prose such as `chat got` unchanged.
- Applied the pronunciation safeguard consistently across standard, merged-token, middle-initial, compressed-tail, and split-join matching so equivalent input is handled the same way regardless of where the acronym appears or how the recognizer divides the phrase.
- Added exact three- and four-token phrase recovery so the matcher consumes the complete spoken span, turning `data api client` into `DataAPIClient` instead of replacing only `api client` and leaving a duplicated `data` prefix.
- Preserved established merged-token and stylized dictionary corrections while adding the new pronunciation safeguard.
- Extended dotted-domain protection across two-, three-, and four-token join windows so website text cannot be collapsed into a dictionary entry.

### Notes

- `1.2.1` bumps the tracked patch engine version for `KeyVoxCore` to cover pronunciation-aware acronym correction, complete multi-token phrase recovery, and domain-safe joining used by shared dictation clients.

---

## [1.2.0] - 2026-08-01

Shared Whisper Base language selection and voice-activity gating for dictation clients.

### Includes

- Added a shared dictation-language value and localized display-name formatter for consistent language presentation across app clients.
- Added a Whisper Base language catalog that exposes Auto Detect and the languages supported by the installed Base model without duplicating language lists in platform code.
- Added Whisper service language configuration with automatic fallback for unsupported values.
- Applied the configured language during model warmup and at the beginning of each transcription request so one request keeps a consistent language across all audio chunks.
- Added a whole-capture voice-activity gate that rejects recordings with no detected speech before Whisper decoding, preventing steady background noise from producing hallucinated text.
- Preserved the complete original recording whenever speech is detected so voice-activity detection does not trim valid words from transcription input.
- Kept transcription available through the existing decoder safeguards when voice-activity analysis is unavailable.
- Added diagnostic output for voice-activity probabilities, detected speech ranges, audio-to-ambient measurements, and primary-versus-retry decode selection.
- Prevented normalized compact times from being processed twice when the minute component is also a valid hour, avoiding output such as `8:10:00 PM` for `810 PM`.
- Allowed whitespace-delimited single-letter split pronunciations to match single dictionary terms when the remaining tail matches exactly and spelling and phonetic evidence are strong, while retaining the existing short-token and common-word safeguards.
- Prevented unanchored plural split/join matches from collapsing unrelated phrases such as `main goes` into stylized dictionary entries.
- Improved stylized dictionary matching across titlecase, list, noun, and particle contexts while preserving common-word protection and ranking only eligible stylized short-token candidates.
- Preserved sentence periods after normalized spoken email addresses when the following sentence is initially overcaptured as part of the domain.
- Expanded year-context detection across numeric and spoken-number paths to preserve four-digit years with leading or trailing uncertainty and stacked qualifiers, including `in 2012 maybe`, `in maybe 2015`, and `since at least 2012`, while continuing to add thousands separators to similarly phrased quantities such as `I need at least 2000`.
- Corrected incidental title casing at Whisper continuation-segment boundaries while preserving proper names and dictionary-defined casing.

### Notes

- `1.2.0` bumps the tracked minor engine version for `KeyVoxCore` to cover reusable Whisper language selection and voice-activity gating for dictation clients.

---

## [1.1.1] - 2026-07-21

Spoken terminal punctuation completion for determiner-ending clauses.

### Includes

- Converted eligible spoken terminal punctuation after determiner-ending phrases, including `I'm happy to hear that exclamation point.` becoming `I'm happy to hear that!`.
- Preserved the existing determiner back-reference behavior for natural phrases such as `I'm a fan of that exclamation point` becoming `I'm a fan of that!`, even when the recognizer omits terminal punctuation.
- Kept ordinary punctuation-word references such as `I typed that question mark.` and short protected determiner edges unchanged.
- Added shared normalizer and full post-processing coverage for punctuated and unpunctuated determiner-ending commands.

### Notes

- `1.1.1` bumps the tracked patch engine version for `KeyVoxCore` to cover spoken terminal punctuation completion used by shared dictation clients.

---

## [1.1.0] - 2026-07-15

Shared deterministic paragraph and list variant controls with dictionary matching protections.

### Includes

- Added shared deterministic state and control types so clients can toggle paragraph or list formatting without changing the other setting.
- Added a shared variant resolver that selects an existing rendered result when available and otherwise restores the saved deterministic source variant.
- Added deterministic text formatting that collapses paragraph breaks while preserving ordered-list line structure when lists remain enabled.
- Added post-rewrite layout adjustment across all four paragraph and list state combinations.
- Required known plural homophone candidates to share their full pronunciation before receiving the relaxed dictionary match boost, preventing unrelated words such as `checks` from becoming `cues` while preserving valid homophones such as `queues` and `cues` regardless of spelling.
- Allowed strong stylized dictionary corrections beside titlecase product context, restoring matches such as `Keybox Core` to `KeyVox Core` while retaining protection for unrelated name-like phrases.
- Added shared-engine coverage for target-state selection, saved and rendered source selection, paragraph collapse, list-line preservation, and post-rewrite formatting.
- Added shared-engine coverage for rejecting unrelated plural pronunciation collisions while preserving differently spelled plural homophone corrections.
- Added shared-engine coverage for strong stylized matches before titlecase product context while preserving unrelated titlecase phrase protection.

### Notes

- `1.1.0` bumps the tracked minor engine version for `KeyVoxCore` to cover shared deterministic paragraph and list variant controls plus dictionary match protections used by dictation clients.

---

## [1.0.20] - 2026-07-12

Terminal period completion for ordinary dictation prose.

### Includes

- Added a shared terminal-period normalizer that completes eligible multi-word prose when it has no sentence-ending punctuation.
- Replaced a terminal comma with the completed period so model-supplied commas do not produce `,.`.
- Preserved existing terminal periods, questions, exclamations, numbered lists, list items, trailing whitespace, and prose containing embedded domains or URLs.
- Kept non-prose output unchanged for standalone math, numeric or time-only results, heading-like labels, laughter-only utterances, and terminal email or website lines.
- Removed incidental single-word ASR periods while preserving explicit spoken question and exclamation punctuation.
- Updated post-processing and pipeline coverage to reflect the completed-prose output contract and the protected non-prose cases.

### Notes

- `1.0.20` bumps the tracked engine version for `KeyVoxCore` to cover consistent terminal punctuation across shared dictation clients.

---

## [1.0.19] - 2026-07-07

Dictionary matcher hardening for random Whisper titlecase output.

### Includes

- Made dictionary matching require corroboration before replacing known titlecase words with weakly similar dictionary entries, reducing accidental replacements caused by recognizer casing noise.
- Prevented common words from using plain titlecase capitalization alone as stylized dictionary evidence.
- Preserved supported structural-context dictionary corrections while keeping accidental titlecase common words unchanged unless another nearby dictionary match provides peer support.
- Disabled Whisper dictionary prompt hinting so custom dictionary behavior is owned by shared post-transcription matching instead of upstream prompt bias.
- Added shared-engine coverage for random stylized dictionary entries against ordinary titlecase words and the structural-context peer-support guard.

### Notes

- `1.0.19` bumps the tracked engine version for `KeyVoxCore` to cover dictionary matcher titlecase hardening and Whisper prompt-hinting disablement used by shared dictation clients.

---

## [1.0.18] - 2026-07-01

Spoken terminal punctuation reference guard, dictionary matcher refinement, and deterministic variant context API.

### Includes

- Refined spoken terminal punctuation eligibility so short verb phrases with explicit trailing punctuation can convert spoken commands such as `exclamation point` while punctuation-word references after verbs stay unchanged.
- Extended spoken terminal punctuation eligibility for narrow determiner back-reference phrases such as `fan of that question mark.` while keeping protected determiner reference edges unchanged.
- Restored lexical-class-based verb guarding for punctuation-word references without relying on a fixed reference-verb word list.
- Prevented dictionary matching from replacing known longer titlecase names with shorter stylized dictionary entries on weak text evidence.
- Exposed raw text, base text, base deterministic settings, and all deterministic paragraph/list variants to the shared output transformation hook so Vibes can choose from package-owned deterministic outputs without changing core list formatting behavior.
- Made deterministic text variants explicitly constructible across package boundaries so shared clients and tests can pass Core-owned deterministic variants into downstream package integrations.
- Added shared-engine coverage for the short verb phrase conversion path, determiner back-reference conversion, protected determiner edges, broader verb-shaped punctuation-word references, known-name dictionary preservation, deterministic variant context passed to output transformation, and cross-package deterministic variant construction.

### Notes

- `1.0.18` bumps the tracked engine version for `KeyVoxCore` to cover the spoken terminal punctuation reference guard, dictionary matcher refinements, and deterministic variant context API used by shared dictation clients.

---

## [1.0.17] - 2026-06-02

Terminal spoken punctuation boundary refinement.

### Includes

- Clarified the short leading reference guard for spoken terminal punctuation normalization so the boundary check directly expresses the exact two-token context it protects.

### Notes

- `1.0.17` bumps the tracked engine version for `KeyVoxCore` to cover the terminal spoken punctuation boundary refinement used by shared dictation clients.

---

## [1.0.16] - 2026-06-01

Spoken terminal punctuation normalization for shared dictation cleanup.

### Includes

- Added linguistic-token-based normalization for terminal spoken punctuation commands so dictated `question mark`, `exclamation point`, and `exclamation mark` can become `?` and `!` when they function as sentence-ending punctuation.
- Supported repeated terminal command sequences such as doubled punctuation and mixed `?!` or `!?` ordering while preserving the original command order.
- Ignored surrounding punctuation around spoken terminal commands so trailing or wrapping punctuation does not prevent the intended terminal symbol from being emitted.
- Kept ordinary references to punctuation wording unchanged by using token context and lexical-class checks before converting ambiguous phrases.
- Wired spoken terminal punctuation normalization into shared transcription post-processing before terminal time punctuation and caps handling.
- Added shared-engine coverage for supported terminal commands, repeated command sequences, punctuation-wrapped commands, clause-ending commands, and ordinary-reference false positives.

### Notes

- `1.0.16` bumps the tracked engine version for `KeyVoxCore` to cover spoken terminal punctuation normalization used by shared dictation clients.

---

## [1.0.15] - 2026-05-31

Uppercase reaction-token normalization for dictation cleanup.

### Includes

- Added `LaughterNormalizer` handling for uppercase reaction tokens so `LOL`, `LMAO`, `LMFAO`, `OMG`, and `WTF` normalize to lowercase forms.
- Added shared-engine coverage for the lowercase reaction-token normalization path.

### Notes

- `1.0.15` bumps the tracked engine version for `KeyVoxCore` to cover reaction-token casing cleanup used by shared dictation clients.

---

## [1.0.14] - 2026-05-30

Whisper retry recovery for trailing words left out of long captures.

### Includes

- Added trailing-audio detection so Whisper retries long captures when speech-like audio remains after the final decoded segment.
- Updated retry selection so a trailing-cutoff retry can keep even a single recovered final word while preserving the stricter threshold for other retry paths.
- Split Whisper retry heuristics out of the chunk transcription core so retry rules stay separate from transcription flow.
- Added shared-engine coverage for trailing cutoff detection, silent trailing audio rejection, likely-no-speech rejection, and single-word retry recovery.

### Notes

- `1.0.14` bumps the tracked engine version for `KeyVoxCore` to cover Whisper trailing-word recovery used by shared dictation clients.

---

## [1.0.13] - 2026-05-29

Audio-derived paragraph variants for deterministic dictation state.

### Includes

- Extended `TranscriptionProviderResult` so providers can return selected text plus preserved paragraph-on and inline text from the same audio boundary evidence.
- Updated Whisper and Parakeet assembly to compute both paragraph and inline forms before post-processing so later deterministic paragraph toggles can use the captured audio-derived variant.
- Updated `DictationPipeline` deterministic variants so paragraph-on states use preserved paragraph text and paragraph-off states use preserved inline text while list variants still flow through shared post-processing.
- Updated deterministic list variants to honor the configured list render mode so list reapply can preserve multiline list boundaries when Paragraphs is off.
- Added pipeline result access to the selected post-transform text before Caps Lock casing is applied so app clients can persist reversible keyboard display transforms without reprocessing dictation.
- Added shared-engine coverage for provider paragraph/inline assembly parity and pipeline deterministic paragraph variants when Paragraphs starts enabled or disabled.

### Notes

- `1.0.13` bumps the tracked engine version for `KeyVoxCore` to cover audio-derived paragraph variants and pre-Caps selected output access used by iOS keyboard deterministic long-press changes while preserving the selected dictation output contract for both app clients.

---

## [1.0.12] - 2026-05-22

Shared address-number protection and pipeline cleanup for dictation post-processing.

### Includes

- Protected address detector ranges during thousands grouping so address numbers such as `1152 North Washington Street` stay ungrouped while nearby quantities can still receive separators.
- Removed the second dictionary normalization pass after Vibes style output transformation so dictionary correction remains owned by the base dictation post-processing pass.
- Added shared-engine coverage for address numbers near ordinary grouped quantities and transformed Vibes output that must not receive dictionary correction after rewrite.

### Notes

- `1.0.12` bumps the tracked engine version for `KeyVoxCore` to cover shared address-number grouping protection and post-transform dictionary ownership used by both app clients.

---

## [1.0.11] - 2026-05-20

Shared dictionary matching refinements for stylized product phrases.

### Includes

- Removed built-in alias variants from the package-owned `KeyVox`, `KeyVox Speak`, and `KeyVox Vibes` dictionary entries so they use the same canonical matching path as user entries.
- Added shared matcher evidence for two-token stylized dictionary entries when the trailing token matches exactly and the leading token is a near miss.
- Reapplied dictionary normalization after output transformation so transformed text can still be corrected before casing and paste.
- Added shared-engine coverage for `Kivok Speak` recovery through the dictation pipeline.

### Notes

- `1.0.11` bumps the tracked engine version for `KeyVoxCore` to cover shared dictionary matching behavior used by both app clients.

---

## [1.0.10] - 2026-05-17

Shared spoken-year and quantity normalization refinements for dictation cleanup.

### Includes

- Updated spoken quantity normalization so plausible spoken year references stay ungrouped when the surrounding lexical context indicates a year.
- Kept nearby spoken quantities eligible for thousands separators when the surrounding lexical context indicates an amount.
- Tightened spoken number span selection so ignored trailing tokens are not consumed when adjacent spoken number phrases are normalized.
- Added shared-engine regression coverage for spoken year references, filler-adjacent spoken years, adjacent spoken years, and nearby spoken quantities.

### Notes

- `1.0.10` bumps the tracked engine version for `KeyVoxCore` to cover shared spoken year and quantity normalization behavior used by both app clients.

---

## [1.0.9] - 2026-05-11

Shared transcription artifact repair for provider-censored output.

### Includes

- Added a focused post-processing normalizer that repairs observed leading-f asterisk censorship artifacts before downstream time, email, website, capitalization, and punctuation finishers run.
- Wired the repair into `TranscriptionPostProcessor` so both macOS and iOS dictation clients receive the same canonical base text.
- Added shared-engine regression coverage for the observed double-asterisk and triple-asterisk output shapes.

### Notes

- `1.0.9` bumps the tracked engine version for `KeyVoxCore` to cover the shared provider-artifact repair used by both app clients.

---

## [1.0.8] - 2026-05-05

Removed Parakeet dictionary prompt forwarding from the shared service layer.

### Includes

- Updated `ParakeetService` so shared dictionary hint prompt updates are ignored for Parakeet instead of being forwarded into the Parakeet decoder.
- Simplified Parakeet warmup and model loading so Core no longer captures or passes prompt text into `KeyVoxParakeet`.
- Kept the shared dictation provider API intact while leaving dictionary correction to the existing post-transcription matcher path.
- Updated Parakeet service coverage for the prompt-free loader shape.

### Notes

- `1.0.8` bumps the tracked engine version for `KeyVoxCore` to cover the shared-service side of removing unsupported Parakeet prompt hinting while preserving dictionary matching.

## [1.0.7] - 2026-05-04

List parsing and built-in dictionary refinements for shared dictation.

### Includes

- Updated shared list detection to keep localized spoken decimal/version phrases inline instead of treating adjacent number words as list markers.
- Updated spoken-number marker parsing so compound quantity phrases stay intact when a later number word is part of the same localized integer.
- Added `KeyVox Vibes` as a package-owned built-in dictionary entry with observed alias variants, including prompt-hint coverage alongside existing built-in product names.
- Quieted shared DEBUG post-processing logs during deterministic variant generation while preserving normal live pipeline observability.

### Notes

- `1.0.7` bumps the tracked engine version for `KeyVoxCore` to cover shared list false-positive fixes, the `KeyVox Vibes` built-in dictionary entry, and deterministic-variant logging behavior used by both app clients.

## [1.0.6] - 2026-04-25

Built-in app and product dictionary handling for shared dictation.

### Includes

- Added package-owned hidden dictionary entries for `KeyVox` and `KeyVox Speak` so both app clients can correct the app and product names without requiring visible user dictionary entries.
- Added built-in alias matching for observed app-name variants such as `Kivok`, `Kivox`, and `Keyvox`, while preserving canonical `KeyVox` and `KeyVox Speak` output.
- Centralized dictionary hint prompt construction in `KeyVoxCore`, including de-duplication when a user already has a matching canonical dictionary entry.
- Moved dictionary prompt refresh ownership into the shared dictation pipeline so app clients provide audio eligibility while the package owns effective dictionary availability and prompt content.
- Tightened stylized split-join matching so fuzzy plural phrases like `key vocals` do not overcorrect to the built-in brand name, while possessive split forms like `key vox's` still normalize correctly.
- Updated adjacent-titlecase safety handling so built-in brand aliases followed by sentence punctuation are not blocked by titlecase words at the start of the next sentence.

### Notes

- `1.0.6` bumps the tracked engine version for `KeyVoxCore` to cover the shared built-in dictionary and prompt ownership behavior used by both app clients.

## [1.0.5] - 2026-04-16

Month-led year preservation for numeric grouping.

### Includes

- Updated shared numeric grouping to keep four-digit year references ungrouped when they follow full calendar month names, such as `November 2025`.
- Preserved existing thousands grouping for nearby four-digit quantities in the same transcription output.

### Notes

- `1.0.5` bumps the tracked engine version for `KeyVoxCore` to cover the shared month-led year preservation fix used by both app clients.

## [1.0.4] - 2026-04-14

Shared Parakeet no-speech handling refinements for short cue-like hallucinations.

### Includes

- Updated `ParakeetService` to preserve and filter full segment metadata across chunk assembly so likely no-speech trailing segments can be dropped before the final transcription is assembled.
- Added shared debug observability for dropped trailing segments, decoded utterance duration, and average decoder no-speech probability to make Parakeet no-speech misses easier to diagnose from package logs.
- Switched the shared Parakeet no-speech gate to use decoded utterance span rather than total captured audio length, which keeps transcription padding and late tail frames from falsely stretching short hallucinated output into confirmed speech.
- Expanded shared-engine regression coverage for padded short captures, trailing `Yeah.`-style tails, short multiword speech preservation, and the updated short single-word confidence boundary.

### Notes

- `1.0.4` bumps the tracked engine version for `KeyVoxCore` to cover the shared Parakeet no-speech handling refinements used by both app clients.

## [1.0.3] - 2026-04-12

Improved shared dictation model lifecycle observability for provider switching.

### Includes

- Added symmetric debug unload logging for `ParakeetService` so shared model teardown is visible alongside the existing Whisper unload path.
- Covered the explicit unload path and the stale-warmup cleanup paths so the shared engine logs when Parakeet is actually released from memory.

### Notes

- `1.0.3` bumps the tracked engine version for `KeyVoxCore` to cover the shared Parakeet lifecycle observability improvement used by both app clients.

## [1.0.2] - 2026-04-09

Version-separator list parsing fix for spoken semantic-version prose.

### Includes

- Updated shared list detection to stop treating spoken version separators like `point zero point` as list cadence inside ordinary prose.
- Made the version-separator gap heuristic language-aware so non-English transcriptions can still avoid the same false positive path.
- Added shared-engine regression coverage for English and Spanish spoken version prose that should remain non-list text.

### Notes

- `1.0.2` bumps the tracked engine version for `KeyVoxCore` to cover the shared spoken-version list-detection fix used by both app clients.

## [1.0.1] - 2026-04-05

Parakeet no-speech confirmation gate for short low-confidence one-shot output.

### Includes

- Added shared Parakeet utterance-gating behavior so brief low-confidence one-shot output is treated as likely no-speech before it reaches the dictation pipeline.
- Updated `ParakeetService` to apply the new gate using transcribed segment confidence and captured audio duration instead of trusting every non-empty Parakeet decode.
- Added shared-engine regression coverage for the `Yeah.`-style short low-confidence result shape while preserving higher-confidence short speech.

### Notes

- `1.0.1` bumps the tracked engine version for `KeyVoxCore` to cover the shared Parakeet no-speech confirmation behavior used by both app clients.

## [1.0.0] - 2026-03-30

Baseline tracked release of the shared KeyVox engine package.

This entry establishes the first explicit package version for `KeyVoxCore` and marks the current shared dictation engine behavior as the starting point for future package-level release tracking inside the monorepo.

### Includes

- Shared dictation pipeline orchestration through `DictationPipeline`, including transcription handoff, post-processing, no-speech handling, and final text delivery boundaries.
- Shared Whisper-backed and Parakeet-backed service integration owned inside the package, including model lifecycle, warmup, unload, and active-provider routing behavior.
- Deterministic transcription post-processing covering dictionary correction, list formatting, punctuation and whitespace cleanup, capitalization, website and email normalization, time normalization, math normalization, and related text cleanup passes.
- Package-owned dictionary persistence, matching, correction, prompt-hint generation, and supporting scoring and phonetic helpers.
- Shared list detection, list rendering, trailing split handling, and formatting support for spoken structured text.
- Shared audio helpers for chunking, silence heuristics, audio signal metrics, and post-processing support used by dictation flows.
- Bundled pronunciation resources, package-owned resource loading, and supporting pronunciation and replacement-scoring behavior.
- Package-focused regression coverage for the shared engine layer.

### Notes

- `1.0.0` is the baseline release-tracking point for `KeyVoxCore`; this changelog does not attempt to reconstruct earlier internal package history before explicit package versioning was introduced.
- Future entries should describe meaningful shared engine behavior changes, fixes, and additions that affect what shipped inside KeyVox app builds.
