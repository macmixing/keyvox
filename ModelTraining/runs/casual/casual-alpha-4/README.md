# KeyVox Casual LoRA alpha-4

This Casual LoRA continuation starts from casual-alpha-3 and focuses on spoken 2010s year precision while preserving Casual voice.

## Inputs

- Dataset: `ModelTraining/datasets/casual/casual-alpha-4-continuation-spoken-years`
- Prompt: `ModelTraining/prompts/casual/casual_runtime_short.txt`
- Config: `train_config.yaml`
- Resume checkpoint: `ModelTraining/artifacts/current/casual-lora-alpha-3/adapters/casual-alpha-3/adapters.safetensors`

## Outputs

- MLX adapter checkpoint: `ModelTraining/artifacts/current/casual-lora-alpha-4/adapters/casual-alpha-4/adapters.safetensors`
- Runtime GGUF: `ModelTraining/artifacts/current/casual-lora-alpha-4/adapters/casual-alpha-4/casual-alpha-4-lora.gguf`

## Run

From this folder:

```bash
./run_train.sh
```
