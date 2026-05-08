# KeyVox Polished LoRA alpha-020

This archived pre-v1 Polished LoRA adapter run continues from alpha-019 and reinforces distinct paragraph meaning preservation.

## Inputs

- Dataset: `ModelTraining/datasets/polished/alpha-020-continuation-paragraph-meaning`
- Prompt: `ModelTraining/prompts/polished/polished_runtime_short.txt`
- Config: `train_config.yaml`
- Resume checkpoint: `ModelTraining/artifacts/archive/polished-lora-alpha-019/adapters/polished-alpha-019/adapters.safetensors`

## Outputs

- MLX adapter checkpoint: `ModelTraining/artifacts/archive/polished-lora-alpha-020/adapters/polished-alpha-020/adapters.safetensors`
- Runtime GGUF: `ModelTraining/artifacts/archive/polished-lora-alpha-020/adapters/polished-alpha-020/polished-alpha-020-lora.gguf`

## Run

From this folder:

```bash
./run_train.sh
```

The default model is:

```text
Qwen/Qwen2.5-0.5B-Instruct
```
