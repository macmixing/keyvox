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

- Current run: `runs/polished/alpha-021`
- Base dataset: `datasets/polished/alpha-010-base`
- Continuation dataset: `datasets/polished/alpha-021-continuation-long-numerics`
- Runtime app resource: `Resources/LocalRewriteAdapters/polished-alpha-021-lora.gguf`

## Polished Run Status

- Current: `runs/polished/alpha-021`
- Previously promoted: `runs/polished/alpha-017`, `runs/polished/alpha-019`, `runs/polished/alpha-020`
- Rejected intermediate: `runs/polished/rejected/alpha-018`, `runs/polished/rejected/alpha-022`
- Rejected dataset: `datasets/polished/rejected/alpha-018-continuation-paragraphs`

The Mac Studio is optional compute. The tracked datasets/configs plus ignored local artifacts are enough to continue training from this Mac when the artifacts are present locally.
