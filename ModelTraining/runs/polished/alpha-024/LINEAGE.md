# Polished Alpha-024 Lineage

## Candidate Adapter

`polished-alpha-024` is a candidate continuation for the Polished vibe. It addresses teen-number age compound regressions observed in live inference after alpha-023.

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

4. `polished-alpha-019`
   - Run: `ModelTraining/runs/polished/alpha-019`
   - Dataset: `ModelTraining/datasets/polished/alpha-019-continuation-numeric-paragraphs`
   - Continued from: `ModelTraining/artifacts/rejected/polished-lora-alpha-018/adapters/polished-alpha-018/adapters.safetensors`
   - Final MLX adapter checkpoint: `ModelTraining/artifacts/archive/polished-lora-alpha-019/adapters/polished-alpha-019/adapters.safetensors`
   - Runtime GGUF: `ModelTraining/artifacts/archive/polished-lora-alpha-019/adapters/polished-alpha-019/polished-alpha-019-lora.gguf`

5. `polished-alpha-020`
   - Run: `ModelTraining/runs/polished/alpha-020`
   - Dataset: `ModelTraining/datasets/polished/alpha-020-continuation-paragraph-meaning`
   - Continued from: `ModelTraining/artifacts/archive/polished-lora-alpha-019/adapters/polished-alpha-019/adapters.safetensors`
   - Final MLX adapter checkpoint: `ModelTraining/artifacts/archive/polished-lora-alpha-020/adapters/polished-alpha-020/adapters.safetensors`
   - Runtime GGUF: `ModelTraining/artifacts/archive/polished-lora-alpha-020/adapters/polished-alpha-020/polished-alpha-020-lora.gguf`

6. `polished-alpha-021`
   - Run: `ModelTraining/runs/polished/alpha-021`
   - Dataset: `ModelTraining/datasets/polished/alpha-021-continuation-long-numerics`
   - Continued from: `ModelTraining/artifacts/archive/polished-lora-alpha-020/adapters/polished-alpha-020/adapters.safetensors`
   - Final MLX adapter checkpoint: `ModelTraining/artifacts/current/polished-lora-alpha-021/adapters/polished-alpha-021/adapters.safetensors`
   - Runtime GGUF: `ModelTraining/artifacts/current/polished-lora-alpha-021/adapters/polished-alpha-021/polished-alpha-021-lora.gguf`

7. `polished-alpha-023`
   - Run: `ModelTraining/runs/polished/alpha-023`
   - Dataset: `ModelTraining/datasets/polished/alpha-023-continuation-spoken-years`
   - Continued from: `ModelTraining/artifacts/current/polished-lora-alpha-021/adapters/polished-alpha-021/adapters.safetensors`
   - Final MLX adapter checkpoint: `ModelTraining/artifacts/current/polished-lora-alpha-023/adapters/polished-alpha-023/adapters.safetensors`
   - Runtime GGUF: `ModelTraining/artifacts/current/polished-lora-alpha-023/adapters/polished-alpha-023/polished-alpha-023-lora.gguf`

8. `polished-alpha-024`
   - Run: `ModelTraining/runs/polished/alpha-024`
   - Dataset: `ModelTraining/datasets/polished/alpha-024-continuation-age-compounds`
   - Continued from: `ModelTraining/artifacts/current/polished-lora-alpha-023/adapters/polished-alpha-023/adapters.safetensors`
   - Final MLX adapter checkpoint: `ModelTraining/artifacts/current/polished-lora-alpha-024/adapters/polished-alpha-024/adapters.safetensors`
   - Runtime GGUF: `ModelTraining/artifacts/current/polished-lora-alpha-024/adapters/polished-alpha-024/polished-alpha-024-lora.gguf`
