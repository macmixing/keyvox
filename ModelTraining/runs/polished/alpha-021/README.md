# KeyVox Polished LoRA alpha-021

This current pre-v1 Polished LoRA adapter run continues from alpha-020 and reinforces numeric precision inside long multi-paragraph text.

## Inputs

- Dataset: `ModelTraining/datasets/polished/alpha-021-continuation-long-numerics`
- Prompt: `ModelTraining/prompts/polished/polished_runtime_short.txt`
- Config: `train_config.yaml`
- Resume checkpoint: `ModelTraining/artifacts/archive/polished-lora-alpha-020/adapters/polished-alpha-020/adapters.safetensors`

## Outputs

- MLX adapter checkpoint: `ModelTraining/artifacts/current/polished-lora-alpha-021/adapters/polished-alpha-021/adapters.safetensors`
- Runtime GGUF: `ModelTraining/artifacts/current/polished-lora-alpha-021/adapters/polished-alpha-021/polished-alpha-021-lora.gguf`
- Bundled app resource: `Resources/LocalRewriteAdapters/polished-alpha-021-lora.gguf`

## Run

From this folder:

```bash
./run_train.sh
```

The default model is:

```text
Qwen/Qwen2.5-0.5B-Instruct
```
