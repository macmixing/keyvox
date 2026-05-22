# Casual Alpha-6 Lineage

## Candidate Adapter

`casual-alpha-6` is a candidate continuation for the Casual vibe. It addresses money negation and money plus spoken-time boundary regressions observed in live inference after casual-alpha-5, including contrast phrases that previously lost the second dollar amount and adjacent dollar/time phrases that previously merged into one number.

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
