# KeyVox Polished LoRA alpha-024

This Polished LoRA continuation starts from alpha-023 and focuses on teen-number age compound precision, especially phrases such as "eighteen year old" that were incorrectly collapsing to "8-year-old" in live inference.

## Inputs

- Dataset: `ModelTraining/datasets/polished/alpha-024-continuation-age-compounds`
- Prompt: `ModelTraining/prompts/polished/polished_runtime_short.txt`
- Config: `train_config.yaml`
- Resume checkpoint: `ModelTraining/artifacts/current/polished-lora-alpha-023/adapters/polished-alpha-023/adapters.safetensors`

## Outputs

- MLX adapter checkpoint: `ModelTraining/artifacts/current/polished-lora-alpha-024/adapters/polished-alpha-024/adapters.safetensors`
- Runtime GGUF: `ModelTraining/artifacts/current/polished-lora-alpha-024/adapters/polished-alpha-024/polished-alpha-024-lora.gguf`

## Run

From this folder:

```bash
./run_train.sh
```

The default model is:

```text
Qwen/Qwen2.5-0.5B-Instruct
```
