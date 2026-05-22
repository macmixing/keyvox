# Casual Alpha-7 Lineage

## Candidate Adapter

`casual-alpha-7` is a candidate continuation for the Casual vibe. It broadens money plus spoken-time boundary coverage after casual-alpha-6, including contrast phrases that mention a dollar amount before a start time and plain ticket-price/start-time phrasing that should keep money and time separate.

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
