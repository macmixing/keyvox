# Polished Alpha-017 Lineage

## Production Adapter

`polished-alpha-017` is the promoted adapter for the Polished vibe.

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

