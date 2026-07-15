# Changelog

All notable changes to `KeyVoxParakeet` will be documented in this file.

The format loosely follows Keep a Changelog and the package uses semantic versioning for internal runtime tracking within the KeyVox monorepo.

---

## [1.0.4] - 2026-07-14

Compatibility support for the current Parakeet Core ML model artifacts.

### Includes

- Added runtime support for the `EncoderInt4` and `JointDecisionv3` model artifacts while preserving compatibility with legacy Parakeet installations.
- Added handling for the current encoder's Float16 output and padded Neural Engine tensor strides.
- Added decoder-state normalization for the current model layout while retaining the existing legacy decoding path.
- Kept Parakeet inference configured for CPU and Neural Engine execution.
- Expanded package regression coverage for current and legacy encoder layouts, padded encoder output, and decoder-state normalization.

### Notes

- `1.0.4` bumps the tracked runtime version for `KeyVoxParakeet` to cover backward-compatible support for the current Parakeet model artifact layout.

## [1.0.3] - 2026-05-05

Removed unsupported Parakeet prompt priming from the runtime.

### Includes

- Removed `initialPrompt` from `ParakeetParams` so package consumers can no longer configure natural-language prompt text for the Parakeet TDT decoder.
- Removed the Core ML decoder path that tokenized prompt text and advanced decoder state before audio decoding.
- Removed prompt-tokenization support from `ParakeetVocabulary`, leaving vocabulary handling focused on token lookup, classification, and decoded text assembly.
- Updated package docs and release tracking to reflect that Parakeet dictionary handling should not use decoder prompt priming.

### Notes

- `1.0.3` bumps the tracked runtime version for `KeyVoxParakeet` to cover removal of the unsupported prompt-priming behavior that could corrupt the start of decoded words.

## [1.0.2] - 2026-04-14

Parakeet decoder timing and no-speech gating refinements for short cue-like hallucinations.

### Includes

- Updated the Core ML decoder timing path to track lexical text timing separately from punctuation-only tail tokens, which keeps late punctuation from stretching short hallucinated segments into longer confirmed utterances.
- Added package-owned relative start and end timing support so decoded segments reflect the actual lexical emission window instead of the whole trailing blank or punctuation tail.
- Refined `ParakeetUtteranceGate` to use decoded utterance span, decoder `noSpeechProbability`, trailing-segment filtering, and a duration-sensitive single-word confidence threshold so short cue-like outputs such as `Yeah.` and `No.` are more likely to be rejected without suppressing valid short speech like `Lol.`.
- Expanded package regression coverage for padding-heavy short captures, trailing hallucinated segments, decoder no-speech signaling, lexical timing behavior, and the updated single-word confidence boundary.

### Notes

- `1.0.2` bumps the tracked runtime version for `KeyVoxParakeet` to cover the decoder-timing and no-speech confirmation refinements used to suppress short hallucinated output before it reaches shared dictation clients.

## [1.0.1] - 2026-04-05

Confidence-gated short-utterance suppression for low-confidence Parakeet output.

### Includes

- Added `ParakeetUtteranceGate` to the package surface so short one-shot Parakeet results can be treated as likely no-speech when they do not clear the confidence bar needed for confirmation.
- Adapted the anti-spam pattern from the local `FluidAudio-reference` Parakeet implementation by gating brief low-confidence output at utterance confirmation time instead of hard-coding filler-word filters.
- Added package regression coverage that rejects the short low-confidence `Yeah.`-style result shape while preserving higher-confidence short speech and longer utterances.

### Notes

- `1.0.1` bumps the tracked runtime version for `KeyVoxParakeet` to cover the new utterance-gating behavior used to suppress short low-confidence hallucinated output before it reaches shared dictation clients.

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
