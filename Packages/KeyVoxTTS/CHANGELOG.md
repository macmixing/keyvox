# Changelog

All notable changes to `KeyVoxTTS` will be documented in this file.

The format loosely follows Keep a Changelog and the package uses semantic versioning for internal runtime tracking within the KeyVox monorepo.

---

## [1.0.0] - 2026-04-05

Baseline tracked release of the KeyVox PocketTTS runtime package.

This entry establishes the first explicit package version for `KeyVoxTTS` and marks the current PocketTTS runtime behavior as the starting point for future package-level release tracking inside the monorepo.

### Includes

- A package-owned Swift wrapper around the local PocketTTS runtime used for on-device speech generation.
- Shared runtime behavior for asset loading, compute-mode preparation, and streamed audio frame generation.
- Package-owned text normalization and chunk planning for short-form and long-form synthesis preparation.
- Internal inference support for PocketTTS Mimi, Flow, and KV-cache model execution, along with sentence-piece tokenization utilities.
- Package regression coverage for text normalization and chunk planning behavior.

### Notes

- `1.0.0` is the baseline release-tracking point for `KeyVoxTTS`; this changelog does not attempt to reconstruct earlier internal runtime history before explicit package versioning was introduced.
- Future entries should capture meaningful runtime, normalization, chunk-planning, asset-handling, and inference-behavior changes that affect the shipped PocketTTS layer.
