# Casual Alpha-2 Lineage

## Intermediate Adapter

`casual-alpha-2` is a targeted continuation from `casual-alpha-1` for spoken hour-minute time formatting. It fixed the spoken-time failures, but was superseded by `casual-alpha-3` after a money-format gauntlet regression.

## Training Lineage

1. `casual-alpha-1`
   - Run: `ModelTraining/runs/casual/casual-alpha-1`
   - Dataset: `ModelTraining/datasets/casual/casual-alpha-1-base`
   - Final MLX adapter checkpoint: `ModelTraining/artifacts/current/casual-lora-alpha-1/adapters/casual-alpha-1/adapters.safetensors`
   - Runtime GGUF: `ModelTraining/artifacts/current/casual-lora-alpha-1/adapters/casual-alpha-1/casual-alpha-1-lora.gguf`
2. `casual-alpha-2`
   - Run: `ModelTraining/runs/casual/casual-alpha-2`
   - Dataset: `ModelTraining/datasets/casual/casual-alpha-2-continuation-times`
   - Resume adapter: `ModelTraining/artifacts/current/casual-lora-alpha-1/adapters/casual-alpha-1/adapters.safetensors`
   - Final MLX adapter checkpoint: `ModelTraining/artifacts/current/casual-lora-alpha-2/adapters/casual-alpha-2/adapters.safetensors`
   - Runtime GGUF: `ModelTraining/artifacts/current/casual-lora-alpha-2/adapters/casual-alpha-2/casual-alpha-2-lora.gguf`
