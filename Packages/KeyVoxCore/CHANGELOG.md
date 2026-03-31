# Changelog

All notable changes to `KeyVoxCore` will be documented in this file.

The format loosely follows Keep a Changelog and the package uses semantic versioning for internal engine tracking within the KeyVox monorepo.

---

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
