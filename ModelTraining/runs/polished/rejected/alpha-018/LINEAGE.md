# Polished Alpha-018 Lineage

## Rejected Adapter

`polished-alpha-018` is a rejected pre-v1 adapter for the Polished vibe. It fixed paragraph preservation but regressed numeric conversion in the live Polished suite.

## Training Lineage

1. `polished-alpha-010`
   - Run: `ModelTraining/runs/polished/alpha-010`
   - Dataset: `ModelTraining/datasets/polished/alpha-010-base`
   - Final MLX adapter checkpoint: `ModelTraining/artifacts/archive/polished-lora-alpha-010/adapters/polished-alpha-010/adapters.safetensors`

2. `polished-alpha-017`
   - Run: `ModelTraining/runs/polished/alpha-017`
   - Dataset: `ModelTraining/datasets/polished/alpha-017-continuation-aint`
   - Continued from: `ModelTraining/artifacts/archive/polished-lora-alpha-010/adapters/polished-alpha-010/adapters.safetensors`
   - Final MLX adapter checkpoint: `ModelTraining/artifacts/archive/polished-lora-alpha-017/adapters/polished-alpha-017/adapters.safetensors`
   - Runtime GGUF: `ModelTraining/artifacts/archive/polished-lora-alpha-017/adapters/polished-alpha-017/polished-alpha-017-lora.gguf`

3. `polished-alpha-018`
   - Run: `ModelTraining/runs/polished/rejected/alpha-018`
   - Dataset: `ModelTraining/datasets/polished/rejected/alpha-018-continuation-paragraphs`
   - Continued from: `ModelTraining/artifacts/archive/polished-lora-alpha-017/adapters/polished-alpha-017/adapters.safetensors`
   - Final MLX adapter checkpoint: `ModelTraining/artifacts/rejected/polished-lora-alpha-018/adapters/polished-alpha-018/adapters.safetensors`
   - Runtime GGUF: `ModelTraining/artifacts/rejected/polished-lora-alpha-018/adapters/polished-alpha-018/polished-alpha-018-lora.gguf`
