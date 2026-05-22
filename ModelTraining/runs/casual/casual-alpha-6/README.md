# KeyVox Casual LoRA alpha-6

This Casual LoRA continuation starts from casual-alpha-5 and focuses on money negation boundaries, shortened-output prevention, and money plus spoken-time boundaries while preserving Casual voice.

## Inputs

- Dataset: `ModelTraining/datasets/casual/casual-alpha-6-continuation-money-negation-boundaries`
- Prompt: `ModelTraining/prompts/casual/casual_runtime_short.txt`
- Config: `train_config.yaml`
- Resume checkpoint: `ModelTraining/artifacts/archive/casual/casual-lora-alpha-5/adapters/casual-alpha-5/adapters.safetensors`

## Outputs

- MLX adapter checkpoint: `ModelTraining/artifacts/archive/casual/casual-lora-alpha-6/adapters/casual-alpha-6/adapters.safetensors`
- Runtime GGUF: `ModelTraining/artifacts/archive/casual/casual-lora-alpha-6/adapters/casual-alpha-6/casual-alpha-6-lora.gguf` converted with f32 precision.

## Run

From this folder:

```bash
./run_train.sh
```
