# Changelog

All notable changes to `KeyVoxParakeet` will be documented in this file.

The format loosely follows Keep a Changelog and the package uses semantic versioning for internal runtime tracking within the KeyVox monorepo.

---

## [1.0.0] - 2026-03-30

Baseline tracked release of the KeyVox Parakeet runtime package.

This entry establishes the first explicit package version for `KeyVoxParakeet` and marks the current Parakeet runtime behavior as the starting point for future package-level release tracking inside the monorepo.

### Includes

- A package-owned Swift wrapper around the Parakeet transcription runtime used for on-device Core ML inference.
- Shared runtime behavior for model loading, lifecycle ownership, unload handling, cancellation, stale-request invalidation, and transcription execution.
- Package-owned inference configuration through `ParakeetParams`, along with segment models, runtime errors, and metadata-aware transcription results.
- Internal Core ML backend support for model loading, tensor bridging, decoder execution, and transcription output generation.
- Vocabulary loading, token lookup, token classification, and prompt tokenization support kept inside the package boundary.
- Package regression coverage for runtime lifecycle behavior, cancellation, vocabulary behavior, decoding helpers, and initialization failure handling.

### Notes

- `1.0.0` is the baseline release-tracking point for `KeyVoxParakeet`; this changelog does not attempt to reconstruct earlier internal runtime history before explicit package versioning was introduced.
- Future entries should capture meaningful runtime, decoding, vocabulary, model-handling, and transcription-behavior changes that affect the shipped Parakeet layer.
