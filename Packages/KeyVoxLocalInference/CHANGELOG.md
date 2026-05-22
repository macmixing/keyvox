# Changelog

All notable changes to `KeyVoxLocalInference` will be documented in this file.

The format loosely follows Keep a Changelog and the package uses semantic versioning for internal local inference tracking within the KeyVox monorepo.

---

## [1.0.3] - 2026-05-22

Live validation coverage for refreshed Vibes adapter boundaries and factual-number repair behavior.

### Includes

- Added Casual live local-model coverage for address-shaped inputs that should stay addresses instead of becoming time expressions.
- Added coverage for numeric, digit-by-digit, spoken, and comma-grouped address number forms around north, south, east, and west street contexts.
- Added Casual live local-model coverage for money and time boundaries so dollar amounts stay money while nearby spoken times stay time.
- Added live coverage for factual number preservation around address, ordinal street, money, math, AP-style, and deleted-number rewrite repairs.
- Removed rating-formatting adapter expectations from live coverage so rating behavior is validated through deterministic AP-style repair instead of adapter-specific star-rating rules.
- Aligned live adapter validation with the promoted Casual alpha-9 and Polished alpha-026 bundled Vibes adapter resources.

### Notes

- `1.0.3` bumps the tracked local inference package version for live validation coverage around the promoted Casual alpha-9 and Polished alpha-026 Vibes adapters and the deterministic repair behavior that runs after local inference.

---

## [1.0.2] - 2026-05-20

Live validation coverage for Polished and Casual money boundary adapter behavior.

### Includes

- Added Polished live local-model coverage for adjacent money and quantity phrases, including dollar amounts followed by day counts, price ratios, star rating counts, and math expressions with money operands.
- Added Casual live local-model coverage for adjacent money and quantity phrases, including dollar amounts followed by day counts, price ratios, star rating counts, and math expressions with money operands.
- Aligned live adapter validation with the promoted Polished alpha-025 and Casual alpha-5 bundled Vibes adapter resources.

### Notes

- `1.0.2` bumps the tracked local inference package version for the live validation coverage added around the promoted money-boundary Vibes adapters.

---

## [1.0.1] - 2026-05-17

Live validation coverage for refreshed Vibes adapters.

### Includes

- Expanded Polished live local-model validation for spoken year recognition and quantity guard coverage.
- Expanded Casual live local-model validation for spoken year recognition and quantity guard coverage.
- Aligned live adapter validation with the refreshed bundled Vibes adapter resources.

### Notes

- `1.0.1` bumps the tracked local inference package version for the live validation coverage added around the refreshed Vibes adapter resources.

---

## [1.0.0] - 2026-05-13

Baseline tracked release of the KeyVox local inference package.

This entry establishes the first explicit package version for `KeyVoxLocalInference` and marks the current local language model runtime behavior as the starting point for future package-level release tracking inside the monorepo.

### Includes

- A package-owned Swift interface for local GGUF language model inference through `LocalLanguageModelGenerating` and `LlamaLocalLanguageModel`.
- Vendored `llama.xcframework` binary artifact from the official `ggml-org/llama.cpp` Apple XCFramework release artifact documented in the package artifact provenance notes.
- Local language model configuration with explicit caller-provided context token limits, thread counts, batch thread counts, and batch token counts.
- Generation requests for raw prompts and structured system/user prompts, with configurable chat-template and special-token handling.
- Model lifecycle operations for prepare, generate, and unload, with serialized inference execution through a package-owned dispatch queue.
- Optional LoRA adapter loading through caller-provided adapter URLs and adapter scale configuration.
- Mac GPU offload modes for disabled, automatic, all-layers, and explicit layer-count operation, with CPU fallback behavior when GPU loading or context creation fails.
- Typed errors for missing model files, model load failures, missing adapter files, adapter load and attach failures, context creation failures, tokenizer failures, prompt length failures, decode failures, empty output, output truncation, and cancellation.
- Generation metrics for load duration, input and output token counts, maximum-token handling, prefill duration, decode duration, total duration, and decode tokens per second.
- Package coverage for configuration defaults with explicit context limits, GPU offload mode equality, metrics, structured chat requests, cancellation, missing-model failures, and opt-in live local model/style prompt validation.

### Notes

- `1.0.0` is the baseline release-tracking point for `KeyVoxLocalInference`; this changelog does not attempt to reconstruct earlier branch work before explicit package versioning was introduced.
- Future entries should capture meaningful local model runtime, artifact, adapter, GPU offload, request configuration, error handling, metrics, lifecycle, and live validation changes.
