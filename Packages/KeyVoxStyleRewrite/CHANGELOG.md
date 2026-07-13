# Changelog

All notable changes to `KeyVoxStyleRewrite` will be documented in this file.

The format loosely follows Keep a Changelog and the package uses semantic versioning for internal style rewrite tracking within the KeyVox monorepo.

---

## [1.0.11] - 2026-07-12

Long-dictation output repair performance and main-thread responsiveness for Vibes rewrites.

### Includes

- Moved deterministic rewrite output repair away from the main actor so long Casual and Polished dictations no longer block overlay animation while repaired text is prepared.
- Prevented AP-style number repair from treating an entire long paragraph as one possible spelled-number phrase.
- Added fast number-token filtering, repeated-token caching, and bounded phrase candidates while continuing to repair every supported number occurrence across the dictation.
- Preserved connector-based hundreds, protected numeric contexts, ordinary AP-style number formatting, and existing factual number repair behavior.
- Added regression coverage for long prose containing a valid spoken number phrase.

### Notes

- `1.0.11` bumps the tracked style rewrite package version for responsive and bounded deterministic output repair during long Vibes dictations.

---

## [1.0.10] - 2026-07-03

Trailing number evidence repair, version evidence preservation, digit-sequence preservation, decimal money preservation, deterministic variant input selection, and number repair organization for Vibes rewrite output.

### Includes

- Restored source-backed trailing number evidence when a local model rewrite changes a final spoken value, including Casual cleanup output that truncated `thirty` to `3`.
- Kept AP-style formatting after factual repair so restored trailing values such as spoken thirty are emitted as `30`.
- Prevented AP-style number repair from collapsing separate nearby facts into one number while still preserving connector-based hundreds.
- Restored spoken digit sequences containing `oh` when a local model rewrite drops the zero digit, such as `one oh seven` becoming `17`.
- Restored source-backed multi-segment version numbers when local model rewrites mix spoken separators and numeric segments, including outputs such as `1.1 point 13`, `1 point 15`, and `16 point 15`.
- Preserved decimal money amounts from source dictation evidence so values such as `five point three dollars` are not repaired from `$5.3` down to `$3`.
- Added Vibes input variant selection so style rewrite callers can prefer deterministic no-list variants when source-backed version repair can recover the intended version number.
- Carried deterministic variants through style rewrite transform requests and used the selected variant as the model cleanup input while preserving the original base text for result comparison.
- Updated cleanup logging to report the actual model/repair input so selected deterministic variants are visible during Vibes diagnostics.
- Split number evidence output repair into focused decimal, changed, inserted, deleted, support, and run-analysis files under a dedicated repair folder.
- Added regression coverage for trailing changed-number evidence, separated video facts, spoken `oh` digit-sequence preservation, version separator repair, decimal money preservation, no-list variant selection, and transformer-level deterministic variant input in Vibes output repair.

### Notes

- `1.0.10` bumps the tracked style rewrite package version for deterministic trailing-number preservation, version evidence preservation, digit-sequence preservation, decimal money preservation, deterministic variant input selection, and the number evidence repair refactor.

---

## [1.0.9] - 2026-06-28

Decimal number evidence repair for Vibes rewrite output.

### Includes

- Repaired spoken decimal drift so model outputs such as `10`, `5`, `5 point 5`, and `5 points 5` restore source-backed decimals like `5.5`.
- Repaired fused prefix decimals such as `GPT56` to deterministic output like `GPT-5.6`, including start and end boundary cases.
- Preserved numeric fractional width from source evidence so values such as `5.05` are not collapsed to `5.5`.
- Added regression coverage for changed, truncated, pluralized, fused, and fractional-width decimal repair cases.

### Notes

- `1.0.9` bumps the tracked style rewrite package version for deterministic decimal evidence preservation across Vibes rewrites.

---

## [1.0.8] - 2026-06-12

Connector-based spoken number repair for Vibes output formatting.

### Includes

- Converted connector-based spoken hundreds such as seven hundred and fifty into one AP-style numeric value.
- Kept connector-number repair limited to number-token runs so surrounding dictation text is not parsed by the connector path.
- Added regression coverage for both spoken connector-number output and changed numeric output restored from source dictation evidence.

### Notes

- `1.0.8` bumps the tracked style rewrite package version for deterministic connector-number repair after local model rewrites.

---

## [1.0.7] - 2026-06-06

Money and number evidence repair for Polished alpha-027 rewrite validation.

### Includes

- Repaired multi-money amount drift when rewritten currency values no longer match spoken source amounts.
- Preserved comma-grouped source money amounts such as `$6,500` and `$1,500` during money fact repair.
- Parsed chunked spoken number phrases so source money evidence can recover values like five thousand twenty two dollars.
- Tightened currency-adjacent number repair so currency symbols only count when directly adjacent to the rewritten number.

### Notes

- `1.0.7` bumps the tracked style rewrite package version for deterministic money and number evidence preservation after local model rewrites.

---

## [1.0.6] - 2026-06-01

Terminal punctuation preservation for Vibes rewrite output repair.

### Includes

- Added deterministic terminal punctuation boundary repair so Vibes rewrites preserve source `!` and mixed `?!` punctuation when the model changes, drops, or simplifies those boundaries.
- Routed terminal punctuation repair through shared `OutputRepair` so Casual, Polished, and Chill all use the same source-backed correction path.
- Reapplied output repair after Chill heuristic formatting so lowercase cleanup cannot strip terminal punctuation that was proven by the source dictation.
- Preserved rewritten paragraph breaks when restoring source punctuation across sentence boundaries instead of collapsing separators to a single space.
- Added regression coverage for exclamation boundary restoration, terminal `!` restoration, mixed `?!` restoration, model drift from `!` to `?`, Chill heuristic preservation, and paragraph-break preservation.

