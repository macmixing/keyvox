# Changelog

All notable changes to `KeyVoxStyleRewrite` will be documented in this file.

The format loosely follows Keep a Changelog and the package uses semantic versioning for internal style rewrite tracking within the KeyVox monorepo.

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
