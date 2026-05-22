# KeyVox Model Training

This folder contains the source-of-truth training materials for local model adapters.

## Tracked

- `datasets/`
  - JSONL training, validation, and held-out test data.
- `prompts/`
  - Runtime and training prompts used by adapter runs.
- `specs/`
  - Human-readable behavior specs.
- `runs/`
  - Reproducible run scripts, configs, manifests, and lineage docs.

## Ignored

- `artifacts/`
  - Local adapter checkpoints, converted GGUF files, and training outputs.
  - `artifacts/current/` should only contain the promoted local artifact cache for the current adapter in each style.
  - Older promoted artifacts belong in `artifacts/archive/`; rejected experiments belong in `artifacts/rejected/` only when they are intentionally preserved for diagnosis.
- `models/`
  - Local base model files used for training or testing.

Tracked `datasets/` and `runs/` are the reproducible source of truth. Ignored artifacts are a local cache. The bundled runtime GGUF under `Packages/KeyVoxVibesAdapters` is the app-shipped adapter artifact and should be tracked.

## Current Polished Adapter

- Current run: `runs/polished/alpha-026`
- Base dataset: `datasets/polished/alpha-010-base`
- Continuation dataset: `datasets/polished/alpha-026-continuation-rating-unlearn`
- Runtime app resource: `Packages/KeyVoxVibesAdapters/Sources/KeyVoxVibesAdapters/Resources/Adapters/polished-alpha-026-lora.gguf`

## Current Casual Adapter

- Current run: `runs/casual/casual-alpha-9`
- Base dataset: `datasets/casual/casual-alpha-1-base`
- Continuation datasets: `datasets/casual/casual-alpha-2-continuation-times`, `datasets/casual/casual-alpha-3-continuation-time-money-guards`, `datasets/casual/casual-alpha-4-continuation-spoken-years`, `datasets/casual/casual-alpha-5-continuation-money-boundaries`, `datasets/casual/casual-alpha-6-continuation-money-negation-boundaries`, `datasets/casual/casual-alpha-7-continuation-money-time-coverage`, `datasets/casual/casual-alpha-8-continuation-address-time-guards`, `datasets/casual/casual-alpha-9-continuation-rating-unlearn`
- Runtime app resource: `Packages/KeyVoxVibesAdapters/Sources/KeyVoxVibesAdapters/Resources/Adapters/casual-alpha-9-lora.gguf`

## Polished Run Status

- Current: `runs/polished/alpha-026`
- Previously promoted: `runs/polished/alpha-017`, `runs/polished/alpha-019`, `runs/polished/alpha-020`, `runs/polished/alpha-021`, `runs/polished/alpha-023`, `runs/polished/alpha-024`, `runs/polished/alpha-025`
- Rejected intermediate: `runs/polished/rejected/alpha-018`, `runs/polished/rejected/alpha-022`
- Rejected dataset: `datasets/polished/rejected/alpha-018-continuation-paragraphs`

The tracked datasets/configs plus ignored local artifacts are enough to continue training when the artifacts are present locally.