### Notes

- `1.0.6` bumps the tracked style rewrite package version for deterministic terminal punctuation preservation across Vibes rewrites.

---

## [1.0.5] - 2026-05-29

Selected uncapped dictation artifact support for reversible keyboard Caps Lock transforms.

### Includes

- Added an optional selected uncapped text field to latest dictation artifacts so app clients can preserve the selected Vibes result before keyboard-level Caps Lock casing is applied.
- Kept artifact decoding backward compatible when older stored dictation artifacts do not include the selected uncapped text field.
- Updated artifact serialization coverage for the selected uncapped text field and legacy decode behavior.

### Notes

- `1.0.5` bumps the tracked style rewrite package version for the artifact schema addition used by keyboard-side Caps Lock reversal on selected Vibes output.

---

## [1.0.4] - 2026-05-25

Money output repair for redundant minor currency units after decimal amounts.

### Includes

- Removed redundant minor currency words when a Vibes rewrite already preserved the matching decimal money amount from source dictation evidence.
- Routed minor currency word matching through the shared currency unit source of truth, including simple plural normalization.
- Added regression coverage for decimal dollar-and-cent output followed by a duplicate cents unit.

### Notes

- `1.0.4` bumps the tracked style rewrite package version for deterministic money repair after local model rewrites.

---

## [1.0.3] - 2026-05-23

Spoken-list cue preservation for Vibes rewrite output repair.

### Includes

- Protected line-start ordered-list markers from AP-style low-number restoration and still restores ordinary low-number wording before list-introducing colons.
- Restored spoken-number list cues from raw dictation variants when Vibe rewriting flattens item markers.
- Preserved the original punctuation around restored spoken list cues across comma and period dictation variants.
- Restored original non-numeric wording when a Vibes rewrite inserts unsupported factual number evidence into an ambiguous source phrase.
- Added focused DEBUG visibility for local model output, repaired style output, and factual number evidence kept during output repair.

### Notes

- `1.0.3` bumps the tracked style rewrite package version for deterministic list marker and spoken-cue preservation across Vibes rewrites.

---

## [1.0.2] - 2026-05-23

Number-evidence repair refinements for model rewrite output.

### Includes

- Added unified number evidence repair for changed, deleted, and separator-drifted numeric values in rewritten text.
- Added repair for time and decimal separator drift so source evidence can restore `5:30` versus `5.30` style values correctly.
- Improved money fact repair so multi-token spoken number phrases are parsed through the shared number evidence path before currency units.
- Added dictation-model-specific style example text for Whisper and Parakeet while preserving the existing default example API.
- Updated Chill formatting so colon-separated numeric runs collapse consistently with the relaxed punctuation policy.

### Notes

- `1.0.2` bumps the tracked style rewrite package version for stronger deterministic numeric evidence preservation across Vibes rewrites.

---

## [1.0.1] - 2026-05-22

Factual-number repair and output repair organization for Vibes rewrites.

### Includes

- Added deterministic rewrite output repair for address numbers that are converted to time-shaped values, collapsed during local model rewriting, or drift in ordinal street contexts.
- Added factual money repair for split dollar-and-cent phrases, currency amount drift, and numeric money operands when the source dictation contains clear currency evidence.
- Added deleted-number evidence repair so low-number words removed by a rewrite can be restored when the surrounding text still aligns.
- Added AP-style spoken-number cleanup for ordinary low numbers while preserving protected numeric contexts such as time, money, percentages, addresses, decimals, and collapsed adjacent number evidence.
- Split output repair into focused modules for punctuation, AP-style numbers, address facts, deleted number evidence, money facts, and shared repair support.

### Notes

- `1.0.1` bumps the tracked style rewrite package version for deterministic output repair behavior and the output repair module split used by Vibes rewrites.

---

## [1.0.0] - 2026-04-29

Baseline tracked release of the KeyVox style rewrite package.

This entry establishes the first explicit package version for `KeyVoxStyleRewrite` and marks the current local-model style rewrite pipeline as the starting point for future package-level release tracking inside the monorepo.

### Includes

- Package-owned style rewrite request, result, timing, error, variant, and latest-utterance artifact models.
- Style identifiers and request configuration for None, Casual, Polished, and Chill.
- Local-model text transformation through injected chunk responders so app targets can provide the runtime implementation.
- Token-aware chunk planning with semantic-boundary preference, word-level fallback splitting, configurable response limits, and approximate counting fallback.
- Local model error mapping for missing models, load failures, prompt length failures, output truncation, generation failures, and cancellation.
- Prompt-leak fallback handling that preserves the post-processed base dictation text when generated output includes rewrite instructions.
- Output repair for protected meaningful token removals after local-model cleanup using token and gap analysis.
- Casual cleanup processing with punctuation repair and partial-fallback metadata.
- Chill processing that runs Casual cleanup first, then applies deterministic lowercase and limited-punctuation formatting.
- Chill preservation for email addresses, emoji, paragraph breaks, ordered lists, time and ratio colons, numeric hyphens, dates, phone numbers, percentages, and post-processed math symbols.
- Package regression coverage for style request construction, chunk planning, stitching, fallback behavior, repair behavior, artifact serialization, prompt-leak fallback, and Chill heuristic formatting.

### Notes

- `1.0.0` is the baseline release-tracking point for `KeyVoxStyleRewrite`; this changelog does not attempt to reconstruct earlier branch experiments before the package settled on the local-model implementation.
- Future entries should capture meaningful style identifiers, prompt/configuration changes, fallback policy changes, artifact schema changes, chunk-planning changes, repair behavior changes, Chill heuristic changes, and local model integration updates.
