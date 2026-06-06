# Polished Alpha 027

Polished alpha-027 continues alpha-026 with meaning-preservation examples from six bad Polished ratings captured on June 5, 2026.

## Dataset

- Source ratings: `bad-ratings.json`
- Continuation dataset: `ModelTraining/datasets/polished/alpha-027-continuation-meaning-preservation-ratings`
- Train examples: 51
- Validation examples: 9
- Held-out examples: 9

## Focus

- Preserve negation, pronouns, uncertainty, and `though`.
- Remove duplicate article drift such as `the The`.
- Avoid invented sleep, timing, or object details.
- Replay existing live-regression guards for money, addresses, ordinals, AP-style numbers, terminal punctuation, and related Polished boundaries.
- Keep `a hundred` and `one hundred` major-currency phrases formatted as source-backed currency amounts.

## Promotion

- Continued from: `ModelTraining/artifacts/current/polished-lora-alpha-026/adapters/polished-alpha-026/adapters.safetensors`
- Current checkpoint: `ModelTraining/artifacts/current/polished-lora-alpha-027/adapters/polished-alpha-027/adapters.safetensors`
- Runtime GGUF: `ModelTraining/artifacts/current/polished-lora-alpha-027/adapters/polished-alpha-027/polished-alpha-027-lora.gguf`
- Bundled package resource: `Packages/KeyVoxVibesAdapters/Sources/KeyVoxVibesAdapters/Resources/Adapters/polished-alpha-027-lora.gguf`
- Training iterations: 80

The adapter was converted as f32 using the Mac Mini training machine's mirrored Kirby conversion setup.
