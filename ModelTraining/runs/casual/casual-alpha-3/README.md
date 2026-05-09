# KeyVox Casual LoRA casual-alpha-3

This pre-v1 Casual LoRA adapter is a targeted continuation from `casual-alpha-2`. It keeps the shared Casual/Chill cleanup behavior, preserves the spoken hour-minute fixes, and adds money-format guards after `casual-alpha-2` regressed a `$500` gauntlet case.

## Inputs

- Continuation dataset: `ModelTraining/datasets/casual/casual-alpha-3-continuation-time-money-guards`
- Prompt: `ModelTraining/prompts/casual/casual_runtime_short.txt`
- Config: `train_config.yaml`
- Base model: `Qwen/Qwen2.5-0.5B-Instruct`
- Resume adapter: `ModelTraining/artifacts/current/casual-lora-alpha-2/adapters/casual-alpha-2/adapters.safetensors`

## Outputs

- MLX adapter checkpoint: `ModelTraining/artifacts/current/casual-lora-alpha-3/adapters/casual-alpha-3/adapters.safetensors`
- Runtime GGUF: `ModelTraining/artifacts/current/casual-lora-alpha-3/adapters/casual-alpha-3/casual-alpha-3-lora.gguf`

## Run

From this folder:

```bash
./run_train.sh
```
