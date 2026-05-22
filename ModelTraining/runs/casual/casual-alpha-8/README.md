# KeyVox Casual LoRA alpha-8

This Casual LoRA continuation starts from casual-alpha-7 and focuses on numeric, comma-separated, and spoken address number guards so street addresses are not rewritten as times while nearby spoken times still format correctly.

## Inputs

- Dataset: `ModelTraining/datasets/casual/casual-alpha-8-continuation-address-time-guards`
- Prompt: `ModelTraining/prompts/casual/casual_runtime_short.txt`
- Config: `train_config.yaml`
- Resume checkpoint: `ModelTraining/artifacts/archive/casual/casual-lora-alpha-7/adapters/casual-alpha-7/adapters.safetensors`

## Outputs

- MLX adapter checkpoint: `ModelTraining/artifacts/current/casual-lora-alpha-8/adapters/casual-alpha-8/adapters.safetensors`
- Runtime GGUF: `ModelTraining/artifacts/current/casual-lora-alpha-8/adapters/casual-alpha-8/casual-alpha-8-lora.gguf` converted with f32 precision.

## Run

From this folder:

```bash
./run_train.sh
```
