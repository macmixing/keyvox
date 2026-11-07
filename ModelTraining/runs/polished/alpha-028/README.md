# Polished Alpha 028

Polished alpha-028 continues alpha-027 so casual spoken reductions are written out in standard form while the rest of Polished behavior stays the same.

## Dataset

- Continuation dataset: `ModelTraining/datasets/polished/alpha-028-continuation-casual-reductions`
- Train examples: 245
- Validation examples: 21
- Held-out examples: 21

## Focus

- Write out `gonna`, `wanna`, and `gotta` as `going to`, `want to`, and `have to`, including sentence-start and subject-free phrasing.
- Write out related reductions such as `lemme`, `gimme`, `kinda`, `sorta`, `outta`, `dunno`, `hafta`, `lotta`, and `ya`.
- Keep the meaning of `gotta` when it stands for `got a`, and keep clause-joining `and` and sentence-start `Anyway,`.
- Leave already-standard phrasing such as `going to`, `want to`, and `got to` unchanged.
- Keep commas when filler `like` is removed inside a list.
- Capitalize numbered list items after removing leading filler, correcting the replayed alpha-027 grocery list example.
- Replay the alpha-027 continuation and the alpha-017 `ain't` examples so meaning preservation and standard-English repair hold.

## Promotion

- Continued from: `ModelTraining/artifacts/current/polished-lora-alpha-027/adapters/polished-alpha-027/adapters.safetensors`
- Current checkpoint: `ModelTraining/artifacts/current/polished-lora-alpha-028/adapters/polished-alpha-028/adapters.safetensors`
- Runtime GGUF: `ModelTraining/artifacts/current/polished-lora-alpha-028/adapters/polished-alpha-028/polished-alpha-028-lora.gguf`
- Bundled package resource: `Packages/KeyVoxVibesAdapters/Sources/KeyVoxVibesAdapters/Resources/Adapters/polished-alpha-028-lora.gguf`
- Training iterations: 300
- Learning rate: 2e-6

The adapter was converted as f32 with `scripts/export_runtime_adapter.py`.
