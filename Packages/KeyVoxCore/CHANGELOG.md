# Changelog

All notable changes to `KeyVoxCore` will be documented in this file.

The format loosely follows Keep a Changelog and the package uses semantic versioning for internal engine tracking within the KeyVox monorepo.

---

## [1.0.18] - 2026-07-01

Spoken terminal punctuation reference guard and dictionary matcher refinement.

### Includes

- Refined spoken terminal punctuation eligibility so short verb phrases with explicit trailing punctuation can convert spoken commands such as `exclamation point` while punctuation-word references after verbs stay unchanged.
- Extended spoken terminal punctuation eligibility for narrow determiner back-reference phrases such as `fan of that question mark.` while keeping protected determiner reference edges unchanged.
- Restored lexical-class-based verb guarding for punctuation-word references without relying on a fixed reference-verb word list.
- Prevented dictionary matching from replacing known longer titlecase names with shorter stylized dictionary entries on weak text evidence.
- Added shared-engine coverage for the short verb phrase conversion path, determiner back-reference conversion, protected determiner edges, broader verb-shaped punctuation-word references, and known-name dictionary preservation.

### Notes

- `1.0.18` bumps the tracked engine version for `KeyVoxCore` to cover the spoken terminal punctuation reference guard and dictionary matcher refinements used by shared dictation clients.

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
