# Casual Alpha-4 Lineage

## Candidate Adapter

`casual-alpha-4` is a candidate continuation for the Casual vibe. It addresses spoken 2010s year recognition regressions observed in live inference.

## Training Lineage

1. `casual-alpha-1`
   - Run: `ModelTraining/runs/casual/casual-alpha-1`
   - Dataset: `ModelTraining/datasets/casual/casual-alpha-1-base`
   - Final MLX adapter checkpoint: `ModelTraining/artifacts/current/casual-lora-alpha-1/adapters/casual-alpha-1/adapters.safetensors`
   - Runtime GGUF: `ModelTraining/artifacts/current/casual-lora-alpha-1/adapters/casual-alpha-1/casual-alpha-1-lora.gguf`

2. `casual-alpha-2`
   - Run: `ModelTraining/runs/casual/casual-alpha-2`
   - Dataset: `ModelTraining/datasets/casual/casual-alpha-2-continuation-times`
   - Continued from: `ModelTraining/artifacts/current/casual-lora-alpha-1/adapters/casual-alpha-1/adapters.safetensors`
   - Final MLX adapter checkpoint: `ModelTraining/artifacts/current/casual-lora-alpha-2/adapters/casual-alpha-2/adapters.safetensors`
   - Runtime GGUF: `ModelTraining/artifacts/current/casual-lora-alpha-2/adapters/casual-alpha-2/casual-alpha-2-lora.gguf`

3. `casual-alpha-3`
   - Run: `ModelTraining/runs/casual/casual-alpha-3`
   - Dataset: `ModelTraining/datasets/casual/casual-alpha-3-continuation-time-money-guards`
   - Continued from: `ModelTraining/artifacts/current/casual-lora-alpha-2/adapters/casual-alpha-2/adapters.safetensors`
   - Final MLX adapter checkpoint: `ModelTraining/artifacts/current/casual-lora-alpha-3/adapters/casual-alpha-3/adapters.safetensors`
   - Runtime GGUF: `ModelTraining/artifacts/current/casual-lora-alpha-3/adapters/casual-alpha-3/casual-alpha-3-lora.gguf`

4. `casual-alpha-4`
   - Run: `ModelTraining/runs/casual/casual-alpha-4`
   - Dataset: `ModelTraining/datasets/casual/casual-alpha-4-continuation-spoken-years`
   - Continued from: `ModelTraining/artifacts/current/casual-lora-alpha-3/adapters/casual-alpha-3/adapters.safetensors`
   - Final MLX adapter checkpoint: `ModelTraining/artifacts/current/casual-lora-alpha-4/adapters/casual-alpha-4/adapters.safetensors`
   - Runtime GGUF: `ModelTraining/artifacts/current/casual-lora-alpha-4/adapters/casual-alpha-4/casual-alpha-4-lora.gguf`
