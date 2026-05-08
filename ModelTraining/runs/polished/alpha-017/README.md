# KeyVox Polished LoRA alpha-017

This is the current promoted pre-v1 Polished LoRA adapter run. It continues from alpha-010 and adds targeted `ain't` repair coverage plus live-regression guards.

## Inputs

- Dataset: `ModelTraining/datasets/polished/alpha-017-continuation-aint`
- Prompt: `ModelTraining/prompts/polished/polished_runtime_short.txt`
- Config: `train_config.yaml`
- Resume checkpoint: `ModelTraining/artifacts/archive/polished-lora-alpha-010/adapters/polished-alpha-010/adapters.safetensors`

## Outputs

- MLX adapter checkpoint: `ModelTraining/artifacts/archive/polished-lora-alpha-017/adapters/polished-alpha-017/adapters.safetensors`
- Runtime GGUF: `ModelTraining/artifacts/archive/polished-lora-alpha-017/adapters/polished-alpha-017/polished-alpha-017-lora.gguf`
- Bundled app resource: `Resources/LocalRewriteAdapters/polished-alpha-017-lora.gguf`

## Run

From this folder:

```bash
./run_train.sh
```

The default model is:

```text
Qwen/Qwen2.5-0.5B-Instruct
```
