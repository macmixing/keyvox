# KeyVox Polished LoRA alpha-022

This rejected pre-v1 Polished LoRA adapter run was canceled before training because the target case did not match real post-processed dictation input.

## Inputs

- Dataset: not generated
- Prompt: `ModelTraining/prompts/polished/polished_runtime_short.txt`
- Config: `train_config.yaml`
- Resume checkpoint: `ModelTraining/artifacts/current/polished-lora-alpha-021/adapters/polished-alpha-021/adapters.safetensors`

## Outputs

No adapter artifacts were promoted.

## Run

From this folder:

```bash
./run_train.sh
```

The default model is:

```text
Qwen/Qwen2.5-0.5B-Instruct
```
