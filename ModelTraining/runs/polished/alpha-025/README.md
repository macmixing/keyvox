# KeyVox Polished LoRA alpha-025

This Polished LoRA continuation starts from alpha-024 and focuses on money/quantity boundary precision. It targets live inference regressions where adjacent money and count phrases were merged, skipped, or assigned the wrong currency marker.

## Inputs

- Dataset: `ModelTraining/datasets/polished/alpha-025-continuation-money-boundaries`
- Prompt: `ModelTraining/prompts/polished/polished_runtime_short.txt`
- Config: `train_config.yaml`
- Resume checkpoint: `ModelTraining/artifacts/current/polished-lora-alpha-024/adapters/polished-alpha-024/adapters.safetensors`

## Outputs

- MLX adapter checkpoint: `ModelTraining/artifacts/current/polished-lora-alpha-025/adapters/polished-alpha-025/adapters.safetensors`
- Runtime GGUF: `ModelTraining/artifacts/current/polished-lora-alpha-025/adapters/polished-alpha-025/polished-alpha-025-lora.gguf` converted with f32 precision.

## Run

From this folder:

```bash
./run_train.sh
```

The default model is:

```text
Qwen/Qwen2.5-0.5B-Instruct
```
