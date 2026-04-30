# Changelog

All notable changes to `KeyVoxStyleRewrite` will be documented in this file.

The format loosely follows Keep a Changelog and the package uses semantic versioning for internal style rewrite tracking within the KeyVox monorepo.

---

## [1.0.0] - 2026-04-29

Baseline tracked release of the KeyVox style rewrite package.

This entry establishes the first explicit package version for `KeyVoxStyleRewrite` and marks the current Foundation-backed style rewrite behavior as the starting point for future package-level release tracking inside the monorepo.

### Includes

- Package-owned style rewrite request, result, timing, error, variant, and latest-utterance artifact models.
- Foundation-backed text transformation for KeyVox Vibes styles including Casual, Polished, and Chill.
- Token-aware chunk planning with semantic-boundary preference, word-level fallback splitting, Foundation token counting when available, and approximate counting fallback.
- Foundation prewarm lifecycle support with warm/cold processing metadata and retained-session release hooks.
- Refusal, guardrail, context-window, empty-response, and chunk-level fallback handling that preserves the post-processed base dictation text when needed.
- Output repair for protected meaningful token removals after Foundation cleanup using token and gap analysis.
- Deterministic Chill formatting for lowercase, limited-punctuation output after optional Foundation cleanup.
- Package regression coverage for style request construction, chunk planning, stitching, fallback behavior, repair behavior, artifact serialization, and opt-in live Foundation smoke coverage.

### Notes

- `1.0.0` is the baseline release-tracking point for `KeyVoxStyleRewrite`; this changelog does not attempt to reconstruct earlier branch experiments before the package settled on the Foundation-backed implementation.
- Future entries should capture meaningful style identifiers, prompt/configuration changes, fallback policy changes, artifact schema changes, chunk-planning changes, repair behavior changes, and Foundation integration updates.
