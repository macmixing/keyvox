# KeyVox Polished LoRA alpha-023

This Polished LoRA continuation starts from alpha-021 and focuses on spoken 2010s year precision, especially phrases such as "twenty twelve" that were incorrectly collapsing to 2022 in live inference.

## Inputs

- Dataset: `ModelTraining/datasets/polished/alpha-023-continuation-spoken-years`
- Prompt: `ModelTraining/prompts/polished/polished_runtime_short.txt`
- Config: `train_config.yaml`
- Resume checkpoint: `ModelTraining/artifacts/current/polished-lora-alpha-021/adapters/polished-alpha-021/adapters.safetensors`

## Outputs

- MLX adapter checkpoint: `ModelTraining/artifacts/current/polished-lora-alpha-023/adapters/polished-alpha-023/adapters.safetensors`
- Runtime GGUF: `ModelTraining/artifacts/current/polished-lora-alpha-023/adapters/polished-alpha-023/polished-alpha-023-lora.gguf`

## Run

From this folder:

```bash
./run_train.sh
```

The default model is:

```text
Qwen/Qwen2.5-0.5B-Instruct
```
