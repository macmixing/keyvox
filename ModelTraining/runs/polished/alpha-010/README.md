# KeyVox Polished LoRA alpha-010

This is the base Polished LoRA training run used by the current alpha-017 continuation.

## Inputs

- Dataset: `ModelTraining/datasets/polished/alpha-010-base`
- Prompt: `ModelTraining/prompts/polished/polished_runtime_short.txt`
- Config: `train_config.yaml`

## Outputs

- MLX adapter checkpoint: `ModelTraining/artifacts/archive/polished-lora-alpha-010/adapters/polished-alpha-010/adapters.safetensors`
- Runtime GGUF: `ModelTraining/artifacts/archive/polished-lora-alpha-010/adapters/polished-alpha-010/polished-alpha-010-lora.gguf`

## Run

From this folder:

```bash
./run_train.sh
```

The default model is:

```text
Qwen/Qwen2.5-0.5B-Instruct
```
