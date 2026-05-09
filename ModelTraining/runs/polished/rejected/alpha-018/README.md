# KeyVox Polished LoRA alpha-018

This rejected pre-v1 Polished LoRA adapter run continues from alpha-017 and adds targeted paragraph-preservation coverage plus live-regression guards.

It fixed paragraph preservation but regressed numeric conversion in the live Polished suite, so it is kept only as lineage for alpha-019.

## Inputs

- Dataset: `ModelTraining/datasets/polished/rejected/alpha-018-continuation-paragraphs`
- Prompt: `ModelTraining/prompts/polished/polished_runtime_short.txt`
- Config: `train_config.yaml`
- Resume checkpoint: `ModelTraining/artifacts/archive/polished-lora-alpha-017/adapters/polished-alpha-017/adapters.safetensors`

## Outputs

- MLX adapter checkpoint: `ModelTraining/artifacts/rejected/polished-lora-alpha-018/adapters/polished-alpha-018/adapters.safetensors`
- Runtime GGUF: `ModelTraining/artifacts/rejected/polished-lora-alpha-018/adapters/polished-alpha-018/polished-alpha-018-lora.gguf`
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
