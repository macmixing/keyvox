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
  - Adapter checkpoints, converted GGUF files, training outputs, old experiments, and rejected runs.
- `models/`
  - Local base model files used for training or testing.

## Current Polished Adapter

- Current run: `runs/polished/alpha-025`
- Base dataset: `datasets/polished/alpha-010-base`
- Continuation dataset: `datasets/polished/alpha-025-continuation-money-boundaries`
- Runtime app resource: `Packages/KeyVoxVibesAdapters/Sources/KeyVoxVibesAdapters/Resources/Adapters/polished-alpha-025-lora.gguf`

## Current Casual Adapter

- Current run: `runs/casual/casual-alpha-5`
- Base dataset: `datasets/casual/casual-alpha-1-base`
- Continuation datasets: `datasets/casual/casual-alpha-2-continuation-times`, `datasets/casual/casual-alpha-3-continuation-time-money-guards`, `datasets/casual/casual-alpha-4-continuation-spoken-years`, `datasets/casual/casual-alpha-5-continuation-money-boundaries`
- Runtime app resource: `Packages/KeyVoxVibesAdapters/Sources/KeyVoxVibesAdapters/Resources/Adapters/casual-alpha-5-lora.gguf`

## Polished Run Status

- Current: `runs/polished/alpha-025`
- Previously promoted: `runs/polished/alpha-017`, `runs/polished/alpha-019`, `runs/polished/alpha-020`, `runs/polished/alpha-021`, `runs/polished/alpha-023`, `runs/polished/alpha-024`
- Rejected intermediate: `runs/polished/rejected/alpha-018`, `runs/polished/rejected/alpha-022`
- Rejected dataset: `datasets/polished/rejected/alpha-018-continuation-paragraphs`

The tracked datasets/configs plus ignored local artifacts are enough to continue training when the artifacts are present locally.
