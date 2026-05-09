# Casual Alpha-3 Lineage

## Current Adapter

`casual-alpha-3` is a targeted continuation from `casual-alpha-2` for spoken hour-minute time formatting plus money-format guards. It is still pre-v1 and remains shared by Casual and Chill.

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
3. `casual-alpha-3`
   - Run: `ModelTraining/runs/casual/casual-alpha-3`
   - Dataset: `ModelTraining/datasets/casual/casual-alpha-3-continuation-time-money-guards`
   - Resume adapter: `ModelTraining/artifacts/current/casual-lora-alpha-2/adapters/casual-alpha-2/adapters.safetensors`
   - Final MLX adapter checkpoint: `ModelTraining/artifacts/current/casual-lora-alpha-3/adapters/casual-alpha-3/adapters.safetensors`
   - Runtime GGUF: `ModelTraining/artifacts/current/casual-lora-alpha-3/adapters/casual-alpha-3/casual-alpha-3-lora.gguf`
