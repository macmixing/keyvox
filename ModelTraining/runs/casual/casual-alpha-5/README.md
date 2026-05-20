# KeyVox Casual LoRA alpha-5

This Casual LoRA continuation starts from casual-alpha-4 and focuses on money/quantity boundary precision while preserving Casual voice.

## Inputs

- Dataset: `ModelTraining/datasets/casual/casual-alpha-5-continuation-money-boundaries`
- Prompt: `ModelTraining/prompts/casual/casual_runtime_short.txt`
- Config: `train_config.yaml`
- Resume checkpoint: `ModelTraining/artifacts/current/casual-lora-alpha-4/adapters/casual-alpha-4/adapters.safetensors`

## Outputs

- MLX adapter checkpoint: `ModelTraining/artifacts/current/casual-lora-alpha-5/adapters/casual-alpha-5/adapters.safetensors`
- Runtime GGUF: `ModelTraining/artifacts/current/casual-lora-alpha-5/adapters/casual-alpha-5/casual-alpha-5-lora.gguf` converted with f32 precision.

## Run

From this folder:

```bash
./run_train.sh
```
