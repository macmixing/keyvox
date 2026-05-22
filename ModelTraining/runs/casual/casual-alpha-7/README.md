# KeyVox Casual LoRA alpha-7

This Casual LoRA continuation starts from casual-alpha-6 and broadens money plus spoken-time boundary coverage across contrast and plain start-time phrasing while preserving Casual voice.

## Inputs

- Dataset: `ModelTraining/datasets/casual/casual-alpha-7-continuation-money-time-coverage`
- Prompt: `ModelTraining/prompts/casual/casual_runtime_short.txt`
- Config: `train_config.yaml`
- Resume checkpoint: `ModelTraining/artifacts/archive/casual/casual-lora-alpha-6/adapters/casual-alpha-6/adapters.safetensors`

## Outputs

- MLX adapter checkpoint: `ModelTraining/artifacts/archive/casual/casual-lora-alpha-7/adapters/casual-alpha-7/adapters.safetensors`
- Runtime GGUF: `ModelTraining/artifacts/archive/casual/casual-lora-alpha-7/adapters/casual-alpha-7/casual-alpha-7-lora.gguf` converted with f32 precision.

## Run

From this folder:

```bash
./run_train.sh
```
