# KeyVox Polished LoRA alpha-019

This previously promoted pre-v1 Polished LoRA adapter run continues from alpha-018 and reinforces numeric conversion while preserving the paragraph-break coverage.

## Inputs

- Dataset: `ModelTraining/datasets/polished/alpha-019-continuation-numeric-paragraphs`
- Prompt: `ModelTraining/prompts/polished/polished_runtime_short.txt`
- Config: `train_config.yaml`
- Resume checkpoint: `ModelTraining/artifacts/rejected/polished-lora-alpha-018/adapters/polished-alpha-018/adapters.safetensors`

## Outputs

- MLX adapter checkpoint: `ModelTraining/artifacts/archive/polished-lora-alpha-019/adapters/polished-alpha-019/adapters.safetensors`
- Runtime GGUF: `ModelTraining/artifacts/archive/polished-lora-alpha-019/adapters/polished-alpha-019/polished-alpha-019-lora.gguf`
- Bundled app resource: none

## Run

From this folder:

```bash
./run_train.sh
```

The default model is:

```text
Qwen/Qwen2.5-0.5B-Instruct
```
