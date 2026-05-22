# Casual Alpha-8 Lineage

## Current Adapter

`casual-alpha-8` is the current continuation for the Casual vibe. It addresses address-number regressions observed after casual-alpha-7 where street numbers before directional street names could be rewritten as times, and covers numeric, comma-separated, and spoken address-number forms that should become numeric street addresses rather than clock times.

## Training Lineage

1. `casual-alpha-1`
   - Run: `ModelTraining/runs/casual/casual-alpha-1`
   - Dataset: `ModelTraining/datasets/casual/casual-alpha-1-base`
   - Final MLX adapter checkpoint: `ModelTraining/artifacts/archive/casual/casual-lora-alpha-1/adapters/casual-alpha-1/adapters.safetensors`
   - Runtime GGUF: `ModelTraining/artifacts/archive/casual/casual-lora-alpha-1/adapters/casual-alpha-1/casual-alpha-1-lora.gguf`

2. `casual-alpha-2`
   - Run: `ModelTraining/runs/casual/casual-alpha-2`
   - Dataset: `ModelTraining/datasets/casual/casual-alpha-2-continuation-times`
   - Continued from: `ModelTraining/artifacts/archive/casual/casual-lora-alpha-1/adapters/casual-alpha-1/adapters.safetensors`
   - Final MLX adapter checkpoint: `ModelTraining/artifacts/archive/casual/casual-lora-alpha-2/adapters/casual-alpha-2/adapters.safetensors`
   - Runtime GGUF: `ModelTraining/artifacts/archive/casual/casual-lora-alpha-2/adapters/casual-alpha-2/casual-alpha-2-lora.gguf`

3. `casual-alpha-3`
   - Run: `ModelTraining/runs/casual/casual-alpha-3`
   - Dataset: `ModelTraining/datasets/casual/casual-alpha-3-continuation-time-money-guards`
   - Continued from: `ModelTraining/artifacts/archive/casual/casual-lora-alpha-2/adapters/casual-alpha-2/adapters.safetensors`
   - Final MLX adapter checkpoint: `ModelTraining/artifacts/archive/casual/casual-lora-alpha-3/adapters/casual-alpha-3/adapters.safetensors`
   - Runtime GGUF: `ModelTraining/artifacts/archive/casual/casual-lora-alpha-3/adapters/casual-alpha-3/casual-alpha-3-lora.gguf`

4. `casual-alpha-4`
   - Run: `ModelTraining/runs/casual/casual-alpha-4`
   - Dataset: `ModelTraining/datasets/casual/casual-alpha-4-continuation-spoken-years`
   - Continued from: `ModelTraining/artifacts/archive/casual/casual-lora-alpha-3/adapters/casual-alpha-3/adapters.safetensors`
   - Final MLX adapter checkpoint: `ModelTraining/artifacts/archive/casual/casual-lora-alpha-4/adapters/casual-alpha-4/adapters.safetensors`
   - Runtime GGUF: `ModelTraining/artifacts/archive/casual/casual-lora-alpha-4/adapters/casual-alpha-4/casual-alpha-4-lora.gguf`

5. `casual-alpha-5`
   - Run: `ModelTraining/runs/casual/casual-alpha-5`
   - Dataset: `ModelTraining/datasets/casual/casual-alpha-5-continuation-money-boundaries`
   - Continued from: `ModelTraining/artifacts/archive/casual/casual-lora-alpha-4/adapters/casual-alpha-4/adapters.safetensors`
   - Final MLX adapter checkpoint: `ModelTraining/artifacts/archive/casual/casual-lora-alpha-5/adapters/casual-alpha-5/adapters.safetensors`
   - Runtime GGUF: `ModelTraining/artifacts/archive/casual/casual-lora-alpha-5/adapters/casual-alpha-5/casual-alpha-5-lora.gguf`

6. `casual-alpha-6`
   - Run: `ModelTraining/runs/casual/casual-alpha-6`
   - Dataset: `ModelTraining/datasets/casual/casual-alpha-6-continuation-money-negation-boundaries`
   - Continued from: `ModelTraining/artifacts/archive/casual/casual-lora-alpha-5/adapters/casual-alpha-5/adapters.safetensors`
   - Final MLX adapter checkpoint: `ModelTraining/artifacts/archive/casual/casual-lora-alpha-6/adapters/casual-alpha-6/adapters.safetensors`
   - Runtime GGUF: `ModelTraining/artifacts/archive/casual/casual-lora-alpha-6/adapters/casual-alpha-6/casual-alpha-6-lora.gguf`

7. `casual-alpha-7`
   - Run: `ModelTraining/runs/casual/casual-alpha-7`
   - Dataset: `ModelTraining/datasets/casual/casual-alpha-7-continuation-money-time-coverage`
   - Continued from: `ModelTraining/artifacts/archive/casual/casual-lora-alpha-6/adapters/casual-alpha-6/adapters.safetensors`
   - Final MLX adapter checkpoint: `ModelTraining/artifacts/archive/casual/casual-lora-alpha-7/adapters/casual-alpha-7/adapters.safetensors`
   - Runtime GGUF: `ModelTraining/artifacts/archive/casual/casual-lora-alpha-7/adapters/casual-alpha-7/casual-alpha-7-lora.gguf`

8. `casual-alpha-8`
   - Run: `ModelTraining/runs/casual/casual-alpha-8`
   - Dataset: `ModelTraining/datasets/casual/casual-alpha-8-continuation-address-time-guards`
   - Continued from: `ModelTraining/artifacts/archive/casual/casual-lora-alpha-7/adapters/casual-alpha-7/adapters.safetensors`
   - Final MLX adapter checkpoint: `ModelTraining/artifacts/current/casual-lora-alpha-8/adapters/casual-alpha-8/adapters.safetensors`
   - Runtime GGUF: `ModelTraining/artifacts/current/casual-lora-alpha-8/adapters/casual-alpha-8/casual-alpha-8-lora.gguf`
