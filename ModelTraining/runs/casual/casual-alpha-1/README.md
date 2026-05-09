# KeyVox Casual LoRA casual-alpha-1

This pre-v1 Casual LoRA adapter is the first shared cleanup adapter for Casual and Chill. Chill keeps its existing formatter; this adapter only learns the shared light cleanup behavior.

## Inputs

- Dataset: `ModelTraining/datasets/casual/casual-alpha-1-base`
- Prompt: `ModelTraining/prompts/casual/casual_runtime_short.txt`
- Config: `train_config.yaml`
- Base model: `Qwen/Qwen2.5-0.5B-Instruct`

## Outputs

- MLX adapter checkpoint: `ModelTraining/artifacts/current/casual-lora-alpha-1/adapters/casual-alpha-1/adapters.safetensors`
- Runtime GGUF: `ModelTraining/artifacts/current/casual-lora-alpha-1/adapters/casual-alpha-1/casual-alpha-1-lora.gguf`

## Run

From this folder:

```bash
./run_train.sh
```
